[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Script:strLineSeparator = "  ---------"
$urljson = "https://api.backup.management/jsonapi"

Function Convert-UnixTimeToDateTime($inputUnixTime) {
  if ($inputUnixTime -gt 0 ) {
    $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
    $epoch = $epoch.ToUniversalTime()
    $epoch = $epoch.AddSeconds($inputUnixTime)
    return $epoch
  }
  else { return "" }
}  ## Convert epoch time to date time

Function Convert-DateTimeToUnixTime($DateToConvert) {
  $epochdate = Get-Date -Date "1970-01-01 00:00:00Z"
  $NewExtensionDate = Get-Date -Date $DateToConvert
  $NewEpoch = (New-TimeSpan -Start $epochdate -End $NewExtensionDate).TotalSeconds
  Return $NewEpoch
}

Function CallJSON {
<#
.SYNOPSIS
Sends a POST request to the specified URL with the provided JSON object.

.DESCRIPTION
The CallJSON function sends a POST request to the specified URL with the provided JSON object. It converts the response from the server to a PowerShell object.

.PARAMETER url
The URL to which the POST request will be sent.

.PARAMETER object
The JSON object to be sent in the request body.

.EXAMPLE
$url = "https://api.example.com/users"
$object = '{"partnername": "John", "username": 30}'
$response = CallJSON -url $url -object $object
$response
#>
  param (
    [Parameter(Mandatory=$true)]
    [string]$url,
    [Parameter(Mandatory=$true)]
    [string]$object
  )

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($object)
  $web = [System.Net.WebRequest]::Create($url)
  $web.Method = "POST"
  $web.ContentLength = $bytes.Length
  $web.ContentType = "application/json"
  $stream = $web.GetRequestStream()
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.close()
  $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
  return $reader.ReadToEnd() | ConvertFrom-Json
  $reader.Close()
}

Function connect-covebackupmanagement {
    <#
    .SYNOPSIS
        This script prompts the user to enter the necessary credentials for the N-able | Cove Backup.Management API.

    .DESCRIPTION
        The script defines a PowerShell function that accepts three parameters: AdminLoginPartnerName, AdminLoginUserName, and AdminPassword.
        The AdminLoginPartnerName parameter is mandatory and expects the user to enter the exact, case-sensitive partner name for the N-able | Cove Backup.Management API.
        The AdminLoginUserName parameter is mandatory and expects the user to enter the login username or email for the N-able | Cove Backup.Management API.
        The AdminPassword parameter is optional and allows the user to enter the password for the N-able | Cove Backup.Management API in a secure manner.

    .PARAMETER AdminLoginPartnerName
        Specifies the exact, case-sensitive partner name for the N-able | Cove Backup.Management API.
        example: 'Contoso Inc (my.email@domain.com)'

    .PARAMETER AdminLoginUserName
        Specifies the login username or email for the N-able | Cove Backup.Management API.

    .PARAMETER AdminPassword
        Specifies the password for the N-able | Cove Backup.Management API. This parameter accepts input in a secure manner.

    .EXAMPLE
        .\Untitled-1.ps1 -AdminLoginPartnerName "Acme, Inc (bob@acme.net)" -AdminLoginUserName "admin" -AdminPassword "P@ssw0rd"
        This example demonstrates how to call the script by providing the required parameters.

    .NOTES
        Author: Your Name
        Date:   Current Date
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$AdminLoginPartnerName,
        [Parameter(Mandatory=$true)]
        [string]$AdminLoginUserName,
        [Parameter(Mandatory=$false)]
        [securestring]$AdminPassword = $(Read-Host -AsSecureString "Enter Password for N-able | Cove Backup.Management API")
    )

    $PlainTextAdminPassword = $AdminPassword | ConvertFrom-SecureString -AsPlainText

    # (Show credentials for Debugging)
    Write-Output "Logging on with the following Credentials`n"
    Write-Output "PartnerName:  $AdminLoginPartnerName"
    Write-Output "UserName:     $AdminLoginUserName"
    Write-Output "Password:     It's secure..."

    # (Create authentication JSON object using ConvertTo-JSON)
    $objAuth = (New-Object PSObject | Add-Member -PassThru NoteProperty jsonrpc '2.0' |
    Add-Member -PassThru NoteProperty method 'Login' |
    Add-Member -PassThru NoteProperty params @{partner=$AdminLoginPartnerName;username=$AdminLoginUserName;password=$PlainTextAdminPassword}|
    Add-Member -PassThru NoteProperty id '1') | ConvertTo-Json

    # (Call the JSON function with URL and authentication object)
    $global:session = CallJSON -url $urlJSON -object $objAuth
    Start-Sleep -Milliseconds 100

    # # (Variable to hold current visa and reused in following routines)
    $global:visa = $session.visa
    $global:PartnerId = [int]$session.result.result.PartnerId

    # (Get Result Status of Authentication)
    $AuthenticationErrorCode = $Session.error.code
    $AuthenticationErrorMsg = $Session.error.message

    # (Check if ErrorCode has a value)
    If ($AuthenticationErrorCode) {
        Write-Output "Authentication Error Code:  $AuthenticationErrorCode"
        Write-Output "Authentication Error Message:  $AuthenticationErrorMsg"
        Pause
        Break Script
    }
    Else {
        # (Action if no error)
    }

  #return $session
}

