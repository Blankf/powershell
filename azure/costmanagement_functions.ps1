
#https://github.com/Azure/azure-powershell/issues/12561
function Get-ConsumptionUsageDetail {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $SubscriptionId,

    [Parameter(Mandatory)]
    [ValidateSet('Legacy', 'Modern')]
    [string] $SubscriptionKind,

    [Parameter(Mandatory)]
    [datetime] $StartDate,

    [Parameter(Mandatory)]
    [datetime] $EndDate

  )

  $isLegacy = $SubscriptionKind -eq 'Legacy'

  $resource = 'https://management.azure.com'
  $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
  $accessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $resource).AccessToken

  $StartDate = $StartDate.Date.ToString('yyyy-MM-dd')
  $EndDate = $EndDate.Date.ToString('yyyy-MM-dd')
  $uriPath = "https://management.azure.com/subscriptions/$($SubscriptionId)/providers/Microsoft.Consumption/usageDetails"

  # https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/manage-automation#get-usage-details-for-a-scope-during-specific-date-range
  if ($isLegacy) {
    $uriQuery = '?$expand=properties/meterDetails&$filter=properties/usageStart ge ''' + $dateFilter + ''' and properties/usageEnd le ''' + $dateFilter + '''&$top=5000&api-version=2019-10-01'
  }
  else {
    $uriQuery = '?startDate=' + $StartDate + '&endDate=' + $EndDate + '&$top=5000&api-version=2019-10-01'
  }
  $uri = $uriPath + $uriQuery
  $consumptionDetailsRaw = Invoke-RestMethod -Method 'Get' -Uri $uri -Headers @{ Authorization = "Bearer " + $accessToken }

  $consumptionDetails = @()
  foreach ($detail in $consumptionDetailsRaw.value) {
    $convertedDetail = @{
      SubscriptionGuid             = if ($isLegacy) { $detail.properties.subscriptionId } else { $detail.properties.subscriptionGuid }
      InstanceName                 = if ($isLegacy) { $detail.properties.resourceName } else { ($detail.properties.instanceName -split '/')[-1] }
      AccountName                  = if ($isLegacy) { $detail.properties.accountName } else { $detail.properties.billingAccountName }
      DepartmentName               = if ($isLegacy) { $detail.properties.invoiceSection } else { $detail.properties.billingProfileName }
      additionalInfo               = $detail.properties.additionalInfo
      billingAccountId             = $detail.properties.billingAccountId
      billingCurrencyCode          = $detail.properties.billingCurrencyCode
      billingPeriodEndDate         = $detail.properties.billingPeriodEndDate
      billingPeriodStartDate       = $detail.properties.billingPeriodStartDate
      billingProfileId             = $detail.properties.billingProfileId
      chargeType                   = $detail.properties.chargeType
      consumedService              = $detail.properties.consumedService
      costInBillingCurrency        = $detail.properties.costInBillingCurrency
      costInPricingCurrency        = $detail.properties.costInPricingCurrency
      costCenter                   = $detail.properties.costCenter
      date                         = $detail.properties.date
      exchangeRate                 = $detail.properties.exchangeRate
      exchangeRateDate             = $detail.properties.exchangeRateDate
      invoiceId                    = $detail.properties.invoiceId
      invoiceSectionId             = $detail.properties.invoiceSectionId
      invoiceSectionName           = $detail.properties.invoiceSectionName
      isAzureCreditEligible        = $detail.properties.isAzureCreditEligible
      MeterDetails                 = @{
        meterId                 = $detail.properties.meterId
        MeterName               = $detail.properties.meterName
        meterRegion             = $detail.properties.meterRegion
        MeterCategory           = $detail.properties.meterCategory
        MeterSubCategory        = $detail.properties.meterSubCategory
        Unit                    = $detail.properties.unitOfMeasure
        MeterLocation           = $detail.properties.resourceLocation
        MeterLocationNormalized = $detail.properties.resourceLocationNormalized
      }
      pricingCurrencyCode          = $detail.properties.pricingCurrencyCode
      product                      = $detail.properties.product
      productIdentifier            = $detail.properties.productIdentifier
      productOrderId               = $detail.properties.productOrderId
      productOrderName             = $detail.properties.productOrderName
      publisherName                = $detail.properties.publisherName
      publisherType                = $detail.properties.publisherType
      quantity                     = $detail.properties.quantity
      resourceGroup                = $detail.properties.resourceGroup
      serviceFamily                = $detail.properties.serviceFamily
      servicePeriodEndDate         = $detail.properties.servicePeriodEndDate
      servicePeriodStartDate       = $detail.properties.servicePeriodStartDate
      subscriptionName             = $detail.properties.subscriptionName
      unitPrice                    = $detail.properties.unitPrice
      customerTenantId             = $detail.properties.customerTenantId
      customerName                 = $detail.properties.customerName
      partnerTenantId              = $detail.properties.partnerTenantId
      partnerName                  = $detail.properties.partnerName
      resellerMpnId                = $detail.properties.resellerMpnId
      resellerName                 = $detail.properties.resellerName
      publisherId                  = $detail.properties.publisherId
      reservationId                = $detail.properties.reservationId
      reservationName              = $detail.properties.reservationName
      frequency                    = $detail.properties.frequency
      term                         = $detail.properties.term
      PreTaxCost                   = if ($isLegacy) { $detail.properties.cost } else { $detail.properties.costInUSD }
      payGPrice                    = $detail.properties.payGPrice
      paygCostInBillingCurrency    = $detail.properties.paygCostInBillingCurrency
      #paygCostInUSD               = $detail.properties.paygCostInUSD.ToString('F20').TrimEnd('0')
      paygCostInUSD                = $detail.properties.paygCostInUSD
      exchangeRatePricingToBilling = $detail.properties.exchangeRatePricingToBilling
      partnerEarnedCreditRate      = $detail.properties.partnerEarnedCreditRate
      partnerEarnedCreditApplied   = $detail.properties.partnerEarnedCreditApplied
      tags                         = $detail.tags.PSObject.Properties | ForEach-Object { [PSCustomObject]@{
          Name  = $_.Name
          Value = $_.Value
        }
      }
    }
    $consumptionDetails += $convertedDetail
  }

  $consumptionDetails
}

function Get-CostsPerResourceGroup {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $SubscriptionId,
    [Parameter(Mandatory)]
    [ValidateSet('Legacy', 'Modern')]
    [string] $SubscriptionKind,
    [Parameter(Mandatory)]
    [datetime] $StartDate,
    [Parameter(Mandatory)]
    [datetime] $EndDate
  )

  $consumptionDetails = Get-ConsumptionUsageDetail -SubscriptionId $SubscriptionId -SubscriptionKind $SubscriptionKind -StartDate $StartDate -EndDate $EndDate
  $costsPerResourceGroup = $consumptionDetails | Group-Object -Property resourceGroup | ForEach-Object {
    $resourceGroup = $_.Name
    $totalCost = 0
    foreach ($item in $_.Group) {
      $totalCost += $item.costInBillingCurrency
    }
    [PSCustomObject]@{
      ResourceGroup = $resourceGroup
      TotalCost     = $totalCost
    }
  }
  $costsPerResourceGroup
}

function Get-CostsPerResource {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $SubscriptionId,
    [Parameter(Mandatory)]
    [ValidateSet('Legacy', 'Modern')]
    [string] $SubscriptionKind,
    [Parameter(Mandatory)]
    [datetime] $StartDate,
    [Parameter(Mandatory)]
    [datetime] $EndDate
  )
  $consumptionDetails = Get-ConsumptionUsageDetail -SubscriptionId $SubscriptionId -SubscriptionKind $SubscriptionKind -StartDate $StartDate -EndDate $EndDate
  $costsPerResource = $consumptionDetails | Group-Object -Property InstanceName | ForEach-Object {
    $resource = $_.Name
    $totalCost = 0
    foreach ($item in $_.Group) {
      $totalCost += $item.costInBillingCurrency
    }
    [PSCustomObject]@{
      Resource  = $resource
      TotalCost = $totalCost
    }
  }
  $costsPerResource
}

function Get-CostsPerResourceWithTag {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $SubscriptionId,
    [Parameter(Mandatory)]
    [ValidateSet('Legacy', 'Modern')]
    [string] $SubscriptionKind,
    [Parameter(Mandatory)]
    [datetime] $StartDate,
    [Parameter(Mandatory)]
    [datetime] $EndDate,
    [Parameter()]
    [string] $TagName,
    [Parameter(Mandatory)]
    [string] $TagValue
  )
  $consumptionDetails = Get-ConsumptionUsageDetail -SubscriptionId $SubscriptionId -SubscriptionKind $SubscriptionKind -StartDate $StartDate -EndDate $EndDate
  $filteredCostsPerResource = $consumptionDetails | Where-Object { $_.tags.Name -eq $TagName -or $_.tags.Value -eq $TagValue } | Group-Object -Property InstanceName | ForEach-Object {
    $resource = $_.Name
    $totalCost = 0
    foreach ($item in $_.Group) {
      $totalCost += $item.costInBillingCurrency
    }
    [PSCustomObject]@{
      Resource  = $resource
      TotalCost = $totalCost
    }
  }
  $filteredCostsPerResource
}
