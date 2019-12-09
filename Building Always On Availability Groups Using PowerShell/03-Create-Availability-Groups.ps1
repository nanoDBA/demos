# 03-Create-Availability-Groups.ps1
#
# Create Availability Groups

# Set Variables
. "$($PSScriptRoot)\00-Set-AgVariables.ps1"

# *** IMPORTANT ***
<#
"The New-SqlAvailabilityReplica cmdlet creates an availability replica. 
Run this cmdlet on the instance of SQL Server that hosts the primary replica." ******
https://docs.microsoft.com/en-us/powershell/module/sqlserver/new-sqlavailabilityreplica?view=sqlserver-ps

https://www.mssqltips.com/sqlservertip/5012/create-and-configure-sql-server-2016-always-on-availability-groups-using-windows-powershell/
#>

Import-Module sqlserver

#Create the T-SQL commands
$createLogin = "IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name =  '$($sqlEngineServiceAccount)') BEGIN CREATE LOGIN [$($sqlEngineServiceAccount)] FROM WINDOWS END;"
$grantConnectPermissions = "GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO [$($sqlEngineServiceAccount)]"

#Run the T-SQL commands using Invoke-SqlCmd
Invoke-DbaQuery -SqlInstance $primaryReplica, $secondaryReplica -Query $createLogin -MessagesToOutput
Invoke-DbaQuery -SqlInstance $primaryReplica, $secondaryReplica -Query $grantConnectPermissions -MessagesToOutput



# Create an in-memory representation of the primary replica.  
#Variable for an array object of Availability Group replicas
$replicas = @()
$primReplica_splat = @{
    Name                          = $primaryReplica
    EndpointURL                   = "TCP://$($primaryReplica).$($domain):5022"
    SeedingMode                   = "Automatic"
    AvailabilityMode              = "SynchronousCommit"
    FailoverMode                  = "Automatic"
    Version                       = $agPrimaryVersion
    AsTemplate                    = $true
    ConnectionModeInSecondaryRole = "AllowAllConnections"
}
$replicas += New-SqlAvailabilityReplica @primReplica_splat 

# Create an in-memory representation of the secondary replica.  
$secReplica_splat = @{
    Name                          = $secondaryReplica
    EndpointURL                   = "TCP://$($secondaryReplica).$($domain):5022"
    SeedingMode                   = "Automatic"
    AvailabilityMode              = "SynchronousCommit"
    FailoverMode                  = "Automatic"
    Version                       = $agSecondaryVersion
    AsTemplate                    = $true
    ConnectionModeInSecondaryRole = "AllowAllConnections"
}
$replicas += New-SqlAvailabilityReplica @secReplica_splat

# Create the availability group - MUST BE RUN ON PRIMARY
$newAgSplat = @{
    Name                      = $agName
    InputObject               = $primaryReplica
    AutomatedBackupPreference = "Primary"
    Database                  = $AGDatabaseNamestoAdd
    AvailabilityReplica       = $replicas
} 
#Verify AG Name
Write-Output "AG NAME: $agName "
# Create the availability group
New-SqlAvailabilityGroup @newAgSplat -Verbose -Confirm

#Create the T-SQL commands
$GrantCreateAnyDatabase = "ALTER AVAILABILITY GROUP [$($agName)] GRANT CREATE ANY DATABASE;"

#Run the T-SQL commands
Invoke-DbaQuery -SqlInstance $primaryReplica -Query $GrantCreateAnyDatabase -MessagesToOutput

#Join the secondary replicas and databases to the Availability Group
Join-SqlAvailabilityGroup -Path "SQLSERVER:\SQL\$($secondaryReplica)\Default" -Name $agName

#Run the T-SQL commands - initiates direct seeding to secondary
Invoke-DbaQuery -SqlInstance $secondaryReplica -Query $GrantCreateAnyDatabase -MessagesToOutput