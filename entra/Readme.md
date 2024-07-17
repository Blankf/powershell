There is a small story to: ConfigureExchangeOnlineMSI.ps1

we were using managed identities with AzureDevops, and configure the proper rights to configure exchangeonline items.

```
$SPID = ""
$params = @{
    ServicePrincipalId = $SPID  # managed identity object id
    PrincipalId = $SPID  # managed identity object id
    ResourceId = (Get-MgServicePrincipal -Filter "AppId eq '00000002-0000-0ff1-ce00-000000000000'").id # Exchange online
    AppRoleId = "dc50a0fb-09a3-484d-be87-e023b12c6440" # Exchange.ManageAsApp
}
New-MgServicePrincipalAppRoleAssignedTo @params

Get-MgServicePrincipal -Filter "AppId eq '00000002-0000-0ff1-ce00-000000000000'" | Select-Object -ExpandProperty AppRoles | Format-Table Value,Id

$roleId = (Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Exchange Administrator'").id
New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $SPID -RoleDefinitionId $roleId -DirectoryScopeId "/"
```

the problem was that exchange online needs another access token then graph, hence we needed another get-aztoken but then for the outlook resource.
and solved it with this devops task.

```
  - task: AzurePowerShell@5
    displayName: 'Run Exchange Online PowerShell script'
    inputs:
      azureSubscription: 'tenantmanagementconnection'
      ScriptType: 'FilePath'
      ScriptPath: "${{ variables.workingdirectory }}/ExchangeOnline/New-YODAntiMalwarePolicy2.ps1"
      azurePowerShellVersion: 'LatestVersion'
      pwsh: true
```
