# Enable LAPS for your Entra Tenant

Connect-mggraph -scope "Policy.Read.All", "Policy.ReadWrite.DeviceConfiguration"

#$EntraPolicy = (Get-MgBetaPolicyDeviceRegistrationPolicy).tojsonstring()

# Create a splat for the device registration policy
$deviceRegistrationPolicySplat = @{
  'id'                           = 'deviceRegistrationPolicy'
  'description'                  = 'Tenant-wide policy that manages initial provisioning controls using quota restrictions, additional authentication and authorization checks'
  'displayName'                  = 'Device Registration Policy'
  'multiFactorAuthConfiguration' = '0'
  'userDeviceQuota'              = 10
  'azureADJoin'                  = @{
    'allowedGroups'       = @(
      'id1',
      'id2'
    )
    'allowedUsers'        = @('id1')
    'appliesTo'           = '2'
    'isAdminConfigurable' = $true
  }
  'azureADRegistration'          = @{
    'allowedGroups'       = @()
    'allowedUsers'        = @()
    'appliesTo'           = '1'
    'isAdminConfigurable' = $false
  }
  'localAdminPassword'           = @{
    'isEnabled' = $true
  }
}

# Convert the splat to JSON for readability
$jsonRepresentation = $deviceRegistrationPolicySplat | ConvertTo-Json

# Output the JSON representation
$jsonRepresentation

Invoke-MgGraphRequest -Url 'https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy' -Method PUT -Body $jsonRepresentation
