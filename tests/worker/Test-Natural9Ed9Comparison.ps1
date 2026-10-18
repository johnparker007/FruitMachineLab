$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$curator = Join-Path $repo 'tools/Curate-Natural9Ed9Comparison.ps1'
. $curator

$script:Checks = 0
$script:Failures = 0
function Write-Pass([string]$Message) { $script:Checks++; Write-Output "PASS: $Message" }
function Write-Fail([string]$Message) { $script:Checks++; $script:Failures++; Write-Output "FAIL: $Message" }
function Assert-True([bool]$Condition,[string]$Message) { if ($Condition) { Write-Pass $Message } else { Write-Fail $Message } }
function Assert-Equal($Actual,$Expected,[string]$Message) { if ([string]$Actual -eq [string]$Expected) { Write-Pass $Message } else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" } }
function Assert-Throws([string]$Name,[scriptblock]$Block,[string]$Pattern) {
    try { & $Block | Out-Null; Write-Fail "$Name was not rejected" }
    catch {
        $message = $_.Exception.Message
        if ($message -match $Pattern) { Write-Pass "$Name rejected: $message" }
        else { Write-Fail "$Name rejected with unexpected message: $message" }
    }
}

$originalRom = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1'
$changedRom = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1'
$sourceMap = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/source-map.json'
$buildReport = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/build-report.json'
$replay = Join-Path $repo 'evidence/mpu4/skill-cash/actions.csv'
$originalRun = Join-Path $repo 'artifacts/deepseek/il-natural-06/runs/original-02'
$changedRun = Join-Path $repo 'artifacts/deepseek/il-natural-06/runs/changed-01'
$earlyOriginalRun = Join-Path $repo 'artifacts/deepseek/il-natural-06/runs/early-original-01'
$earlyChangedRun = Join-Path $repo 'artifacts/deepseek/il-natural-06/runs/early-changed-01'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-n9-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $output = Join-Path $tempRoot 'comparison.json'
    $result = Invoke-N9Curation -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -EarlyOriginalRunDirectory $earlyOriginalRun -EarlyChangedRunDirectory $earlyChangedRun -OriginalRom $originalRom -ChangedRom $changedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -ReplayPath $replay -OutputPath $output
    Assert-Equal $result.result_status 'gate_changed_did_not_reach_ee16' 'real evidence is recorded as a changed-image gate, not a target success'
    Assert-Equal $result.gate.earliest_sampled_state_mismatch.t '49.050000000' 'earliest sampled meaningful mismatch is 49.050 s'
    Assert-Equal $result.gate.earliest_sampled_state_mismatch.field 'reel3' 'earliest sampled mismatch is reel3'
    Assert-Equal $result.gate.early_operand.control 'FF80' 'early control operand is FF80'
    Assert-Equal $result.gate.early_operand.changed 'FF00' 'early changed operand is FF00'
    Assert-Equal $result.gate.early_return_top.control '0000' 'early control 9ED9 result is 0000'
    Assert-Equal $result.gate.early_return_top.changed '0080' 'early changed 9ED9 result is 0080'
    Assert-Equal $result.control_target.downstream_counter_07d5_07d7 'FFE0C0' 'control target downstream counter is FFE0C0'
    Assert-True (Test-Path -LiteralPath $output) 'real evidence produces a curated JSON file'

    Assert-Throws 'requiring a target comparison for the gated changed run' {
        Invoke-N9Curation -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -EarlyOriginalRunDirectory $earlyOriginalRun -EarlyChangedRunDirectory $earlyChangedRun -OriginalRom $originalRom -ChangedRom $changedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -ReplayPath $replay -OutputPath (Join-Path $tempRoot 'required.json') -RequireTargetComparison
    } 'did not reach EE16/EE22'

    $controlLog = Get-Content -LiteralPath (Join-Path $originalRun 'debug.log')
    $controlFacts = Get-N9TargetFacts $controlLog 'control'
    Assert-N9ControlTarget $controlFacts (Join-Path $originalRun 'roms/m4addr/a6ls.p1')
    Write-Pass 'real control target trace passes the exact phase/stack checks'

    $wrongOperand = $controlLog.Clone()
    for ($i=0;$i -lt $wrongOperand.Count;$i++) {
        if ($wrongOperand[$i] -match '^PF y=9ED9 ') {
            $wrongOperand[$i] = $wrongOperand[$i].Replace('op0=FF80','op0=FF00').Replace('rom9edb=FF80','rom9edb=FF00')
        }
    }
    Assert-Throws 'altered control inline operand' { Assert-N9ControlTarget (Get-N9TargetFacts $wrongOperand 'control') (Join-Path $originalRun 'roms/m4addr/a6ls.p1') } 'inline operand|does not read FF80'

    $wrongPhase = $controlLog.Clone()
    for ($i=0;$i -lt $wrongPhase.Count;$i++) { if ($wrongPhase[$i] -match '^PF y=9ED9 ') { $wrongPhase[$i] = $wrongPhase[$i].Replace('y=9ED9','y=9EDB') } }
    Assert-Throws 'wrong pre-fetch phase' { Assert-N9ControlTarget (Get-N9TargetFacts $wrongPhase 'control') (Join-Path $originalRun 'roms/m4addr/a6ls.p1') } 'phase sequence|Y/token'

    $missingHandler = @($controlLog | Where-Object { $_ -notmatch '^HE pc=7880 ' })
    Assert-Throws 'missing primitive handler hook' { Assert-N9ControlTarget (Get-N9TargetFacts $missingHandler 'control') (Join-Path $originalRun 'roms/m4addr/a6ls.p1') } 'handler phase sequence|field pc'

    $badReturn = $controlLog.Clone()
    for ($i=0;$i -lt $badReturn.Count;$i++) { if ($badReturn[$i] -match '^HE pc=7931 ') { $badReturn[$i] = $badReturn[$i].Replace('sw0=EBCC','sw0=EE22') } }
    Assert-Throws 'bad stack return' { Assert-N9ControlTarget (Get-N9TargetFacts $badReturn 'control') (Join-Path $originalRun 'roms/m4addr/a6ls.p1') } 'return handler|sw0|control stack'

    $badPrestate = $controlLog.Clone()
    for ($i=0;$i -lt $badPrestate.Count;$i++) { if ($badPrestate[$i] -match '^TAIL y=EE16 ') { $badPrestate[$i] = $badPrestate[$i].Replace('credit=02','credit=03') } }
    Assert-Throws 'altered pre-invocation credit' { Assert-N9ControlTarget (Get-N9TargetFacts $badPrestate 'control') (Join-Path $originalRun 'roms/m4addr/a6ls.p1') } 'credit/bank prestate'

    $badCounter = $controlLog.Clone()
    for ($i=0;$i -lt $badCounter.Count;$i++) { if ($badCounter[$i] -match '^TERM y=EE22 ') { $badCounter[$i] = $badCounter[$i].Replace('c=FFE0C0','c=000000') } }
    Assert-Throws 'altered terminal counter' { Assert-N9ControlTarget (Get-N9TargetFacts $badCounter 'control') (Join-Path $originalRun 'roms/m4addr/a6ls.p1') } 'counter/credit/bank'

    $earlyOriginalLog = Get-Content -LiteralPath (Join-Path $earlyOriginalRun 'debug.log')
    $earlyChangedLog = Get-Content -LiteralPath (Join-Path $earlyChangedRun 'debug.log')
    Assert-N9EarlyPair $earlyOriginalLog $earlyChangedLog $originalRom $changedRom
    Write-Pass 'real early 9ED9 pair passes operand/result/state checks'

    $earlyWrongOperand = $earlyChangedLog.Clone()
    for ($i=0;$i -lt $earlyWrongOperand.Count;$i++) { if ($earlyWrongOperand[$i] -match '^E9L ') { $earlyWrongOperand[$i] = $earlyWrongOperand[$i].Replace('token=FF00','token=FF80').Replace('rom9edb=FF00','rom9edb=FF80') } }
    Assert-Throws 'early changed operand relabelled' { Assert-N9EarlyPair $earlyOriginalLog $earlyWrongOperand $originalRom $changedRom } 'operand mismatch|operand-read'

    $earlyWrongResult = $earlyChangedLog.Clone()
    for ($i=0;$i -lt $earlyWrongResult.Count;$i++) { if ($earlyWrongResult[$i] -match '^E9R ') { $earlyWrongResult[$i] = $earlyWrongResult[$i].Replace('top=0080','top=0000') } }
    Assert-Throws 'early changed result relabelled as control' { Assert-N9EarlyPair $earlyOriginalLog $earlyWrongResult $originalRom $changedRom } 'expected 0000/0080'

    $syntheticA = Join-Path $tempRoot 'state-a.csv'
    $syntheticB = Join-Path $tempRoot 'state-b.csv'
    @(
        't,pc,y,u,s,credit_candidate,state_2f0',
        '49.050000000,0000,0000,0000,0000,000000,00',
        '100.050000000,0000,0000,0000,0000,00001E,05'
    ) | Set-Content -LiteralPath $syntheticA
    @(
        't,pc,y,u,s,credit_candidate,state_2f0',
        '49.050000000,0000,0000,0000,0000,000001,01',
        '100.050000000,0000,0000,0000,0000,000012,0B'
    ) | Set-Content -LiteralPath $syntheticB
    $mismatch = Get-N9EarliestStateMismatch $syntheticA $syntheticB
    Assert-Equal $mismatch.key '49.050000000' 'earliest state mismatch follows chronological row order, not lexical time order'
    Assert-Equal $mismatch.field 'credit_candidate' 'synthetic earliest mismatch field is detected'

    Assert-Throws 'wrong ROM identity' { Assert-N9Rom $originalRom ('0'*40) $script:N9OriginalSha256 'original' } 'SHA1'
    Assert-Throws 'forbidden playback argument' { Assert-N9RunArguments @('m4addr','-noreadconfig','-playback','x') $originalRun } 'forbidden option'
    Assert-Throws 'debugger CPU write' { Assert-N9DebuggerCommands @('bpset 0xfc,1,{pc=0x1234;go}') } 'writes CPU state'
    Assert-Throws 'debugger memory write' { Assert-N9DebuggerCommands @('bpset 0xfc,1,{w@0x100=1;go}') } 'writes memory'
    Assert-Throws 'debugger state load' { Assert-N9DebuggerCommands @('load state') } 'forbidden operation'
    $stateSeed = Join-Path $tempRoot 'state-seed'
    New-Item -ItemType Directory -Path (Join-Path $stateSeed 'state') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $stateSeed 'state/seed.sta') -Value 'x'
    Assert-Throws 'seeded save state' { Assert-N9StateDirectory $stateSeed } 'save state'

    $staleMap = Join-Path $tempRoot 'source-map.json'
    Copy-Item -LiteralPath $sourceMap -Destination $staleMap
    Add-Content -LiteralPath $staleMap -Value ' '
    Assert-Throws 'stale source map' {
        Invoke-N9Curation -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -EarlyOriginalRunDirectory $earlyOriginalRun -EarlyChangedRunDirectory $earlyChangedRun -OriginalRom $originalRom -ChangedRom $changedRom -SourceMapPath $staleMap -BuildReportPath $buildReport -ReplayPath $replay -OutputPath (Join-Path $tempRoot 'stale-map.json')
    } 'Source map is not the accepted'

    $alteredReplay = Join-Path $tempRoot 'actions.csv'
    $replayText = Get-Content -LiteralPath $replay -Raw
    [IO.File]::WriteAllText($alteredReplay, $replayText.Replace('2100,2103,:AUX2,128','2101,2103,:AUX2,128'), (New-Object System.Text.UTF8Encoding($false)))
    Assert-Throws 'altered replay hash' {
        Invoke-N9Curation -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -EarlyOriginalRunDirectory $earlyOriginalRun -EarlyChangedRunDirectory $earlyChangedRun -OriginalRom $originalRom -ChangedRom $changedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -ReplayPath $alteredReplay -OutputPath (Join-Path $tempRoot 'altered-replay.json')
    } 'replay SHA256'

    Assert-Throws 'changed run relabelled as original' {
        Invoke-N9Curation -OriginalRunDirectory $originalRun -ChangedRunDirectory $originalRun -EarlyOriginalRunDirectory $earlyOriginalRun -EarlyChangedRunDirectory $earlyChangedRun -OriginalRom $originalRom -ChangedRom $changedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -ReplayPath $replay -OutputPath (Join-Path $tempRoot 'wrong-run.json')
    } 'variant|SHA1|expected Changed'

    Assert-Throws 'changed early run relabelled as control' {
        Invoke-N9Curation -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -EarlyOriginalRunDirectory $earlyOriginalRun -EarlyChangedRunDirectory $earlyOriginalRun -OriginalRom $originalRom -ChangedRom $changedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -ReplayPath $replay -OutputPath (Join-Path $tempRoot 'wrong-early.json')
    } 'variant|SHA1|early'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
Write-Output ("RESULT: {0} checks, {1} failures" -f $script:Checks,$script:Failures)
if ($script:Failures -ne 0) { exit 1 }

