Function Update-HaloRecuringInvoiceAzureCosts {
  <#
  .SYNOPSIS
  Updates the recurring invoice for a customer in the Halo system.

  .DESCRIPTION
  This function updates the recurring invoice for a customer in the Halo system. It retrieves the client ID based on the provided customer name or the specified client ID. If the client ID is not provided, it will be retrieved based on the customer name.

  .PARAMETER AzureCosts
  The new value for the Azure costs.

  .PARAMETER Customer
  The name of the customer. Either the customer name or the client ID must be specified.

  .PARAMETER ClientID
  The ID of the client. Either the customer name or the client ID must be specified.

  .EXAMPLE
  Update-HaloRecuringInvoice -AzureCosts 1000 -Customer "Contoso"

  .EXAMPLE
  Update-HaloRecuringInvoice -AzureCosts 1000 -ClientID "12345"
  #>

  param (
    [Parameter(Mandatory = $true)]
    $AzureCosts,
    [Parameter(Mandatory = $true, ParameterSetName = "Customer")]
    [String]$Customer,
    [Parameter(Mandatory = $true, ParameterSetName = "ClientId")]
    [String]$ClientID
  )

  $Azurecosts = [decimal]::Parse($AzureCosts, [System.Globalization.CultureInfo]::GetCultureInfo("en-US"))

  if (!($ClientID)) {
    $HaloClients = Get-HaloClient
    $ClientId = $HaloClients | where-object { $_.Name -eq $Customer } | Select-Object -ExpandProperty Id
  }

  $Invoice = Get-HaloRecurringInvoice -ClientID $ClientId -includeLines
  ($invoice.lines | Where-Object { $_.nominal_code -eq 'AZU001' }).unit_price = $AzureCosts
  $output = Set-HaloRecurringInvoice -RecurringInvoice $Invoice

  if ($output) {
    Write-Output "Recurring invoice updated successfully."
  }
  else {
    Write-Output "Failed to update recurring invoice."
  }

}
