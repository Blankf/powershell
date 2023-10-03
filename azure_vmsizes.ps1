$vmSizes = Get-AzComputeResourceSku | where { $_.ResourceType -eq 'virtualMachines' -and $_.Locations.Contains('westeurope') } 

#-- Get all vmsizes that support EncryptionAtHostSupported --#
foreach ($vmSize in $vmSizes) {
    foreach ($capability in $vmSize.capabilities) {
        if ($capability.Name -eq 'EncryptionAtHostSupported' -and $capability.Value -eq 'true') {
            $vmSize
        }
    }
}
#--------#
