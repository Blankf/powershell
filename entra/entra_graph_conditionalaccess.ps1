Connect-MgGraph -Scopes "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess", "Application.Read.All"

Get-MgIdentityConditionalAccessPolicy

$policy = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $PolicyID

$conditions = @{
  Applications   = @{
    includeApplications = 'All'
  }
  Users          = @{
    includeUsers = 'All'
    ExcludeUsers = @('a9bdf414-08a0-4aad-978a-90db7eb1a05a')
  }
  ClientAppTypes = @(
    'ExchangeActiveSync',
    'Other'
  )
}

$grantcontrols = @{
  #BuiltInControls = @('mfa', 'compliantDevice')
  BuiltInControls = @('mfa')
  Operator        = 'OR'
}

$name = "C001 - Block Legacy Authentication All Apps (Graph PowerShell)"
$state = "Disabled"

$conditionalAccessParams = @{
  DisplayName   = $name
  State         = $state
  Conditions    = $conditions
  GrantControls = $grantcontrols
}

New-MgIdentityConditionalAccessPolicy @conditionalAccessParams
