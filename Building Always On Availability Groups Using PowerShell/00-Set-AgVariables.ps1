# 00-Set-AgVariables.ps1
#
# Change variable values to match deployment environment

$AGDatabaseNamestoAdd = ($hereString = @"
MyDatabase
YourDatabase
"@
).split("`n").TrimEnd("`r") <# Converting a Here-String to an Array of Strings https://gallery.technet.microsoft.com/scriptcenter/Tip-of-the-Week-Converting-221aab3f #>

# sqlserver module needed as it is referenced for provider variables
Import-Module sqlserver

#variables to be populated
$domain = "Company.Pri" #Domain DNS sufix
$dnsServer = "DOM1" # used to create the CNAME
$primaryReplica = "SRV1"
$sqlEngineServiceAccount = "COMPANY\ArtD"
$primarySqlInstanceSMO = Get-Item "SQLSERVER:\SQL\$($primaryReplica)\Default"
$secondaryReplica = "SRV2"
$secondarySqlInstanceSMO = Get-Item "SQLSERVER:\SQL\$($secondaryReplica)\Default"
$agListenerIPSubnetMask = "192.168.3.17/255.255.255.0"
$agListenerShortName = "L-SRV"
$agListenerCNAME = "SRV"
$agName = "AG01"
$agPrimaryVersion = $primarySqlInstanceSMO.Version
$agSecondaryVersion = $secondarySqlInstanceSMO.Version

# Check if AlwaysOn Feature is enabled on each node in cluster (these nodes will become the Primary and Seconday Replicas)
$stNodesAandB = ($hereString = @"
$($primaryReplica).$($domain)
$($secondaryReplica).$($domain)
"@
).split("`n").TrimEnd("`r") 
