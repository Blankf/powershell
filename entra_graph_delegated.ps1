# ---- Creating a new delegated permission ---- # 
Import-Module Microsoft.Graph.Identity.SignIns
Import-Module Microsoft.Graph.Applications
import-module Microsoft.Graph.Users

$clientAppId = ""
$clientAppName = ""
$permissions = @("offline_access", "User.Read", "Files.ReadWrite")
$scopeToGrant = $permissions -join " "

Connect-MgGraph -Scopes "Application.ReadWrite.All", "User.Read.All", "AppRoleAssignment.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All"

# Step 1. Check if a service principal exists for the client application. 
$clientsp = Get-MgServicePrincipal -Filter "displayName eq '$($clientAppName)'"
or
$clientSp = Get-MgServicePrincipal -Filter "appId eq '$($clientAppId)'"


# Step 2. Get the information for the GraphAPI
$GraphApi = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'"

# Step 3. Create a delegated permission that grants the client app access to the
#     API, on behalf of the user. (This example assumes that an existing delegated 
#     permission grant does not already exist, in which case it would be necessary 
#     to update the existing grant, rather than create a new one.)
$params = @{
  "ClientId"    = $clientsp.id
  "ConsentType" = "AllPrincipals"
  "ResourceId"  = $GraphApi.id
  "Scope"       = $scopeToGrant
}
New-MgOauth2PermissionGrant -BodyParameter $params | 
Format-List Id, ClientId, ConsentType, ExpiryTime, PrincipalId, ResourceId, Scope

# ----- Adding a delegated permission ---- #

$clientAppName = ""
$permissions = @("User.Read.All")
$PermissionsToAdd = $permissions -join " "

# Step 1. Check if a service principal exists for the client application. 
$clientsp = Get-MgServicePrincipal -Filter "displayName eq '$($clientAppName)'"

# Step 2. select the delegation that is for "AllPrincipals"
$updgrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($clientsp.id)' and consentType eq 'AllPrincipals'"

# Step 3. Add the permissions
$newscope = $($updgrant.Scope) + " " + $PermissionsToAdd

# Step 4. Apply the new scopes.
Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $updgrant.Id -Scope $newscope

# ----- Remove a delegated permission ---- #

$clientAppName = ""
$permissionsToRemove = @("User.Read.All","Group.Read.All")

# Step 1. Check if a service principal exists for the client application. 
$clientsp = Get-MgServicePrincipal -Filter "displayName eq '$($clientAppName)'"

# Step 2. select the delegation that is for "AllPrincipals"
$updgrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($clientsp.id)' and consentType eq 'AllPrincipals'"

# Step 3. Add the permissions
$temp = $updgrant.Scope -split " "
$filteredPermissions = $temp | Where-Object { $_ -notin $permissionsToRemove }
$newscope = $filteredPermissions -join " "

# Step 4. Apply the new scopes.
Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $updgrant.Id -Scope $newscope

# ----- Remove the whole grant ---- #

$clientAppName = ""

# Step 1. Check if a service principal exists for the client application. 
$clientsp = Get-MgServicePrincipal -Filter "displayName eq '$($clientAppName)'"

# Step 2. select the delegation that is for "AllPrincipals"
$updgrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($clientsp.id)' and consentType eq 'AllPrincipals'"

# Step 3. Remove the whole grant
Remove-MgOauth2PermissionGrant -OAuth2PermissionGrantId $updgrant.Id
