Import-Module MSAL.PS

# Login with Managed identity, fetch the tokens and contstruct a authentication header for Graph
# Specific used now for IntuneWin32App Module

az login --identity --username '%%ID%%'
$AccessToken = az account get-access-token --resource-type ms-graph
$AccessToken = $AccessToken | ConvertFrom-Json

$GraphApiAccessToken = $AccessToken.accessToken
$AccessTokenExpiresOn = [system.datetimeoffset]$AccessToken.expiresOn
$AccessTokenExtendedExpiresOn = [system.datetimeoffset]$AccessToken.expiresOn
$Global:AccessToken = [Microsoft.Identity.Client.AuthenticationResult]::new($GraphApiAccessToken, $false, $null, $AccessTokenExpiresOn, $AccessTokenExtendedExpiresOn, $TenantId, $null, $null, $null, [Guid]::NewGuid(), $null, "Bearer")

$AuthenticationHeader = @{
    "Content-Type" = "application/json"
    "Authorization" = $AccessToken.CreateAuthorizationHeader()
    "ExpiresOn" = $AccessToken.ExpiresOn.UTCDateTime
}
