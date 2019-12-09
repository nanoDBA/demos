# 04-AlwaysOn-Create-Listener.ps1
#
# Set Variables
. "$($PSScriptRoot)\00-Set-AgVariables.ps1"

#Create the Availability Group listener name (on the primary replica) 
$listenerProps = @{
    Name     = $agListenerShortName
    staticIP = $agListenerIPSubnetMask
    Port     = 1433
    Path     = "SQLSERVER:\SQL\$($primaryReplica)\Default\AvailabilityGroups\$($agName)"
}
  
New-SqlAvailabilityGroupListener @listenerProps -Verbose -Confirm