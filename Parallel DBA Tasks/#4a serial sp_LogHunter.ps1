#4a serial sp_LogHunter runs (Important Error Log Messages From SQL Server Instances)

$results = @(); foreach ($inst in $instances) {

    Write-Output "$inst..."
    $results += Invoke-DbaQuery -SqlInstance $inst -Database master -Query 'EXEC sp_LogHunter @first_log_only = 1' `
    -AppendServerInstance -MessagesToOutput -QueryTimeout 500
}
$results | Out-GridView

# sp_LogHunter - written by Erik Darling https://github.com/erikdarlingdata/DarlingData/blob/main/sp_LogHunter/sp_LogHunter.sql