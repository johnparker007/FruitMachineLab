[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [string]$RepairedRom,
    [Parameter(Mandatory=$true)][ValidateSet('Original','Changed')][string]$Variant,
    [ValidateSet('9ED9','9A64')][string]$Definition = '9ED9',
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$PlanPath,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [ValidateRange(1,120)][int]$SecondsToRun = 120,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'

$script:DsOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:DsOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:DsRepairedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$script:DsRepairedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$script:DsReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:DsMameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:DsExpectedChangedOffsets = @(0x9EDC,0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5)
$script:DsProtocol = 'il-debug-session-v1'
$script:DsRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path $script:DsRoot 'artifacts/deepseek/il-boot-04/build-01/source-map.json' }
if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path $script:DsRoot 'artifacts/deepseek/il-boot-04/build-01/build-report.json' }
if ([string]::IsNullOrWhiteSpace($PlanPath)) { $PlanPath = Join-Path $script:DsRoot 'evidence/mpu4/integrity/il-natural-reachability-plan.json' }
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:DsRoot 'evidence/mpu4/skill-cash/actions.csv' }
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) { $InputLuaPath = Join-Path $script:DsRoot 'evidence/mpu4/skill-cash/input.lua' }

function Get-DsHash {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Write-DsJson {
    param([string]$Path,$Object,[int]$Depth = 14)
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),(New-Object System.Text.UTF8Encoding($false)))
}

function ConvertTo-DsInt {
    param([string]$Text)
    return [Convert]::ToInt32($Text,16)
}

function Format-DsHex16 {
    param([int]$Value)
    return ('{0:X4}' -f ($Value -band 0xFFFF))
}

function Get-DsOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length images' }
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($i=0;$i -lt $A.Length;$i++) { if ($A[$i] -ne $B[$i]) { [void]$list.Add($i) } }
    return $list.ToArray()
}

function Assert-DsCanonicalJsonFile {
    param([string]$Path,[string]$Label)
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "$Label SHA256 validation failed: UTF-8 BOM is not canonical"
    }
    if ($bytes.Length -lt 2 -or $bytes[$bytes.Length-1] -ne 0x7D) {
        throw "$Label SHA256 validation failed: file is not the canonical create-only JSON document"
    }
}

function Assert-DsProperties {
    param($Object,[string[]]$Expected,[string]$Label)
    if ($null -eq $Object) { throw "$Label is missing" }
    $actual = @($Object.PSObject.Properties | ForEach-Object { [string]$_.Name })
    if ($actual.Count -ne $Expected.Count) { throw "$Label has $($actual.Count) properties, expected $($Expected.Count)" }
    foreach ($name in $Expected) {
        if ($actual -cnotcontains $name) { throw "$Label is missing property $name" }
    }
}

function Assert-DsSequence {
    param($Actual,[object[]]$Expected,[string]$Label)
    $values = @($Actual)
    if ($values.Count -ne $Expected.Count) { throw "$Label has $($values.Count) values, expected $($Expected.Count)" }
    for ($index=0; $index -lt $values.Count; $index++) {
        if ([string]$values[$index] -ne [string]$Expected[$index]) {
            throw "$Label value $index is $($values[$index]), expected $($Expected[$index])"
        }
    }
}

function Assert-DsSourceMap {
    param($Map,[byte[]]$RepairedBytes,[string]$OriginalSha256,[string]$RepairedSha256)
    Assert-DsProperties $Map @('schemaVersion','taskId','classification','originalRomSha256','outputImageSha256','identityBuild','bodyStart','bodyEndExclusive','entries') 'Source map'
    if ([int]$Map.schemaVersion -ne 1) { throw 'Source map schemaVersion is not 1' }
    if ([string]$Map.taskId -cne 'il-integrity-03') { throw 'Source map taskId is not il-integrity-03' }
    if ([string]$Map.originalRomSha256 -ine $OriginalSha256) { throw 'Source map original identity is stale or wrong' }
    if ([string]$Map.outputImageSha256 -ine $RepairedSha256) { throw 'Source map is not bound to the repaired image' }
    if ([bool]$Map.identityBuild) { throw 'Source map must describe the non-identity repaired build' }
    if ([string]$Map.bodyStart -ine '9ED9' -or [string]$Map.bodyEndExclusive -ine '9EE7') { throw 'Source map body span is not 9ED9..9EE7' }
    $entries = @($Map.entries)
    if ($entries.Count -ne 14) { throw "Source map has $($entries.Count) entries, expected 14" }
    $expectedNodeIndices = @(0,0,0,0,1,1,2,2,2,2,3,3,4,4)
    $expectedTokens = @('795B','795B','795B','795B','787E','787E','795B','795B','795B','795B','7AAF','7AAF','792F','792F')
    $expectedOperations = @(
        'vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal',
        'vm_add_words','vm_add_words',
        'vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal','vm_push_inline_word_literal',
        'vm_bitwise_xor','vm_bitwise_xor',
        'vm_return_to_caller_stream','vm_return_to_caller_stream')
    for ($index=0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        Assert-DsProperties $entry @('address','nodeIndex','token','operation','imageByte') "Source map entry $index"
        $address = ConvertTo-DsInt ([string]$entry.address)
        if ($address -ne (0x9ED9 + $index)) { throw "Source map entry $index address is not contiguous" }
        if ([int]$entry.nodeIndex -ne $expectedNodeIndices[$index]) { throw "Source map entry $index nodeIndex is wrong" }
        if ([string]$entry.token -ine $expectedTokens[$index]) { throw "Source map entry $index token is wrong" }
        if ([string]$entry.operation -cne $expectedOperations[$index]) { throw "Source map entry $index operation is wrong" }
        if ([Convert]::ToInt32([string]$entry.imageByte,16) -ne [int]$RepairedBytes[$address]) {
            throw "Source map entry $index imageByte differs from the repaired image"
        }
    }
}

