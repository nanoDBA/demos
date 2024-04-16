<# #0 object creation RSJob vs PSJobs 
https://learn-powershell.net/2015/03/31/introducing-poshrsjob-as-an-alternative-to-powershell-jobs/  
#>
Write-Verbose "Begin RSJobs Test" -Verbose
$Test = 42
(Measure-Command {
    $results = 1..5|Start-RSJob -Name {"TEST_$($_)"} -ScriptBlock {
        Param($Object)
        $DebugPreference = 'Continue'
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Debug $_
        }
        Write-Verbose "Creating object" -Verbose
        New-Object PSObject -Property @{
            Object=$Object
            Test=$Using:Test
        }
    }
}).TotalSeconds
Write-Verbose "End RSJobs Test" -Verbose
# Get-RSJob | Receive-RSJob

Write-Verbose "Begin PSJobs Test" -Verbose
$Test = 42
(Measure-Command {
    1..5 | ForEach {
        Start-Job -Name "TEST_$($_)" -ScriptBlock {
            Param($Object)
            $DebugPreference = 'Continue'
            $PSBoundParameters.GetEnumerator() | ForEach {
                Write-Debug $_ # display the key-value pairs of the hashtable in the debug stream by using Write-Debug - example: DEBUG: Key = Object, Value = 1
            }
            Write-Verbose "Creating object" -Verbose
            New-Object PSObject -Property @{
                Object = $Object
                Test   = $Using:Test
            }
        } -ArgumentList $_
    }
}).TotalSeconds
Write-Verbose "End PSJobs Test" -Verbose
# Get-Job | Receive-Job

#0 object creation ForEach -Parallel
Write-Verbose "Begin ForEach-Parallel Test" -Verbose
$Test = 42

(Measure-Command {
    $results = 1..5 | ForEach-Object -Parallel {
        # Using Invoke-Command instead of Start-Job to avoid the overhead of creating a new runspace
        Invoke-Command -ScriptBlock {
            param($Object, $TestValue) # $Object is the current pipeline object, $TestValue is the value of $using:Test
            $DebugPreference = 'Continue'
            Write-Debug "Processing object $Object with test value $TestValue"
            Write-Verbose "Creating object" -Verbose
            New-Object PSObject @{
                Object = $Object
                Test   = $TestValue
            }
        } -ArgumentList $_, $using:Test
    }
}).TotalSeconds

Write-Verbose "End ForEach -Parallel Test" -Verbose
# $results