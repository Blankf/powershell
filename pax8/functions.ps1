function Calculate-MarginPercentage {
  param (
    [Parameter(Mandatory = $true)]
    [decimal]$originalPrice,
    [Parameter(Mandatory = $true)]
    [decimal]$newPrice
  )

  $priceDifference = $newPrice - $originalPrice
  $marginPercentage = ($priceDifference / $originalPrice) * 100

  return $marginPercentage
}

function Get-Pax8InvoiceDetails {
  [CmdletBinding()]
  param(
  # Parameter help description
  [Parameter()]
  [array]$customers,
  [Parameter()]
  [switch]$includesummary,
  [Parameter()]
  [switch]$showsummary
  )

  $latestinvoice = Get-Pax8Invoice | Select-Object -First 1
  $invoice = Get-Pax8InvoiceItem -invoiceId $latestinvoice.id -all

  $customerlist = @()
  if ($customers) {
    $customerlist = $customers
  }
  elseif ($null -eq $customers) {
    $customersoninvoice = $invoice | Select-Object -ExpandProperty companyName -Unique
    $customerlist += $customersoninvoice
  }

  foreach ($customer in $customerlist) {
    $custinvoicedata = $invoice | Where-Object companyName -eq $customer
    #$totalcost = ($custinvoicedata | Measure-Object -Property costTotal -Sum).sum * 1.15
    $totalcost = ($custinvoicedata | Measure-Object -Property costTotal -Sum).sum
    $totalazurecosts = (($custinvoicedata | Where-Object { $_.details -match "(.*) - [\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12} - (.*)" }).costTotal | Measure-Object -Sum).sum
    $totallicensecosts = (($custinvoicedata | Where-Object { $_.details -notmatch "(.*) - [\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12} - (.*)" }).costTotal | Measure-Object -Sum).sum
    $totallicenseretail = (($custinvoicedata | Where-Object { $_.details -notmatch "(.*) - [\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12} - (.*)" }).total | Measure-Object -Sum).sum
    $totalcost = [math]::Round($totalcost, 2)
    $totalazurecosts = [math]::Round($totalazurecosts, 2)
    $totallicensecosts = [math]::Round($totallicensecosts, 2)
    $totallicenseretail = [math]::Round($totallicenseretail, 2)

    if (!($showsummary)) {

    # Generate a custom table with a calculated "total" property, a "subscription" property, and a "subscriptionName" property
    $custinvoicedata | Select-Object @{
      Name       = "description"
      Expression = {
        if ($_.description -match '(.*) - [\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12} - (.*)') {
          $Matches[3]
        }
        else {
          $_.description
        }
      }
    }, @{
      Name       = "AzureSubscriptionName"
      Expression = {
        if ($_.description -match '(.*) - [\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12} - (.*)') {
          $Matches[1] -replace 'Microsoft Azure Plan - Arrears Charge - ', ''
        }
        else {
          $null
        }
      }
    }, sku, quantity, cost, costTotal, @{
      Name       = "RetailPrice"
      Expression = {
        if ($_.price) {
          $_.price
        }
        else {
          $null
        }
      }
    }, @{
      Name       = "RetailTotal"
      Expression = {
        if ($_.total) {
          $_.total
        }
        else {
          $null
        }
      }
    }, @{
      Name       = "MarginPercentage"
      Expression = {
        if ($_.price -and $_.cost) {
          Calculate-MarginPercentage -originalPrice $_.cost -newPrice $_.price
        }
        else {
          $null
        }
      }
    }, @{
      Name       = "subscriptionID"
      Expression = {
        if ($_.description -match '[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}') {
          $Matches[0]
        }
        else {
          $null
        }
      }
    }
    }

    if ($includesummary -or $showsummary) {
      $invoiceSummary = [PSCustomObject]@{
        Customer           = $customer
        TotalAzureCosts    = $totalazurecosts
        TotalLicenseCosts  = $totallicensecosts
        TotalLicenseRetail = $totallicenseretail
        TotalCost          = $totalcost
      }

      return $invoiceSummary
    }
  }
}

function Get-Pax8InvoiceCustomers {
  $latestinvoice = Get-Pax8Invoice | select-object -First 1
  $invoice = Get-Pax8InvoiceItem -invoiceId $latestinvoice.id -all
  $customersoninvoice = $invoice | Select-Object -ExpandProperty companyName -Unique
  $customersoninvoice
}
