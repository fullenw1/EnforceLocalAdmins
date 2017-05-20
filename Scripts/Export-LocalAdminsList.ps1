function Export-LocalAdminsList
{
    <#
    .SYNOPSIS
        Creates a file with the member list of the local administrators group.
    .DESCRIPTION
        Creates a file with the member list of the local administrators group.
    .PARAMETER AdminListFile
        A file where the local administrators group list will be exported.
    .PARAMETER Overwrite
        If the destination file already exists it will be overwritten.
    .EXAMPLE
        Export the current member list of the local Administrators group to a specified file.
        If the file exists, it is not overwritten.

        PS C:>New-LocalAdminsList -AdminListFolder \\FileServerName\CentralRepositoryShare\myfile.txt
    .EXAMPLE
        Export the current member list of the local Administrators group to a specified file
        and overwrite the file if it already exists.

        PS C:>New-LocalAdminsList -AdminListFolder \\FileServerName\CentralRepositoryShare\myfile.txt -Overwrite
    .NOTES
        Requires Powershell 5.1 or later.
    #>
    
    [Alias("elal")]

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
            [Alias("adm")]
            [String]$AdminListFile,

            [Parameter(
                        Mandatory=$False,
                        HelpMessage="Don't overwrite an extisting file"
                      )
            ]
            [Alias("nocl")]
            [switch]$NoClobber=$False
        )

    Begin
    {
        #Requires -Version 5.1
        Set-StrictMode -Version Latest
    }

    Process
    {
        Write-Verbose -Message 'Listing Local Administrators group members...'

        #https://github.com/PowerShell/PowerShell/issues/2996
        #$ComputerLocalAdminsMemberList=(Get-LocalGroupMember -SID 'S-1-5-32-544').Name

        $GroupName=(Get-LocalGroup -SID 'S-1-5-32-544').Name
        $ComputerLocalAdminsMemberList=([ADSI]"WinNT://./$GroupName").psbase.Invoke('Members') |
                                       ForEach-Object {([ADSI]$_).InvokeGet('AdsPath') -replace '^WinNT://','' -replace '\/','\'}

        Write-Verbose -Message 'Creating the member list file...'

        $Parameters=@{
                            FilePath=$AdminListFile
                            InputObject=$ComputerLocalAdminsMemberList
                            NoClobber=$NoClobber
                            ErrorAction='Stop'
                        }

        Try
        {
            Out-File @Parameters
        }
        Catch
        {
            Throw "Unable to write to the $AdminListFile file!"
        }            
    }

    End
    {
    }
}
