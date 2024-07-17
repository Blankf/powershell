[CmdletBinding()]
param (
    [switch]$CleanupOldPolicies = $true,
    [string]$Version = "3.1"
)

$GraphAccessToken = (Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com').Token
$ExchangeAccessToken = (Get-AzAccessToken -ResourceUrl 'https://outlook.office365.com').Token

# Connect with Managed Identity
try {
    $Token = ConvertTo-SecureString -String $($GraphAccessToken) -AsPlainText -Force
    Connect-MgGraph -AccessToken $Token -NoWelcome -ErrorAction Stop
}

catch {
    Write-Host "ERROR: Failed to connect to Managed Graph. Please check your access token and ensure you have the correct permissions."
    return
}

# Collect all the domains
if (-not($domains)) {
    Write-host "INFO: Collecting all registered domains..."
    try {
        $domains = (Get-MgDomain).id
    }
    catch {
        Write-host "ERROR: Failed to retrieve domains. Please ensure you are connected to mggraph or have the correct permissions."
        return
    }
}

# Connect to Exchange Online
try {
    $OnMicrosoftDomain = $domains | Where-Object { $_ -like "*.onmicrosoft.com" }
    Connect-ExchangeOnline -AccessToken $ExchangeAccessToken -Organization $OnMicrosoftDomain -ErrorAction Stop
}
catch {
    Write-Error "$_.Exception.Message"
    return
}

$AntiMalwareFilterName = "Anti-Malware Policy"
$AntimalwarePolicyNameWithVersion = "$AntiMalwareFilterName $Version"

# Get the Existing Anti-Malware Policy
$Existing_AntiMalwarePolicies = Get-MalwareFilterPolicy | Where-Object { $_.IsDefault -ne $true -and $_.Name -match $AntiMalwareFilterName } | Sort-Object -Property WhenCreated

foreach ($AntimalwarePolicy in $Existing_AntiMalwarePolicies) {
    #Check version
    $Existing_Version = (($AntimalwarePolicy.name).split(" ")[-1])

    # Check if the policy is enabled based on the rule
    $Rule = Get-MalwareFilterRule -Identity $AntimalwarePolicy.name

    if ($rule.state -eq "Enabled" -and $Existing_Version -ne $Version) {
        Write-host "INFO: $($AntimalwarePolicy.name) is not the latest version. Disabling the policy and rule."

        # Disable malware rule
        $AntimalwarePolicy | Disable-MalwareFilterRule -Confirm:$false

        if ($?) {
            Write-Host "INFO: Successfully disabled $($AntimalwarePolicy.Name)"
        }
        else {
            Write-Host "ERROR: Failed to disable $($AntimalwarePolicy.Name)"
        }

    }
    elseif ($rule.state -eq "Enabled" -and $Existing_Version -eq $Version) {
        Write-host "INFO: $($AntimalwarePolicy.name) is the latest version. Skipping the creation of the policy."
        return
    }
}



# Create the Anti-Malware Policy and Rule Set
$BlockFileTypes = @("ace", "apk", "app", "appx", "ani", "arj", "bat", "cab", "cmd", "com", "deb", "dex", "dll", "docm", "elf", "exe", "hta", "img", "iso", "jar", "jnlp", "kext", "lha", "lib", "library", "lnk", "lzh", "macho", "msc", "msi", "msix", "msp", "mst", "pif", "ppa", "ppam", "reg", "rev", "scf", "scr", "sct", "sys", "uif", "vb", "vbe", "vbs", "vxd", "wsc", "wsf", "wsh", "xll", "xz", "z")

$AntimalwarePolicySet = @{
    Name                                   = $AntimalwarePolicyNameWithVersion
    CustomNotifications                    = $false
    EnableExternalSenderAdminNotifications = $false
    EnableFileFilter                       = $true
    EnableInternalSenderAdminNotifications = $false
    FileTypeAction                         = "Reject"
    FileTypes                              = ($BlockFileTypes).Split(",")
    QuarantineTag                          = "AdminOnlyAccessPolicy"
    RecommendedPolicyType                  = "Custom"
    ZapEnabled                             = $true
}

Write-host "INFO: Creating $AntimalwarePolicyNameWithVersion and Rule Set"
$Created_PolicySet = New-MalwareFilterPolicy @AntimalwarePolicySet

$AntiMalwareRuleSet = @{
    Name                = $AntimalwarePolicyNameWithVersion
    MalwareFilterPolicy = $AntimalwarePolicyNameWithVersion
    Priority            = 0
    RecipientDomainIs   = ($domains).split(",")
}

$Created_RuleSet = New-MalwareFilterRule @AntiMalwareRuleSet

if ($Created_PolicySet -and $Created_RuleSet) {
    Write-host "INFO: Successfully created $AntimalwarePolicyNameWithVersion Policy and Rule Set."
}
else {
    Write-host "ERROR: Something went wrong. Please check the output for more information."
}


if ($CleanupOldPolicies) {

    # collect all the Anti-Phishing Policies after the new policy is created
    $Existing_AntiMalwarePolicies = Get-MalwareFilterPolicy | Where-Object { $_.IsDefault -ne $true -and $_.Name -match $AntiMalwareFilterName } | Sort-Object -Property WhenCreated -Descending
    # Clean up older versions of the Anti-Phishing Policy
    if ($Existing_AntiMalwarePolicies.Count -gt 2) {
        $RemoveOlderPolicies = $Existing_AntiMalwarePolicies | Sort-Object -Property WhenCreated -Descending | Select-Object -Skip 2

        foreach ($OlderPolicy in $RemoveOlderPolicies) {
            Write-host "CLEAN UP: Removing $($OlderPolicy.Name)"
            $OlderPolicy | Remove-MalwareFilterRule -Confirm:$false
            $OlderPolicy | Remove-MalwareFilterPolicy -Confirm:$false
        }
    }
}
else {
    Write-Host "CLEAN UP: Skipping the cleanup of older versions of $antiPhishingPolicyName"
}

# # Bulk Delete
# #Disable malware rule
# Get-MalwareFilterPolicy | Where-Object {$_.IsDefault -ne $true} | Disable-MalwareFilterRule -Confirm:$false

# #Remove malware rule and policy
# Get-MalwareFilterPolicy | Where-Object {$_.IsDefault -ne $true} | Remove-MalwareFilterRule -Confirm:$false
# Get-MalwareFilterPolicy | Where-Object {$_.IsDefault -ne $true}| Remove-MalwareFilterPolicy -Confirm:$false