function Assert-DsBuildReport {
    param($Build,[byte[]]$OriginalBytes,[byte[]]$RepairedBytes,[string]$OriginalPath,[string]$RepairedPath,[string]$SourceMapPath,[string]$OriginalSha256,[string]$RepairedSha256)
    Assert-DsProperties $Build @('schemaVersion','taskId','classification','original','unrepaired','repaired','edit','unrepairedDiff','repairedDiff','repairOnlyDiff','integrity','sourceMap','checks','limitations') 'Build report'
    if ([int]$Build.schemaVersion -ne 1) { throw 'Build report schemaVersion is not 1' }
    if ([string]$Build.taskId -cne 'il-integrity-03') { throw 'Build report taskId is not il-integrity-03' }
    Assert-DsProperties $Build.original @('path','length','sha1','sha256','spanHex','storedFieldsHex','computedFieldsHex') 'Build report original'
    Assert-DsProperties $Build.unrepaired @('path','length','sha1','sha256','spanHex','storedFieldsHex','changedOffsets','changedOffsetsHex','integrityStatus') 'Build report unrepaired'
    Assert-DsProperties $Build.repaired @('path','length','sha1','sha256','spanHex','storedFieldsHex','computedFieldsHex','changedOffsets','changedOffsetsHex','integrityStatus') 'Build report repaired'
    Assert-DsProperties $Build.edit @('nodeIndex','tokenAddress','operandAddress','operandWidthBytes','token','operation','expectedOriginalValue','actualOriginalValue','replacementValue','expectedOriginalBytesHex','replacementBytesHex','changedOffsets','changedOffsetsHex') 'Build report edit'
    if ([int]$Build.original.length -ne 65536 -or [int]$Build.unrepaired.length -ne 65536 -or [int]$Build.repaired.length -ne 65536) {
        throw 'Build report image length is not 65536'
    }
    if ([string]$Build.original.path -ine [IO.Path]::GetFullPath($OriginalPath)) { throw 'Build report original path differs from the supplied original ROM' }
    if ([string]$Build.repaired.path -ine [IO.Path]::GetFullPath($RepairedPath)) { throw 'Build report repaired path differs from the supplied repaired ROM' }
    if ([string]$Build.sourceMap.path -ine [IO.Path]::GetFullPath($SourceMapPath)) { throw 'Build report source map path differs from the supplied source map' }
    $unrepairedExpected = Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($RepairedPath))) 'edited-unrepaired.p1'
    if ([string]$Build.unrepaired.path -ine $unrepairedExpected) { throw 'Build report unrepaired path is not the sibling create-only artifact' }
    if ([string]$Build.original.sha1 -ine (Get-DsHash $OriginalPath 'SHA1') -or [string]$Build.original.sha256 -ine $OriginalSha256) { throw 'Build report original identity is wrong' }
    if ([string]$Build.repaired.sha1 -ine (Get-DsHash $RepairedPath 'SHA1') -or [string]$Build.repaired.sha256 -ine $RepairedSha256) { throw 'Build report repaired identity is wrong' }
    if (!(Test-Path -LiteralPath $unrepairedExpected -PathType Leaf)) { throw 'Build report unrepaired image is missing' }
    if ([string]$Build.unrepaired.sha1 -ine (Get-DsHash $unrepairedExpected 'SHA1') -or [string]$Build.unrepaired.sha256 -ine (Get-DsHash $unrepairedExpected 'SHA256')) { throw 'Build report unrepaired identity is wrong' }
    if ([string]$Build.original.spanHex -ine '795BFF80787E795BFF807AAF792F') { throw 'Build report original span is wrong' }
    if ([string]$Build.original.storedFieldsHex -ine '3E761E2605' -or [string]$Build.original.computedFieldsHex -ine '3E761E2605') { throw 'Build report original integrity fields are wrong' }
    if ([string]$Build.unrepaired.spanHex -ine '795BFF00787E795BFF807AAF792F') { throw 'Build report unrepaired span is wrong' }
    if ([string]$Build.unrepaired.storedFieldsHex -ine '3E761E2605') { throw 'Build report unrepaired fields are wrong' }
    Assert-DsSequence $Build.unrepaired.changedOffsets @(40668) 'Build report unrepaired changed offsets'
    Assert-DsSequence $Build.unrepaired.changedOffsetsHex @('9EDC') 'Build report unrepaired changed offsets hex'
    if ([string]$Build.repaired.spanHex -ine '795BFF00787E795BFF807AAF792F') { throw 'Build report repaired span is wrong' }
    if ([string]$Build.repaired.storedFieldsHex -ine 'BEF69E7CC7' -or [string]$Build.repaired.computedFieldsHex -ine 'BEF69E7CC7') { throw 'Build report repaired integrity fields are wrong' }
    Assert-DsSequence $Build.repaired.changedOffsets @(40668,65489,65490,65491,65492,65493) 'Build report repaired changed offsets'
    Assert-DsSequence $Build.repaired.changedOffsetsHex @('9EDC','FFD1','FFD2','FFD3','FFD4','FFD5') 'Build report repaired changed offsets hex'
    if ([int]$Build.edit.nodeIndex -ne 0 -or [string]$Build.edit.tokenAddress -ine '9ED9' -or [string]$Build.edit.operandAddress -ine '9EDB') { throw 'Build report edit address is wrong' }
    if ([int]$Build.edit.operandWidthBytes -ne 2 -or [string]$Build.edit.token -ine '795B' -or [string]$Build.edit.operation -cne 'vm_push_inline_word_literal') { throw 'Build report edit token is wrong' }
    if ([string]$Build.edit.expectedOriginalValue -ine 'FF80' -or [string]$Build.edit.actualOriginalValue -ine 'FF80' -or [string]$Build.edit.replacementValue -ine 'FF00') { throw 'Build report edit value is wrong' }
    if ([string]$Build.edit.expectedOriginalBytesHex -ine 'FF80' -or [string]$Build.edit.replacementBytesHex -ine 'FF00') { throw 'Build report edit byte encoding is wrong' }
    Assert-DsSequence $Build.edit.changedOffsets @(40668) 'Build report edit changed offsets'
    Assert-DsSequence $Build.edit.changedOffsetsHex @('9EDC') 'Build report edit changed offsets hex'
    $unrepairedDiff = @($Build.unrepairedDiff)
    if ($unrepairedDiff.Count -ne 1) { throw 'Build report unrepaired diff is not exactly 9EDC' }
    if ([int]$unrepairedDiff[0].offset -ne 40668 -or [string]$unrepairedDiff[0].before -ine '80' -or [string]$unrepairedDiff[0].after -ine '00') { throw 'Build report unrepaired diff is wrong' }
    $repairedDiff = @($Build.repairedDiff)
    if ($repairedDiff.Count -ne 6) { throw 'Build report repaired diff is not the accepted six bytes' }
    $expectedBefore = @('80','3E','76','1E','26','05')
    $expectedAfter = @('00','BE','F6','9E','7C','C7')
    $expectedOffsets = @(40668,65489,65490,65491,65492,65493)
    for ($index=0; $index -lt 6; $index++) {
        if ([int]$repairedDiff[$index].offset -ne $expectedOffsets[$index]) { throw "Build report repaired diff offset $index is wrong" }
        if ([string]$repairedDiff[$index].before -ine $expectedBefore[$index] -or [string]$repairedDiff[$index].after -ine $expectedAfter[$index]) { throw "Build report repaired diff value $index is wrong" }
        if ([int]$OriginalBytes[$expectedOffsets[$index]] -ne [Convert]::ToInt32($expectedBefore[$index],16)) { throw "Original image byte at $($expectedOffsets[$index]) is wrong" }
        if ([int]$RepairedBytes[$expectedOffsets[$index]] -ne [Convert]::ToInt32($expectedAfter[$index],16)) { throw "Repaired image byte at $($expectedOffsets[$index]) is wrong" }
    }
    $repairOnlyDiff = @($Build.repairOnlyDiff)
    if ($repairOnlyDiff.Count -ne 5) { throw 'Build report repair-only diff is not exactly FFD1..FFD5' }
    for ($index=0; $index -lt 5; $index++) {
        if ([int]$repairOnlyDiff[$index].offset -ne (65489 + $index)) { throw "Build report repair-only diff offset $index is wrong" }
        if ([string]$repairOnlyDiff[$index].before -ine $expectedBefore[$index+1] -or [string]$repairOnlyDiff[$index].after -ine $expectedAfter[$index+1]) { throw "Build report repair-only diff value $index is wrong" }
    }
    Assert-DsProperties $Build.integrity @('repaired','accepted','recordBase','rangeStart','rangeEnd','errorCode','gate','algorithmOrder','evidenceSource','fieldWrites','status') 'Build report integrity'
    if (![bool]$Build.integrity.repaired -or [bool]$Build.integrity.accepted) { throw 'Build report integrity acceptance flags are wrong' }
    if ([string]$Build.integrity.recordBase -ine 'FFD1' -or [string]$Build.integrity.rangeStart -ine '1400' -or [string]$Build.integrity.rangeEnd -ine 'FFFF') { throw 'Build report integrity range is wrong' }
    if ([string]$Build.integrity.errorCode -ine '12' -or [string]$Build.integrity.gate -ine '00') { throw 'Build report integrity record is wrong' }
    $fieldWrites = @($Build.integrity.fieldWrites)
    if ($fieldWrites.Count -ne 5) { throw 'Build report integrity field count is wrong' }
    $expectedFieldNames = @('sum','xor','rotate_add','rotate_sub_xor_a','rotate_sub_xor_b')
    for ($index=0; $index -lt 5; $index++) {
        if ([string]$fieldWrites[$index].Name -cne $expectedFieldNames[$index]) { throw "Build report field $index name is wrong" }
        if ([int]$fieldWrites[$index].offset -ne (65489 + $index)) { throw "Build report field $index offset is wrong" }
        if ([string]$fieldWrites[$index].before -ine $expectedBefore[$index+1] -or [string]$fieldWrites[$index].after -ine $expectedAfter[$index+1]) { throw "Build report field $index value is wrong" }
    }
    Assert-DsProperties $Build.sourceMap @('outputImageSha256','originalRomSha256','identityBuild','bodyStart','bodyEndExclusive','coveredBytes','entries','path') 'Build report source map'
    if ([string]$Build.sourceMap.outputImageSha256 -ine $RepairedSha256 -or [string]$Build.sourceMap.originalRomSha256 -ine $OriginalSha256) { throw 'Build report source-map identity is wrong' }
    if ([bool]$Build.sourceMap.identityBuild) { throw 'Build report source map must be non-identity' }
    if ([string]$Build.sourceMap.bodyStart -ine '9ED9' -or [string]$Build.sourceMap.bodyEndExclusive -ine '9EE7') { throw 'Build report source-map span is wrong' }
    if ([int]$Build.sourceMap.coveredBytes -ne 14 -or [int]$Build.sourceMap.entries -ne 14) { throw 'Build report source-map coverage is wrong' }
    Assert-DsProperties $Build.checks @('originalIdentityStrict','originalFieldsVerified','editedSpanDerivedFromIlValue','exactlyOneUnrepairedChangedOffset','secondLiteralPreserved','headerPreserved','orderedIntegrityRepair','repairedDiffIsEditPlusFields','sourceMapBoundToRepairedSha256','acceptedForBoot') 'Build report checks'
    foreach ($check in @('originalIdentityStrict','originalFieldsVerified','editedSpanDerivedFromIlValue','exactlyOneUnrepairedChangedOffset','secondLiteralPreserved','headerPreserved','orderedIntegrityRepair','repairedDiffIsEditPlusFields','sourceMapBoundToRepairedSha256')) {
        if (![bool]$Build.checks.$check) { throw "Build report check $check is not true" }
    }
    if ([bool]$Build.checks.acceptedForBoot) { throw 'Build report must not claim boot acceptance' }
}

