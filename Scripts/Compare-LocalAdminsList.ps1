function Compare-LocalAdminsList
{
    <#
    .SYNOPSIS
        Verifies if the member list from the local administrators group is compliant with the list from a text file.
    .DESCRIPTION
        Verifies if the member list from the local administrators group is compliant with the list from the text file.
    .PARAMETER AdminListFile
        A file with the member list of the local administrators group.
        All members in the file list must be written in the following format <.|Computername|DomainName>\<SamAccountName>
    .PARAMETER ValidateLocalMembers
        Local groups and users from the file are validated.
        Domain groups and users are not validated.
    .EXAMPLE
        Test the compliance of the local Administrators group members with the file.
        
        PS C:\>Compare-LocalAdminsList -AdminListFolder \\FileServerName\CentralRepositoryShare\mylist.txt
    .EXAMPLE
        Test the compliance of the local Administrators group members with the file and validate local members which should be added.
        
        PS C:\>Compare-LocalAdminsList -AdminListFolder \\FileServerName\CentralRepositoryShare\mylist.txt -ValidateLocalMembers
    .NOTES
        Requires Powershell 5.1 or later.
    #>

    [Alias('clal')]

    [CmdletBinding()]

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
            [Alias("adm")]
            [String]$AdminListFile,

            [Parameter(
                        Mandatory=$False,
                        HelpMessage='Validate local users and/or groups'
                       )
            ]
            [Alias("val")]
            [Switch]$ValidateLocalMembers=$False
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
        $ComputerName=$env:COMPUTERNAME

        #region Process file
        Write-Verbose -Message 'Reading file...'

        $FileLocalAdminsMemberList=Get-Content -Path $AdminListFile

        If(-not($FileLocalAdminsMemberList))
        {
            Throw "The $AdminListFile file is empty!"
        }

        Write-Verbose 'Replacing dots by computer names...'

        for($ArrayItem=0
            $ArrayItem -lt $FileLocalAdminsMemberList.Length
            $ArrayItem++)
        {
            # .\account is replaced by computername\account
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
        
        $ListOfMembersToRemove=Compare-Object @Params| Where-Object -Property SideIndicator -EQ '=>'
        $ListOfMembersToAdd=Compare-Object @Params| Where-Object -Property SideIndicator -EQ '<='

        $DebugMessage="Members to remove:`n`r{0}" -f $ListOfMembersToRemove
        Write-Debug $DebugMessage
        $DebugMessage="Members to add:`n`r{0}" -f $ListOfMembersToAdd
        Write-Debug $DebugMessage
        
        foreach($Member in $ListOfMembersToRemove)
        {
            $MemberToRemove=$Member.InputObject
            $Message="{0} should be removed" -f $MemberToRemove
            Write-Output $Message
        }

        foreach($Member in $ListOfMembersToAdd)
        {
            $MemberToAdd=$Member.InputObject
            $Message="{0} should be added" -f $MemberToAdd
            Write-Output $Message

            #region Check if file members to add exist on local computer
            If($ValidateLocalMembers)
            {
                Write-Verbose -Message 'Validating the $Member member...'

                If($MemberToAdd -match "^$env:COMPUTERNAME\\")
                {
                    $LocalMemberName=$MemberToAdd -replace "^$env:COMPUTERNAME\\",""

                    Try
                    {
                        $Null=Get-LocalGroup -Name $LocalMemberName -ErrorAction Stop
                    }
                    Catch
                    {
                        Try
                        {
                            $Null=Get-LocalUser -Name $LocalMemberName -ErrorAction Stop
                        }
                        Catch
                        {
                            Write-Warning -Message "$MemberToAdd is not a valid member"
                        }
                    }
                }
            }
            #endregion
        }
        #endregion

        If((-not($ListOfMembersToAdd)) -and (-not($ListOfMembersToRemove)))
        {
            Write-Output 'The Local Administrators group is already compliant with the file.'
        }
    }

    End
    {
    }
}