Function Get-AccountInfoById {
  param(
    [Parameter(Mandatory=$true)]
    [int]$AccountId
  )

  $url = "https://api.backup.management/jsonapi"
  $method = 'POST'
  $data = @{}
  $data.jsonrpc = '2.0'
  $data.id = '2'
  $data.visa = $global:Visa
  $data.method = 'GetAccountInfoById'
  $data.params = @{}
  $data.params.accountId = [int]$AccountId

  $jsondata = (ConvertTo-Json $data -depth 6)

  $params = @{
      Uri         = $url
      Method      = $method
      Headers     = @{ 'Authorization' = "Bearer $Script:visa" }
      Body        = ([System.Text.Encoding]::UTF8.GetBytes($jsondata))
      WebSession  = $websession
      ContentType = 'application/json; charset=utf-8'
  }

  $result = Invoke-RestMethod @params

  return $result

  $global:visa = $result.visa
}

Function Get-CoveDevices {
  param (
    [Parameter(Mandatory=$false)]
    [string]$visa = $global:visa,
    [int]$PartnerId = $global:PartnerId,
    [int]$devicecount = 5000
  )

  $url = "https://api.backup.management/jsonapi"
  $method = 'POST'
  $data = @{
    jsonrpc = '2.0'
    id = '2'
    visa = $visa
    method = 'EnumerateAccountStatistics'
    params = @{
      query = @{
        PartnerId = $PartnerId
        Filter = "AT==2"
        Columns = @("AR", "PF", "AN", "MN", "AL", "AU", "CD", "TS", "TL", "T3", "US", "TB", "T7", "TM", "D19F21", "GM", "JM", "D5F20", "D5F22", "LN", "AA843")
        OrderBy = "CD DESC"
        StartRecordNumber = 0
        RecordsCount = $devicecount
        Totals = @("COUNT(AT==2)", "SUM(T3)", "SUM(US)")
      }
    }
  }

  $jsondata = ConvertTo-Json $data -Depth 6

  $params = @{
    Uri = $url
    Method = $method
    Headers = @{ 'Authorization' = "Bearer $visa" }
    Body = [System.Text.Encoding]::UTF8.GetBytes($jsondata)
    ContentType = 'application/json; charset=utf-8'
  }

  try {
    $DeviceResponse = Invoke-RestMethod @params
    #$global:tst = $DeviceResponse
  } catch {
    Write-Output "Error: $_"
  }

  Write-Verbose -Message "DeviceResponse: $DeviceResponse"

  $DeviceDetail = @()

  ForEach ($DeviceResult in $DeviceResponse.result.result) {

    $AccountID = [Int]$DeviceResult.AccountId
    $AccountInfoResponse = Get-AccountInfoById $AccountID

    $DeviceDetail += New-Object -TypeName PSObject -Property @{
      AccountID = [Int]$DeviceResult.AccountId
      PartnerID = [string]$DeviceResult.PartnerId
      PartnerName = $DeviceResult.Settings.AR -join ''
      Reference = $DeviceResult.Settings.PF -join ''
      Account = $DeviceResult.Settings.AU -join ''
      DeviceName = $DeviceResult.Settings.AN -join ''
      ComputerName = $DeviceResult.Settings.MN -join ''
      DeviceAlias = $DeviceResult.Settings.AL -join ''
      Creation = Convert-UnixTimeToDateTime ($DeviceResult.Settings.CD -join '')
      TimeStamp = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TS -join '')
      LastSuccess = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TL -join '')
      SelectedGB = [math]::Round([Decimal](($DeviceResult.Settings.T3 -join '') / 1GB), 2)
      UsedGB = [math]::Round([Decimal](($DeviceResult.Settings.US -join '') / 1GB), 2)
      #Last28Days = (($DeviceResult.Settings.TB -join '')[-1..-28] -join '') -replace ("8", [char]0x26a0) -replace ("7", [char]0x23f9) -replace ("6", [char]0x23f9) -replace ("5", [char]0x2611) -replace ("2", [char]0x274e) -replace ("1", [char]0x2BC8) -replace ("0", [char]0x274c)
      #Last28 = (($DeviceResult.Settings.TB -join '')[-1..-28] -join '') -replace("8","!") -replace("7","!") -replace("6","?") -replace("5","+") -replace("2","-") -replace("1",">") -replace("0","X")
      Errors = $DeviceResult.Settings.T7 -join ''
      Billable = $DeviceResult.Settings.TM -join ''
      Shared = $DeviceResult.Settings.D19F21 -join ''
      MailBoxes = $DeviceResult.Settings.GM -join ''
      OneDrive = $DeviceResult.Settings.JM -join ''
      SPusers = $DeviceResult.Settings.D5F20 -join ''
      SPsites = $DeviceResult.Settings.D5F22 -join ''
      StorageLocation = $DeviceResult.Settings.LN -join ''
      AccountToken = $AccountInfoResponse.result.result.Token
      Notes = $DeviceResult.Settings.AA843 -join ''
    }
  }

  return $DeviceDetail

  $global:visa = $DeviceResponse.visa
}