function Assert-DsRom {
    param([string]$Path,[int]$Length,[string]$Sha1,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualLength = (Get-Item -LiteralPath $Path).Length
    if ($actualLength -ne $Length) { throw "$Label length is $actualLength, expected $Length" }
    $actualSha1 = Get-DsHash $Path 'SHA1'
    $actualSha256 = Get-DsHash $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{path=[IO.Path]::GetFullPath($Path);length=$actualLength;sha1=$actualSha1;sha256=$actualSha256}
}

function Get-DsVariantEntries {
    param($SourceMap,[byte[]]$RepairedBytes,[byte[]]$VariantBytes,[string]$Variant)
    if ($SourceMap.schemaVersion -ne 1) { throw 'Source map schemaVersion is not 1' }
    if ($SourceMap.originalRomSha256 -ine $script:DsOriginalSha256) { throw 'Source map original identity is stale or wrong' }
    if ($SourceMap.outputImageSha256 -ine $script:DsRepairedSha256) { throw 'Source map is not bound to the accepted repaired image' }
    if ($SourceMap.bodyStart -ne '9ED9' -or $SourceMap.bodyEndExclusive -ne '9EE7') { throw 'Source map body span is not 9ED9..9EE7' }
    $entries = @($SourceMap.entries)
    if ($entries.Count -ne 14) { throw "Source map has $($entries.Count) entries, expected 14" }
    $expectedAddress = ConvertTo-DsInt $SourceMap.bodyStart
    $spanEnd = ConvertTo-DsInt $SourceMap.bodyEndExclusive
    $lastNode = -1
    foreach ($entry in $entries) {
        $address = ConvertTo-DsInt $entry.address
        if ($address -ne $expectedAddress) { throw "Source map is not contiguous at $($entry.address)" }
        if ($entry.nodeIndex -lt $lastNode) { throw "Source map node order is reordered at $($entry.address)" }
        if ($entry.nodeIndex -gt $lastNode) {
            if ($entry.nodeIndex -ne ($lastNode + 1)) { throw "Source map node index gap at $($entry.address)" }
            $lastNode = $entry.nodeIndex
        }
        $imageByte = [Convert]::ToInt32($entry.imageByte,16)
        if ($imageByte -ne $RepairedBytes[$address]) { throw "Source map byte at $($entry.address) differs from the repaired image" }
        $expectedAddress++
    }
    if ($expectedAddress -ne $spanEnd) { throw 'Source map does not cover the declared body end' }
    if ($lastNode -ne 4) { throw 'Source map does not contain the five checked node indices 0..4' }

    $differences = Get-DsOffsets $script:DsOriginalBytes $RepairedBytes
    if (($differences -join ',') -ne ($script:DsExpectedChangedOffsets -join ',')) {
        throw "Original/repaired diff is $(($differences | ForEach-Object { '{0:X4}' -f $_ }) -join ','), expected 9EDC,FFD1,FFD2,FFD3,FFD4,FFD5"
    }
    $spanDifference = @($differences | Where-Object { $_ -ge (ConvertTo-DsInt $SourceMap.bodyStart) -and $_ -lt (ConvertTo-DsInt $SourceMap.bodyEndExclusive) })
    if (($spanDifference -join ',') -ne '40668') { throw "The only source-map span difference must be 9EDC, found $(($spanDifference | ForEach-Object { '{0:X4}' -f $_ }) -join ',')" }

    $list = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in $entries) {
        $address = ConvertTo-DsInt $entry.address
        $list.Add([ordered]@{
            address = Format-DsHex16 $address
            nodeIndex = [int]$entry.nodeIndex
            token = [string]$entry.token
            operation = [string]$entry.operation
            imageByte = '{0:X2}' -f $VariantBytes[$address]
        })
    }
    return $list.ToArray()
}

function Get-DsNodes {
    param($VariantEntries,[string[]]$HandlersByOperation)
    $nodes = New-Object 'System.Collections.Generic.List[object]'
    $byIndex = @{}
    foreach ($entry in @($VariantEntries)) {
        $index = [int]$entry.nodeIndex
        if (!$byIndex.ContainsKey($index)) {
            $byIndex[$index] = [ordered]@{
                index = $index
                address = $entry.address
                token = $entry.token
                operation = $entry.operation
                handlerPc = $HandlersByOperation[$index]
                bytes = New-Object 'System.Collections.Generic.List[int]'
            }
            $nodes.Add($byIndex[$index])
        }
        [void]$byIndex[$index].bytes.Add([Convert]::ToInt32($entry.imageByte,16))
    }
    if ($nodes.Count -ne 5) { throw "Expected five source-map nodes, found $($nodes.Count)" }
    return $nodes.ToArray()
}

function Get-DsPlan {
    param([string]$Path)
    $plan = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $handlers = @($plan.vm_observation_boundaries.handler_entries)
    if ($handlers.Count -lt 4) { throw 'handler-entry plan is incomplete' }
    $byOperation = @{}
    foreach ($handler in $handlers) { $byOperation[[string]$handler.operation] = [string]$handler.pc }
    return [ordered]@{ plan=$plan; handlers=$handlers; byOperation=$byOperation }
}

