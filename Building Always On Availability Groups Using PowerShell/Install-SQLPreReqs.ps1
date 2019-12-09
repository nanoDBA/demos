#requires -version 5.0
#requires -RunAsAdministrator
<#PSScriptInfo
.Synopsis
   Install Prerequisites for SQL Server (2016 and higher) on local machine (May require reboots / multiple runs)
.DESCRIPTION
   Multiple Tweaks to the OS are included, and some best practice checks
.EXAMPLE
   Install-DBAPreReqs -AutoReboot $true -InstallModuledbatools $true
.EXAMPLE
#verify options such as default shell _BEFORE_ uncommenting the below section

$splatting = @{
AutoReboot=1
PowerShellDefaultShell=0
HideServerManagerAtLogon=0
DisableWindowsDefender=1
InstallWindowsUpdates=0
DisableOSVolumeIndexing=1
InstallModuleSqlServer=1
InstallModuleDBAtools=1
SetBestPracticePowerPlan=1
UpdatePSHelp=0
}

#Load function
. '\\WIN10\AlwaysOn\Install-SQLPreReqs.ps1'

# May require reboots / multiple runs
Install-DBAPreReq @splatting -ConfirmExecute 1
#>

function Install-DBAPreReq {
    [CmdletBinding()]

    param (

          [Parameter(Mandatory = $true)][bool]$ConfirmExecute
        , [Parameter(Mandatory = $true)][bool]$AutoReboot = $false
        , [Parameter(Mandatory = $false)][bool]$PowerShellDefaultShell = $false
        , [Parameter(Mandatory = $false)][bool]$HideServerManagerAtLogon = $false
        , [Parameter(Mandatory = $true)][bool]$DisableWindowsDefender = $false
        , [Parameter(Mandatory = $true)][bool]$InstallWindowsUpdates = $false
        , [Parameter(Mandatory = $true)][bool]$DisableOSVolumeIndexing = $false
        , [Parameter(Mandatory = $false)][bool]$InstallModuledbatools = $true
        , [Parameter(Mandatory = $false)][bool]$SetBestPracticePowerPlan = $true
        , [Parameter(Mandatory = $false)][bool]$InstallModuleSqlServer = $true
        , [Parameter(Mandatory = $false)][bool]$UpdatePSHelp = $false
    )

    Begin {
    }
    Process {


        ###_SQL_Pre-reqs,install.txt
        #Create profile if it doesn't exist and set an execution policy limited to process scope
        if (!(Test-Path $profile)) {Write-Output "Creating Profile..."; if (!(Test-Path(split-path $PROFILE))) {mkdir (split-path $PROFILE)}; "Set-ExecutionPolicy Bypass -Scope Process -Force" | Set-Content $PROFILE; . $profile}

        #region Deploy Transcription file w/o access to network share - *all* new PowerShell sessions will transcribe

        If (!(Test-Path $PsHome\Microsoft.PowerShell_profile.ps1)) {
            Add-Content -Path $PsHome\Microsoft.PowerShell_profile.ps1 @"
#Checks for C:\PowerShellLog folder and creates one if none exists.
$([environment]::NewLine)
If(!(Test-Path C:\PowerShellLog\`$env:computername))
{
New-Item C:\PowerShellLog\`$env:computername -ItemType Directory | Out-Null;
$([environment]::NewLine)
`$folder = Get-WmiObject -Query "SELECT * FROM CIM_Directory WHERE Name='C:\\PowerShellLog'";
$([environment]::NewLine)
`$folder.Compress();
}
$([environment]::NewLine)
pushd;
$([environment]::NewLine)
Set-Location C:\ ;
$([environment]::NewLine)
`$TranscriptPath ="C:\PowerShellLog\`$env:computername\"+ ([string](Get-Date -format "yyyy-MM-dd__HH-mm-ss") + "_" + ([string](`$env:COMPUTERNAME)) + "_" + ([string](`$env:USERNAME)) + "__PowerShell_Session_Transcript.txt") ;
$([environment]::NewLine)
popd ;
$([environment]::NewLine)
Start-Transcript `$TranscriptPath ;
"@
        }

        #endregion Deploy Transcription file w/o access to network share - *all* new PowerShell sessions will transcribe

        #check for other logged on users
        Invoke-WebRequest 'https://gallery.technet.microsoft.com/scriptcenter/Get-LoggedOnUser-Gathers-7cbe93ea/file/85728/5/Get-LoggedOnUser.ps1' -OutFile $env:TEMP\Get-LoggedOnUser.ps1 ; if ( (. $env:TEMP\Get-LoggedOnUser.ps1 -ComputerName localhost).count -GT 1) {Write-Output "***WARNING: Other Users are logged on.***"; . $env:TEMP\Get-LoggedOnUser.ps1 -ComputerName localhost | Format-Table -AutoSize ; Write-Output "^^ WARNING: Other Users are logged on. ^^" | Out-String | Write-Host -ForegroundColor Red; }

        $regKey = "hklm:/software/microsoft/windows nt/currentversion"
        $Core = (Get-ItemProperty $regKey).InstallationType -eq "Server Core"

        sleep -Seconds 7;

        if ($core) { 
            if ($PowerShellDefaultShell) {
                # DANGER # Server Core? ---OPTIONAL--- Setting PowerShell as the Default Shell Manually
                #If you've only got one server, a couple of servers or maybe your Server Core machines are workgroup members so you can't use Group Policy and if any of these are true, the manual method is for you. It's a simple PowerShell one-liner:
                # source: https://richardjgreen.net/setting-powershell-default-shell-server-core/
                Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name Shell -Value 'PowerShell.exe -NoExit'
            }
        }
        # DANGER #Revert needed? Setting explorer as the Default Shell Manually
        # i.e. Be careful not to change the default shell unless you're on Server Core
        #Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name Shell -Value 'explorer.exe'

        #check Installed Software
        Invoke-WebRequest 'https://gallery.technet.microsoft.com/scriptcenter/Get-RemoteProgram-Get-list-de9fd2b4/file/94849/6/Get-RemoteProgram.ps1' -OutFile $env:TEMP\Get-RemoteProgram.ps1 ; . $env:TEMP\Get-RemoteProgram.ps1; Get-RemoteProgram -Property Publisher, InstallDate, DisplayVersion, InstallSource | Where-Object SystemComponent -ne 1 | Sort-Object InstallDate | Format-Table -AutoSize

        if (!($core) -and ($HideServerManagerAtLogon)) {
            #Hide Server Manager at logon   https://blogs.technet.microsoft.com/rmilne/2014/05/30/how-to-hide-server-manager-at-logon/
            New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" -Force
        }

        if ($DisableWindowsDefender) {	
            if (! ( (Get-WindowsFeature -Name Windows-Defender-Features).Installed)) {Write-Output "Windows Defender is not installed" | Out-String | Write-Host -ForegroundColor Yellow; }
            if ( (Get-WindowsFeature -Name Windows-Defender-Features).Installed) { 
                #Disable Windows Defender http://www.thomasmaurer.ch/2016/07/how-to-disable-and-configure-windows-defender-on-windows-server-2016-using-powershell/
                Set-MpPreference -DisableRealtimeMonitoring $true ;
                # uninstall Windows Defender https://technet.microsoft.com/en-us/windows-server-docs/security/windows-defender/windows-defender-overview-windows-server
                Get-WindowsFeature -Name Windows-Defender-Features ;
                Uninstall-WindowsFeature -Name Windows-Defender-Features -Confirm:$false ;
                Get-WindowsFeature -Name Windows-Defender-Features ;
            }
        }

        #check for pending reboots
        Invoke-WebRequest https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542/file/139923/3/Get-PendingReboot.ps1 -UseBasicParsing | Invoke-Expression
        $RebootPending = (Get-PendingReboot localhost).RebootPending ;
        Get-PendingReboot $env:COMPUTERNAME | Format-Table RebootPending | Out-String | Write-Host -ForegroundColor Yellow; ;
        if (($AutoReboot) -AND ($RebootPending)) {
            Write-Output "Rebooting..."; Write-Output "Waiting 7 seconds to continue script execution... Push CTRL+C to terminate"
            Start-Sleep -Seconds 7; Restart-Computer -Force
        }


        #check last reboot
        Get-LastReboot localhost | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow;

        #Verify NTFS block size of 64k
        $NTFS_Volumes = Invoke-WebRequest https://gallery.technet.microsoft.com/PowerShell-Get-Volumes-ac89376b/file/150348/1/Get-VolumesBlockSize.ps1 -UseBasicParsing | Invoke-Expression | where Name -GT 'C:\';
        Write-Output $NTFS_Volumes
        if ( ($NTFS_Volumes).Blocksize -NE 65536) {Write-Output "WARNING: *** Volume Block Size != 64K. ***"}

        # Check hotfixes
        Get-HotFix | Sort-Object InstalledOn -desc | Format-Table -AutoSize

        if ($InstallWindowsUpdates) {
            ### DANGER REBOOTS - optional
            <# Update Windows Critical and Security Updates Only - Auto-reboots #>
            $moduleName = "PSWindowsUpdate"
            if (Get-Module -ListAvailable -Name $moduleName) {
                Write-Output "$moduleName module is already installed." | Out-String | Write-Host -ForegroundColor Yellow; ;
                Import-Module $moduleName; 
                Get-WUInstall -MicrosoftUpdate -Category 'Security Updates', 'Critical Updates' -AcceptAll -WindowsUpdate -AutoReboot -Verbose
            }
            else {
                Write-Output "Module $moduleName is not installed - installing..." | Out-String | Write-Host -ForegroundColor Yellow;
                $NuGetProvider = Get-PackageProvider -Name NuGet | Where-Object Version -GT 2.8.5.201; if ( -not $NuGetProvider) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false }
                <# Install moduleName #>Install-Module -Force $moduleName -Confirm:$false -Verbose ; 
                Import-Module $moduleName; 
                Get-WUInstall -MicrosoftUpdate -Category 'Security Updates', 'Critical Updates' -AcceptAll -WindowsUpdate -AutoReboot -Verbose
            }
        }

        if ($DisableOSVolumeIndexing) {
            #deploy / disable indexing
            Get-WmiObject -Class Win32_Volume -Filter "SystemVolume='False' and FileSystem!='UDF' and IndexingEnabled='True' and DriveLetter!='C:'" | Select Caption, IndexingEnabled, SystemVolume, Label | sort Caption | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow;
            Get-WmiObject -Class Win32_Volume -Filter "SystemVolume='False' and FileSystem!='UDF' and IndexingEnabled='True' and DriveLetter!='C:'" | Set-WmiInstance -Arguments @{IndexingEnabled = $False} | Out-Null 
            Get-WmiObject -Class Win32_Volume -Filter "SystemVolume='False' and FileSystem!='UDF' and IndexingEnabled='False' and DriveLetter!='C:'" | Select Caption, IndexingEnabled, SystemVolume, Label | sort Caption | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow;

            #rollback / re-enable indexing
            #Get-WmiObject -Class Win32_Volume -Filter "SystemVolume='False' and FileSystem!='UDF' and IndexingEnabled='False' and DriveLetter!='C:'" | Select Caption, IndexingEnabled, SystemVolume, Label | sort Caption | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow;
            #Get-WmiObject -Class Win32_Volume -Filter "SystemVolume='False' and FileSystem!='UDF' and IndexingEnabled='False' and DriveLetter!='C:'" | Set-WmiInstance -Arguments @{IndexingEnabled=$True} | Out-Null 
            #Get-WmiObject -Class Win32_Volume -Filter "SystemVolume='False' and FileSystem!='UDF' and IndexingEnabled='True' and DriveLetter!='C:'" | Select Caption, IndexingEnabled, SystemVolume, Label | sort Caption | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow;

        }

        if ($InstallModuleSqlServer) {
            $moduleName = "SqlServer"
            if (Get-Module -ListAvailable -Name $moduleName) {
                Write-Output "$moduleName module is already installed." | Out-String | Write-Host -ForegroundColor Yellow;
                #Get-DiskSpace $env:COMPUTERNAME | Format-Table -AutoSize ;
            }
            else {
                Write-Output "Module $moduleName is not installed - installing..." | Out-String | Write-Host -ForegroundColor Yellow;
                $NuGetProvider = Get-PackageProvider -Name NuGet | Where-Object Version -GT 2.8.5.201; if ( -not $NuGetProvider) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false }
                <# Install moduleName #>Install-Module -Force $moduleName -Confirm:$false -Verbose
            }

        }

        if ($InstallModuledbatools) {
            $moduleName = "dbatools"
            if (Get-Module -ListAvailable -Name $moduleName) {
                Write-Output "$moduleName module is already installed." | Out-String | Write-Host -ForegroundColor Yellow;
                Get-DbaDiskSpace $env:COMPUTERNAME | Format-Table -AutoSize ;
            }
            else {
                Write-Output "Module $moduleName is not installed - installing..." | Out-String | Write-Host -ForegroundColor Yellow;
                $NuGetProvider = Get-PackageProvider -Name NuGet | Where-Object Version -GT 2.8.5.201; if ( -not $NuGetProvider) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false }
                <# Install moduleName #>Install-Module -Force $moduleName -Confirm:$false -Verbose ; Get-DbaDiskSpace $env:COMPUTERNAME | Format-Table -AutoSize
            }

        }


        if ($SetBestPracticePowerPlan) {

            #$rollback = $true
            $rollback = $false

            $boxen = @(
                "localhost"
            )
            $results_before = Test-DbaPowerPlan -ComputerName $boxen
            $results_before | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow;
            $results_before_boxen = $results_before | where IsBestPractice -EQ $False | Select -ExpandProperty ComputerName
            $target_boxen = $results_before_boxen
            if ($rollback) {$target_boxen | Set-DbaPowerPlan -CustomPowerPlan 'Balanced' <# rollback #> } 
                elseif (!($rollback)) {$target_boxen | Set-DbaPowerPlan -CustomPowerPlan 'High Performance' <# Set best practice #> }
            $results_after = Test-DbaPowerPlan -ComputerName $target_boxen
            $results_after | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow;
        }

        if ($UpdatePSHelp) {
            <# Update all the help things, ignore uavailable/non-updateable help files #>Update-Help -Force -ErrorAction SilentlyContinue
        }

        ##Standalone OS patches from MSU - use only if needed
        #$patchname = "\\srv-sqlbk01\sqlbackup\OS patches\windows10.0-kb3199986-x64_5d4678c30de2de2bd7475073b061d0b3b2e5c3be.msu"
        #. wusa.exe $patchname /quiet /warnrestart
        #
        #$patchname = "\\srv-sqlbk01\sqlbackup\OS patches\windows10.0-kb3197954-x64_74819c01705e7a4d0f978cc0fbd7bed6240642b0.msu"
        #. wusa.exe $patchname /quiet /warnrestart
        ##Recent Patches
        #Get-HotFix | sort InstalledDate -desc | Format-Table -AutoSize


        #<#Enable Cred-SSP for double-hop remoting #>Enable-PSRemoting -Force; Enable-WSManCredSSP -Role Server -Force ; Enable-WSManCredSSP -Role Client -Force -DelegateComputer *.SOMEDOMAIN.COM, *.SOMEDOMAIN.LOCAL, *.SRV.INT
        <#Enable Cred-SSP for double-hop remoting #>Enable-PSRemoting -Force; Enable-WSManCredSSP -Role Server -Force

        #Verify .NET Framework 4.6 installed
        #Get-WindowsFeature NET-Framework-45-Core;
        if (!(Get-WindowsFeature NET-Framework-45-Core).Installed) {
            Write-Output "Installing .NET Framework"; Add-WindowsFeature NET-Framework-45-Core -Confirm:$false
        }
        Get-WindowsFeature NET-Framework-45-Core -verbose | Format-Table -AutoSize
        #<# Install .NET 3.5 for SQL 2014 and older - usually I mount an ISO #>Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -LimitAccess -Source '\\srv\it\DBA\OS\Server_2012_R2\SW_DVD9_Windows_Svr_Std_and_DataCtr_2012_R2_64Bit_English_-3_MLF_X19-53588\sources\sxs'


    }
    End {
        Get-PendingReboot $env:COMPUTERNAME | Format-Table RebootPending ;
        Write-Output "Done." | Out-String | Write-Host -ForegroundColor Yellow
    }
}
# Jeffrey Snover wrote Get-LastReboot - wrapping it in a function
# https://www.powershellgallery.com/packages/get-lastreboot
function Get-LastReboot {
    param(
        [Parameter(Mandatory = 0, Position = 0)]
        [string[]]$ComputerName = ".",
        [Parameter(Mandatory = 0, Position = 1)]
        $Count = 1
    )

    foreach ($e in Get-EventLog -LogName System -Source Microsoft-Windows-Kernel-General -InstanceId 12 -Newest $Count -ComputerName $ComputerName) {
        $reboot = [DateTime]$e.ReplacementStrings[-1]
        $ago = New-TimeSpan -Start $reboot
        [pscustomobject]@{
            ComputerName = $e.MachineName
            LastReboot   = $reboot; 
            DaysAgo      = $ago.Days
            HoursAgo     = [int]$ago.TotalHours
        }
    }
}
