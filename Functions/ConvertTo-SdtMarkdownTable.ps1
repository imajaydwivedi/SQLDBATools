Function ConvertTo-SdtMarkdownTable {
  [CmdletBinding()]
  [OutputType([string])]
  Param (
    [Parameter(
      Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true
    )]
    [PSObject[]]$InputObject,

    [Switch]$Pretty
  )

  Begin {
    $items = @()
    $columns = [ordered]@{}
  }

  Process {
    ForEach ($item in $InputObject) {
      $items += $item

      $item.PSObject.Properties | ForEach-Object {
        if ($null -ne $_.Value ) {
          if ((-not ($columns.Keys -contains $_.Name)) -or $columns[$_.Name] -lt $_.Value.ToString().Length) {
            $columns[$_.Name] = $_.Value.ToString().Length
          }
        }
      }
    }
  }

  End {
    ForEach ($key in $($columns.Keys)) {
      $columns[$key] = [Math]::Max($columns[$key], $key.Length)
    }

    if ($Pretty) {
      $separator = @()
      ForEach ($key in $columns.Keys) {
        $separator += '-' * $columns[$key]
      }
      '+-{0}-+' -f ($separator -join '-+-')
    }

    $header = @()
    ForEach ($key in $columns.Keys) {
      $header += ('{0,-' + $columns[$key] + '}') -f $key
    }
    '| {0} |' -f ($header -join ' | ')
        

    $separator = @()
    ForEach ($key in $columns.Keys) {
      $separator += '-' * $columns[$key]
    }
    if ($Pretty) {
      '+-{0}-+' -f ($separator -join '-+-')
    }
    else {
      '| {0} |' -f ($separator -join ' | ')
    }

    ForEach ($item in $items) {
      $values = @()
      ForEach ($key in $columns.Keys) {
        $values += ('{0,-' + $columns[$key] + '}') -f $item.($key)
      }
      '| {0} |' -f ($values -join ' | ')
    }

    if ($Pretty) {
      '+-{0}-+' -f ($separator -join '-+-')
    }
  }
  <#
.Synopsis
    Converts a PowerShell object to a Markdown table.
.EXAMPLE
    $data | ConvertTo-SdtMarkdownTable
.EXAMPLE
    ConvertTo-SdtMarkdownTable($data)
.EXAMPLE
    $InputObject = Get-Service | Select-Object Name, Status, DisplayName -First 5
    $InputObject | ConvertTo-SdtMarkdownTable
    Write-Host "`n`n*************************************************************************`n`n"
    $InputObject | ConvertTo-SdtMarkdownTable -Pretty
.LINK
    https://stackoverflow.com/questions/69010143/convert-powershell-output-to-a-markdown-file
.LINK
    https://gist.github.com/mac2000/86150ab43cfffc5d0eef
#>
}