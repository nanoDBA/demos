# Export past 50 hours of Error 50000 from SQL Server Error Logs to Excel
# parallel processing with dbatools and ImportExcel modules
$sqlInstances = $instances
Write-Output "`$instances count`: $($instances.count)"

Get-RSJob | Stop-RSJob
Get-RSJob | Remove-RSJob # clear out any existing jobs

$numberParallelThreads = 4

$results = Start-RSJob -Throttle $numberParallelThreads -ModulesToImport dbatools, BetterCredentials -InputObject $sqlInstances -ScriptBlock { 
  Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true # Set certs to be trusted
  $sqlCred = BetterCredentials\Get-Credential sa
  
  # Set default parameters for dbatools commands to use the SQL credential - https://dbatools.io/defaults/
  $PSDefaultParameterValues['*-Dba*:SqlCredential'] = $sqlCred
  $PSDefaultParameterValues['*-Dba*:SourceSqlCredential'] = $sqlCred
  $PSDefaultParameterValues['*-Dba*:DestinationSqlCredential'] = $sqlCred

  $sqlInstance = $_

  $paramHash = @{
    SqlInstance   = $sqlInstance
    SqlCredential = $sqlCred
    After         = (Get-Date).AddHours((-50))
    Text          = "Error: 50000"
  }

  Get-DbaErrorLog @paramHash
} | Wait-RSJob -ShowProgress | Receive-RSJob

Write-Output "`$results.Count: $($results.Count)"
#multiple key sort #with one unique column(commented out uniqueness)
$results | Sort-Object -Property @{e={$_.SqlInstance}}, @{e={$_.LogDate}} | Select-Object SqlInstance, LogDate, Text, Source | ogv #ft -Wrap
Get-Date -Format o

Write-Output "`$results.Count: $($results.Count)"

$fileDescription = 'Error50000'
$worksheetName = $fileDescription.replace('_','')
$filenameExcel = ("$env:USERPROFILE\Documents\" + [string](Get-Date -format "yyyy-MM-dd__HHmmss") + "_" + $fileDescription + ".xlsx" ); #assign $filename variable

$paramHash = @{
    Path              = $filenameExcel
    WorksheetName     = $fileDescription.replace('_','')
    TableName         = $fileDescription.replace('_','')
    TableStyle        = 'Medium27'
    AutoSize          = $True
    IncludePivotTable = $True
    PivotRows         = "SqlInstance"
    PivotData         = @{LogDate = 'count'}
    IncludePivotChart = $True
    ChartType         = "PieExploded3D"
    ShowCategory      = $True
    ShowPercent       = $True
}

Write-Output "$(($results).count) records exported" 
#multiple key sort #with one unique column(commented out uniqueness)

# Module ImportExcel is required - thank you, Doug Finke!
$excel = $results | Sort-Object -Property @{e={$_.SqlInstance}}, @{e={$_.LogDate}} <#@{e={$_.Text}} -Unique #>| Select-Object SqlInstance, LogDate, Text, Source | Export-Excel @paramHash -Verbose -PassThru
#$results | Select SqlInstance, LogDate, Text, Source | Export-Excel @paramHash
#$results | Select SqlInstance, LogDate, Text, Source | Out-GridView
$sheet = $excel.workbook.worksheets[$($worksheetName)]
$sheet.Column(2) | Set-ExcelRange -NFormat "yyyy-mm-dd hh:mm:ss.000" -AutoFit
$excel.Save()
$excel.Dispose()
if(Test-Path $filenameExcel) { Write-Output "$filenameExcel exported"}