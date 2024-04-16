# PowerShell script to automate the creation of SQL Server containers for demonstration
# Ensure Docker is installed and running before continuing

# Import the module with the Get-Credential function to securely retrieve the password for the SQL Server containers

param (
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10)]
    [int]$numContainers = 4
)

# # Adjust verbosity based on input
# if ($Verbose) {
#     $VerbosePreference = 'Continue'
# }

# retrieve the password from the secure store and convert it to a secure string
$sqlCred = (BetterCredentials\Get-Credential -UserName sa)


# Define the base command with environment variables for the EULA and sa password
# quote the ACCEPT_EULA and MSSQL_SA_PASSWORD values to avoid errors with special characters
$baseCommand = "docker run -e `'ACCEPT_EULA=Y`' -e `'MSSQL_SA_PASSWORD=$($sqlCred.GetNetworkCredential().Password)`'" # escape the single quotes

# Loop to create multiple containers
Set-Variable -Name contNames -Value @() -Scope Global -Force # create a global variable for the container names
                                                                # and set its value to an empty array

$tmp = (Get-Item $env:tmp).FullName # get the full path to the temp folder

# loop to create multiple containers
1..$numContainers | ForEach-Object {
    $containerName = "sql0${PSItem}"
    $port = 1400 + $PSItem   # 1401, 1402, 1403, 1404, etc.
    $contNames += "localhost:$port"

    # Construct the command for each container
    # Write-Verbose "path: $env:tmp\backup\sql0${PSItem}"
    Write-Verbose "path: $tmp\backup\sql0${PSItem}"
    # if (Test-Path -Path $env:tmp\backup\sql0${PSItem}) { # check if the backup folder exists
    if (Test-Path -Path $tmp\backup\sql0${PSItem}) { # check if the backup folder exists
        # Remove-Item $env:tmp\backup\sql0${PSItem} -Force -Recurse
        Remove-Item $tmp\backup\sql0${PSItem} -Force -Recurse
        # mkdir $env:tmp\backup\sql0${PSItem} | Out-Null
    }

    # $backupPath = "$env:tmp\backup\sql0${PSItem}"
    $backupPath = "$tmp\backup\sql0${PSItem}"
    # $volumes   = " --volume $env:tmp\backup:/tmp/backup"
    $volumes = " --volume ${backupPath}:/tmp/backup"
    # $volumes = " --volume $env:tmp\backup\sql0${PSItem}:/tmp/backup"
    # $volumes = " --volume sqlvol:/var/opt/mssql0${PSItem}"
    # $volumes +=  " --volume c:\sqldata\mssql0${PSItem}\:/var/opt/mssql/data"
    # $volumes =  " --volume d:\sqldata\mssql0${PSItem}\:/var/opt/mssql/data"
    # $volumes =  " --volume c:\sqldata\:/var/opt/mssql/data"
    # $volumes += " --volume l:\sqllogs\mssql0${PSItem}\:/var/opt/mssql/log"
    # $volumes += " --volume c:\sqllogs\:/var/opt/mssql/log"
    # $volumes += " --volume c:\sqlbackup\:/var/opt/mssql/backup"
    # $volumes += " --volume $env:tmp\backup:/tmp/backup"
    # $volumes += " --volume $env:tmp\backup\sql0${PSItem}:/tmp/backup"
    # $volumes += " --volume c:\sqlbackup\:/tmp/sqlbackup"
    # $volumes += " --volume /var/opt/mssql0${PSItem}"
    # $volumes += "--volume /var/opt/mssql"
    Write-Verbose "volumes: $volumes"
    $hostname = "-h $containerName"
    $image = "-d mcr.microsoft.com/mssql/server:2022-latest"

    # Construct the command for each container with the volumes, hostname, and image
    $createCommand = "$baseCommand --name $containerName -p ${port}:1433 $volumes $hostname $image"

       # Execute with logging
       Write-Verbose "[$(Get-Date -Format o)] Executing: $createCommand"
    try {
        Invoke-Expression $createCommand | Out-Null # suppress the output
        Write-Host "Container $containerName created on port $port."

        # create a hard link to the pubs.bak file in the backup folder for each container
        # New-Item -ItemType HardLink -Path "$env:tmp\backup\sql0${PSItem}\pubs.bak" -Target "$env:tmp\backup\pubs.bak"

        # Copy the pubs.bak file to the backup folder for each container because hard links don't work in Docker volumes
        Copy-Item -Path "$env:tmp\backup\pubs.bak" -Destination "$env:tmp\backup\sql0${PSItem}\pubs.bak" -Force

        # start the container
        # docker start $containerName
    }
    catch {
        Write-Host "Error creating container $containerName on port $($port): $PSItem"
    }
}

# Wait a bit before starting all containers to avoid immediate stop
Start-Sleep -Seconds 2

# Start all stopped containers silently - this is a bit dangerous because it will start all containers
docker start $(docker ps -a -q) | Out-Null # Run all containers in the background and suppress the output
Write-Host "All containers started." -ForegroundColor White -BackgroundColor Blue