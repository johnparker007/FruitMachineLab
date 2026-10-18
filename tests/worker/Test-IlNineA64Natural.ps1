[CmdletBinding()]
param(
    [string]$OriginalRom = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\general-14\roms\original.p1',
    [string]$RunDirectory = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-9a64-finish-15\run-02',
    [string]$EvidencePath = 'C:\projects\GitRepos\FruitMachineLab\evidence\mpu4\integrity\il-9a64-natural.json',
    [string]$MemoryRunDirectory = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-9a64-memory-final-23\run-01',
    [string]$MemoryNaturalEvidencePath = 'C:\projects\GitRepos\FruitMachineLab\artifacts\deepseek\il-9a64-memory-final-23\natural-evidence.json',
    [string]$MemoryEvidencePath = 'C:\projects\GitRepos\FruitMachineLab\evidence\mpu4\integrity\il-9a64-memory.json'
)
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$tool = Join-Path $repo 'tools/Capture-IlNineA64Natural.ps1'
$lua = Join-Path $repo 'tools/lua/IlNineA64Natural.lua'
$doc = Join-Path $repo 'docs/recovery/IL-9A64-NATURAL.md'
$memoryDoc = Join-Path $repo 'docs/recovery/IL-9A64-MEMORY.md'
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
    Assert-True (Test-Path -LiteralPath $memoryDoc -PathType Leaf) 'memory proof document exists'
    Assert-True (Test-Path -LiteralPath $MemoryRunDirectory -PathType Container) 'preserved memory proof run exists'
    Assert-True (Test-Path -LiteralPath $MemoryNaturalEvidencePath -PathType Leaf) 'memory proof natural evidence exists'
    Assert-True (Test-Path -LiteralPath $MemoryEvidencePath -PathType Leaf) 'curated memory evidence exists'

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
    foreach ($site in @('0x00FC','0x00F8','0x7B6F','0x7984','0x7667','0x797B','0x7673','0x7931','0x766F','0x767D')) {
        Assert-True ($luaText -match [regex]::Escape($site)) "observer hooks native boundary $site"
    }
    Assert-True ($luaText -match 'node_prefetch') 'observer emits mapped node prefetch records'
    Assert-True ($luaText -match 'handler_entry') 'observer emits mapped handler records'
    Assert-True ($luaText -match 'post_return_prefetch') 'observer emits actual post-return records'
    Assert-True ($luaText -match 'branchCondition|conditionCell') 'observer records the branch condition cell'
    Assert-True ($luaText -match 'MEMORY_WORD_ADDRESS = 0x00A0') 'observer bounds memory reads to 00A0'
    Assert-True ($luaText -match 'MEMORY_MASK = 0x4000') 'observer bounds the accepted mask to 4000'
    Assert-True ($luaText -match 'memory_entry') 'observer emits bounded memory entry records'
    Assert-True ($luaText -match 'memory_after_std') 'observer emits actual after-STD memory records'
    Assert-True ($luaText -match 'memory\.entryU \+ 4') 'observer checks U advanced by four across the memory handler'
    Assert-True ($luaText -match 'entryCC|exitCC') 'observer records carry state for the memory handlers'

    Assert-True ($toolText -match "ValidateSet\('Capture','Analyze','Verify','MapOnly'\)") 'tool exposes Capture, Analyze, Verify and MapOnly modes'
    Assert-True ($toolText -match 'il-9a64-source-map-generation') 'tool generates the map through the IL API'
    Assert-True ($toolText -match 'NineASixFourDecoder\.Decode') 'map generation calls the independent decoder'
    Assert-True ($toolText -match 'VmIlCompiler\.CompileIdentity') 'map generation uses identity compilation'
    Assert-True ($toolText -match 'VmIlSourceMap\.CreateForBuild') 'map generation uses the source map API'
    Assert-True ($toolText -match 'Test-IlEventJson\.ps1') 'tool uses the strict JSON helper'
    Assert-True ($toolText -match '-noreadconfig') 'tool launches MAME without reading configuration'
    Assert-True ($toolText -match "\$script:IlA64FrontendDebugger = 'imgui'") 'tool pins the accepted imgui debugger frontend'
    Assert-True ($toolText -match "\$script:IlA64FrontendVideo = 'bgfx'") 'tool pins the BGFX renderer required by imgui'
    Assert-True ($toolText -match '''-debugger'',\$script:IlA64FrontendDebugger') 'generated arguments use the pinned imgui debugger'
    Assert-True ($toolText -match '''-video'',\$script:IlA64FrontendVideo') 'generated arguments use the pinned BGFX video'
    Assert-True ($toolText -match '''-bgfx_path'',\$bgfxPath') 'generated arguments pass the installed BGFX asset path'
    Assert-True ($toolText -notmatch "'-debugger','windows'|'-video','none'") 'tool no longer launches the Windows debugger with video none'
    Assert-True ($toolText -notmatch '(?i)-playback') 'tool has no playback argument'
    Assert-True ($toolText -notmatch 'test410|plugins[\\/]|boot\.lua') 'tool has no probe or plugin-bootstrap path'
    Assert-True ($toolText -match 'per-event|node_prefetch Y differs') 'analysis validates mapped event phase, not only event presence'
    Assert-True ($toolText -match 'Get-IlA64MemoryContract') 'tool derives the memory contract from exact ROM bytes'
    Assert-True ($toolText -match '3716AA84EA01ED840EFC') 'tool pins the exact OR handler span'
    Assert-True ($toolText -match '37164353A484E401ED840EFC') 'tool pins the exact clear handler span'
    Assert-True ($toolText -match 'bounded_00A0_v1') 'tool marks the new run as requiring bounded memory effects'
    Assert-True ($toolText -match 'wrong_memory_target') 'tool has a wrong-memory-target negative control'
    Assert-True ($toolText -match 'bad_memory_before_after_equation') 'tool has a bad before/after equation negative control'
    Assert-True ($toolText -match 'phase_mismatched_memory_after_std') 'tool has a memory phase negative control'

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

    $memoryVerify = Invoke-Tool @('-Mode','Verify','-RunDirectory',$MemoryRunDirectory,'-EvidencePath',$MemoryNaturalEvidencePath,'-MemoryEvidencePath',$MemoryEvidencePath)
    Assert-Equal $memoryVerify.exitCode 0 'memory proof Verify exits 0 without launching MAME'
    $mv = $memoryVerify.text | ConvertFrom-Json
    Assert-Equal $mv.status 'complete_natural_calls_observed' 'memory proof run status is complete'
    Assert-Equal $mv.callsStarted 3 'memory proof run started three natural 9A64 calls'
    Assert-Equal $mv.callsCompleted 3 'memory proof run completed three natural 9A64 calls'
    Assert-Contains @($mv.branchPaths) 'nonzero' 'memory proof run observed the nonzero branch'
    Assert-Equal $mv.memoryEffectCount 3 'memory proof run observed three memory effects'
    Assert-Contains @($mv.memoryEffects) 'or' 'memory proof run observed the OR memory effect'
    Assert-Equal $mv.strictJsonPass $true 'memory proof events pass strict System.Text.Json parsing'
    Assert-Equal $mv.negativeControlCount 7 'memory proof verification runs seven negative controls'
    Assert-Equal $mv.negativeControlsPass $true 'all memory proof negative controls pass'
    Assert-Equal $mv.memoryStatus 'partial_memory_effect_observed' 'memory evidence truthfully records partial natural coverage'
    Assert-Equal $mv.memoryEvidenceSha256 (Get-Sha256 $MemoryEvidencePath) 'memory verification evidence hash matches the curated file'

    $memoryNatural = Get-Content -LiteralPath $MemoryNaturalEvidencePath -Raw | ConvertFrom-Json
    Assert-Equal $memoryNatural.resultStatus 'complete_natural_calls_observed' 'memory natural evidence records complete calls'
    Assert-Equal $memoryNatural.requiresMemoryEffects $true 'memory natural evidence requires bounded memory effects'
    Assert-Equal @($memoryNatural.calls).Count 3 'memory natural evidence contains three call records'
    Assert-Equal @($memoryNatural.memoryEffects).Count 3 'memory natural evidence contains three memory effects'
    Assert-Equal $memoryNatural.run.eventRecordCount 51 'memory natural run has 51 strict event records'
    Assert-Equal $memoryNatural.run.eventsSha256 (Get-Sha256 (Join-Path $MemoryRunDirectory 'events.jsonl')) 'memory natural event hash matches the run log'
    Assert-Equal $memoryNatural.observer.match $true 'memory natural evidence captured observer matches the tracked source'
    Assert-Equal $memoryNatural.run.mameRecord.exitCode 0 'memory natural MAME run exited 0'
    Assert-Equal $memoryNatural.run.mameRecord.timedOut $false 'memory natural MAME run did not time out'
    Assert-Equal $memoryNatural.run.sessionComplete.reason 'emulated_budget' 'memory natural run stopped at the emulated budget'

    $finalArguments = Get-Content -LiteralPath (Join-Path $MemoryRunDirectory 'arguments.json') -Raw | ConvertFrom-Json
    $debuggerIndex = [array]::IndexOf([object[]]$finalArguments, '-debugger')
    $videoIndex = [array]::IndexOf([object[]]$finalArguments, '-video')
    $bgfxIndex = [array]::IndexOf([object[]]$finalArguments, '-bgfx_path')
    Assert-True ($debuggerIndex -ge 0 -and $finalArguments[$debuggerIndex + 1] -eq 'imgui') 'final capture arguments select the imgui debugger'
    Assert-True ($videoIndex -ge 0 -and $finalArguments[$videoIndex + 1] -eq 'bgfx') 'final capture arguments select the BGFX renderer'
    Assert-True ($bgfxIndex -ge 0) 'final capture arguments contain an explicit bgfx_path'
    $finalMetadata = Get-Content -LiteralPath (Join-Path $MemoryRunDirectory 'session-metadata.json') -Raw | ConvertFrom-Json
    $expectedBgfxPath = [IO.Path]::GetFullPath((Join-Path (Split-Path ([string]$finalMetadata.mame_executable) -Parent) 'bgfx'))
    Assert-Equal $finalArguments[$bgfxIndex + 1] $expectedBgfxPath 'final capture bgfx_path is derived from the installed MAME directory'
    Assert-True (Test-Path -LiteralPath $expectedBgfxPath -PathType Container) 'final capture bgfx_path exists in the installed MAME directory'
    Assert-Equal $finalMetadata.frontend.debugger 'imgui' 'final session metadata records the imgui debugger'
    Assert-Equal $finalMetadata.frontend.video 'bgfx' 'final session metadata records the BGFX renderer'
    Assert-Equal $finalMetadata.frontend.bgfx_path $expectedBgfxPath 'final session metadata records the installed bgfx_path'
    Assert-Equal $finalMetadata.frontend.focus_stealing $false 'final session metadata records no focus stealing'
    Assert-True ([string]$finalMetadata.frontend.focus_note -match 'set_foreground') 'final session metadata documents the imgui no-focus-stealing provenance'
    $finalRunRecord = Get-Content -LiteralPath (Join-Path $MemoryRunDirectory 'run-record.json') -Raw | ConvertFrom-Json
    Assert-True ([string]$finalRunRecord.commandLine -match '-debugger imgui') 'final run record command line uses the imgui debugger'
    Assert-True ([string]$finalRunRecord.commandLine -match '-video bgfx') 'final run record command line uses the BGFX renderer'
    Assert-True ([string]$finalRunRecord.commandLine -match [regex]::Escape(('-bgfx_path ' + $expectedBgfxPath))) 'final run record command line passes the installed bgfx_path'
    Assert-Equal $finalMetadata.source_provenance.capture_tool_sha256 (Get-Sha256 $tool) 'final capture records the current capture tool hash'
    Assert-Equal $finalMetadata.source_provenance.observer_source_sha256 (Get-Sha256 $lua) 'final capture records the current observer source hash'
    Assert-Equal $finalMetadata.source_provenance.observer_source_sha256 (Get-Sha256 (Join-Path $MemoryRunDirectory 'IlNineA64Natural.lua')) 'final capture copied observer matches its recorded source hash'

    $memoryEvidence = Get-Content -LiteralPath $MemoryEvidencePath -Raw | ConvertFrom-Json
    Assert-Equal $memoryEvidence.taskId 'il-9a64-memory-final-23' 'memory evidence task id is current'
    Assert-Equal $memoryEvidence.frontend.debugger 'imgui' 'curated memory evidence binds the imgui debugger'
    Assert-Equal $memoryEvidence.frontend.video 'bgfx' 'curated memory evidence binds the BGFX renderer'
    Assert-Equal $memoryEvidence.frontend.bgfx_path $expectedBgfxPath 'curated memory evidence binds the installed bgfx_path'
    Assert-Equal $memoryEvidence.frontend.focus_stealing $false 'curated memory evidence records no focus stealing'
    Assert-Equal $memoryEvidence.sourceProvenance.capture_tool_sha256 (Get-Sha256 $tool) 'curated memory evidence binds the current capture tool hash'
    Assert-Equal $memoryEvidence.sourceProvenance.observer_source_sha256 (Get-Sha256 $lua) 'curated memory evidence binds the current observer source hash'
    Assert-True ([string]$memoryEvidence.run.mameRecord.commandLine -match '-debugger imgui') 'curated memory evidence run command line uses the imgui debugger'
    Assert-True ([string]$memoryEvidence.run.mameRecord.commandLine -match '-video bgfx') 'curated memory evidence run command line uses the BGFX renderer'
    Assert-Equal $memoryEvidence.resultStatus 'partial_memory_effect_observed' 'memory evidence records the truthful partial status'
    Assert-Equal $memoryEvidence.images.original.sha1 '402d1518bb78fdc489b06c2aabc771e5ce151847' 'memory evidence binds the original SHA1'
    Assert-Equal $memoryEvidence.images.original.sha256 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c' 'memory evidence binds the original SHA256'
    Assert-Equal $memoryEvidence.images.runRomUnchanged $true 'memory proof isolated run ROM is unchanged'
    Assert-Equal $memoryEvidence.sourceMap.sha256 (Get-Sha256 (Join-Path $MemoryRunDirectory 'source-map.json')) 'memory evidence source-map hash matches the run'
    Assert-Equal $memoryEvidence.sourceMap.originalRomSha256 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C' 'memory evidence source map is bound to the original image'
    Assert-Equal $memoryEvidence.buildReport.sha256 (Get-Sha256 (Join-Path $MemoryRunDirectory 'build-report.json')) 'memory evidence build-report hash matches the run'
    Assert-Equal $memoryEvidence.buildReport.identityImageUnchanged $true 'memory evidence build report is an identity build'
    Assert-Equal $memoryEvidence.run.eventsSha256 (Get-Sha256 (Join-Path $MemoryRunDirectory 'events.jsonl')) 'memory evidence event hash matches the run log'
    Assert-Equal $memoryEvidence.observer.match $true 'memory evidence captured observer matches the tracked source'
    Assert-Equal $memoryEvidence.observer.capturedSha256 (Get-Sha256 (Join-Path $MemoryRunDirectory 'IlNineA64Natural.lua')) 'memory evidence captured observer hash matches the run copy'
    Assert-Equal $memoryEvidence.observer.sourceSha256 (Get-Sha256 $lua) 'memory evidence tracked observer hash matches the source file'

    $mc = $memoryEvidence.memoryContract
    Assert-Equal $mc.tokenPointers.orToken '7665' 'memory contract binds token 7665'
    Assert-Equal $mc.tokenPointers.orHandler '7667' 'memory contract binds OR handler 7667'
    Assert-Equal $mc.tokenPointers.clearToken '7671' 'memory contract binds token 7671'
    Assert-Equal $mc.tokenPointers.clearHandler '7673' 'memory contract binds clear handler 7673'
    Assert-Equal $mc.afterStdAddresses.or '766F' 'memory contract binds OR after-STD address 766F'
    Assert-Equal $mc.afterStdAddresses.clear '767D' 'memory contract binds clear after-STD address 767D'
    Assert-Equal $mc.orHandler.spanHex '3716AA84EA01ED840EFC' 'memory contract has the exact OR 6809 span'
    Assert-Equal $mc.clearHandler.spanHex '37164353A484E401ED840EFC' 'memory contract has the exact clear 6809 span'
    Assert-Equal @($mc.orHandler.instructions).Count 5 'OR contract has five checked instructions'
    Assert-Equal @($mc.clearHandler.instructions).Count 7 'clear contract has seven checked instructions'
    Assert-True ([string]$mc.evidenceClass -match 'Static deduction' -and [string]$mc.evidenceClass -match 'names are not used') 'memory contract is static byte evidence, not names'
    Assert-Equal $mc.boundedMemory.address '00A0' 'memory contract bounds the address to 00A0'
    Assert-Equal $mc.boundedMemory.mask '4000' 'memory contract bounds the mask to 4000'

    Assert-Equal @($memoryEvidence.memoryCalls).Count 3 'memory evidence contains three natural memory calls'
    foreach ($memoryCall in @($memoryEvidence.memoryCalls)) {
        Assert-Equal $memoryCall.branchPath 'nonzero' "memory call $($memoryCall.callId) is the nonzero path"
        Assert-Equal $memoryCall.memoryEffect 'or' "memory call $($memoryCall.callId) is the OR effect"
        Assert-Equal $memoryCall.memoryAddress '00A0' "memory call $($memoryCall.callId) used bounded address 00A0"
        Assert-Equal $memoryCall.maskWord '4000' "memory call $($memoryCall.callId) used the accepted mask 4000"
        $before = [Convert]::ToInt32([string]$memoryCall.beforeWord,16)
        $mask = [Convert]::ToInt32([string]$memoryCall.maskWord,16)
        $expectedAfter = ('{0:X4}' -f (($before -bor $mask) -band 0xFFFF))
        Assert-Equal $memoryCall.expectedAfterWord $expectedAfter "memory call $($memoryCall.callId) expected word is the OR equation"
        Assert-Equal $memoryCall.afterWord $expectedAfter "memory call $($memoryCall.callId) after word is the OR equation"
        Assert-Equal $memoryCall.memoryUAdvance '0004' "memory call $($memoryCall.callId) advanced U by four"
        Assert-Equal $memoryCall.memorySUnchanged $true "memory call $($memoryCall.callId) preserved S"
        Assert-Equal $memoryCall.memoryYUnchanged $true "memory call $($memoryCall.callId) preserved Y"
        Assert-Equal $memoryCall.memoryXExact '00A0' "memory call $($memoryCall.callId) exited with X at 00A0"
        Assert-Equal $memoryCall.memoryDAfter $memoryCall.afterWord "memory call $($memoryCall.callId) D equals the written word"
        Assert-True ([string]$memoryCall.memoryCCContract -match 'C unchanged from entry') "memory call $($memoryCall.callId) records the OR carry contract"
    }
    Assert-Equal $memoryEvidence.coverage.orEffectsObserved 3 'memory evidence records three OR effects'
    Assert-Equal $memoryEvidence.coverage.clearEffectsObserved 0 'memory evidence truthfully records zero natural clear effects'
    Assert-True ((($memoryEvidence.coverage.gaps) -join ' ') -match 'Zero-condition 7982 path was not observed') 'memory evidence reports the unobserved zero path'
    Assert-True ((($memoryEvidence.coverage.gaps) -join ' ') -match 'No natural zero/clear 7671 memory effect was observed') 'memory evidence reports the unobserved clear effect'
    Assert-Equal @($memoryEvidence.negativeControls).Count 7 'memory evidence contains seven negative controls'
    Assert-Equal @($memoryEvidence.negativeControls | Where-Object { -not [bool]$_.pass }).Count 0 'memory evidence has no failed negative control'
    foreach ($control in @('wrong_memory_target','bad_memory_before_after_equation','phase_mismatched_memory_after_std')) {
        $case = @($memoryEvidence.negativeControls | Where-Object { $_.name -eq $control })
        Assert-Equal $case.Count 1 "memory negative control $control is recorded"
        Assert-Equal $case[0].observed 'rejected' "memory negative control $control is rejected"
    }
    Assert-True ([string]$memoryEvidence.evidenceClasses.naturalExecution -match 'breakpoint') 'memory evidence distinguishes natural breakpoint observation'
    Assert-True ([string]$memoryEvidence.evidenceClasses.staticDeduction -match '6809') 'memory evidence distinguishes static ROM deduction'

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
