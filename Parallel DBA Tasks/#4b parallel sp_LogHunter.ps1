#4b parallel sp_LogHunter runs (Important Error Log Messages From SQL Server Instances)
#   using PoshRSJob module
Write-Output "`$instances count`: $($instances.count)"

Get-RSJob | Stop-RSJob; Get-RSJob | Remove-RSJob # stop & remove any existing jobs

### 
$numberParallelThreads = 4

$resultsLogHunter = Start-RSJob -Throttle $numberParallelThreads -ModulesToImport dbatools -InputObject $instances <# -Verbose #> -ScriptBlock { 

    $sqlCred = BetterCredentials\Get-Credential sa
    <# Set certs to be trusted #>Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true

    $sqlInstance = $_
    $database = 'master'
    Write-Verbose "$sqlInstance..."
    Invoke-DbaQuery -SqlInstance $sqlInstance -Database $database -Query "
       EXEC sp_LogHunter @first_log_only = 1
" `
    -SqlCredential $sqlCred -AppendServerInstance -MessagesToOutput


} | Wait-RSJob -ShowProgress <#-Verbose#> | Receive-RSJob <#-Verbose#>; 

Write-Output "$(($resultsGenPseudoErrors).count) results"
$resultsLogHunter | Out-GridView
Get-Date -Format o


# sp_LogHunter - written by Erik Darling https://github.com/erikdarlingdata/DarlingData/blob/main/sp_LogHunter/sp_LogHunter.sql