#1a Get-DbaErrorLog serially for multiple instances
$instances = $contNames
$paramHash = @{

After = (Get-Date).AddDays((-50) )
# Text = "A fatal error occurred while reading the input stream from the network. The session will be terminated (input error: 10054, output error: 0)."
Text = "build"
#Text = "err"
}

$results = foreach($sqlInstance in $instances) {

   Get-DbaErrorLog @paramHash -SqlInstance $sqlInstance `
}
Write-Output "`$results.Count: $($results.Count)"
#multiple key sort #with one unique column(commented out uniqueness)
$results | Sort-Object -Property @{e={$_.SqlInstance}}, @{e={$_.LogDate}} ` <#@{e={$_.Text}} -Unique #>
 | Select-Object SqlInstance, LogDate, Text, Source `
 | Format-Table -Wrap