# 01-Enable-SqlAlwaysOn.ps1
#
# Set Variables
. "$($PSScriptRoot)\00-Set-AgVariables.ps1"
# Verify current AlwaysOn instance setting before enabling
$primaryReplica, $secondaryReplica | Get-DbaAgHadr | Select-Object ComputerName, SqlInstance, IsHadrEnabled, InstanceName, Version, UpdateLevel, HostPlatform, HostDistribution | Format-Table
# *************************************************
# *** requires restart of SQL Server Service ******
<# Enable AlwaysOn Feature on default instance - requires restart of SQL Server Service #>Invoke-Command $primaryReplica, $secondaryReplica { Enable-SqlAlwaysOn -Path SQLSERVER:\SQL\$($env:COMPUTERNAME)\Default }
# ***************************************************************************************************************************************************************************************************************************
$primaryReplica, $secondaryReplica | Get-DbaAgHadr | Select-Object ComputerName, SqlInstance, IsHadrEnabled, InstanceName, Version, UpdateLevel, HostPlatform, HostDistribution | Format-Table

# Install Failover Clustering feature adding mgmt tools and cmdlets on primary and secondary
Invoke-Command $primaryReplica, $secondaryReplica { Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools }

# Optional - Review cluster settings
# Invoke-Command $primaryReplica { Get-ClusterGroup | Get-ClusterResource | Where-Object {$_.ResourceType -EQ "IP Address" -OR $_.ResourceType -EQ "Network Name" } | Get-ClusterParameter |  Where-Object {$_.Name -EQ "DnsName" -OR $_.Name -EQ "Name" -OR $_.Name -EQ "Address" -OR $_.Name -EQ "Network" } | Format-Table } 
# Invoke-Command $secondaryReplica { Get-ClusterGroup | Get-ClusterResource | Where-Object {$_.ResourceType -EQ "IP Address" -OR $_.ResourceType -EQ "Network Name" } | Get-ClusterParameter |  Where-Object {$_.Name -EQ "DnsName" -OR $_.Name -EQ "Name" -OR $_.Name -EQ "Address" -OR $_.Name -EQ "Network" } | Format-Table }
