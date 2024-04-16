#1b Get-DbaErrorLog in parallel for multiple instances
$sqlInstances = $instances
Write-Output "`$instances count`: $($instances.count)"

Get-RSJob | Stop-RSJob
Get-RSJob | Remove-RSJob # clear out any existing jobs

$numberParallelThreads = 4

$results = Start-RSJob -Throttle $numberParallelThreads -ModulesToImport dbatools, BetterCredentials -InputObject $sqlInstances -ScriptBlock { 
  Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true # Set certs to be trusted
  $sqlCred = BetterCredentials\Get-Credential sa

  $PSDefaultParameterValues['*-Dba*:SqlCredential'] = $sqlCred
  $PSDefaultParameterValues['*-Dba*:SourceSqlCredential'] = $sqlCred
  $PSDefaultParameterValues['*-Dba*:DestinationSqlCredential'] = $sqlCred

  $sqlInstance = $_

  $paramHash = @{
    SqlInstance   = $sqlInstance
    SqlCredential = $sqlCred
    After         = (Get-Date).AddHours((-50))
    Text          = "build" #"Error: 50000"
  }

  Get-DbaErrorLog @paramHash
} | Wait-RSJob -ShowProgress | Receive-RSJob

Write-Output "`$results.Count: $($results.Count)"
#multiple key sort #with one unique column(commented out uniqueness)
$results | Sort-Object -Property @{e={$_.SqlInstance}}, @{e={$_.LogDate}} | Select-Object SqlInstance, LogDate, Text, Source | ogv #ft -Wrap
Get-Date -Format o