Function Get-CoveM365Users {
  param (
    [Parameter(Mandatory=$true)]
    [string]$AccountToken,
    [Parameter(Mandatory = $false)]
    [string]$visa = $global:visa
  )
  $url = "https://api.backup.management/management_api"
  $method = 'POST'
  $data = @{
    jsonrpc = '2.0'
    id = '2'
    method = 'EnumerateUsers'
    params = @{
      accountToken = $AccountToken
    }
  }
  $jsondata = ConvertTo-Json $data -Depth 6
  $params = @{
    Uri = $url
    Method = $method
    Headers = @{
      'Authorization' = "Bearer $visa"
    }
    Body = [System.Text.Encoding]::UTF8.GetBytes($jsondata)
    WebSession = $websession
    ContentType = 'application/json; charset=utf-8'
  }
  $EnumerateM365UsersResponse = Invoke-RestMethod @params

  $M365UserStatistics = $EnumerateM365UsersResponse.result.result.Users | Select-object DisplayName,
  EmailAddress,
  @{
    Name = "MailBoxSelection"
    Expression = {$_.ExchangeInfo.Selection}
  },
  @{
    Name = "MailBoxStatus"
    Expression = {$_.ExchangeInfo.MailboxType}
  },
  @{
    Name = "New"
    Expression = {$_.IsNew[0] -replace "True", "New" -replace "False", ""}
  },
  @{
    Name = "Deleted"
    Expression = {$_.IsDeleted[0] -replace "True", "Deleted" -replace "False", ""}
  },
  @{
    Name = "Shared"
    Expression = {$_.IsShared[0] -replace "True", "Shared" -replace "False", ""}
  },
  @{
    Name = "MailBoxLastBackupStatus"
    Expression = {$_.ExchangeInfo.LastBackupStatus}
  },
  @{
    Name = "MailBoxLastBackupTimestamp"
    Expression = {Convert-UnixTimeToDateTime ($_.ExchangeInfo.LastBackupTimestamp)}
  },
  @{
    Name = "ExchangeAutoInclude"
    Expression = {$EnumerateM365UsersResponse.result.result.ExchangeAutoInclusionType}
  },
  @{
    Name = "OneDriveSelection"
    Expression = {$_.OneDriveInfo.Selection}
  },
  @{
    Name = "OneDriveStatus"
    Expression = {$_.OneDriveInfo.LicenseStatus}
  },
  @{
    Name = "OneDriveSelectedGib"
    Expression = {[math]::Round([Decimal]($_.OneDriveInfo.SelectedSize / 1GB), 3)}
  },
  @{
    Name = "OneDriveLastBackupStatus"
    Expression = {$_.OneDriveInfo.LastBackupStatus}
  },
  @{
    Name = "OneDriveLastBackupTimestamp"
    Expression = {Convert-UnixTimeToDateTime ($_.OneDriveInfo.LastBackupTimestamp)}
  },
  @{
    Name = "OneDriveAutoInclude"
    Expression = {$EnumerateM365UsersResponse.result.result.OneDriveAutoInclusionType}
  },
  UserGuid

  #$M365UserStatistics | Select-object * | format-table
  return $M365UserStatistics
  $global:visa = $EnumerateM365UsersResponse.visa
}

