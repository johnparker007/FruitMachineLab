$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../tools/worker/WorkerWatchdog.psm1') -Force
$t=[datetime]::UtcNow
$script:count=0
function Check($Expected,$Overrides){
    $p=@{Now=$t.AddSeconds(40);Started=$t;LastActivity=$t.AddSeconds(39);LastMilestone=$t.AddSeconds(39);HardDeadline=$t.AddSeconds(100);SoftSeconds=30;IdleSeconds=15;MilestoneSeconds=30;CommandSeconds=45}
    foreach($key in $Overrides.Keys){$p[$key]=$Overrides[$key]}
    $actual=Get-WorkerWatchdogDecision @p
    if($actual -ne $Expected){throw "Expected $Expected, got $actual"}
    $script:count++
}
Check 'running-extended' @{}
Check 'running' @{Now=$t.AddSeconds(10)}
Check 'stalled-no-activity' @{LastActivity=$t}
Check 'stalled-no-milestone' @{LastMilestone=$t}
Check 'running-extended' @{LastActivity=$t;LastMilestone=$t;CommandStarted=$t}
Check 'command-deadline' @{Now=$t.AddSeconds(46);CommandStarted=$t}
Check 'hard-deadline' @{Now=$t.AddSeconds(100);LastActivity=$t.AddSeconds(100);LastMilestone=$t.AddSeconds(100);CommandStarted=$t.AddSeconds(99)}
$file=Join-Path $env:TEMP ('watchdog-'+[guid]::NewGuid().ToString('N')+'.json')
try{
    $p=@{taskId='test';phase='inspect';completed=@();nextStep='verify';percent=10;activeCommand=$null}
    $p|ConvertTo-Json|Set-Content $file
    $first=Read-WorkerProgress $file 'test' $t.AddSeconds(-1)
    $p.percent=90;$p|ConvertTo-Json|Set-Content $file
    $second=Read-WorkerProgress $file 'test' $t.AddSeconds(-1)
    if($first.signature -ne $second.signature){throw 'Percent-only rewrite counted as milestone'}
    $script:count++
    $rejected=$false
    try{Read-WorkerProgress $file 'other-task' $t.AddSeconds(-1)|Out-Null}catch{$rejected=$true}
    if(!$rejected){throw 'Wrong task progress accepted'}
    $script:count++
    $rejected=$false
    try{Read-WorkerProgress $file 'test' $t.AddDays(1)|Out-Null}catch{$rejected=$true}
    if(!$rejected){throw 'Stale progress accepted'}
    $script:count++
}finally{Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue}
Write-Output "PASS: $script:count watchdog policy/progress checks (no API calls)"
