function ConvertTo-SortedDictionary {
<#
.SYNOPSIS
Converts a hashtable into a sorted dictionary.

.DESCRIPTION
The ConvertTo-SortedDictionary function takes a hashtable as input and converts it into a sorted dictionary. The resulting sorted dictionary will have its keys sorted in ascending order.

.PARAMETER HashTable
The hashtable to be converted into a sorted dictionary.

.EXAMPLE
$hashTable = @{
    "Key3" = "Value3"
    "Key1" = "Value1"
    "Key2" = "Value2"
}
$sortedDictionary = ConvertTo-SortedDictionary -HashTable $hashTable

This example demonstrates how to convert a hashtable into a sorted dictionary using the ConvertTo-SortedDictionary function.

.INPUTS
System.Collections.Hashtable

.OUTPUTS
System.Collections.Generic.SortedDictionary[string, string]

#>
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.Hashtable]$HashTable
  )

  $SortedDictionary = New-Object 'System.Collections.Generic.SortedDictionary[string, string]'
  foreach ($Key in $HashTable.Keys) {
    $SortedDictionary[$Key] = $HashTable[$Key]
  }
  Write-Output $SortedDictionary
}