Function Get-CoveM365History {
  param (
    [Parameter(Mandatory = $true)]
    [string]$AccountToken,
    [Parameter(Mandatory = $false)]
    [string]$visa = $global:visa,
    [Parameter(Mandatory = $false)]
    [int]$historymonths = 1
  )
  $url = "https://api.backup.management/reporting_api"
  $method = 'POST'
  $data = @{
    jsonrpc = '2.0'
    id = '2'
    method = 'EnumerateSessions'
    params = @{
      accountToken = $accountToken
      filter = @{
        CreatedAfter = Convert-DateTimeToUnixTime ((Get-Date).AddMonths([int]$historymonths * -1))
        CreatedBefore = Convert-DateTimeToUnixTime ((Get-Date).AddDays(1))
      }
      range = @{
        Offset = 0
        Size = 20000
      }
    }
  }

  $jsondata = ConvertTo-Json $data -Depth 6

  $params = @{
    Uri = $url
    Method = $method
    Headers = @{ 'Authorization' = "Bearer $visa" }
    Body = [System.Text.Encoding]::UTF8.GetBytes($jsondata)
    WebSession = $websession
    ContentType = 'application/json; charset=utf-8'
  }

  $EnumerateM365HistoryResponse = Invoke-RestMethod @params

  $M365Sessions = $EnumerateM365HistoryResponse.result.result | Select-Object Id,
  Type,
  @{
    Name = "DataSource"
    Expression = {$_.DataSourceType}
  },
  @{
    Name = "StartTime"
    Expression = {Convert-UnixTimeToDateTime ($_.StartTime)}
  },
  @{
    Name = "EndTime"
    Expression = {Convert-UnixTimeToDateTime ($_.EndTime)}
  },
  @{
    Name = "Duration"
    Expression = {[Math]::Round($_.Duration/60, 2)}
  },
  @{
    Name = "Users"
    Expression = {$_.AccountsCount}
  },
  @{
    Name = "Sites"
    Expression = {$_.SiteCollectionsCount}
  },
  Status,
  ErrorsCount

  return $M365Sessions
  $global:visa = $EnumerateM365HistoryResponse.visa
}

Function Get-CoveM365Stats {
  Param(
    [Parameter(Mandatory=$true)]
    [Int]$DeviceId,
    [Parameter(Mandatory=$false)]
    [String]$visa = $global:visa
  ) #end param

  $url2 = "https://api.backup.management/c2c/statistics/devices/id/$deviceid"
  $method = 'GET'

  $params = @{
    Uri         = $url2
    Method      = $method
    Headers     = @{ 'Authorization' = "Bearer $visa" }
    WebSession  = $websession
    ContentType = 'application/json; charset=utf-8'
  }

  try {
    $M365response = Invoke-RestMethod @params
  } catch {
    Write-Output "Error: $_"
  }

  $devicestatistics = $M365response.deviceStatistics | Select-object DisplayName,
  EmailAddress,
  Billable,
  @{
    Nname = "Shared"
    Expression = {$_.shared[0] -replace("TRUE","Shared") -replace("FALSE","") }
  },
  @{
    Name = "MailBox"
    Expression = {$_.datasources.status[0] -replace("unprotected","") }
  },
  @{
    Name = "OneDrive"
    Expression = {$_.datasources.status[1]  -replace("unprotected","")  }
  },
  @{
    Name = "SharePoint"
    Expression = {$_.datasources.status[2]  -replace("unprotected","")  }
  },
  @{
    Name = "UserGuid"
    Expression = {$_.UserId}
  },
  @{
    Name = "AccountToken"
    Expression = {$accountToken}
  }

  $devicestatistics | foreach-object {
    if((($_.Mailbox -eq "protected") -and ($_.shared -ne "shared")) -or ($_.OneDrive -eq "protected") -or ($_.SharePoint -eq "protected")) {
      $_.Billable = "Billable"
    }
  }

  return $devicestatistics
  $global:visa = $M365response.visa
}
