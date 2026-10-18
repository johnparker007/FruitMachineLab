[CmdletBinding()]
param(
    [string]$OriginalRom = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\general-14\roms\original.p1',
    [string]$RunDirectory = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-9a64-finish-15\run-02',
    [string]$EvidencePath = 'C:\projects\GitRepos\FruitMachineLab\evidence\mpu4\integrity\il-9a64-natural.json'
)
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$tool = Join-Path $repo 'tools/Capture-IlNineA64Natural.ps1'
$lua = Join-Path $repo 'tools/lua/IlNineA64Natural.lua'
$doc = Join-Path $repo 'docs/recovery/IL-9A64-NATURAL.md'
$manifest = Join-Path $repo 'tools/Update-CuratedManifest.ps1'

$script:Checks = 0
$script:Failures = 0
function Write-Pass([string]$Message) { $script:Checks++; Write-Output "PASS: $Message" }
function Write-Fail([string]$Message) { $script:Checks++; $script:Failures++; Write-Output "FAIL: $Message" }
function Assert-True([bool]$Condition,[string]$Message) { if ($Condition) { Write-Pass $Message } else { Write-Fail $Message } }
function Assert-Equal($Actual,$Expected,[string]$Message) {
    if ([string]$Actual -eq [string]$Expected) { Write-Pass $Message }
    else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" }
}
function Assert-Contains([object[]]$Values,$Expected,[string]$Message) {
    if (@($Values) -contains $Expected) { Write-Pass $Message } else { Write-Fail "$Message (missing '$Expected')" }
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Invoke-Tool([string[]]$Arguments) {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $tool @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    return [ordered]@{ exitCode=$exitCode; text=($output | Out-String) }
}

$tempRoot = Join-Path $repo ('artifacts/deepseek/il-9a64-finish-15/test-runs/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    Assert-True (Test-Path -LiteralPath $tool -PathType Leaf) 'capture tool exists'
    Assert-True (Test-Path -LiteralPath $lua -PathType Leaf) 'Lua observer exists'
    Assert-True (Test-Path -LiteralPath $doc -PathType Leaf) 'natural 9A64 document exists'
    Assert-True (Test-Path -LiteralPath $EvidencePath -PathType Leaf) 'curated natural 9A64 evidence exists'
    Assert-True (Test-Path -LiteralPath $OriginalRom -PathType Leaf) 'strict original ROM exists'
    Assert-True (Test-Path -LiteralPath $RunDirectory -PathType Container) 'preserved natural run exists'

    $luaText = Get-Content -LiteralPath $lua -Raw
    $toolText = Get-Content -LiteralPath $tool -Raw
    Assert-True ($luaText -match 'local function sameHex') 'observer normalises hex identity comparison'
    Assert-True ($luaText -match 'sameHex\(map\.imageSha256, config\.expectedImageSha256\)') 'observer uses case-insensitive image identity'
    Assert-True ($luaText -match 'sameHex\(map\.originalRomSha256, config\.expectedOriginalRomSha256\)') 'observer uses case-insensitive original identity'
    Assert-True ($luaText -match 'emu\.register_periodic') 'periodic callback is the stopped-state driver'
    Assert-True ($luaText -match 'never treated as an') 'observer documents periodic is not a boundary source'
    Assert-True ($luaText -notmatch '(?i)plugins[\\/]|boot\.lua') 'observer has no plugin bootstrap dependency'
    Assert-True ($luaText -notmatch 'mem:write|:write_u8|:write_u16|state\[[^\]]+\]\.value\s*=') 'observer has no memory or register writes'
    Assert-True ($luaText -notmatch '(?i)playback|:save\b|:load\b') 'observer has no state save/load method or playback path'
    foreach ($site in @('0x00FC','0x00F8','0x7B6F','0x7984','0x7667','0x797B','0x7673','0x7931')) {
        Assert-True ($luaText -match [regex]::Escape($site)) "observer hooks native boundary $site"
    }
    Assert-True ($luaText -match 'node_prefetch') 'observer emits mapped node prefetch records'
    Assert-True ($luaText -match 'handler_entry') 'observer emits mapped handler records'
    Assert-True ($luaText -match 'post_return_prefetch') 'observer emits actual post-return records'
    Assert-True ($luaText -match 'branchCondition|conditionCell') 'observer records the branch condition cell'

    Assert-True ($toolText -match "ValidateSet\('Capture','Analyze','Verify','MapOnly'\)") 'tool exposes Capture, Analyze, Verify and MapOnly modes'
    Assert-True ($toolText -match 'il-9a64-source-map-generation') 'tool generates the map through the IL API'
    Assert-True ($toolText -match 'NineASixFourDecoder\.Decode') 'map generation calls the independent decoder'
    Assert-True ($toolText -match 'VmIlCompiler\.CompileIdentity') 'map generation uses identity compilation'
    Assert-True ($toolText -match 'VmIlSourceMap\.CreateForBuild') 'map generation uses the source map API'
    Assert-True ($toolText -match 'Test-IlEventJson\.ps1') 'tool uses the strict JSON helper'
    Assert-True ($toolText -match '-noreadconfig') 'tool launches MAME without reading configuration'
    Assert-True ($toolText -match '-debug.*-debugger.*windows') 'tool uses the installed native debugger host'
    Assert-True ($toolText -notmatch '(?i)-playback') 'tool has no playback argument'
    Assert-True ($toolText -notmatch 'test410|plugins[\\/]|boot\.lua') 'tool has no probe or plugin-bootstrap path'
    Assert-True ($toolText -match 'per-event|node_prefetch Y differs') 'analysis validates mapped event phase, not only event presence'

    $mapRun = Join-Path $tempRoot 'map'
    $map = Invoke-Tool @('-Mode','MapOnly','-RunDirectory',$mapRun,'-OriginalRom',$OriginalRom)
    Assert-Equal $map.exitCode 0 'MapOnly exits 0'
    $mapJson = $map.text | ConvertFrom-Json
    Assert-Equal $mapJson.entries 14 'generated source map has fourteen entries'
    Assert-Equal $mapJson.nodes 6 'generated source map has six nodes'
    Assert-Equal $mapJson.branches 2 'generated source map has two byte branches'
    Assert-Equal $mapJson.original.sha1 '402d1518bb78fdc489b06c2aabc771e5ce151847' 'MapOnly verifies the original SHA1'
    Assert-Equal $mapJson.original.sha256 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c' 'MapOnly verifies the original SHA256'

    $verify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$RunDirectory,'-EvidencePath',$EvidencePath)
    Assert-Equal $verify.exitCode 0 'Verify exits 0 without launching MAME'
    $v = $verify.text | ConvertFrom-Json
    Assert-Equal $v.status 'complete_natural_calls_observed' 'preserved natural run status is complete'
    Assert-Equal $v.callsStarted 5 'preserved natural run started five 9A64 calls'
    Assert-Equal $v.callsCompleted 5 'preserved natural run completed five 9A64 calls'
    Assert-Contains @($v.branchPaths) 'zero' 'preserved natural run observed the zero branch'
    Assert-Contains @($v.branchPaths) 'nonzero' 'preserved natural run observed the nonzero branch'
    Assert-Equal $v.strictJsonPass $true 'preserved events pass strict System.Text.Json parsing'
    Assert-Equal $v.negativeControlCount 4 'capture verification runs four negative controls'
    Assert-Equal $v.negativeControlsPass $true 'all capture negative controls pass'
    Assert-Equal $v.evidenceSha256 (Get-Sha256 $EvidencePath) 'verification evidence hash matches the curated file'

    $evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
    Assert-Equal $evidence.taskId 'il-9a64-finish-15' 'evidence task id is current'
    Assert-Equal $evidence.resultStatus 'complete_natural_calls_observed' 'evidence records complete natural calls'
    Assert-Equal @($evidence.calls).Count 5 'evidence contains five call records'
    Assert-Equal @($evidence.coverage.branchPathsObserved).Count 2 'evidence records both branch paths'
    Assert-Equal @($evidence.coverage.unobservedNodes).Count 0 'evidence records no unobserved 9A64 nodes'
    foreach ($index in 0..5) { Assert-Contains @($evidence.coverage.observedNodeIndexes) $index "node $index was observed" }
    foreach ($handler in @('7B6F','7984','7667','797B','7673','7931')) {
        Assert-Contains @($evidence.coverage.observedHandlers) $handler "handler $handler was observed"
    }
    Assert-Equal $evidence.sourceMap.sha256 $mapJson.sourceMapSha256 'captured map hash matches a fresh identity map from current code'
    Assert-Equal $evidence.buildReport.sha256 $mapJson.buildReportSha256 'captured build-report hash matches current identity compilation'
    Assert-Equal $evidence.sourceMap.originalRomSha256 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C' 'source map is bound to the original image'
    Assert-Equal $evidence.buildReport.identityImageUnchanged $true 'build report asserts an unchanged identity image'
    Assert-Equal $evidence.images.runRomUnchanged $true 'isolated run ROM is unchanged after execution'
    Assert-Equal $evidence.run.mameRecord.exitCode 0 'natural MAME run exited 0'
    Assert-Equal $evidence.run.mameRecord.timedOut $false 'natural MAME run did not time out'
    Assert-Equal $evidence.run.sessionComplete.reason 'emulated_budget' 'natural run stopped at the emulated budget'
    Assert-Equal $evidence.run.strictJsonPass $true 'evidence records strict JSON pass'

    foreach ($call in @($evidence.calls)) {
        Assert-Equal $call.completed $true "call $($call.callId) is complete"
        Assert-Equal @($call.errors).Count 0 "call $($call.callId) has no semantic errors"
        Assert-Equal $call.callSiteToken '9A62' "call $($call.callId) entered through token 9A62"
        Assert-Equal $call.callSiteY 'EF9C' "call $($call.callId) used the observed EF9C site"
        Assert-Equal $call.callerSuccessor 'EF9E' "call $($call.callId) caller successor is EF9E"
        Assert-Equal $call.branchOperandAddress '9A68' "call $($call.callId) branch operand address is 9A68"
        Assert-Equal $call.branchOperandByte '06' "call $($call.callId) branch operand byte is 06"
        Assert-Equal $call.branchUAdvance '0002' "call $($call.callId) branch handler advanced U by two"
        Assert-Equal $call.returnSavedCursor 'EF9E' "call $($call.callId) saved caller cursor is EF9E"
        Assert-Equal $call.returnS '07AA' "call $($call.callId) return handler S is 07AA"
        Assert-Equal $call.postReturnS '07AC' "call $($call.callId) post-return S is 07AC"
        Assert-Equal $call.returnSAdvanced '0002' "call $($call.callId) return advanced S by two"
        Assert-Equal $call.postReturnY $call.returnSavedCursor "call $($call.callId) post-return Y equals the saved cursor"
        Assert-Equal $call.postReturnY $call.callerSuccessor "call $($call.callId) post-return Y equals the composite caller successor"
        Assert-Equal $call.postReturnToken '80C4' "call $($call.callId) post-return token is the ROM word at EF9E"
        if ($call.branchPath -eq 'zero') {
            Assert-Equal $call.branchConditionCell '0000' "call $($call.callId) zero condition cell is 0000"
            Assert-Equal $call.branchNextY '9A6E' "call $($call.callId) zero branch next Y is 9A6E"
            Assert-Equal $call.nodeSequence '0,1,4,5' "call $($call.callId) zero path visits nodes 0,1,4,5"
            Assert-Equal $call.handlerSequence '7B6F,7984,7673,7931' "call $($call.callId) zero path handlers are exact"
        }
        elseif ($call.branchPath -eq 'nonzero') {
            Assert-True ([string]$call.branchConditionCell -ne '0000') "call $($call.callId) nonzero condition cell is nonzero"
            Assert-Equal $call.branchNextY '9A69' "call $($call.callId) nonzero branch next Y is 9A69"
            Assert-Equal $call.nodeSequence '0,1,2,3,5' "call $($call.callId) nonzero path visits nodes 0,1,2,3,5"
            Assert-Equal $call.handlerSequence '7B6F,7984,7667,797B,7931' "call $($call.callId) nonzero path handlers are exact"
        }
        else {
            Write-Fail "call $($call.callId) has an unsupported branch path '$($call.branchPath)'"
        }
    }

    $zeroCall = @($evidence.calls | Where-Object { $_.branchPath -eq 'zero' })
    $nonzeroCall = @($evidence.calls | Where-Object { $_.branchPath -eq 'nonzero' })
    Assert-True ($zeroCall.Count -ge 1) 'at least one zero-branch call is recorded'
    Assert-True ($nonzeroCall.Count -ge 1) 'at least one nonzero-branch call is recorded'
    Assert-Equal $zeroCall[0].emulatedTime '53.026843605' 'zero-branch call time is recorded exactly'
    Assert-Equal $nonzeroCall[0].emulatedTime '50.166901744' 'first nonzero-branch call time is recorded exactly'

    $failedNegative = @($evidence.negativeControls | Where-Object { -not [bool]$_.pass })
    Assert-Equal $failedNegative.Count 0 'evidence contains no failed negative control'
    Assert-Equal @($evidence.negativeControls).Count 4 'evidence contains four negative controls'
    $phase = @($evidence.negativeControls | Where-Object { $_.name -eq 'phase_mismatched_node_prefetch' })
    Assert-Equal $phase.Count 1 'phase negative control is recorded'
    Assert-Equal $phase[0].observed 'rejected' 'phase-mismatched node prefetch is rejected'
    Assert-True ([string]$phase[0].detail -match 'node_prefetch') 'phase negative control fails on mapped event phase, not an earlier error'

    $manifestOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $manifest -Verify 2>&1
    $manifestExit = $LASTEXITCODE
    Assert-Equal $manifestExit 0 'curated manifest verifies on final evidence and documents'
    Assert-True (($manifestOutput | Out-String) -match 'Verified \d+ curated entries') 'curated manifest verifier reports its entry count'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Output ("RESULT: {0} checks, {1} failures" -f $script:Checks,$script:Failures)
if ($script:Failures -ne 0) { exit 1 }
