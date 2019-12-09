# 05-Change-Cluster-Parameters.ps1
#
# Set Variables
. "$($PSScriptRoot)\00-Set-AgVariables.ps1"

# (On the primary replica)  change cluster parameters 
#   https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/create-or-configure-an-availability-group-listener-sql-server?view=sql-server-2017#HostRecordTTL

Import-Module FailoverClusters
Get-ClusterResource
Get-ClusterResource $agName
Get-ClusterResource "$($agName)_$($agListenerShortName)" | Get-ClusterParameter |  Select-Object * | Format-List
Get-ClusterResource "$($agName)_$($agListenerShortName)" | Get-ClusterParameter |  Select-Object * | Format-Table
Get-ClusterResource "$($agName)_$($agListenerShortName)" | Set-ClusterParameter RegisterAllProvidersIP 0 
Get-ClusterResource "$($agName)_$($agListenerShortName)" | Set-ClusterParameter HostRecordTTL 300

#stop listener cluster resource
Stop-ClusterResource "$($agName)_$($agListenerShortName)"
#start listener cluster resource
Start-ClusterResource "$($agName)_$($agListenerShortName)"
#start parent cluster resource
Start-ClusterResource $agName
Get-ClusterResource "$($agName)_$($agListenerShortName)" | Get-ClusterParameter |  Select-Object * | Format-Table

#Test the listener, failover, and CNAME
#Test the listener, failover, and CNAME
#Test the listener, failover, and CNAME
#Test the listener, failover, and CNAME