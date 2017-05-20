function Import-LocalAdminsList
{
    <#
    .SYNOPSIS
        Applies a member list from a file to the local Administrators group.
    .DESCRIPTION
        Applies a member list from a file to the local Administrators group.
    .PARAMETER AdminListFile
        The path to a folder containing the file with the member list of the local administrators group.
        All members in the file list must be written in the following format <.|Computername|DomainName>\<SamAccountName>
    .EXAMPLE
        Apply the members list from the file to the local Administrators group.

        Import-LocalAdminsList -AdminListFolder \\FileServerName\CentralRepositoryShare\TabDelimitedFile.txt
    .NOTES
        Requires Powershell 5.1 or later.
    #>

    [Alias("ilal")]

    [CmdletBinding(SupportsShouldProcess=$True)]

    Param
        (
            [Parameter(
                        Mandatory=$True,
                        Position=0,
                        HelpMessage='Folder containing the file'
                       )
            ]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({Test-Path -Path $_})]
            [Alias("alp")]
            [String]$AdminListFile
        )

    Begin
    {
        #Requires -Version 5.1
        Set-StrictMode -Version Latest

        If($PSBoundParameters['Debug'])
        {$DebugPreference='Continue'}
    }

    Process
    {
        #region Process file
        Write-Verbose -Message 'Reading file...'

        $FileLocalAdminsMemberList=Get-Content -Path $AdminListFile

        If(-not($FileLocalAdminsMemberList))
        {
            Throw "The $AdminListFilePath file is empty!"
        }

        Write-Verbose 'Replacing dots by computernames...'

        for($ArrayItem=0
            $ArrayItem -lt $FileLocalAdminsMemberList.Length
            $ArrayItem++)
        {
            # Replace .\account with computername\account
            $FileLocalAdminsMemberList[$ArrayItem]=$FileLocalAdminsMemberList[$ArrayItem] -replace "^\.\\","$env:COMPUTERNAME\"
        }
        #endregion

        Write-Verbose -Message 'Getting members from the local Administrators group...'

        #https://github.com/PowerShell/PowerShell/issues/2996
        #$ComputerLocalAdminsMemberList=(Get-LocalGroupMember -SID 'S-1-5-32-544').Name

        $GroupName=(Get-LocalGroup -SID 'S-1-5-32-544').Name
        $ComputerLocalAdminsMemberList=([ADSI]"WinNT://./$GroupName").psbase.Invoke('Members') |
                                       ForEach-Object {([ADSI]$_).InvokeGet('AdsPath') -replace '^WinNT://','' -replace '\/','\'}

        #region Find members to add and to remove

        Write-Verbose 'Comparing lists...'

        $Params=@{
                    ReferenceObject=$FileLocalAdminsMemberList
                    DifferenceObject=$ComputerLocalAdminsMemberList
                 }

        $MembersToRemove=Compare-Object @Params| Where-Object -Property SideIndicator -EQ '=>'
        $MembersToAdd=Compare-Object @Params| Where-Object -Property SideIndicator -EQ '<='

        $DebugMessage="Members to remove:`n`r{0}" -f $MembersToRemove
        Write-Debug $DebugMessage
        $DebugMessage="Members to add:`n`r{0}" -f $MembersToAdd
        Write-Debug $DebugMessage
                
        #endregion

        #region Remove members
        foreach($Member in $MembersToRemove)
        {                
            $MemberName=$Member.InputObject
         
            If($PSCmdlet.ShouldProcess($MemberName,'Remove from the local Administrators group'))
            {
                Write-Output "Removing $MemberName from the local Administrators group..."

                $Parameters=@{
                                SID='S-1-5-32-544'
                                Member=$MemberName
                                Confirm=$false
                             }
                        
                Remove-LocalGroupMember @Parameters
            }
        }
        #endregion

        #region Add members 
        foreach($Member in $MembersToAdd)
        {
            $MemberName=$Member.InputObject
            
            If($PSCmdlet.ShouldProcess($MemberName,'Add to the local Administrators group'))
            {
                Write-Output "Adding $MemberName to the local Administrators group..."

                $Parameters=@{
                                SID='S-1-5-32-544'                                Member=$MemberName
                                Confirm=$false
                             }
                        
                Add-LocalGroupMember @Parameters
            }
        }
        #endregion

        If((-not($MembersToAdd)) -and (-not($MembersToRemove)))
        {
            Write-Output 'The Local Administrators group is already compliant with the file.'
        }
    }

    End{}
}
