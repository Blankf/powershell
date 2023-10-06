Import-Module Microsoft.Graph.Identity.SignIns
Import-Module Microsoft.Graph.Applications
import-module Microsoft.Graph.Users

$clientAppId = ""
$userUpnOrIds = @()
$resourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph API
$permissions = @("offline_access", "User.Read", "Files.ReadWrite")

$MgGraphParams = @{
    Scopes = "User.ReadBasic.All Application.ReadWrite.All",
    "DelegatedPermissionGrant.ReadWrite.All",
    "AppRoleAssignment.ReadWrite.All"
}
Connect-MgGraph @MgGraphParams

# Step 1. Check if a service principal exists for the client application. 
#     If one doesn't exist, create it.
$clientSp = Get-MgServicePrincipal -Filter "appId eq '$($clientAppId)'"
if (-not $clientSp) {
   $clientSp = New-MgServicePrincipal -AppId $clientAppId
}

# Step 2. Create a delegated permission that grants the client app access to the
#     API, on behalf of the user. (This example assumes that an existing delegated 
#     permission grant does not already exist, in which case it would be necessary 
#     to update the existing grant, rather than create a new one.)
foreach ($userUpnOrId in $userUpnOrIds) {
  $user = Get-MgUser -UserId $userUpnOrId
  $resourceSp = Get-MgServicePrincipal -Filter "appId eq '$($resourceAppId)'"
  $scopeToGrant = $permissions -join " "
  $GrantParams = @{
      ResourceId     = $resourceSp.Id
      Scope          = $scopeToGrant
      ClientId       = $clientSp.Id
      ConsentType    = "Principal"
      PrincipalId    = $user.Id
  }
  $grant = New-MgOauth2PermissionGrant @GrantParams
}

# Step 3. Assign the app to the user. This ensures that the user can sign in if assignment
#     is required, and ensures that the app shows up under the user's My Apps portal.
$warningMessage = @"
A default app role assignment cannot be created because the client application
exposes user-assignable app roles. You must assign the user a specific app role
for the app to be listed in the user's My Apps access panel.
"@

foreach ($userUpnOrId in $userUpnOrIds) {
  if ($clientSp.AppRoles | Where-Object { $_.AllowedMemberTypes -contains "User" }) {
    Write-Warning $warningMessage
  }
  else {
    # The app role ID 00000000-0000-0000-0000-000000000000 is the default app role
    # indicating that the app is assigned to the user, but not for any specific 
    # app role.
    $user = Get-MgUser -UserId $userUpnOrId
    $AssignmentParams = @{
      ServicePrincipalId = $clientSp.Id
      ResourceId         = $clientSp.Id
      PrincipalId        = $user.Id
      AppRoleId          = "00000000-0000-0000-0000-000000000000"
    }

    # Create a new service principal app role assignment using splatting
    $assignment = New-MgServicePrincipalAppRoleAssignedTo @AssignmentParams
  }
}
