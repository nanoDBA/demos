# 02-AlwaysOn-Creating-Endpoints.ps1
#
# Set Variables
. "$($PSScriptRoot)\00-Set-AgVariables.ps1"

<# Check Existing Endpoints #>Import-Module sqlserver; $stNodesAandB | ForEach-Object { Write-Output "`n$_ Endpoints:";
    (Get-ChildItem SQLSERVER:\SQL\$($_)\Default\Endpoints).Name }

<# Create New Endpoints #>
$stNodesAandB | ForEach-Object { 
    $endpointName = 'Hadr_endpoint'
    New-SqlHadrEndpoint $endpointName -Port 5022 -Path SQLSERVER:\SQL\$($_)\Default
}

<# Check Existing Endpoints #> $stNodesAandB | ForEach-Object { Write-Output "`n$_ Endpoints:"; (Get-ChildItem SQLSERVER:\SQL\$($_)\Default\Endpoints).Name }

$stNodesAandB | ForEach-Object { $endpointName = 'Hadr_endpoint'; Get-DbaEndpoint -SqlInstance "$($_)" -Endpoint "$endpointName" } | Format-Table *

#$stNodesAandB 
<# start endpoints #>
$stNodesAandB | ForEach-Object { $endpointName = 'Hadr_endpoint'; Get-DbaEndpoint -SqlInstance "$($_)" -Endpoint "$endpointName" | Start-DbaEndpoint }

<# Check Existing Endpoints #> $stNodesAandB | ForEach-Object { Write-Output "`n$_ Endpoints:"; (Get-ChildItem SQLSERVER:\SQL\$($_)\Default\Endpoints).Name }
<# Verify Started status of Endpoints #>
$stNodesAandB | ForEach-Object { $endpointName = 'Hadr_endpoint'; Get-DbaEndpoint -SqlInstance "$($_)" -Endpoint "$endpointName" } | Format-Table *