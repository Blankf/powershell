function Get-EmailContent {
  <#
  .SYNOPSIS
  Fetches the MFA token from a specific email in a mailbox.

  .DESCRIPTION
  This function retrieves the MFA token from the most recent email in a mailbox that matches a specific subject and extracts the token using a regular expression.

  .PARAMETER Mailbox
  The name of the mailbox to fetch the email from.

  .PARAMETER Subject
  The subject of the email to search for.

  .PARAMETER RegexPattern
  The regular expression pattern to extract the MFA token from the email body.

  .EXAMPLE
  Get-MFAToken -Mailbox "Test@domain.com" -Subject "MFA Login Authentication" -RegexPattern "(?<=is:)\s*(.*)"
  #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Mailbox,

    [Parameter(Mandatory = $true)]
    [string]$Subject,

    [Parameter(Mandatory = $true)]
    [string]$RegexPattern
  )

  # Fetch a specific email from the mailbox
  $msg = Get-MgUserMessage -UserId $Mailbox -OrderBy "receivedDateTime desc" -Top 1 | Where-Object { $_.ReceivedDateTime -gt ((get-date).AddMinutes(-5)) -and $_.Subject -eq $Subject }

  if ($msg) {
    $msg.BodyPreview -match $RegexPattern | Out-Null
    $Content = $Matches[1]
    $Content = $Content.Trim()
    return $Content
  }
  elseif ($null -eq $msg) {
    $Content = $null
  }
  else {
    Write-Error "No email found with the subject '$Subject'."
  }
}