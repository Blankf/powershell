#Requires Pax8-API

function Get-Pax8InvoiceDetails {
  $latestinvoice = Get-Pax8Invoice | select -First 1
  $invoice = Get-Pax8InvoiceItem -invoiceId $latestinvoice.id -all
  $customersoninvoice = $invoice | select -ExpandProperty companyName -Unique

  foreach ($customer in $customersoninvoice) {
    $custinvoicedata = $invoice | Where-Object companyName -eq $customer
    $totalcost = ($custinvoicedata | Measure-Object -Property costTotal -Sum).sum * 1.15
    $totalcost = [math]::Round($totalcost, 2)

    Write-Output "################################"
    Write-Output "${customer}: $($totalcost)"
    Write-Output "################################"

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
    }, sku, quantity, price, @{
      Name       = "total"
      Expression = {
        $_.quantity * $_.price
      }
    }#, @{
    #   Name = "subscriptionID"
    #   Expression = {
    #     if ($_.description -match '[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}') {
    #       $Matches[0]
    #     } else {
    #       $null
    #     }
    #   }
    # }
  | Format-Table -AutoSize
  }
}
