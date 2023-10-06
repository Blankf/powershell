#Requires -Modules @{ModuleName="Okta.Core.Automation";ModuleVersion="1.0.1"},AzureADPreview

Import-Module AzureADPreview
Import-Module Okta.Core.Automation

$VerbosePreference = 'Continue'
$baseurl = ''

#Groups information.
$GroupIdentity = ''
$RoleListToApply = 'Global Administrator', 'Privileged Role Administrator', 'Intune Administrator', 'Security Administrator', 'Application Administrator'

### Okta Token object.
$TokenObject = Get-AutomationPSCredential -Name 'OktaToken'
$token = $TokenObject.GetNetworkCredential().Password

$GraphTokenObject = Get-AutomationPSCredential -Name 'azuread_app_pim'
$GraphTokenPassword = $GraphTokenObject.GetNetworkCredential().Password | ConvertTo-SecureString -AsPlainText -force
[pscredential]$AzureAdCred = New-Object System.Management.Automation.PSCredential ($GraphTokenObject.UserName, $GraphTokenPassword)

# Set the schedule that's used later in the role assignment request - no end time means a permanent assignment
$schedule = New-Object Microsoft.Open.MSGraph.Model.AzureADMSPrivilegedSchedule
$schedule.Type = "Once"
$schedule.StartDateTime = "2021-03-12T09:00:00.000Z"

########### Lets go

function Get-UsersinPIMRole {
  [CmdletBinding()]
  param (
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [String]
    $PimRoleId,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [String]
    $tenantid
  )
  [array]$Allowedtobein = 'test1@domain.onmicrosoft.com', 'test2@domain.onmicrosoft.com'
  $UsersAssigned = (Get-AzureADMSPrivilegedRoleAssignment -ProviderId aadRoles -ResourceId $tenantid -Filter "RoleDefinitionId eq '$($PimRoleId)' AND AssignmentState eq 'Eligible'")
  $usersinGroup = @()
  foreach ($id in $UsersAssigned) {
    $user = Get-AzureADUser -ObjectId $id.SubjectId
    $usersinGroup += $user | where-object { $user.userPrincipalName -notin $allowedtobein }
  }
  Write-Output $usersinGroup
}

Function Sync-PIMUsers {
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline = $True, Position = 0, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [PSObject]$OktaSourceGroup,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [PSObject]$PimRoleId,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    [string]$tenantid,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)]
    $schedule,
    [Switch]$Mirror
  )
  Write-Verbose $PimRoleID
  Write-Verbose $OktaSourceGroup
  Try { $SourceMembers = @(Get-OktaGroupMember -IdOrName $OktaSourceGroup) } Catch { Throw $_ }
  Try { $TargetMembers = @(Get-UsersinPIMRole -PimRoleId $PimRoleId -tenantid $tenantid) } Catch { Throw $_ }
  If ($SourceMembers) {
    If ($DifferenceMembers = Compare-Object -ReferenceObject $($SourceMembers.profile.login) -DifferenceObject $($TargetMembers.userPrincipalName)) {
      $ProcessMembers = $DifferenceMembers | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject
      foreach ($member in $ProcessMembers) {
        $usersubjid = (Get-AzureADUser -Filter "userPrincipalName eq '$member'").ObjectId
        Open-AzureADMSPrivilegedRoleAssignmentRequest -ProviderId 'aadRoles' -ResourceId $tenantid -RoleDefinitionId $PimRoleId -SubjectId $usersubjid -Type 'adminAdd' -AssignmentState 'Eligible' -schedule $schedule
        Write-Output "Adding '$($member)' to '$($PimRoleID)'"
      }
    }
    if ($Mirror) {
      $ProcessMembers = $DifferenceMembers | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
      foreach ($member in $ProcessMembers) {
        $usersubjid = (Get-AzureADUser -Filter "userPrincipalName eq '$member'").ObjectId
        Open-AzureADMSPrivilegedRoleAssignmentRequest -ProviderId 'aadRoles' -ResourceId $tenantid -RoleDefinitionId $PimRoleId -SubjectId $usersubjid -Type 'AdminRemove' -AssignmentState 'Eligible' -schedule $schedule
        Write-Output "Removing '$($member)' from '$($PimRoleID)'"
      }
    }
    Else {
      Write-Verbose -Message "Okta: '$($OktaSourceGroup)' --> Azure:'$($PimRoleID)': No differences found."
    }
  }
  Else {
    Write-Verbose -Message "SourceMembers is empty, will not do anything to protect wipeout"
  }
}


###########Starting Script##################

### Connect to Okta
Connect-Okta -Token $token -FullDomain $baseurl
Connect-AzureAD -Credential $AzureAdCred

$tenantinfo = Get-AzureADTenantDetail

Foreach ($role in $RoleListToApply) {
  $RoleID = Get-AzureADMSPrivilegedRoleDefinition -ProviderId aadRoles -ResourceId $tenantinfo.ObjectId -Filter "DisplayName eq '$($role)'"
  Write-Output "Going to start with $role"
  Sync-PIMUsers -OktaSourceGroup $GroupIdentity -PimRoleId $RoleId.id -Mirror -Verbose -tenantid $tenantinfo.ObjectId -schedule $schedule
}
