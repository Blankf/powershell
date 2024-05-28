function Get-AzureGroupCosts {
  <#
.SYNOPSIS
  Retrieves Azure group costs based on specified parameters.

.DESCRIPTION
  The Get-AzureGroupCosts function retrieves Azure group costs based on the specified parameters. It uses the Azure Cost Management API to query the costs for a specific subscription and time period. The costs are grouped by either ServiceName or ResourceGroupName.

.PARAMETER FromDate
  The start date of the time period for which costs should be retrieved. This parameter is mandatory when using the "Period" parameter set.

.PARAMETER ToDate
  The end date of the time period for which costs should be retrieved. This parameter is mandatory when using the "Period" parameter set.

.PARAMETER SelectedMonth
  The name of the month for which costs should be retrieved. This parameter is mandatory when using the "Month" parameter set. Valid values are: January, February, March, April, May, June, July, August, September, October, November, December.

.PARAMETER SubscriptionId
  The ID of the Azure subscription for which costs should be retrieved. This parameter is mandatory.

.PARAMETER GroupBy
  The property by which the costs should be grouped. Valid values are: ServiceName, ResourceGroupName. The default value is ResourceGroupName.

.OUTPUTS
  An array of objects representing the costs for the specified group(s). Each object contains the following properties:
  - TotalOriginalEUR: The total cost in the original currency (EUR).
  - TotalEUR: The total cost in EUR formatted with two decimal places.
  - TotalOriginalUSD: The total cost in the original currency (USD).
  - TotalUSD: The total cost in USD formatted with two decimal places.
  - GroupBy: The value of the property used for grouping the costs (ServiceName or ResourceGroupName).

.EXAMPLE
  Get-AzureGroupCosts -FromDate "2022-01-01" -ToDate "2022-01-31" -SubscriptionId "12345678-1234-1234-1234-1234567890AB" -GroupBy "ResourceGroupName"
  Retrieves the costs for the specified time period (January 2022) and subscription, grouped by ResourceGroupName.

.EXAMPLE
  Get-AzureGroupCosts -SelectedMonth "February" -SubscriptionId "12345678-1234-1234-1234-1234567890AB" -GroupBy "ServiceName"
  Retrieves the costs for the specified month (February) and subscription, grouped by ServiceName.
#>
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
    [string]$GroupBy = "ResourceGroupName",
    [parameter(Mandatory = $false)]
    [switch]$Total
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

  if ($total) {
    $totalprice = ($costs.TotalEUR | Measure-Object -Sum).Sum / 100
    $price = '{0:C}' -f $totalprice
    return $price
  } else {
    return $costs
  }

}

