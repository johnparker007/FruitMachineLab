$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $repo 'tools/Curate-IlVmTrace.ps1')

$script:Checks = 0
$script:Failures = 0
function Write-Pass([string]$Message) { $script:Checks++; Write-Output "PASS: $Message" }
function Write-Fail([string]$Message) { $script:Checks++; $script:Failures++; Write-Output "FAIL: $Message" }
function Assert-True([bool]$Condition,[string]$Message) { if ($Condition) { Write-Pass $Message } else { Write-Fail $Message } }
function Assert-Equal($Actual,$Expected,[string]$Message) { if ([string]$Actual -eq [string]$Expected) { Write-Pass $Message } else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" } }
function Assert-NoThrow([string]$Name,[scriptblock]$Block) {
    try { & $Block | Out-Null; Write-Pass "$Name accepted" }
    catch { Write-Fail "$Name rejected unexpectedly: $($_.Exception.Message)" }
}
function Assert-Throws([string]$Name,[scriptblock]$Block,[string]$Pattern) {
    try { & $Block | Out-Null; Write-Fail "$Name was not rejected" }
    catch {
        $message = $_.Exception.Message
        if ($message -match $Pattern) { Write-Pass "$Name rejected: $message" }
        else { Write-Fail "$Name rejected with unexpected message: $message" }
    }
}
function Copy-Events($Events) { return @($Events | ConvertTo-Json -Depth 8 | ConvertFrom-Json) }

$originalRom = 'C:\Users\John\Documents\Codex\2026-10-13\help-me-set-up-a-local\outputs\mpu4\rom\a6ls.p1'
if (!(Test-Path -LiteralPath $originalRom -PathType Leaf)) {
    $originalRom = Join-Path $repo 'artifacts/deepseek/il-natural-06/runs/early-original-01/roms/m4addr/a6ls.p1'
}
$repairedRom = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/edited-repaired.p1'
$sourceMap = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/source-map.json'
$buildReport = Join-Path $repo 'artifacts/deepseek/il-boot-04/build-01/build-report.json'
$plan = Join-Path $repo 'evidence/mpu4/integrity/il-natural-reachability-plan.json'
$replay = Join-Path $repo 'evidence/mpu4/skill-cash/actions.csv'
$originalRun = Join-Path $repo 'artifacts/deepseek/il-lua-api-09/runs/original-03'
$changedRun = Join-Path $repo 'artifacts/deepseek/il-lua-api-09/runs/repaired-01'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-lt-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

function Copy-Run([string]$Source,[string]$Name) {
    $destination = Join-Path $tempRoot $Name
    New-Item -ItemType Directory -Path $destination | Out-Null
    Get-ChildItem -LiteralPath $Source | Copy-Item -Destination $destination -Recurse
    $runArgs = @(Read-LtJson (Join-Path $destination 'arguments.json'))
    for ($i=0;$i -lt $runArgs.Count;$i++) { $runArgs[$i] = ([string]$runArgs[$i]).Replace($Source,$destination) }
    Write-LtJson (Join-Path $destination 'arguments.json') $runArgs 6
    return $destination
}

try {
    $output = Join-Path $tempRoot 'curated.json'
    $result = Invoke-LtCuration -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -OriginalRom $originalRom -RepairedRom $repairedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -PlanPath $plan -ReplayPath $replay -OutputPath $output -RequireBoundaryTrace -Force
    Assert-Equal $result.result_status 'complete_early_natural_9ed9_call_native_debugger_hooks' 'real evidence records the complete early native-debugger call'
    Assert-True ([bool]$result.complete_call_proof) 'real evidence claims a complete call'
    Assert-Equal $result.early_call.original.result '0000' 'original early call result is 0000'
    Assert-Equal $result.early_call.changed.result '0080' 'changed early call result is 0080'
    Assert-Equal $result.early_call.original.first_literal 'FF80' 'original first literal is FF80'
    Assert-Equal $result.early_call.changed.first_literal 'FF00' 'changed first literal is FF00'
    Assert-Equal $result.early_call.original.saved_cursor $result.early_call.changed.saved_cursor 'saved caller cursors match'
    Assert-True ([bool]$result.early_call.actual_post_puls_continuation) 'post-PULS continuation is recorded'
    Assert-Equal @($result.early_call.original.events).Count 11 'original run has eleven exact-boundary events'
    Assert-Equal @($result.early_call.changed.events).Count 11 'changed run has eleven exact-boundary events'
    Assert-True ($result.runs.physical_inputs_identical) 'physical inputs are identical across original/changed'
    Assert-Equal $result.mame.manager_machine_debugger 'userdata under -debug' 'debugger manager capability is recorded'
    Assert-True (Test-Path -LiteralPath $output) 'real evidence produces a curated JSON file'

    $valid = Copy-Events $result.early_call.original.events
    Assert-NoThrow 'valid exact-boundary sequence' { Assert-LtBoundaryClaims $valid }

    $wrongY = Copy-Events $valid
    $wrongY[2].y = '9EDB'
    Assert-Throws 'wrong Y phase' { Assert-LtBoundaryClaims $wrongY } 'Y is'

    $missing = @($valid | Where-Object { $_.event -ne 'NODE_PREFETCH' -or [int]$_.index -ne 2 })
    Assert-Throws 'missing node' { Assert-LtBoundaryClaims $missing } 'count'

    $reordered = Copy-Events $valid
    $swap = $reordered[2]; $reordered[2] = $reordered[3]; $reordered[3] = $swap
    Assert-Throws 'reordered node' { Assert-LtBoundaryClaims $reordered } 'event|Y|index'

    $forgedReturn = Copy-Events $valid
    $forgedReturn[9].saved_cursor = 'EE22'
    Assert-Throws 'forged return' { Assert-LtBoundaryClaims $forgedReturn } 'post-return Y'

    $badState = Copy-Events $valid
    $badState[1].s = '0798'
    Assert-Throws 'mismatched handler entry state' { Assert-LtBoundaryClaims $badState } 'S is'

    $ambiguous = Copy-Events $valid
    $ambiguous[4].index = 9
    Assert-Throws 'ambiguous/reordered node index' { Assert-LtBoundaryClaims $ambiguous } 'index'

    Assert-Throws 'wrong ROM identity' { Assert-LtRomFile $repairedRom $script:LtOriginalSha1 $script:LtOriginalSha256 'wrong original' } 'SHA'
    Assert-Throws 'wrong image for original map' { Assert-LtVariantMap (Read-LtJson (Join-Path $originalRun 'variant-map.json')) 'Original' $script:LtRepairedSha256 (Join-Path $changedRun 'roms/m4addr/a6ls.p1') } 'stale or wrong'
    $ambiguousMap = Read-LtJson (Join-Path $originalRun 'variant-map.json')
    $ambiguousMap.entries[2].nodeIndex = 1
    Assert-Throws 'ambiguous map node order' { Assert-LtVariantMap $ambiguousMap 'Original' $script:LtOriginalSha256 (Join-Path $originalRun 'roms/m4addr/a6ls.p1') } 'node order|reordered'

    $staleMap = Join-Path $tempRoot 'stale-map.json'
    Copy-Item -LiteralPath $sourceMap -Destination $staleMap
    Add-Content -LiteralPath $staleMap -Value ' '
    Assert-Throws 'stale source map' { Invoke-LtCuration -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -OriginalRom $originalRom -RepairedRom $repairedRom -SourceMapPath $staleMap -BuildReportPath $buildReport -PlanPath $plan -ReplayPath $replay -OutputPath (Join-Path $tempRoot 'stale-map-out.json') -Force } 'Source map identity'

    $staleBuild = Join-Path $tempRoot 'stale-build.json'
    Copy-Item -LiteralPath $buildReport -Destination $staleBuild
    Add-Content -LiteralPath $staleBuild -Value ' '
    Assert-Throws 'stale build report' { Invoke-LtCuration -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -OriginalRom $originalRom -RepairedRom $repairedRom -SourceMapPath $sourceMap -BuildReportPath $staleBuild -PlanPath $plan -ReplayPath $replay -OutputPath (Join-Path $tempRoot 'stale-build-out.json') -Force } 'Build report identity'

    $staleReplay = Join-Path $tempRoot 'stale-replay.csv'
    Copy-Item -LiteralPath $replay -Destination $staleReplay
    Add-Content -LiteralPath $staleReplay -Value '999999,999999,:BLACK2,1,forged'
    Assert-Throws 'stale replay' { Invoke-LtCuration -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -OriginalRom $originalRom -RepairedRom $repairedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -PlanPath $plan -ReplayPath $staleReplay -OutputPath (Join-Path $tempRoot 'stale-replay-out.json') -Force } 'Replay identity'

    $seeded = Copy-Run $originalRun 'seeded-run'
    Set-Content -LiteralPath (Join-Path $seeded 'state/seed.sta') -Value 'forged' -NoNewline
    Assert-Throws 'seeded save state' { Get-LtRunFacts $seeded 'Original' } 'State directory'

    $debugWrite = Copy-Run $originalRun 'debug-write-run'
    $debugWriteObservation = Read-LtJson (Join-Path $debugWrite 'observation.json')
    $debugWriteObservation.debugger_writes = $true
    Write-LtJson (Join-Path $debugWrite 'observation.json') $debugWriteObservation 18
    Assert-Throws 'debugger write claim' { Get-LtRunFacts $debugWrite 'Original' } 'debugger state writes'

    $noDebug = Copy-Run $originalRun 'no-debug-run'
    $noDebugArgs = @(Read-LtJson (Join-Path $noDebug 'arguments.json') | Where-Object { $_ -ne '-debug' })
    Write-LtJson (Join-Path $noDebug 'arguments.json') $noDebugArgs 6
    Assert-Throws 'missing debugger argument' { Get-LtRunFacts $noDebug 'Original' } 'required option -debug'

    $alteredLog = Copy-Run $originalRun 'altered-log-run'
    Add-Content -LiteralPath (Join-Path $alteredLog 'debug.log') -Value 'EVENT NODE_PREFETCH index=0 y=9ED9 token=795B x=9ED9 u=066E s=0796 top=0000 second=0000 third=0000 fourth=0000 sw0=9F16 sw1=9F3F cycle=0000000003C5FEF0'
    Assert-Throws 'altered raw debug log' { Get-LtRunFacts $alteredLog 'Original' } 'altered'

    $wrongMapRun = Copy-Run $originalRun 'wrong-map-run'
    Copy-Item -LiteralPath (Join-Path $changedRun 'variant-map.json') -Destination (Join-Path $wrongMapRun 'variant-map.json') -Force
    Assert-Throws 'wrong variant map' { Get-LtRunFacts $wrongMapRun 'Original' } 'variant differs|hash'

    $differentActions = Copy-Run $changedRun 'different-actions-run'
    Add-Content -LiteralPath (Join-Path $differentActions 'actions.csv') -Value '999999,999999,:BLACK2,1,forged,,,'
    Assert-Throws 'different scripted physical inputs' { Invoke-LtCuration -OriginalRunDirectory $originalRun -ChangedRunDirectory $differentActions -OriginalRom $originalRom -RepairedRom $repairedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -PlanPath $plan -ReplayPath $replay -OutputPath (Join-Path $tempRoot 'different-actions-out.json') -Force } 'scripted physical inputs'

    $collision = Join-Path $tempRoot 'collision.json'
    Set-Content -LiteralPath $collision -Value '{}' -NoNewline
    Assert-Throws 'output collision' { Invoke-LtCuration -OriginalRunDirectory $originalRun -ChangedRunDirectory $changedRun -OriginalRom $originalRom -RepairedRom $repairedRom -SourceMapPath $sourceMap -BuildReportPath $buildReport -PlanPath $plan -ReplayPath $replay -OutputPath $collision } 'already exists'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Output "Test-IlVmTrace: $($script:Checks) checks, $($script:Failures) failures"
if ($script:Failures -gt 0) { exit 1 }
