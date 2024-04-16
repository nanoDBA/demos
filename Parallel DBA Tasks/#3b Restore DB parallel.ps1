## 3b # Restores parallel
     #  using PoshRSJob module
Write-Output "`$instances count`: $($instances.count)"

Get-RSJob | Stop-RSJob; Get-RSJob | Remove-RSJob # stop & remove any existing jobs

### 
$numberParallelThreads = 4

$resultsRestore = Start-RSJob -Throttle $numberParallelThreads -ModulesToImport dbatools -InputObject $instances <#-Verbose#> -ScriptBlock { 

    $sqlCred = BetterCredentials\Get-Credential sa
    <# Set certs to be trusted #>Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true

    $sqlInstance = $_
    $database = 'master'
    Write-Verbose "$sqlInstance..."
    Restore-DbaDatabase -SqlInstance $sqlInstance `
    -SqlCredential $sqlCred `
    -Path /tmp/backup/pubs.bak #-Verbose

} | Wait-RSJob -ShowProgress <#-Verbose#> | Receive-RSJob <#-Verbose#>

Write-Output "$(($resultsGenPseudoErrors).count) results"
$resultsRestore | Format-Table
Get-Date -Format o