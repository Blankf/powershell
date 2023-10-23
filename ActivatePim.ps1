# Once with PIM to gather the proper rights
# Connect-MgGraph -scope "RoleEligibilitySchedule.ReadWrite.Directory","RoleManagement.ReadWrite.Directory","RoleManagement.Read.All","Group.Read.All","User.Read.All", "AppRoleAssignment.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All"

Function Activate-Pim {
  Param(
    [int]$Time = 4
  )

  Import-Module Microsoft.Graph.Authentication
  Import-Module Microsoft.Graph.Identity.Governance

  Connect-MgGraph
  $context = Get-MgContext
  $currentUser = (Get-MgUser -UserId $context.Account).Id
  $myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$currentuser'"

  Write-Host "Choose one of the following roles:"
  $results = @()
  for ($i = 0; $i -lt $myroles.Count; $i++) {
    Write-Host "$($i + 1): $($($myroles.RoleDefinition.DisplayName)[$i])"
    $obj = New-Object System.Object
    $obj | Add-Member -Type NoteProperty -Name Number -Value $($i + 1)
    $obj | Add-Member -Type NoteProperty -Name Role -Value $($($myroles.RoleDefinition.DisplayName)[$i])
    $obj | Add-Member -Type NoteProperty -Name RoleId -Value $($($myroles.RoleDefinition.id)[$i])
    $obj | Add-Member -Type NoteProperty -Name DirId -Value $($($myroles.DirectoryScopeId)[$i])
    $results += $obj
  }
  $choice = Read-Host "Enter the number of the object you want to choose"
  $myRole = ($results | Where-Object { $_.Number -eq $choice })

  $params = @{
    Action           = "selfActivate"
    PrincipalId      = $currentUser
    RoleDefinitionId = $myRole.RoleId
    DirectoryScopeId = $myRole.DirId
    Justification    = "Enable $($myRole.Role) role"
    ScheduleInfo     = @{
      StartDateTime = Get-Date
      Expiration    = @{
        Type     = "AfterDuration"
        Duration = "PT$($Time)H"
      }
    }
  }

  New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
}