function Write-DsMap {
    param([string]$Path,$VariantMap,$Nodes,$PlanInfo,[byte[]]$VariantBytes)
    $handlerByIndex = @{}
    foreach ($node in $Nodes) {
        if (!$PlanInfo.byOperation.ContainsKey([string]$node.operation)) { throw "no handler entry for operation $($node.operation)" }
        $handlerPc = [string]$PlanInfo.byOperation[[string]$node.operation]
        if ($handlerPc -notmatch '^[0-9A-Fa-f]{4}$') { throw "handler entry for $($node.operation) is not a 4-digit hex address" }
        $handlerByIndex[[int]$node.index] = $handlerPc.ToUpperInvariant()
    }
    $firstAddress = ConvertTo-DsInt $Nodes[0].address
    $secondAddress = ConvertTo-DsInt $Nodes[2].address
    $firstLiteral = ([int]$VariantBytes[$firstAddress+2] -shl 8) -bor [int]$VariantBytes[$firstAddress+3]
    $secondLiteral = ([int]$VariantBytes[$secondAddress+2] -shl 8) -bor [int]$VariantBytes[$secondAddress+3]
    $expectedResult = $firstLiteral -bxor $secondLiteral
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  protocol = "{0}",' -f $script:DsProtocol))
    [void]$sb.AppendLine(('  variant = "{0}",' -f $VariantMap.variant))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $VariantMap.imageSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $VariantMap.originalRomSha256))
    [void]$sb.AppendLine(('  bodyStart = 0x{0},' -f $VariantMap.bodyStart))
    [void]$sb.AppendLine(('  bodyEndExclusive = 0x{0},' -f $VariantMap.bodyEndExclusive))
    [void]$sb.AppendLine(('  expectedFirstLiteral = 0x{0:X4},' -f $firstLiteral))
    [void]$sb.AppendLine(('  expectedSecondLiteral = 0x{0:X4},' -f $secondLiteral))
    [void]$sb.AppendLine(('  expectedResult = 0x{0:X4},' -f $expectedResult))
    [void]$sb.AppendLine('  returnNodeIndex = 4,')
    [void]$sb.AppendLine('  nodes = {')
    foreach ($node in $Nodes) {
        $bytes = (@($node.bytes) | ForEach-Object { '0x{0:X2}' -f $_ }) -join ','
        [void]$sb.AppendLine(('    {{ index = {0}, address = 0x{1}, token = 0x{2}, operation = "{3}", handlerPc = 0x{4}, bytes = {{{5}}} }},' -f $node.index,$node.address,$node.token,$node.operation,$handlerByIndex[[int]$node.index],$bytes))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  entries = {')
    foreach ($entry in @($VariantMap.entries)) {
        [void]$sb.AppendLine(('    {{ address = 0x{0}, nodeIndex = {1}, token = 0x{2}, operation = "{3}", imageByte = 0x{4} }},' -f $entry.address,$entry.nodeIndex,$entry.token,$entry.operation,$entry.imageByte))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
    return [ordered]@{
        firstLiteral = Format-DsHex16 $firstLiteral
        secondLiteral = Format-DsHex16 $secondLiteral
        expectedResult = Format-DsHex16 $expectedResult
        handlerByIndex = $handlerByIndex
    }
}

function Write-DsConfigLua {
    param([string]$Path,$Config)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    foreach ($key in $Config.Keys) {
        $value = $Config[$key]
        if ($value -is [int] -or $value -is [long]) { [void]$sb.AppendLine(('  {0} = {1},' -f $key,$value)) }
        else { [void]$sb.AppendLine(('  {0} = "{1}",' -f $key,$value)) }
    }
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
}

function Write-DsA64Map {
    param([string]$Path,$SessionMap)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  protocol = "{0}",' -f $script:DsProtocol))
    [void]$sb.AppendLine('  definition = "9A64",')
    [void]$sb.AppendLine(('  variant = "{0}",' -f $SessionMap.variant))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $SessionMap.imageSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $SessionMap.originalRomSha256))
    [void]$sb.AppendLine(('  bodyStart = 0x{0},' -f $SessionMap.bodyStart))
    [void]$sb.AppendLine(('  bodyEndExclusive = 0x{0},' -f $SessionMap.bodyEndExclusive))
    [void]$sb.AppendLine(('  sourceMapSha256 = "{0}",' -f $SessionMap.sourceMapSha256))
    [void]$sb.AppendLine(('  buildReportSha256 = "{0}",' -f $SessionMap.buildReportSha256))
    [void]$sb.AppendLine('  returnNodeIndex = 5,')
    [void]$sb.AppendLine('  nodes = {')
    foreach ($node in @($SessionMap.nodes)) {
        $bytes = (@($node.bytes) | ForEach-Object { '0x{0:X2}' -f $_ }) -join ','
        $branchText = 'nil'
        if ($null -ne $node.branch) {
            $branchText = ('{{ tokenAddress = 0x{0}, operandAddress = 0x{1}, operandByte = 0x{2}, targetAddress = 0x{3}, condition = "{4}", offsetBase = "{5}", offsetUnsigned = {6}, operandWidthBytes = {7}, handlerAddress = 0x{8} }}' -f `
                $node.branch.tokenAddress,$node.branch.operandAddress,$node.branch.operandByte,$node.branch.targetAddress,$node.branch.condition,$node.branch.offsetBase,($(if ($node.branch.offsetUnsigned) { 'true' } else { 'false' })),$node.branch.operandWidthBytes,$node.branch.handlerAddress)
        }
        [void]$sb.AppendLine(('    {{ index = {0}, address = 0x{1}, token = 0x{2}, operation = "{3}", handlerPc = 0x{4}, handlerAddress = 0x{5}, bytes = {{{6}}}, branch = {7} }},' -f $node.index,$node.address,$node.token,$node.operation,$node.handlerPc,$node.handlerAddress,($bytes),$branchText))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  entries = {')
    foreach ($entry in @($SessionMap.entries)) {
        [void]$sb.AppendLine(('    {{ address = 0x{0}, nodeIndex = {1}, token = 0x{2}, operation = "{3}", imageByte = 0x{4} }},' -f $entry.address,$entry.nodeIndex,$entry.token,$entry.operation,$entry.imageByte))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
}

function Get-DsA64Word {
    param([byte[]]$Bytes,[int]$Address)
    return ((([int]$Bytes[$Address]) -shl 8) -bor [int]$Bytes[($Address + 1) -band 0xFFFF])
}

function Assert-DsA64MapDocument {
    param($Map,$Build,[byte[]]$Rom,[string]$OriginalSha1,[string]$OriginalSha256)
    if ($Map.schemaVersion -ne 1) { throw '9A64 source map schemaVersion is not 1' }
    if ($Map.originalRomSha1 -ine $OriginalSha1) { throw '9A64 source map original SHA1 is wrong' }
    if ($Map.originalRomSha256 -ine $OriginalSha256) { throw '9A64 source map original SHA256 is wrong' }
    if ($Map.outputSha256 -ine $OriginalSha256) { throw '9A64 source map is not bound to the original identity image' }
    if (!$Map.identityBuild) { throw '9A64 source map is not an identity build map' }
    if ($Map.bodyStart -ne '9A64' -or $Map.bodyEndExclusive -ne '9A72') { throw '9A64 source map body span is not 9A64..9A72' }
    $span = '7B6D79820676657979037671792F'
    if ($Map.spanHex -ine $span) { throw '9A64 source map span bytes differ from the checked listing' }
    if ($Map.emittedBodyHex -ine $span) { throw '9A64 identity build emitted a different body' }
    $nodes = @($Map.nodes)
    $branches = @($Map.branches)
    $entries = @($Map.entries)
    if ($nodes.Count -ne 6) { throw "9A64 source map has $($nodes.Count) nodes, expected 6" }
    if ($branches.Count -ne 2) { throw "9A64 source map has $($branches.Count) branches, expected 2" }
    if ($entries.Count -ne 14) { throw "9A64 source map has $($entries.Count) entries, expected 14" }
    $expectedNodes = @(
        @{ index=0; address='9A64'; token='7B6D'; operation='vm_rotate_three_cells'; handlerPc='7B6F'; bytes='7B6D' },
        @{ index=1; address='9A66'; token='7982'; operation='vm_branch_forward8_if_zero'; handlerPc='7984'; bytes='798206'; branch=@{ tokenAddress='9A66'; operandAddress='9A68'; operandByte='06'; targetAddress='9A6E'; condition='IfZero' } },
        @{ index=2; address='9A69'; token='7665'; operation='vm_or_word_memory'; handlerPc='7667'; bytes='7665' },
        @{ index=3; address='9A6B'; token='7979'; operation='vm_branch_unsigned_forward8'; handlerPc='797B'; bytes='797903'; branch=@{ tokenAddress='9A6B'; operandAddress='9A6D'; operandByte='03'; targetAddress='9A70'; condition='Always' } },
        @{ index=4; address='9A6E'; token='7671'; operation='vm_clear_word_memory_bits'; handlerPc='7673'; bytes='7671' },
        @{ index=5; address='9A70'; token='792F'; operation='vm_return_to_caller_stream'; handlerPc='7931'; bytes='792F' }
    )
    $nodeByAddress = @{}
    for ($index=0; $index -lt 6; $index++) {
        $node = $nodes[$index]
        $expected = $expectedNodes[$index]
        if ([int]$node.index -ne $expected.index) { throw "9A64 node position $index has index $($node.index)" }
        if ($node.address -ine $expected.address) { throw "9A64 node $index address is $($node.address), expected $($expected.address)" }
        if ($node.token -ine $expected.token) { throw "9A64 node $index token is $($node.token), expected $($expected.token)" }
        if ($node.operation -ne $expected.operation) { throw "9A64 node $index operation is $($node.operation), expected $($expected.operation)" }
        if ($node.handlerPc -ine $expected.handlerPc) { throw "9A64 node $index handler PC is $($node.handlerPc), expected $($expected.handlerPc)" }
        if ($node.bytesHex -ine $expected.bytes) { throw "9A64 node $index bytes are $($node.bytesHex), expected $($expected.bytes)" }
        $address = ConvertTo-DsInt $node.address
        $tokenAddress = ConvertTo-DsInt $node.token
        if ((Get-DsA64Word $Rom $address) -ne $tokenAddress) { throw "9A64 node $index live token word differs from the map" }
        if ((Get-DsA64Word $Rom $tokenAddress) -ne (ConvertTo-DsInt $node.handlerPc)) { throw "9A64 node $index code field does not point at the mapped handler" }
        if ($node.handlerAddress -ine ([string](Format-DsHex16 ($tokenAddress + 2)))) { throw "9A64 node $index handlerAddress is not token+2" }
        if ($node.handlerAddress -ine $node.handlerPc) { throw "9A64 node $index handlerAddress and handlerPc differ" }
        if ($expected.ContainsKey('branch')) {
            $branch = $node.branch
            if ($null -eq $branch) { throw "9A64 node $index is missing its byte-branch model" }
            $expectedBranch = $expected.branch
            if ($branch.tokenAddress -ine $expectedBranch.tokenAddress) { throw "9A64 node $index branch tokenAddress is wrong" }
            if ($branch.operandAddress -ine $expectedBranch.operandAddress) { throw "9A64 node $index branch operand address is wrong" }
            if ($branch.operandByte -ine $expectedBranch.operandByte) { throw "9A64 node $index branch operand byte is wrong" }
            if ($branch.targetAddress -ine $expectedBranch.targetAddress) { throw "9A64 node $index branch target is wrong" }
            if ($branch.condition -ne $expectedBranch.condition) { throw "9A64 node $index branch condition is wrong" }
            if ($branch.offsetBase -ne 'operand-address') { throw "9A64 node $index branch offset base is wrong" }
            if (!$branch.offsetUnsigned) { throw "9A64 node $index branch is not unsigned" }
            if ([int]$branch.operandWidthBytes -ne 1) { throw "9A64 node $index branch operand width is not one byte" }
            $operandAddress = ConvertTo-DsInt $branch.operandAddress
            if ([int]$Rom[$operandAddress] -ne (ConvertTo-DsInt $branch.operandByte)) { throw "9A64 node $index live branch operand differs from the map" }
            if (($operandAddress + (ConvertTo-DsInt $branch.operandByte)) -ne (ConvertTo-DsInt $branch.targetAddress)) { throw "9A64 node $index branch target arithmetic does not hold" }
            if (!($expectedNodes | Where-Object { $_.address -ieq $branch.targetAddress })) { throw "9A64 node $index branch target is not a node boundary" }
            if ($branch.handlerAddress -ine $node.handlerPc) { throw "9A64 node $index branch handler address differs from the handler PC" }
        }
        elseif ($null -ne $node.branch) { throw "9A64 node $index has an unexpected branch model" }
        $nodeByAddress[$expected.address] = $node
    }
    $expectedBranchTable = @($branches | ForEach-Object { [string]$_.tokenAddress })
    if (($expectedBranchTable -join ',') -ne '9A66,9A6B') { throw '9A64 branch table does not bind the two checked token addresses' }
    $expectedAddress = 0x9A64
    for ($index=0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        if ((ConvertTo-DsInt $entry.address) -ne $expectedAddress) { throw "9A64 entry $index is not contiguous" }
        if ((ConvertTo-DsInt $entry.imageByte) -ne [int]$Rom[$expectedAddress]) { throw "9A64 entry $index image byte differs from the original ROM" }
        $owner = $expectedNodes | Where-Object { (ConvertTo-DsInt $_.address) -le $expectedAddress -and $expectedAddress -lt ((ConvertTo-DsInt $_.address) + ($_.bytes.Length / 2)) } | Select-Object -First 1
        if ($null -eq $owner) { throw "9A64 entry $index has no owning node" }
        if ([int]$entry.nodeIndex -ne $owner.index) { throw "9A64 entry $index nodeIndex differs from the owning node" }
        if ($entry.token -ine $owner.token -or $entry.operation -ne $owner.operation) { throw "9A64 entry $index token/operation differs from its node" }
        $expectedAddress++
    }
    if ($expectedAddress -ne 0x9A72) { throw '9A64 entries do not reach the declared body end' }
    $handlerExpectations = @(
        @{ token='7979'; handler='797B'; instructions=@(@{a='797B';b='E6A4'},@{a='797D';b='4F'},@{a='797E';b='31AB'},@{a='7980';b='0EFC'}) },
        @{ token='7982'; handler='7984'; instructions=@(@{a='7984';b='ECC1'},@{a='7986';b='27F3'},@{a='7988';b='3121'},@{a='798A';b='0EFC'}) }
    )
    foreach ($expected in $handlerExpectations) {
        $handler = @($Map.handlers | Where-Object { $_.tokenAddress -ieq $expected.token })
        if ($handler.Count -ne 1) { throw "9A64 handler record for token $($expected.token) is missing or duplicated" }
        if ($handler[0].handlerAddress -ine $expected.handler) { throw "9A64 handler entry for token $($expected.token) is wrong" }
        $instructions = @($handler[0].instructions)
        if ($instructions.Count -ne $expected.instructions.Count) { throw "9A64 handler $($expected.handler) instruction count is wrong" }
        for ($index=0; $index -lt $instructions.Count; $index++) {
            if ($instructions[$index].address -ine $expected.instructions[$index].a) { throw "9A64 handler $($expected.handler) instruction $index address is wrong" }
            if ($instructions[$index].bytesHex -ine $expected.instructions[$index].b) { throw "9A64 handler $($expected.handler) instruction $index bytes are wrong" }
            $address = ConvertTo-DsInt $expected.instructions[$index].a
            $byteCount = ([string]$expected.instructions[$index].b).Length / 2
            $live = -join @(0..($byteCount - 1) | ForEach-Object { '{0:X2}' -f [int]$Rom[$address + $_] })
            if ($live -ine $expected.instructions[$index].b) { throw "9A64 handler $($expected.handler) instruction $index live bytes differ from the ROM" }
        }
    }
    if ($Build.schemaVersion -ne 1) { throw '9A64 build report schemaVersion is not 1' }
    if ($Build.originalSha1 -ine $OriginalSha1 -or $Build.originalSha256 -ine $OriginalSha256) { throw '9A64 build report original identity is wrong' }
    if ($Build.outputSha1 -ine $OriginalSha1 -or $Build.outputSha256 -ine $OriginalSha256) { throw '9A64 build report output is not the original identity image' }
    if (!$Build.identityImageUnchanged) { throw '9A64 build report is not an identity build' }
    if (@($Build.changedOffsets).Count -ne 0) { throw '9A64 build report changed offsets are not empty' }
    if ($Build.bodyStart -ne '9A64' -or $Build.bodyEndExclusive -ne '9A72') { throw '9A64 build report body span is wrong' }
    if ($Build.emittedBodyHex -ine $span) { throw '9A64 build report emitted body differs from the original span' }
    if ([int]$Build.sourceMapEntryCount -ne 14 -or [int]$Build.sourceMapBranchCount -ne 2) { throw '9A64 build report source-map counts are wrong' }
    foreach ($check in @('strictOriginalIdentity','identityImageUnchanged','emittedBodyMatchesSpan','sourceMapBoundToOutputSha256','tokenHandlersVerified','branchModelPresent')) {
        if (!$Build.checks.$check) { throw "9A64 build report check $check is not true" }
    }
}

function Invoke-DsNineA64Session {
    $script:DsA64SourceMapSha256 = '8d9c9ddc58373e1ffdd221590a75babc1fb7bf3f497bfca587dbac84981df766'
    $script:DsA64BuildReportSha256 = '11455cdcc15d91780bd1f67c3bd0f6fcdffb3a6a22a4cb61f6fdbc901e3ec3e2'
    if ($Variant -ne 'Original') { throw '9A64 supports only the original identity image; modified images and edits are not supported' }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only session directory: $run" }
    foreach ($path in @($MameExecutable,$SourceMapPath,$BuildReportPath,$ReplayPath,$InputLuaPath)) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $path" }
    }
    if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }
    $mameHash = Get-DsHash $MameExecutable 'SHA256'
    if ($mameHash -ine $script:DsMameSha256) { throw "MAME SHA256 is $mameHash, expected $($script:DsMameSha256)" }
    $replayHash = Get-DsHash $ReplayPath 'SHA256'
    if ($replayHash -ine $script:DsReplaySha256) { throw "Replay SHA256 is $replayHash, expected $($script:DsReplaySha256)" }
    $mapHash = Get-DsHash $SourceMapPath 'SHA256'
    if ($mapHash -ine $script:DsA64SourceMapSha256) { throw "9A64 source map SHA256 is $mapHash, expected $($script:DsA64SourceMapSha256)" }
    $buildHash = Get-DsHash $BuildReportPath 'SHA256'
    if ($buildHash -ine $script:DsA64BuildReportSha256) { throw "9A64 build report SHA256 is $buildHash, expected $($script:DsA64BuildReportSha256)" }
    $inputLuaHash = Get-DsHash $InputLuaPath 'SHA256'
    $originalIdentity = Assert-DsRom $OriginalRom 65536 $script:DsOriginalSha1 $script:DsOriginalSha256 'original ROM'
    $originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
    if (![string]::IsNullOrWhiteSpace($RepairedRom)) {
        $other = Assert-DsRom $RepairedRom 65536 $script:DsOriginalSha1 $script:DsOriginalSha256 '9A64 image'
        if ((Get-DsHash $RepairedRom 'SHA256') -ine $script:DsOriginalSha256) { throw '9A64 does not support modified images or edits' }
    }
    $map = Get-Content -LiteralPath $SourceMapPath -Raw | ConvertFrom-Json
    $build = Get-Content -LiteralPath $BuildReportPath -Raw | ConvertFrom-Json
    Assert-DsA64MapDocument $map $build $originalBytes $script:DsOriginalSha1 $script:DsOriginalSha256
    $sessionNodes = New-Object 'System.Collections.Generic.List[object]'
    foreach ($node in @($map.nodes)) {
        $bytes = New-Object 'System.Collections.Generic.List[int]'
        for ($i=0; $i -lt ([string]$node.bytesHex).Length; $i+=2) { [void]$bytes.Add([Convert]::ToInt32(([string]$node.bytesHex).Substring($i,2),16)) }
        $branch = $null
        if ($null -ne $node.branch) {
            $branch = [ordered]@{
                tokenAddress = [string]$node.branch.tokenAddress
                operandAddress = [string]$node.branch.operandAddress
                operandByte = [string]$node.branch.operandByte
                targetAddress = [string]$node.branch.targetAddress
                condition = [string]$node.branch.condition
                offsetBase = [string]$node.branch.offsetBase
                offsetUnsigned = [bool]$node.branch.offsetUnsigned
                operandWidthBytes = [int]$node.branch.operandWidthBytes
                handlerAddress = [string]$node.branch.handlerAddress
            }
        }
        $sessionNodes.Add([ordered]@{
            index = [int]$node.index
            address = [string]$node.address
            token = [string]$node.token
            operation = [string]$node.operation
            handlerPc = [string]$node.handlerPc
            handlerAddress = [string]$node.handlerAddress
            bytes = $bytes.ToArray()
            branch = $branch
        })
    }
    $sessionEntries = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in @($map.entries)) {
        $sessionEntries.Add([ordered]@{
            address = [string]$entry.address
            nodeIndex = [int]$entry.nodeIndex
            token = [string]$entry.token
            operation = [string]$entry.operation
            imageByte = [string]$entry.imageByte
        })
    }
    $sessionBranches = New-Object 'System.Collections.Generic.List[object]'
    foreach ($branch in @($map.branches)) {
        $sessionBranches.Add([ordered]@{
            nodeIndex = [int]$branch.nodeIndex
            tokenAddress = [string]$branch.tokenAddress
            operandAddress = [string]$branch.operandAddress
            operandByte = [string]$branch.operandByte
            targetAddress = [string]$branch.targetAddress
            condition = [string]$branch.condition
            offsetBase = [string]$branch.offsetBase
            offsetUnsigned = [bool]$branch.offsetUnsigned
            operandWidthBytes = [int]$branch.operandWidthBytes
        })
    }
    $sessionId = [guid]::NewGuid().ToString('D')
    $sessionMap = [ordered]@{
        variant = 'Original'
        imageSha256 = $script:DsOriginalSha256
        originalRomSha256 = $script:DsOriginalSha256
        bodyStart = '9A64'
        bodyEndExclusive = '9A72'
        sourceMapSha256 = $mapHash
        buildReportSha256 = $buildHash
        nodes = $sessionNodes.ToArray()
        entries = $sessionEntries.ToArray()
        branches = $sessionBranches.ToArray()
    }
    $config = [ordered]@{
        schemaVersion = 1
        protocol = $script:DsProtocol
        sessionId = $sessionId
        definition = '9A64'
        variant = 'Original'
        cpuTag = ':maincpu'
        secondsToRun = $SecondsToRun
        wallTimeoutSeconds = $WallTimeoutSeconds
        expectedOriginalRomSha256 = $script:DsOriginalSha256
        expectedImageSha256 = $script:DsOriginalSha256
        expectedSourceMapSha256 = $mapHash
        expectedBuildReportSha256 = $buildHash
        expectedPlanSha256 = ''
        expectedReplaySha256 = $replayHash
        expectedInputLuaSha256 = $inputLuaHash
        expectedMameSha256 = $mameHash
    }
    New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
    foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff','commands','responses','protocol')) {
        New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
    }
    $variantPath = $OriginalRom
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    Copy-Item -LiteralPath $variantPath -Destination $runRom -ErrorAction Stop
    $runRomIdentity = Assert-DsRom $runRom 65536 $script:DsOriginalSha1 $script:DsOriginalSha256 'isolated run ROM copy'
    Copy-Item -LiteralPath $ReplayPath -Destination (Join-Path $run 'replay-actions.csv') -ErrorAction Stop
    Copy-Item -LiteralPath $InputLuaPath -Destination (Join-Path $run 'input.lua') -ErrorAction Stop
    Copy-Item -LiteralPath (Join-Path $script:DsRoot 'tools/lua/IlDebugSession.lua') -Destination (Join-Path $run 'IlDebugSession.lua') -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlDebugSession.lua')`n",(New-Object System.Text.UTF8Encoding($false)))
    Write-DsA64Map (Join-Path $run 'session-map.lua') $sessionMap
    Write-DsConfigLua (Join-Path $run 'session-config.lua') $config
    Write-DsJson (Join-Path $run 'session-config.json') $config 8
    Write-DsJson (Join-Path $run 'variant-map.json') ([ordered]@{
        schemaVersion = 1
        definition = '9A64'
        variant = 'Original'
        originalRomSha256 = $script:DsOriginalSha256
        outputImageSha256 = $script:DsOriginalSha256
        bodyStart = '9A64'
        bodyEndExclusive = '9A72'
        sourceMapSha256 = $mapHash
        buildReportSha256 = $buildHash
        entries = $sessionEntries.ToArray()
        nodes = $sessionNodes.ToArray()
        branches = $sessionBranches.ToArray()
    }) 12
    Write-DsJson (Join-Path $run 'session-metadata.json') ([ordered]@{
        sessionId = $sessionId
        protocol = $script:DsProtocol
        definition = '9A64'
        variant = 'Original'
        original_rom = $originalIdentity
        variant_rom = $originalIdentity
        run_rom_before = $runRomIdentity
        source_map_path = [IO.Path]::GetFullPath($SourceMapPath)
        source_map_sha256 = $mapHash
        build_report_path = [IO.Path]::GetFullPath($BuildReportPath)
        build_report_sha256 = $buildHash
        replay_sha256 = $replayHash
        input_lua_sha256 = $inputLuaHash
        mame_executable = [IO.Path]::GetFullPath($MameExecutable)
        mame_sha256 = $mameHash
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
        body_start = '9A64'
        body_end_exclusive = '9A72'
        return_node_index = 5
        changed_offsets_hex = ''
        starting_nvram = 'absent'
        starting_configuration = 'absent; -noreadconfig'
        save_state_loaded = $false
        debugger_writes = $false
        classification = 'Fresh-isolated natural original-image 9A64 run with read-only Lua run-control and bounded IL-node stepping.'
    }) 14
    $preRunCounts = [ordered]@{}
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) { $preRunCounts[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count }
    foreach ($key in $preRunCounts.Keys) { if ($preRunCounts[$key] -ne 0) { throw "Pre-run directory $key is not empty" } }
    $preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
    if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
    Write-DsJson (Join-Path $run 'pre-run-empty.json') $preRunCounts 6
    $versionOut = Join-Path $run 'mame-version.txt'
    $versionErr = Join-Path $run 'mame-version.err.txt'
    $versionInfo = New-Object System.Diagnostics.ProcessStartInfo
    $versionInfo.FileName = [IO.Path]::GetFullPath($MameExecutable)
    $versionInfo.Arguments = '-version'
    $versionInfo.WorkingDirectory = $run
    $versionInfo.UseShellExecute = $false
    $versionInfo.CreateNoWindow = $true
    $versionInfo.RedirectStandardOutput = $true
    $versionInfo.RedirectStandardError = $true
    $versionProcess = New-Object System.Diagnostics.Process
    $versionProcess.StartInfo = $versionInfo
    [void]$versionProcess.Start()
    $versionStdout = $versionProcess.StandardOutput.ReadToEndAsync()
    $versionStderr = $versionProcess.StandardError.ReadToEndAsync()
    if (-not $versionProcess.WaitForExit(60000)) { & "$env:SystemRoot\System32\taskkill.exe" /PID $versionProcess.Id /T /F | Out-Null; throw 'MAME -version timed out' }
    [IO.File]::WriteAllText($versionOut,$versionStdout.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($versionErr,$versionStderr.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
    if ($versionProcess.ExitCode -ne 0) { throw "MAME -version failed: exit=$($versionProcess.ExitCode)" }
    $versionProcess.Dispose()
    $mameVersion = ((Get-Content -LiteralPath $versionOut -Raw).Trim() -split "\r?\n")[0]
    if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }
    $arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
        '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
        '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
        '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
        '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','imgui','-debuglog',
        '-video','bgfx','-sound','none','-window','-skip_gameinfo','-nothrottle',
        '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
        '-autoboot_script',(Join-Path $run 'observer.lua'))
    $arguments += @('-bgfx_path',(Join-Path (Split-Path $MameExecutable -Parent) 'bgfx'))
    $quotedArguments = foreach ($arg in $arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') { '"' + $text.Replace('"','\"') + '"' } else { $text }
    }
    $argumentString = ($quotedArguments -join ' ')
    $consolePath = Join-Path $run 'console.txt'
    $consoleErrorPath = Join-Path $run 'console.err.txt'
    $wrapperPath = Join-Path $run 'launch.cmd'
    $wrapperLines = @(
        '@echo off',
        ('set "MPU4_REPLAY={0}"' -f (Join-Path $run 'replay-actions.csv')),
        'set "MPU4_POLICY=7"',
        'set "FML_IL_DEBUG_SESSION=1"',
        ('set "FML_IL_DEBUG_SESSION_ID={0}"' -f $sessionId),
        ('"{0}" {1} > "{2}" 2> "{3}"' -f ([IO.Path]::GetFullPath($MameExecutable)), $argumentString, $consolePath, $consoleErrorPath),
        'set "MAME_EXIT=%ERRORLEVEL%"',
        ('echo %MAME_EXIT% > "{0}"' -f (Join-Path $run 'mame-exit-code.txt')),
        'exit /b %MAME_EXIT%'
    )
    [IO.File]::WriteAllLines($wrapperPath, $wrapperLines, (New-Object System.Text.UTF8Encoding($false)))
    $wrapperCommand = 'cmd.exe /c ""' + [IO.Path]::GetFullPath($wrapperPath) + '""'
    $createResult = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $wrapperCommand; CurrentDirectory = $run }
    if ($createResult.ReturnValue -ne 0) { throw "Failed to create the detached MAME launcher (WMI return $($createResult.ReturnValue))" }
    $launchPid = [int]$createResult.ProcessId
    $startUtc = [DateTime]::UtcNow
    $readyPath = Join-Path $run 'ready.txt'
    $readyDeadline = [DateTime]::UtcNow.AddSeconds([Math]::Min($WallTimeoutSeconds, 60))
    while (!(Test-Path -LiteralPath $readyPath -PathType Leaf)) {
        if ($null -eq (Get-Process -Id $launchPid -ErrorAction SilentlyContinue)) {
            $consoleText = if (Test-Path -LiteralPath $consoleErrorPath) { Get-Content -LiteralPath $consoleErrorPath -Raw } else { '' }
            throw "MAME launcher exited before the session became ready: $consoleText"
        }
        if ([DateTime]::UtcNow -gt $readyDeadline) {
            & "$env:SystemRoot\System32\taskkill.exe" /PID $launchPid /T /F | Out-Null
            throw "Session did not become ready within $([Math]::Min($WallTimeoutSeconds,60)) wall seconds"
        }
        Start-Sleep -Milliseconds 200
    }
    $readyLines = @(Get-Content -LiteralPath $readyPath)
    $ready = @{}
    foreach ($line in $readyLines) {
        if ($line -match '^([a-zA-Z0-9]+)=(.*)$') { $ready[$Matches[1]] = $Matches[2] }
    }
    if ($ready['protocol'] -ne $script:DsProtocol) { throw 'Ready file protocol mismatch' }
    if ($ready['session'] -ne $sessionId) { throw 'Ready file session mismatch' }
    if ($ready['variant'] -ne 'Original') { throw 'Ready file variant mismatch' }
    if ($ready['map'] -ne 'ok') { throw 'Lua map validation did not pass' }
    if ($ready['exec'] -ne 'stop') { throw "Session did not start stopped (exec=$($ready['exec']))" }
    if ($ready['lfs'] -ne 'ok') { throw 'Lua lfs directory enumeration is unavailable' }
    if ($ready['nodes'] -ne '6') { throw "Ready file reports $($ready['nodes']) nodes, expected 6" }
    Write-DsJson (Join-Path $run 'session-launch.json') ([ordered]@{
        sessionId = $sessionId
        definition = '9A64'
        variant = 'Original'
        protocol = $script:DsProtocol
        process_id = $launchPid
        start_utc = $startUtc.ToString('o')
        command_line = $argumentString
        mame_version = $mameVersion
        mame_sha256 = $mameHash
        launch_wrapper = $wrapperPath
        ready = $ready
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
    }) 10
    $launchRecord = [ordered]@{
        sessionId = $sessionId
        definition = '9A64'
        variant = 'Original'
        session_directory = $run
        process_id = $launchPid
        mame_version = $mameVersion
        ready = $ready
    }
    Write-Output (ConvertTo-Json -InputObject $launchRecord -Depth 6)
}

if ($Definition -eq '9A64') {
    Invoke-DsNineA64Session
    return
}
if ([string]::IsNullOrWhiteSpace($RepairedRom)) { throw 'The 9ED9 session requires -RepairedRom' }

# Validate inputs before creating the session directory.
$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only session directory: $run" }
foreach ($path in @($MameExecutable,$SourceMapPath,$BuildReportPath,$PlanPath,$ReplayPath,$InputLuaPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $path" }
}
if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }
$mameHash = Get-DsHash $MameExecutable 'SHA256'
if ($mameHash -ine $script:DsMameSha256) { throw "MAME SHA256 is $mameHash, expected $($script:DsMameSha256)" }
Assert-DsCanonicalJsonFile $SourceMapPath 'Source map'
Assert-DsCanonicalJsonFile $BuildReportPath 'Build report'
$sourceMapHash = Get-DsHash $SourceMapPath 'SHA256'
$buildReportHash = Get-DsHash $BuildReportPath 'SHA256'
$replayHash = Get-DsHash $ReplayPath 'SHA256'
if ($replayHash -ine $script:DsReplaySha256) { throw "Replay SHA256 is $replayHash, expected $($script:DsReplaySha256)" }
$planHash = Get-DsHash $PlanPath 'SHA256'
$inputLuaHash = Get-DsHash $InputLuaPath 'SHA256'

$originalIdentity = Assert-DsRom $OriginalRom 65536 $script:DsOriginalSha1 $script:DsOriginalSha256 'original ROM'
$repairedIdentity = Assert-DsRom $RepairedRom 65536 $script:DsRepairedSha1 $script:DsRepairedSha256 'repaired ROM'
$expectedVariant = if ($Variant -eq 'Original') { @{ Sha1=$script:DsOriginalSha1; Sha256=$script:DsOriginalSha256 } } else { @{ Sha1=$script:DsRepairedSha1; Sha256=$script:DsRepairedSha256 } }
$variantPath = if ($Variant -eq 'Original') { $OriginalRom } else { $RepairedRom }
$variantIdentity = Assert-DsRom $variantPath 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 "$Variant ROM"
$script:DsOriginalBytes = [IO.File]::ReadAllBytes($OriginalRom)
$repairedBytes = [IO.File]::ReadAllBytes($RepairedRom)
$variantBytes = [IO.File]::ReadAllBytes($variantPath)
$actualChanged = Get-DsOffsets $script:DsOriginalBytes $repairedBytes
if (($actualChanged -join ',') -ne ($script:DsExpectedChangedOffsets -join ',')) { throw 'Original/repaired diff is not the accepted six-byte edit' }

$sourceMap = Get-Content -LiteralPath $SourceMapPath -Raw | ConvertFrom-Json
$buildReport = Get-Content -LiteralPath $BuildReportPath -Raw | ConvertFrom-Json
Assert-DsSourceMap $sourceMap $repairedBytes $script:DsOriginalSha256 $script:DsRepairedSha256
Assert-DsBuildReport $buildReport $script:DsOriginalBytes $repairedBytes $OriginalRom $RepairedRom $SourceMapPath $script:DsOriginalSha256 $script:DsRepairedSha256

$planInfo = Get-DsPlan $PlanPath
$variantEntries = Get-DsVariantEntries $sourceMap $repairedBytes $variantBytes $Variant
$variantMap = [ordered]@{
    variant = $Variant
    imageSha256 = $expectedVariant.Sha256
    originalRomSha256 = $script:DsOriginalSha256
    bodyStart = '9ED9'
    bodyEndExclusive = '9EE7'
    entries = @($variantEntries)
}
$handlerByOperation = $planInfo.byOperation
$handlerByIndex = @{}
$nodeOperations = @{}
foreach ($entry in $variantEntries) { $nodeOperations[[int]$entry.nodeIndex] = [string]$entry.operation }
foreach ($index in $nodeOperations.Keys) {
    $operation = $nodeOperations[$index]
    if (!$handlerByOperation.ContainsKey($operation)) { throw "no handler entry for operation $operation" }
    $handlerByIndex[[int]$index] = [string]$handlerByOperation[$operation]
}
$nodes = Get-DsNodes $variantEntries $handlerByIndex
$sessionId = [guid]::NewGuid().ToString('D')
$config = [ordered]@{
    schemaVersion = 1
    protocol = $script:DsProtocol
    sessionId = $sessionId
    variant = $Variant
    cpuTag = ':maincpu'
    secondsToRun = $SecondsToRun
    wallTimeoutSeconds = $WallTimeoutSeconds
    expectedOriginalRomSha256 = $script:DsOriginalSha256
    expectedImageSha256 = $expectedVariant.Sha256
    expectedSourceMapSha256 = $sourceMapHash
    expectedBuildReportSha256 = $buildReportHash
    expectedPlanSha256 = $planHash
    expectedReplaySha256 = $replayHash
    expectedInputLuaSha256 = $inputLuaHash
    expectedMameSha256 = $mameHash
}

# Create the fresh isolated session directory and immutable copies.
New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff','commands','responses','protocol')) {
    New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
}
$runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
Copy-Item -LiteralPath $variantPath -Destination $runRom -ErrorAction Stop
$runRomIdentity = Assert-DsRom $runRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 'isolated run ROM copy'
Copy-Item -LiteralPath $ReplayPath -Destination (Join-Path $run 'replay-actions.csv') -ErrorAction Stop
Copy-Item -LiteralPath $InputLuaPath -Destination (Join-Path $run 'input.lua') -ErrorAction Stop
Copy-Item -LiteralPath (Join-Path $script:DsRoot 'tools/lua/IlDebugSession.lua') -Destination (Join-Path $run 'IlDebugSession.lua') -ErrorAction Stop
[IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlDebugSession.lua')`n",(New-Object System.Text.UTF8Encoding($false)))
$mapInfo = Write-DsMap (Join-Path $run 'session-map.lua') $variantMap $nodes $planInfo $variantBytes
Write-DsConfigLua (Join-Path $run 'session-config.lua') $config
Write-DsJson (Join-Path $run 'session-config.json') $config 8
Write-DsJson (Join-Path $run 'variant-map.json') ([ordered]@{
    schemaVersion = 1
    variant = $Variant
    originalRomSha256 = $script:DsOriginalSha256
    outputImageSha256 = $expectedVariant.Sha256
    bodyStart = '9ED9'
    bodyEndExclusive = '9EE7'
    entries = @($variantEntries)
    nodes = @($nodes)
}) 12
Write-DsJson (Join-Path $run 'session-metadata.json') ([ordered]@{
    sessionId = $sessionId
    protocol = $script:DsProtocol
    variant = $Variant
    original_rom = $originalIdentity
    repaired_rom = $repairedIdentity
    variant_rom = $variantIdentity
    run_rom_before = $runRomIdentity
    source_map_path = [IO.Path]::GetFullPath($SourceMapPath)
    source_map_sha256 = $sourceMapHash
    build_report_path = [IO.Path]::GetFullPath($BuildReportPath)
    build_report_sha256 = $buildReportHash
    plan_path = [IO.Path]::GetFullPath($PlanPath)
    plan_sha256 = $planHash
    replay_sha256 = $replayHash
    input_lua_sha256 = $inputLuaHash
    mame_executable = [IO.Path]::GetFullPath($MameExecutable)
    mame_sha256 = $mameHash
    seconds_to_run = $SecondsToRun
    wall_timeout_seconds = $WallTimeoutSeconds
    expected_first_literal = $mapInfo.firstLiteral
    expected_second_literal = $mapInfo.secondLiteral
    expected_result = $mapInfo.expectedResult
    handler_by_index = [ordered]@{ '0'=$mapInfo.handlerByIndex[0]; '1'=$mapInfo.handlerByIndex[1]; '2'=$mapInfo.handlerByIndex[2]; '3'=$mapInfo.handlerByIndex[3]; '4'=$mapInfo.handlerByIndex[4] }
    changed_offsets_hex = (($actualChanged | Sort-Object | ForEach-Object { '{0:X4}' -f $_ }) -join ',')
    starting_nvram = 'absent'
    starting_configuration = 'absent; -noreadconfig'
    save_state_loaded = $false
    debugger_writes = $false
    classification = 'Fresh-isolated natural run with read-only Lua run-control and bounded IL-node stepping.'
}) 14

$preRunCounts = [ordered]@{}
foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) { $preRunCounts[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count }
foreach ($key in $preRunCounts.Keys) { if ($preRunCounts[$key] -ne 0) { throw "Pre-run directory $key is not empty" } }
$preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
Write-DsJson (Join-Path $run 'pre-run-empty.json') $preRunCounts 6

# Version check, then asynchronous launch. The session exits only by the stop command or its wall bound.
$versionOut = Join-Path $run 'mame-version.txt'
$versionErr = Join-Path $run 'mame-version.err.txt'
$versionInfo = New-Object System.Diagnostics.ProcessStartInfo
$versionInfo.FileName = [IO.Path]::GetFullPath($MameExecutable)
$versionInfo.Arguments = '-version'
$versionInfo.WorkingDirectory = $run
$versionInfo.UseShellExecute = $false
$versionInfo.CreateNoWindow = $true
$versionInfo.RedirectStandardOutput = $true
$versionInfo.RedirectStandardError = $true
$versionProcess = New-Object System.Diagnostics.Process
$versionProcess.StartInfo = $versionInfo
[void]$versionProcess.Start()
$versionStdout = $versionProcess.StandardOutput.ReadToEndAsync()
$versionStderr = $versionProcess.StandardError.ReadToEndAsync()
if (-not $versionProcess.WaitForExit(60000)) { & "$env:SystemRoot\System32\taskkill.exe" /PID $versionProcess.Id /T /F | Out-Null; throw 'MAME -version timed out' }
[IO.File]::WriteAllText($versionOut,$versionStdout.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($versionErr,$versionStderr.GetAwaiter().GetResult(),(New-Object System.Text.UTF8Encoding($false)))
if ($versionProcess.ExitCode -ne 0) { throw "MAME -version failed: exit=$($versionProcess.ExitCode)" }
$versionProcess.Dispose()
$mameVersion = ((Get-Content -LiteralPath $versionOut -Raw).Trim() -split "\r?\n")[0]
if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }

$arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
    '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
    '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
    '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
    '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','imgui','-debuglog',
    '-video','bgfx','-sound','none','-window','-skip_gameinfo','-nothrottle',
    '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
    '-autoboot_script',(Join-Path $run 'observer.lua'))
$arguments += @('-bgfx_path',(Join-Path (Split-Path $MameExecutable -Parent) 'bgfx'))
$quotedArguments = foreach ($arg in $arguments) {
    $text = [string]$arg
    if ($text -match '[\s"]') { '"' + $text.Replace('"','\"') + '"' } else { $text }
}
$argumentString = ($quotedArguments -join ' ')
$consolePath = Join-Path $run 'console.txt'
$consoleErrorPath = Join-Path $run 'console.err.txt'
$wrapperPath = Join-Path $run 'launch.cmd'
$wrapperLines = @(
    '@echo off',
    ('set "MPU4_REPLAY={0}"' -f (Join-Path $run 'replay-actions.csv')),
    'set "MPU4_POLICY=7"',
    'set "FML_IL_DEBUG_SESSION=1"',
    ('set "FML_IL_DEBUG_SESSION_ID={0}"' -f $sessionId),
    ('"{0}" {1} > "{2}" 2> "{3}"' -f ([IO.Path]::GetFullPath($MameExecutable)), $argumentString, $consolePath, $consoleErrorPath),
    'set "MAME_EXIT=%ERRORLEVEL%"',
    ('echo %MAME_EXIT% > "{0}"' -f (Join-Path $run 'mame-exit-code.txt')),
    'exit /b %MAME_EXIT%'
)
[IO.File]::WriteAllLines($wrapperPath, $wrapperLines, (New-Object System.Text.UTF8Encoding($false)))
$wrapperCommand = 'cmd.exe /c ""' + [IO.Path]::GetFullPath($wrapperPath) + '""'
$createResult = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $wrapperCommand; CurrentDirectory = $run }
if ($createResult.ReturnValue -ne 0) { throw "Failed to create the detached MAME launcher (WMI return $($createResult.ReturnValue))" }
$launchPid = [int]$createResult.ProcessId
$startUtc = [DateTime]::UtcNow
$readyPath = Join-Path $run 'ready.txt'
$readyDeadline = [DateTime]::UtcNow.AddSeconds([Math]::Min($WallTimeoutSeconds, 60))
while (!(Test-Path -LiteralPath $readyPath -PathType Leaf)) {
    if ($null -eq (Get-Process -Id $launchPid -ErrorAction SilentlyContinue)) {
        $consoleText = if (Test-Path -LiteralPath $consoleErrorPath) { Get-Content -LiteralPath $consoleErrorPath -Raw } else { '' }
        throw "MAME launcher exited before the session became ready: $consoleText"
    }
    if ([DateTime]::UtcNow -gt $readyDeadline) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $launchPid /T /F | Out-Null
        throw "Session did not become ready within $([Math]::Min($WallTimeoutSeconds,60)) wall seconds"
    }
    Start-Sleep -Milliseconds 200
}
$readyLines = @(Get-Content -LiteralPath $readyPath)
$ready = @{}
foreach ($line in $readyLines) {
    if ($line -match '^([a-zA-Z0-9]+)=(.*)$') { $ready[$Matches[1]] = $Matches[2] }
}
if ($ready['protocol'] -ne $script:DsProtocol) { throw 'Ready file protocol mismatch' }
if ($ready['session'] -ne $sessionId) { throw 'Ready file session mismatch' }
if ($ready['variant'] -ne $Variant) { throw 'Ready file variant mismatch' }
if ($ready['map'] -ne 'ok') { throw 'Lua map validation did not pass' }
if ($ready['exec'] -ne 'stop') { throw "Session did not start stopped (exec=$($ready['exec']))" }
if ($ready['lfs'] -ne 'ok') { throw 'Lua lfs directory enumeration is unavailable' }
Write-DsJson (Join-Path $run 'session-launch.json') ([ordered]@{
    sessionId = $sessionId
    variant = $Variant
    protocol = $script:DsProtocol
    process_id = $launchPid
    start_utc = $startUtc.ToString('o')
    command_line = $argumentString
    mame_version = $mameVersion
    mame_sha256 = $mameHash
    launch_wrapper = $wrapperPath
    ready = $ready
    seconds_to_run = $SecondsToRun
    wall_timeout_seconds = $WallTimeoutSeconds
}) 10
$launchRecord = [ordered]@{
    sessionId = $sessionId
    variant = $Variant
    session_directory = $run
    process_id = $launchPid
    mame_version = $mameVersion
    ready = $ready
}
Write-Output (ConvertTo-Json -InputObject $launchRecord -Depth 6)
