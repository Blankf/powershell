function Get-AzureGroupCosts {
  param (
    [Parameter(Mandatory = $true, ParameterSetName = "Period")]
    [DateTime]$FromDate,
    [Parameter(Mandatory = $true, ParameterSetName = "Period")]
    [DateTime]$ToDate,
    [Parameter(Mandatory = $true, ParameterSetName = "Month")]
    [ValidateSet("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")]
    [string]$SelectedMonth,
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory = $false)]
    [ValidateSet("ServiceName", "ResourceGroupName")]
    [string]$GroupBy = "ResourceGroupName"
  )

  if ($selectedmonth) {
    $month = [DateTime]::ParseExact($SelectedMonth, "MMMM", $null)
    $FromDate = $month
    $ToDate = $month.AddMonths(1).AddSeconds(-1)
  }

  $resource = 'https://management.azure.com'
  $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
  $accessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $resource).AccessToken

  $jsonobject = @"
{
  "type": "ActualCost",
  "dataSet": {
  "granularity": "None",
  "aggregation": {
    "totalCost": {
    "name": "Cost",
    "function": "Sum"
    },
    "totalCostUSD": {
    "name": "CostUSD",
    "function": "Sum"
    }
  },
  "sorting": [
  {
    "direction": "descending",
    "name": "Cost"
  }
  ],
  "grouping": [
  {
    "type": "Dimension",
    "name": "$GroupBy"
  },
  {
    "type": "Dimension",
    "name": "SubscriptionId"
  }
  ]
  },
  "timeframe": "Custom",
  "timePeriod": {
    "from": "$($FromDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))",
    "to": "$($ToDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))"
  }
}
"@

  $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CostManagement/query?api-version=2023-03-01&top=5000"
  $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $AccessToken" } -Body $jsonobject -ContentType "application/json"

  $costs = @()
  $response.properties.rows | ForEach-Object {
    $object = [PSCustomObject]@{
      "TotalOriginalEUR" = $_[0]
      "TotalEUR"         = "{0:N2}" -f $_[0]
      "TotalOriginalUSD" = $_[1]
      "TotalUSD"         = "{0:N2}" -f $_[1]
      $GroupBy           = $_[2]
    }
    $costs += $object
  }

  return $costs
}

function Get-AzureTagCosts {
  param (
    [Parameter(Mandatory = $true, ParameterSetName = "Period")]
    [DateTime]$FromDate,
    [Parameter(Mandatory = $true, ParameterSetName = "Period")]
    [DateTime]$ToDate,
    [Parameter(Mandatory = $true, ParameterSetName = "Month")]
    [ValidateSet("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")]
    [string]$SelectedMonth,
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory = $true)]
    [string]$TagKey,
    [Parameter(Mandatory = $true)]
    [array]$TagValue
  )

  if ($selectedmonth) {
    $month = [DateTime]::ParseExact($SelectedMonth, "MMMM", $null)
    $FromDate = $month
    $ToDate = $month.AddMonths(1).AddSeconds(-1)
  }

  $resource = 'https://management.azure.com'
  $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
  $accessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $resource).AccessToken

  $TagValueObject = ConvertTo-Json $TagValue

  $jsonobject = @"
{
  "type": "ActualCost",
  "dataSet": {
  "granularity": "None",
  "aggregation": {
    "totalCost": {
    "name": "Cost",
    "function": "Sum"
    },
    "totalCostUSD": {
    "name": "CostUSD",
    "function": "Sum"
    }
  },
  "sorting": [
  {
    "direction": "descending",
    "name": "Cost"
  }
  ],
  "grouping": [
    {
      "type": "Tagkey",
      "name": "$TagKey"
    },
    {
      "type": "Dimension",
      "name": "ResourceGroupName"
    },
    {
      "type": "Dimension",
      "name": "ChargeType"
    },
    {
      "type": "Dimension",
      "name": "PublisherType"
    }
  ],
  "filter": {
    "Tags": {
      "Name": "$TagKey",
      "Operator": "In",
      "Values": $TagValueObject
    }
  }
  },
  "timeframe": "Custom",
  "timePeriod": {
    "from": "$($FromDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))",
    "to": "$($ToDate.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))"
  }
}
"@

  $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CostManagement/query?api-version=2023-03-01&top=5000"
  $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $AccessToken" } -Body $jsonobject -ContentType "application/json"

  $costs = @()
  $response.properties.rows | ForEach-Object {
    $object = [PSCustomObject]@{
      "TotalOriginalEUR" = $_[0]
      "TotalEUR"         = "{0:N2}" -f $_[0]
      "TotalOriginalUSD" = $_[1]
      "TotalUSD"         = "{0:N2}" -f $_[1]
      "TagKey"           = $_[3]
    }
    $costs += $object
  }

  return $costs
}
