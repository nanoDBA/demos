# 06-Test-Listener-Failover.ps1
#
# Set Variables
. "$($PSScriptRoot)\00-Set-AgVariables.ps1"

#Test the listener, failover, and CNAME
<#  
  How long does it take to failover the 
  entire AG and successfully connect to 
  each database on the current primary
  replica in the AG after failover?
   #>

#Failover Testing - AlwaysOn
$targetOwnerNode = $secondaryReplica ;
$startTest = Get-Date; 
Invoke-Command $targetOwnerNode -ScriptBlock { Get-ClusterGroup | Move-ClusterGroup -Node $($using:targetOwnerNode) }

# wait for a succesful connection to the listener's CNAME
while (!($agListenerCNAME | Test-DbaConnection ).ConnectSuccess) { Start-Sleep -Milliseconds 100 }

# Return @@SERVERNAME
$results = $null; $results = $agListenerCNAME | Invoke-SqlCmd -database master -Query "SELECT @@SERVERNAME [InstanceName], db_name() [db], getdate() CurrentTime, CAST((datediff(mi, login_time, getdate())/60.0) AS DECIMAL (16,1)) [hours uptime], '<-^ hours uptime' [__], (datediff(mi, login_time, getdate())/60/24) [days uptime], '<-^ days uptime' [___], @@VERSION as Version FROM master..sysprocesses WHERE spid = 1; " -Verbose -OutputSqlErrors $true -IncludeSqlUserErrors -AbortOnError; $results | Format-List

#Verify synchronization status
Get-DbaAgDatabase -SqlInstance $agListenerCNAME -AvailabilityGroup $agName
$endTest = Get-Date
$duration = New-TimeSpan -Start $startTest -End $endTest
Write-Output "Failover + Connect Time = $($duration.TotalSeconds) seconds"
#Test the listener, failover, and CNAME

<# Troubleshooting
#_AlwaysOn_Adding_Databases_to_Existing_Availability_Group_using_Direct_Seeding
Get-DbaAgDatabase -SqlInstance $agListenerCNAME -AvailabilityGroup $agName
Get-DbaAgDatabase -SqlInstance $primaryReplica -AvailabilityGroup $agName
Get-DbaAgDatabase -SqlInstance $secondaryReplica -AvailabilityGroup $agName

Add-DbaAgDatabase -SqlInstance $agListenerCNAME -AvailabilityGroup $agName -Database $AGDatabaseNamestoAdd -Verbose

Get-DbaAgDatabase -SqlInstance $agListenerShortName -AvailabilityGroup $agName
Get-DbaAgDatabase -SqlInstance $agListenerCNAME -AvailabilityGroup $agName
Get-DbaAgDatabase -SqlInstance $primaryReplica -AvailabilityGroup $agName
Get-DbaAgDatabase -SqlInstance $secondaryReplica -AvailabilityGroup $agName
# Seems like direct seeding can fail when trying to add several databases at the same time - consider adding 4 or less at a time

#Remove-DbaAgDatabase -SqlInstance SRV -AvailabilityGroup $agName -Database MyDatabase  -Verbose

$Source = "SRV"

$Destination = 'SRV2'

$Database = @("MyDatabase")

$paramHash = @{
  Source = $Source
   Destination = $Destination
   Database = $Database
   BackupRestore = $True
   UseLastBackup = $True
   #NoRecovery = $True
}

Copy-DbaDatabase @paramHash -Verbose -Force

#Add-DbaAgDatabase -SqlInstance SRV -AvailabilityGroup $agName -Database MyDatabase  -Verbose

#Remove-DbaAgDatabase -SqlInstance SRV -AvailabilityGroup $agName -Database MyDatabase, YourDatabase  -Verbose
#   Add-DbaAgDatabase -SqlInstance SRV -AvailabilityGroup $agName -Database MyDatabase, YourDatabase  -Verbose
#>