function Get-AzureTagCosts {
<#
.SYNOPSIS
  Retrieves Azure costs based on specified parameters.

.DESCRIPTION
  The Get-AzureTagCosts function retrieves Azure costs based on the specified parameters. It uses the Azure Cost Management API to query cost data.

.PARAMETER FromDate
  Specifies the start date for the cost data. Mandatory when using the "Period" parameter set.

.PARAMETER ToDate
  Specifies the end date for the cost data. Mandatory when using the "Period" parameter set.

.PARAMETER SelectedMonth
  Specifies the month for the cost data. Mandatory when using the "Month" parameter set. Valid values are "January" through "December".

.PARAMETER SubscriptionId
  Specifies the Azure subscription ID.

.PARAMETER TagKey
  Specifies the key of the tag to filter the cost data.

.PARAMETER TagValue
  Specifies the value(s) of the tag to filter the cost data. Must be an array.

.OUTPUTS
  Returns an array of objects representing the cost data. Each object contains the following properties:
  - TotalOriginalEUR: The total cost in the original currency (EUR).
  - TotalEUR: The total cost in EUR formatted with two decimal places.
  - TotalOriginalUSD: The total cost in the original currency (USD).
  - TotalUSD: The total cost in USD formatted with two decimal places.
  - TagKey: The key of the tag associated with the cost data.

.EXAMPLE
  Get-AzureTagCosts -FromDate "2022-01-01" -ToDate "2022-01-31" -SubscriptionId "12345678-1234-1234-1234-1234567890AB" -TagKey "Environment" -TagValue @("Production", "Staging")

  Retrieves the Azure costs for the month of January 2022, filtered by the "Environment" tag with values "Production" and "Staging".

.EXAMPLE
  Get-AzureTagCosts -SelectedMonth "February" -SubscriptionId "12345678-1234-1234-1234-1234567890AB" -TagKey "Department" -TagValue @("Finance")

  Retrieves the Azure costs for the month of February, filtered by the "Department" tag with value "Finance".
#>

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

function Get-AllAzureAvailableTags {
<#
.SYNOPSIS
Retrieves all available Azure tags and their corresponding values.

.DESCRIPTION
The Get-AllAzureAvailableTags function retrieves all available Azure tags and their corresponding values. It uses the Get-AzTag cmdlet to retrieve the list of tags, and then iterates through each tag to retrieve its values. The function returns an array of custom objects, where each object represents a tag and its corresponding value.

.PARAMETER None
This function does not accept any parameters.

.EXAMPLE
Get-AllAzureAvailableTags

This example demonstrates how to use the Get-AllAzureAvailableTags function to retrieve all available Azure tags and their corresponding values.

.OUTPUTS
System.Object[]
The function returns an array of custom objects, where each object represents a tag and its corresponding value. Each object has the following properties:
- TagKey: The name of the tag.
- TagValue: The value of the tag.

.NOTES
This function requires the Az module to be installed. Make sure you have the latest version of the Az module installed before using this function.

.LINK
Get-AzTag
#>

  $keytags = Get-AzTag

  $tags = @()
  foreach ($tag in $keytags) {
    $tagValues = (Get-AzTag -Name $tag.name).values | Select-Object -ExpandProperty Name | Get-Unique
    foreach ($value in $tagValues) {
      $tagObject = [PSCustomObject]@{
        "TagKey"   = $tag.name
        "TagValue" = $value
      }
      $tags += $tagObject
    }
  }
  return $tags
}

function Get-AllAzureTags {
<#
.SYNOPSIS
Retrieves all Azure tags associated with resources in a specified subscription.

.DESCRIPTION
The `Get-AllAzureTags` function retrieves all Azure tags associated with resources in a specified subscription. It uses the Azure Management API to authenticate and retrieve the tags.

.PARAMETER SubscriptionId
The ID of the Azure subscription for which to retrieve the tags.

.EXAMPLE
Get-AllAzureTags -SubscriptionId "12345678-90ab-cdef-ghij-klmnopqrstuv"
This example retrieves all Azure tags associated with resources in the specified subscription.

.INPUTS
None. You cannot pipe objects to this function.

.OUTPUTS
[System.Management.Automation.PSCustomObject[]]
An array of custom objects representing the Azure tags. Each object has two properties: "Key" and "Value".

.NOTES
This function requires the Azure PowerShell module to be installed and authenticated with a valid Azure account.

.LINK
https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers

#>
  param (
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId
  )

  $resource = 'https://management.azure.com'
  $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
  $accessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $resource).AccessToken

  $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resources?api-version=2021-04-01"
  $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{Authorization = "Bearer $accessToken" }

  $tagList = @()
  $newlist = @()

  foreach ($item in $response.value) {
    if (!([string]::IsNullOrEmpty($item.tags))) {
      $newlist += $item.tags | Where-Object { $_ -notlike "*hidden*" -and $_ -notlike "*cm-resource*" }
    }
  }

  foreach ($i in $newlist) {
    foreach ($property in $i.PSObject.Properties) {
      $tagList += [PSCustomObject]@{
        "Key"   = $property.Name
        "Value" = $property.Value
      }
    }
  }

  return $tagList | Sort-Object -Property Value | Get-Unique -AsString

}
