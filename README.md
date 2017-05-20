# tl;dr or the short explanation
Only once export local administrators group members to a file on a central share

```Powershell
Export-LocalAdminsList -FilePath C:\Temp\ComputerName.txt
```

Then compare the file with the group

```Powershell
Compare-LocalAdminsList -FilePath \\FileServer\AdminLists$\ComputerName.txt
```

Or enforce the file to the group

```Powershell
Import-LocalAdminsList -FilePath \\FileServer\AdminLists$\ComputerName.txt
```

# The full explanation
## Environments targeted by this module
- Many servers have different local Administrators members
- Applicative teams have been granted administrators rights on some servers
and you want avoid them to add more accounts to the Administrators group
## Preparation steps
1. Copy the module to every local server (usually to C:\Program Files\Windows Powershell\Modules)
2. Export members of the local Administrators group to a file

```Powershell
Export-LocalAdminsList -FilePath C:\Temp\ComputerName.txt
```

3. Copy this file to a central  repository.

```Powershell
Copy-Item -Path C:\Temp\ComputerName.txt -Destination \\FileServer\Z$\AdminLists
```

## Monitor drifts
Schedule a Powershell script

```Powershell
Compare-LocalAdminsList -FilePath \\FileServer\AdminLists$\ComputerName.txt
```

## Enforce local administrators
Schedule a Powershell script

```Powershell
Import-LocalAdminsList -FilePath \\FileServer\AdminLists$\ComputerName.txt
```

## Additional considerations
### Requirements
This module is based on Powershell 5.1 cmdlets.
### Scheduled script
Depending on your needs, the script you schedule, to monitor drifts or enforce local administrators,
can send a mail and/or write an event in the eventlog (which can be monitored by SCOM or another tool).
### Warning about the central repository
Permissions on the central repository should be narrowed down
so that authorized people and computers have only permissions they need.

Typical permissions could look like this:

- Domain admins have Full Control permissions
- Computers accounts from computers using this module have Read Only permissions
- Computers accounts from computers not using this module have no access
- If applicable, you can add the Read-Write permissions on files
for people who manage matching computers
