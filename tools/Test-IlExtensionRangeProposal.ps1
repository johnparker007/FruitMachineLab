[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RomPath,
    [string]$RepositoryRoot = '',
    [string]$OutputDirectory = '',
    [string]$PriorAuditSourceDirectory = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepositoryRoot 'artifacts/deepseek/il-extension-approval-28/checker'
}
$repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$outDir = (Resolve-Path -LiteralPath $OutputDirectory).Path
$log = New-Object System.Collections.Generic.List[string]
$checks = New-Object System.Collections.ArrayList
$script:failed = $false

$rangeStart = 0x1010
$rangeEnd = 0x13EF
$rangeLength = 0x03E0
$rangeSha1 = 'eee7e8ec3670c1fb218bb9839c01277394e00c09'
$rangeSha256 = '1a7a6a16a718aaf4221baa1f787612dd995aaa5b083cfb9409023ac6c0985c16'
$romLength = 65536
$romSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$romSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$opcodePatternOffsets = @('167D','227E','237C','2689','26DD','3667','36F0','43A3','60DA','8E38','96A0','96AC','96B8','96C4','96D3','B597','B74D','F150')
$opcodeBytes = @('8E','CE','BE','BD','7E','BF','B7','F7','FC','FD','FE','7F')
$approvalStatement = 'I confirm you are ok to use that range btw. It is a little larger, I just left I think 16 bytes each side for a safety head/tail.'
$expectedApprovalStatus = 'approved-reserved-not-allocated'

function Write-Log([string]$text) {
    $log.Add($text) | Out-Null
    Write-Output $text
}

function Add-Check([string]$id, [bool]$ok, [string]$detail) {
    $checks.Add([ordered]@{ id = $id; ok = $ok; detail = $detail }) | Out-Null
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Log ("{0} {1}: {2}" -f $tag, $id, $detail)
    if (-not $ok) { $script:failed = $true }
}

function Get-BytesHash([byte[]]$bytes, [string]$algorithm) {
    $h = [System.Security.Cryptography.HashAlgorithm]::Create($algorithm)
    try {
        return (($h.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $h.Dispose()
    }
}

function Get-RomHex([int]$start, [int]$length) {
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $length; $i++) {
        [void]$sb.Append($rom[$start + $i].ToString('x2'))
    }
    return $sb.ToString().ToUpperInvariant()
}

function Test-Overlap([int]$aStart, [int]$aEnd, [int]$bStart, [int]$bEnd) {
    return ($aStart -le $bEnd -and $bStart -le $aEnd)
}

function Get-RangeBytes([int]$start, [int]$end) {
    $length = $end - $start + 1
    $bytes = New-Object byte[] $length
    [Array]::Copy($rom, $start, $bytes, 0, $length)
    return $bytes
}

function Test-AllFill([byte[]]$bytes, [byte]$fill) {
    foreach ($b in $bytes) {
        if ($b -ne $fill) { return $false }
    }
    return $true
}

function Find-NativeAssemblyTokens([int]$start, [int]$end) {
    $results = New-Object System.Collections.ArrayList
    $dir = Join-Path $repo 'evidence/mpu4/native'
    Get-ChildItem -LiteralPath $dir -Filter '*.json' -File | ForEach-Object {
        $fileName = $_.Name
        $doc = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
        if ($null -ne $doc.assembly) {
            foreach ($line in ($doc.assembly -split "`r?`n")) {
                foreach ($m in [regex]::Matches($line, '\b[0-9A-Fa-f]{4}\b')) {
                    $value = [Convert]::ToInt32($m.Value, 16)
                    if ($value -ge $start -and $value -le $end) {
                        [void]$results.Add([ordered]@{
                            source = ('evidence/mpu4/native/' + $fileName)
                            containingFunction = [string]$doc.address
                            token = $m.Value.ToUpperInvariant()
                            line = $line
                            classification = 'native_assembly_token'
                        })
                    }
                }
            }
        }
    }
    return @($results.ToArray())
}

function Find-VmListingTokens([int]$start, [int]$end) {
    $results = New-Object System.Collections.ArrayList
    $dir = Join-Path $repo 'evidence/mpu4/VM-SCRIPTS'
    Get-ChildItem -LiteralPath $dir -Filter '*.txt' -File | ForEach-Object {
        $fileName = $_.Name
        $lineNumber = 0
        foreach ($line in [System.IO.File]::ReadLines($_.FullName)) {
            $lineNumber++
            if ($line.Length -gt 400) { continue }
            foreach ($m in [regex]::Matches($line, '\b[0-9A-Fa-f]{4}\b')) {
                $value = [Convert]::ToInt32($m.Value, 16)
                if ($value -ge $start -and $value -le $end) {
                    [void]$results.Add([ordered]@{
                        source = ('evidence/mpu4/VM-SCRIPTS/' + $fileName)
                        lineNumber = $lineNumber
                        token = $m.Value.ToUpperInvariant()
                        line = $line.Trim()
                        classification = 'vm_listing_token'
                    })
                }
            }
        }
    }
    return @($results.ToArray())
}

function Find-OpcodeAdjacentPatterns([int]$start, [int]$end) {
    $opcodes = @(0x8E, 0xCE, 0xBE, 0xBD, 0x7E, 0xBF, 0xB7, 0xF7, 0xFC, 0xFD, 0xFE, 0x7F)
    $results = New-Object System.Collections.ArrayList
    for ($i = 0x1000; $i -lt 0xFFFE; $i++) {
        if ($opcodes -contains [int]$rom[$i]) {
            $value = (([int]$rom[$i + 1]) -shl 8) -bor [int]$rom[$i + 2]
            if ($value -ge $start -and $value -le $end) {
                [void]$results.Add([ordered]@{
                    offset = ('{0:X4}' -f $i)
                    opcode = ('{0:X2}' -f $rom[$i])
                    operand = ('{0:X4}' -f $value)
                    context = (Get-RomHex ([Math]::Max(0x1000, $i - 4)) 12)
                    classification = 'unresolved_opcode_adjacent_pattern_not_a_decoded_reference'
                })
            }
        }
    }
    return @($results.ToArray())
}

function Get-ProposalErrors($doc) {
    $e = New-Object System.Collections.ArrayList
    if ($null -eq $doc) {
        [void]$e.Add('document:null')
        return @($e.ToArray())
    }
    if ([string]$doc.schemaVersion -ne '2') { [void]$e.Add('document:schemaVersion') }
    if ([string]$doc.taskId -ne 'il-extension-approval-28') { [void]$e.Add('document:taskId') }
    if ([string]$doc.supersedesTaskId -ne 'il-extension-range-26') { [void]$e.Add('document:supersedesTaskId') }
    if ([string]$doc.status -ne $expectedApprovalStatus) {
        [void]$e.Add('status:expected approved-reserved-not-allocated')
    }
    if ([string]$doc.rom.length -ne '65536') { [void]$e.Add('status:rom-length') }
    if ([string]$doc.rom.sha1 -ne $romSha1) { [void]$e.Add('status:rom-sha1') }
    if ([string]$doc.rom.sha256 -ne $romSha256) { [void]$e.Add('status:rom-sha256') }

    $p = $doc.proposal
    if ([string]$p.id -ne 'P1-1010-13EF') { [void]$e.Add('range:id') }
    if ([string]$p.cpuStart -ne '1010') { [void]$e.Add('range:cpuStart') }
    if ([string]$p.cpuEnd -ne '13EF') { [void]$e.Add('range:cpuEnd') }
    if ([int]$p.fileStart -ne 4112) { [void]$e.Add('range:fileStart') }
    if ([int]$p.fileEnd -ne 5103) { [void]$e.Add('range:fileEnd') }
    if ([int]$p.length -ne 992) { [void]$e.Add('range:length') }
    if ([string]$p.lengthHex -ne '03E0') { [void]$e.Add('range:lengthHex') }
    if ([string]$p.expectedFill -ne 'FF') { [void]$e.Add('range:expectedFill') }
    if ([string]$p.expectedSha1 -ne $rangeSha1) { [void]$e.Add('range:expectedSha1') }
    if ([string]$p.expectedSha256 -ne $rangeSha256) { [void]$e.Add('range:expectedSha256') }

    $a = $doc.approval
    if ($null -eq $a) {
        [void]$e.Add('approval:missing')
    }
    else {
        if ([string]$a.status -ne $expectedApprovalStatus) { [void]$e.Add('approval:status') }
        if ([string]$a.approvedBy -ne 'John') { [void]$e.Add('approval:approvedBy') }
        if ([string]$a.approvedOn -ne '2026-10-18') { [void]$e.Add('approval:approvedOn') }
        if ([string]$a.approvalStatement -ne $approvalStatement) { [void]$e.Add('approval:statement') }
        if ([string]::IsNullOrWhiteSpace([string]$a.approvalSource)) { [void]$e.Add('approval:source') }
        if ([string]::IsNullOrWhiteSpace([string]$a.approvalScope)) { [void]$e.Add('approval:scope') }
        if ([string]$a.revision.set -ne 'm4addr') { [void]$e.Add('approval:revision-set') }
        if ([string]$a.revision.file -ne 'a6ls.p1') { [void]$e.Add('approval:revision-file') }
        if ([string]$a.revision.length -ne '65536') { [void]$e.Add('approval:revision-length') }
        if ([string]$a.revision.sha1 -ne $romSha1) { [void]$e.Add('approval:revision-sha1') }
        if ([string]$a.revision.sha256 -ne $romSha256) { [void]$e.Add('approval:revision-sha256') }
        if ([string]$a.range.cpuStart -ne '1010') { [void]$e.Add('approval:range-start') }
        if ([string]$a.range.cpuEnd -ne '13EF') { [void]$e.Add('approval:range-end') }
        if ([int]$a.range.length -ne 992) { [void]$e.Add('approval:range-length') }
        if ([string]$a.range.lengthHex -ne '03E0') { [void]$e.Add('approval:range-lengthHex') }
        if ([string]$a.guards.left -ne '1000-100F') { [void]$e.Add('approval:guard-left') }
        if ([string]$a.guards.right -ne '13F0-13FF') { [void]$e.Add('approval:guard-right') }
        if ([string]$a.guards.protectedCells -ne '1000-1003') { [void]$e.Add('approval:guard-protected-cells') }
        if ([string]$a.guards.integrityStart -ne '1400') { [void]$e.Add('approval:guard-integrity-start') }
        if (-not [bool]$a.boundedDevelopmentCovered) { [void]$e.Add('approval:bounded-development-not-covered') }
        if ([bool]$a.separateApprovalForBoundedDevelopment) { [void]$e.Add('approval:invented-separate-approval') }
        if ([bool]$a.linkerOrAllocatorImplementationClaimed) { [void]$e.Add('approval:implementation-overclaim') }
        if ([bool]$a.allocationPerformed) { [void]$e.Add('approval:allocation-overclaim') }
        if ([bool]$a.romWritten) { [void]$e.Add('approval:rom-write-overclaim') }
        if ([bool]$a.compiled) { [void]$e.Add('approval:compile-overclaim') }
        if ([bool]$a.linked) { [void]$e.Add('approval:link-overclaim') }
        if ([bool]$a.bootedByUs) { [void]$e.Add('approval:boot-overclaim') }
        if ([bool]$a.naturalExecutionObservedByUs) { [void]$e.Add('approval:execution-overclaim') }
        if ([bool]$a.hardwareValidated) { [void]$e.Add('approval:hardware-overclaim') }

        if (([string]$a.revision.sha1 -ne [string]$doc.rom.sha1) -or
            ([string]$a.revision.sha256 -ne [string]$doc.rom.sha256) -or
            ([string]$a.revision.length -ne [string]$doc.rom.length)) {
            [void]$e.Add('approval:revision-binding-mismatch')
        }
        if (([string]$a.range.cpuStart -ne [string]$p.cpuStart) -or
            ([string]$a.range.cpuEnd -ne [string]$p.cpuEnd) -or
            ([int]$a.range.length -ne [int]$p.length)) {
            [void]$e.Add('approval:range-binding-mismatch')
        }
        $expectedProtectedCells = [string]$p.guards.left.protectedSubrange.start + '-' + [string]$p.guards.left.protectedSubrange.end
        $expectedIntegrityStart = [string]$p.guards.right.nextStart.address
        if (([string]$a.guards.left -ne '1000-100F') -or
            ([string]$a.guards.right -ne '13F0-13FF') -or
            ([string]$a.guards.protectedCells -ne $expectedProtectedCells) -or
            ([string]$a.guards.integrityStart -ne $expectedIntegrityStart)) {
            [void]$e.Add('approval:guard-binding-mismatch')
        }
    }

    if ([string]$p.mapping.bank -ne '0') { [void]$e.Add('mapping:bank') }
    if ([string]$p.mapping.cpuWindow -ne '1000-FFFF') { [void]$e.Add('mapping:cpuWindow') }
    if ([string]$p.mapping.fileAddressRule -notmatch 'same file offsets') { [void]$e.Add('mapping:fileAddressRule') }
    if (-not [bool]$p.mapping.bank0Only) { [void]$e.Add('mapping:bank0Only') }
    if (-not [bool]$p.mapping.futureBankChangesRequireEvidence) { [void]$e.Add('mapping:futureBankChangesRequireEvidence') }
    $curatedMapping = @($p.mapping.evidence.curated)
    if (($curatedMapping -join ' ') -notmatch 'docs/recovery/README\.txt') { [void]$e.Add('mapping:curated-readme') }
    if (($curatedMapping -join ' ') -notmatch 'evidence/mpu4/maps/rom-layout\.json') { [void]$e.Add('mapping:curated-layout') }
    $priorMapping = $p.mapping.evidence.priorConclusion
    if ($null -eq $priorMapping) {
        [void]$e.Add('mapping:prior-conclusion-missing')
    }
    else {
        if ([string]$priorMapping.recordedBy -ne 'il-extension-audit-25') { [void]$e.Add('mapping:prior-recorded-by') }
        if ([string]::IsNullOrWhiteSpace([string]$priorMapping.statement)) { [void]$e.Add('mapping:prior-statement') }
        if ([bool]$priorMapping.reverifiedByThisChecker) { [void]$e.Add('mapping:prior-silently-reverified') }
        $sourceFiles = @($priorMapping.historicalSourceFiles)
        if ($sourceFiles.Count -ne 2) { [void]$e.Add('mapping:prior-source-file-count') }
        $expectedSourceHashes = @{
            'mpu4-mame0281.cpp' = '8efb9b50e48e49e274f60d3a63fe8611de74e96d316fe54c0b8ad0e3bf996d0f'
            'mpu4mod4yam-mame0281.cpp' = '7a3249fbde3e35490653c1a3568332988ff01e4a6019a8c44f2d437c49e36ac9'
        }
        foreach ($source in $sourceFiles) {
            $name = [string]$source.file
            if (-not $expectedSourceHashes.ContainsKey($name)) {
                [void]$e.Add('mapping:prior-source-unknown:' + $name)
            }
            elseif ([string]$source.sha256 -ne $expectedSourceHashes[$name]) {
                [void]$e.Add('mapping:prior-source-hash:' + $name)
            }
        }
    }

    if ([string]$p.guards.left.start -ne '1000') { [void]$e.Add('guard:left-start') }
    if ([string]$p.guards.left.end -ne '100F') { [void]$e.Add('guard:left-end') }
    if ([int]$p.guards.left.length -ne 16) { [void]$e.Add('guard:left-length') }
    if ([string]$p.guards.left.expectedHex -ne 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') { [void]$e.Add('guard:left-hex') }
    if ([string]$p.guards.left.protectedSubrange.start -ne '1000') { [void]$e.Add('guard:left-protected-start') }
    if ([string]$p.guards.left.protectedSubrange.end -ne '1003') { [void]$e.Add('guard:left-protected-end') }
    if ([string]$p.guards.left.protectedSubrange.expectedHex -ne 'FFFFFFFF') { [void]$e.Add('guard:left-protected-hex') }
    if ([string]$p.guards.right.start -ne '13F0') { [void]$e.Add('guard:right-start') }
    if ([string]$p.guards.right.end -ne '13FF') { [void]$e.Add('guard:right-end') }
    if ([int]$p.guards.right.length -ne 16) { [void]$e.Add('guard:right-length') }
    if ([string]$p.guards.right.expectedHex -ne 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') { [void]$e.Add('guard:right-hex') }
    if ([string]$p.guards.right.nextStart.address -ne '1400') { [void]$e.Add('guard:right-next-address') }
    if ([string]$p.guards.right.nextStart.expectedHex -ne '343631A9145D8E01') { [void]$e.Add('guard:right-next-hex') }

    if (-not [bool]$p.integrity.rangeOutsideActiveRecord) { [void]$e.Add('integrity:outside-active') }
    if ([string]$p.integrity.activeRecord.start -ne '1400') { [void]$e.Add('integrity:active-start') }
    if ([string]$p.integrity.activeRecord.end -ne 'FFFF') { [void]$e.Add('integrity:active-end') }
    if ([string]$p.integrity.activeRecord.gate -ne '00') { [void]$e.Add('integrity:active-gate') }
    if ([string]$p.integrity.activeRecord.errorCode -ne '12') { [void]$e.Add('integrity:active-error') }
    if ([string]$p.integrity.activeRecord.expectedHex -ne '3E761E2605') { [void]$e.Add('integrity:active-fields') }
    if ([string]$p.integrity.recordTable.base -ne 'FFB0') { [void]$e.Add('integrity:table-base') }
    if ([int]$p.integrity.recordTable.recordSize -ne 11) { [void]$e.Add('integrity:table-size') }
    if ([string]$p.integrity.recordTable.termination -ne 'FFDC') { [void]$e.Add('integrity:table-termination') }
    if ([string]$p.integrity.outerGate719B -ne '00') { [void]$e.Add('integrity:outer-gate') }
    if ([string]$p.integrity.fieldsOriginal -ne '3E761E2605') { [void]$e.Add('integrity:fields-original') }
    if (-not [bool]$p.integrity.loaderCrcShaWarningsSeparate) { [void]$e.Add('integrity:loader-warnings-separate') }
    if (-not [bool]$p.integrity.characteriserChecksSeparate) { [void]$e.Add('integrity:characteriser-separate') }
    if ([string]$p.vectors.reservedFFF0 -ne 'FE51') { [void]$e.Add('integrity:vector-reserved') }
    if ([string]$p.vectors.SWI3 -ne 'FE66') { [void]$e.Add('integrity:vector-swi3') }
    if ([string]$p.vectors.SWI2 -ne 'FE66') { [void]$e.Add('integrity:vector-swi2') }
    if ([string]$p.vectors.FIRQ -ne 'FE56') { [void]$e.Add('integrity:vector-firq') }
    if ([string]$p.vectors.IRQ -ne 'FE70') { [void]$e.Add('integrity:vector-irq') }
    if ([string]$p.vectors.SWI -ne '3620') { [void]$e.Add('integrity:vector-swi') }
    if ([string]$p.vectors.NMI -ne 'FE51') { [void]$e.Add('integrity:vector-nmi') }
    if ([string]$p.vectors.RESET -ne '7CCF') { [void]$e.Add('integrity:vector-reset') }

    if ([int]$p.knownReferenceChecks.decodedNativeReferences -ne 0) { [void]$e.Add('refs:native-count') }
    if ([int]$p.knownReferenceChecks.decodedVmListingReferences -ne 0) { [void]$e.Add('refs:vm-count') }
    if ([int]$p.knownReferenceChecks.opcodeAdjacentPatternCount -ne 18) { [void]$e.Add('refs:opcode-count') }
    $documentedOffsets = @($p.knownReferenceChecks.opcodeAdjacentPatternOffsets | ForEach-Object { [string]$_ })
    if (($documentedOffsets -join ',') -ne ($opcodePatternOffsets -join ',')) { [void]$e.Add('refs:opcode-offsets') }
    $patternDetails = @($p.knownReferenceChecks.opcodeAdjacentPatternDetails)
    if ($patternDetails.Count -ne 18) { [void]$e.Add('refs:opcode-detail-count') }
    $detailOffsets = @($patternDetails | ForEach-Object { [string]$_.offset })
    if (($detailOffsets -join ',') -ne ($opcodePatternOffsets -join ',')) { [void]$e.Add('refs:opcode-detail-offsets') }
    foreach ($detail in $patternDetails) {
        if ([string]$detail.opcode -notmatch '^[0-9A-F]{2}$') { [void]$e.Add('refs:opcode-detail-opcode:' + [string]$detail.offset) }
        if ([string]$detail.operand -notmatch '^[0-9A-F]{4}$') { [void]$e.Add('refs:opcode-detail-operand:' + [string]$detail.offset) }
        if ([string]$detail.classification -notmatch '^unresolved_') {
            [void]$e.Add('refs:opcode-detail-not-unresolved:' + [string]$detail.offset)
        }
        if ([string]::IsNullOrWhiteSpace([string]$detail.note)) { [void]$e.Add('refs:opcode-detail-note:' + [string]$detail.offset) }
    }
    $method = $p.knownReferenceChecks.opcodeAdjacentMethod
    if ($null -eq $method) {
        [void]$e.Add('refs:method-missing')
    }
    else {
        $methodOpcodes = @($method.opcodes | ForEach-Object { [string]$_ })
        if (($methodOpcodes -join ',') -ne ($opcodeBytes -join ',')) { [void]$e.Add('refs:method-opcodes') }
        if ([string]$method.scanStart -ne '1000') { [void]$e.Add('refs:method-scan-start') }
        if ([string]$method.scanEndExclusive -ne 'FFFE') { [void]$e.Add('refs:method-scan-end') }
        if (@($method.limitations).Count -lt 3) { [void]$e.Add('refs:method-limitations') }
    }
    if (@($p.knownReferenceChecks.referenceInventoryMethod.limitations).Count -lt 3) { [void]$e.Add('refs:inventory-limitations') }
    if (-not [bool]$p.knownReferenceChecks.inventoryIncomplete) { [void]$e.Add('refs:inventory-incomplete') }
    if (-not [bool]$p.knownReferenceChecks.absenceOfDecodedReferenceIsNotProof) { [void]$e.Add('refs:absence-not-proof') }

    if (-not [bool]$p.claims.rangeReservationApproved) { [void]$e.Add('claims:reservation-not-approved') }
    if (-not [bool]$p.claims.boundedDevelopmentPermittedByApproval) { [void]$e.Add('claims:bounded-development-not-permitted') }
    if ([bool]$p.claims.allocated) { [void]$e.Add('claims:allocated') }
    if ([bool]$p.claims.written) { [void]$e.Add('claims:written') }
    if ([bool]$p.claims.compiled) { [void]$e.Add('claims:compiled') }
    if ([bool]$p.claims.linked) { [void]$e.Add('claims:linked') }
    if ([bool]$p.claims.bootedByUs) { [void]$e.Add('claims:bootedByUs') }
    if ([bool]$p.claims.naturalExecutionObservedByUs) { [void]$e.Add('claims:naturalExecutionObservedByUs') }
    if ([bool]$p.claims.hardwareValidated) { [void]$e.Add('claims:hardwareValidated') }
    if ([bool]$p.claims.loaderIntegrityEvaluated) { [void]$e.Add('claims:loaderIntegrityEvaluated') }
    if ([bool]$p.claims.completeReferenceInventory) { [void]$e.Add('claims:completeReferenceInventory') }

    if ([bool]$p.scope.boundedAllocatorImplemented) { [void]$e.Add('scope:boundedAllocatorImplemented') }
    if ([bool]$p.scope.linkerImplemented) { [void]$e.Add('scope:linkerImplemented') }
    if ([bool]$p.scope.newVmWordsImplemented) { [void]$e.Add('scope:newVmWordsImplemented') }
    if ([bool]$p.scope.patchingPerformed) { [void]$e.Add('scope:patchingPerformed') }
    if ([bool]$p.scope.romWritesPerformed) { [void]$e.Add('scope:romWritesPerformed') }
    if ([bool]$p.scope.outputImageBuilt) { [void]$e.Add('scope:outputImageBuilt') }
    if ([bool]$p.scope.mameRunPerformed) { [void]$e.Add('scope:mameRunPerformed') }
    if ([bool]$p.scope.hardwareRunPerformed) { [void]$e.Add('scope:hardwareRunPerformed') }

    if ([string]$p.userReportedMfmeTest.reportedBy -ne 'John') { [void]$e.Add('usertest:reporter') }
    if ([bool]$p.userReportedMfmeTest.reproducedByWorker) { [void]$e.Add('usertest:overclaim-reproduced') }
    if ([bool]$p.userReportedMfmeTest.physicalHardwareProof) { [void]$e.Add('usertest:overclaim-hardware') }
    if ([string]$p.userReportedMfmeTest.evidenceClass -notmatch 'user-reported') { [void]$e.Add('usertest:class') }

    foreach ($key in @('humanApprovedReservation','staticVerified','curatedPriorConclusions','traceBacked','userReported','hypothesis','syntheticFaultExperiments','notEstablished')) {
        if ($null -eq $p.evidenceClasses.$key) { [void]$e.Add(('evidence:' + $key)) }
        elseif (@($p.evidenceClasses.$key).Count -eq 0) { [void]$e.Add(('evidence-empty:' + $key)) }
    }
    if ([string]::IsNullOrWhiteSpace([string]$p.approvalSummary)) { [void]$e.Add('review:approval-summary') }
    if ([string]::IsNullOrWhiteSpace([string]$p.nextBoundedTask)) { [void]$e.Add('review:next-bounded-task') }
    if (@($p.remainingRisks).Count -lt 5) { [void]$e.Add('review:risks') }

    $prior = $p.inputs.priorCandidate
    if ($null -eq $prior) {
        [void]$e.Add('prior:missing')
    }
    else {
        if ([string]$prior.id -ne 'C1') { [void]$e.Add('prior:id') }
        if ([string]$prior.cpuStart -ne '1004') { [void]$e.Add('prior:start') }
        if ([string]$prior.cpuEnd -ne '13FF') { [void]$e.Add('prior:end') }
        if ([int]$prior.length -ne 1020) { [void]$e.Add('prior:length') }
        if ([string]$prior.sha256 -ne 'd7e44f57783f8cc4890c29047cd04e1a50d7f8ab0b48fed2dc891c134430187a') { [void]$e.Add('prior:sha256') }
        if ([string]$prior.conclusion -notmatch 'not reverified') { [void]$e.Add('prior:conclusion') }
    }

    return @($e.ToArray())
}

function Get-ErrorsByPrefix($errors, [string]$prefix) {
    return @($errors | Where-Object { $_ -like ($prefix + '*') })
}

$romFile = (Resolve-Path -LiteralPath $RomPath).Path
$rom = [System.IO.File]::ReadAllBytes($romFile)
$sha1 = Get-BytesHash $rom 'SHA1'
$sha256 = Get-BytesHash $rom 'SHA256'

Add-Check 'input-length' ($rom.Length -eq $romLength) ("actual=" + $rom.Length + " expected=" + $romLength)
Add-Check 'input-sha1' ($sha1 -eq $romSha1) ("actual=" + $sha1)
Add-Check 'input-sha256' ($sha256 -eq $romSha256) ("actual=" + $sha256)
if ($script:failed) { throw 'Input ROM identity check failed.' }

$readmePath = Join-Path $repo 'docs/recovery/README.txt'
$readme = Get-Content -Raw -LiteralPath $readmePath
$layoutPath = Join-Path $repo 'evidence/mpu4/maps/rom-layout.json'
$layout = Get-Content -Raw -LiteralPath $layoutPath | ConvertFrom-Json
Add-Check 'mapping-readme-bank0' ($readme -match 'Runtime ROM bank 0: 1000-FFFF from matching offsets in the original file') 'docs/recovery/README.txt:58 (curated)'
Add-Check 'mapping-file-offset-equals-cpu' ([string]$layout.file_address_rule -match 'CPU ROM window 1000-FFFF uses same offsets') 'evidence/mpu4/maps/rom-layout.json file_address_rule (curated)'

$optionalSource = [ordered]@{
    requested = (-not [string]::IsNullOrWhiteSpace($PriorAuditSourceDirectory))
    status = 'not-requested'
    note = 'Normal validation uses tracked curated evidence only. Optional historical MAME source checks were not requested and were not treated as performed.'
    checks = @()
}
if (-not [string]::IsNullOrWhiteSpace($PriorAuditSourceDirectory)) {
    $sourceExists = Test-Path -LiteralPath $PriorAuditSourceDirectory -PathType Container
    Add-Check 'optional-prior-source-directory' $sourceExists ('explicit optional check; path=' + $PriorAuditSourceDirectory)
    $optionalSource.status = if ($sourceExists) { 'requested-present' } else { 'requested-missing' }
    if ($sourceExists) {
        $mpu4Path = Join-Path $PriorAuditSourceDirectory 'mpu4-mame0281.cpp'
        $yamPath = Join-Path $PriorAuditSourceDirectory 'mpu4mod4yam-mame0281.cpp'
        $mpu4Exists = Test-Path -LiteralPath $mpu4Path -PathType Leaf
        $yamExists = Test-Path -LiteralPath $yamPath -PathType Leaf
        $optionalSource.checks += [ordered]@{ id = 'optional-source-files'; ok = ($mpu4Exists -and $yamExists); detail = 'explicit optional check; mpu4-mame0281.cpp and mpu4mod4yam-mame0281.cpp' }
        Add-Check 'optional-prior-source-files' ($mpu4Exists -and $yamExists) 'explicit optional check; both historical source files present'
        if ($mpu4Exists -and $yamExists) {
            $mpu4Bytes = [System.IO.File]::ReadAllBytes($mpu4Path)
            $yamBytes = [System.IO.File]::ReadAllBytes($yamPath)
            $mpu4Source = [System.Text.Encoding]::UTF8.GetString($mpu4Bytes)
            $yamSource = [System.Text.Encoding]::UTF8.GetString($yamBytes)
            $mpu4Hash = Get-BytesHash $mpu4Bytes 'SHA256'
            $yamHash = Get-BytesHash $yamBytes 'SHA256'
            Add-Check 'optional-prior-source-mpu4-hash' ($mpu4Hash -eq '8efb9b50e48e49e274f60d3a63fe8611de74e96d316fe54c0b8ad0e3bf996d0f') ('explicit optional check; actual=' + $mpu4Hash)
            Add-Check 'optional-prior-source-yam-hash' ($yamHash -eq '7a3249fbde3e35490653c1a3568332988ff01e4a6019a8c44f2d437c49e36ac9') ('explicit optional check; actual=' + $yamHash)
            Add-Check 'optional-mapping-mame-memmap' ($mpu4Source -match 'map\(0x1000, 0xffff\)\.bankr\("bank1"\)') 'explicit optional check; MAME 0.281 mpu4_memmap maps 1000-FFFF bankr(bank1)'
            Add-Check 'optional-mapping-mame-nonextended-banks' ($mpu4Source -match 'configure_entries\(0, 4, &rom\[0x01000\], 0x10000\)') 'explicit optional check; MAME 0.281 setup_rom_banks, non-extended 64 KiB image'
            Add-Check 'optional-mapping-m4addr-init-m4' (($yamSource -match 'GAME_CUSTOM\( 1991, m4addr,') -and ($yamSource -match 'init_m4') -and ($yamSource -match 'a6ls\.p1') -and ($yamSource -match '402d1518bb78fdc489b06c2aabc771e5ce151847')) 'explicit optional check; MAME 0.281 m4addr uses init_m4 and a6ls.p1 SHA1'
            $optionalSource.checks += [ordered]@{ id = 'optional-source-content'; ok = $true; detail = 'explicit optional source content checks completed; not part of normal clean-checkout validation' }
        }
    }
}
else {
    Add-Check 'optional-prior-source-not-requested' $true 'not requested; no private artifact dependency and no silent re-verification claim'
}

$integrityPath = Join-Path $repo 'evidence/mpu4/maps/rom-integrity.json'
$integrity = Get-Content -Raw -LiteralPath $integrityPath | ConvertFrom-Json
$activeRecords = @($integrity.records | Where-Object { $_.enabled -eq $true })
Add-Check 'integrity-one-active-record' ($activeRecords.Count -eq 1) ("active records=" + $activeRecords.Count)
$active = $activeRecords[0]
Add-Check 'integrity-active-range' (([string]$active.start -eq '1400') -and ([string]$active.end -eq 'FFFF')) ("start=" + $active.start + " end=" + $active.end)
Add-Check 'integrity-active-gate' (([string]$active.gate -eq '00') -and ([string]$active.error_code -eq '12')) ("gate=" + $active.gate + " error=" + $active.error_code)
Add-Check 'integrity-table-base' (([string]$integrity.table.base -eq 'FFB0') -and ([int]$integrity.table.record_size -eq 11) -and ([string]$integrity.table.termination -eq 'FFDC')) 'evidence/mpu4/maps/rom-integrity.json'
Add-Check 'integrity-active-fields-original' ((Get-RomHex 0xFFD1 5) -eq '3E761E2605') ("FFD1-FFD5=" + (Get-RomHex 0xFFD1 5))
Add-Check 'integrity-outer-gate' (($rom[0x719B] -band 0x02) -eq 0) ("719B=" + $rom[0x719B].ToString('x2') + " bit1 clear")

$vectors = [ordered]@{
    'FFF2' = 'FE66'
    'FFF4' = 'FE66'
    'FFF6' = 'FE56'
    'FFF8' = 'FE70'
    'FFFA' = '3620'
    'FFFC' = 'FE51'
    'FFFE' = '7CCF'
}
foreach ($key in $vectors.Keys) {
    $address = [Convert]::ToInt32($key, 16)
    $actual = Get-RomHex $address 2
    Add-Check ('vector-' + $key) ($actual -eq $vectors[$key]) ("actual=" + $actual + " expected=" + $vectors[$key])
}
$reservedFFF0 = Get-RomHex 0xFFF0 2
Add-Check 'vector-fff0-reserved-not-entry' ($reservedFFF0 -eq 'FE51') ("FFF0=" + $reservedFFF0 + " documented as reserved; not a CPU vector")
Add-Check 'reset-fallback-guard-719A' ($rom[0x719A] -eq 0x00) ("719A=" + $rom[0x719A].ToString('x2') + " makes FF20 path take the 7CF4 branch")
Add-Check 'irq-vector-guard' ((Get-RomHex 0xFFF8 2) -eq 'FE70') 'FFF8==FE70 makes the 7D26 alternate path dormant in the original'

$protectedRanges = @(
    [ordered]@{ id = 'vectors'; start = 0xFFF0; end = 0xFFFF; source = 'docs/recovery/README.txt:64-66' },
    [ordered]@{ id = 'integrity-table-and-metadata'; start = 0xFFB0; end = 0xFFDB; source = 'evidence/mpu4/maps/rom-integrity.json' },
    [ordered]@{ id = 'integrity-active-fields'; start = 0xFFD1; end = 0xFFD5; source = 'evidence/mpu4/maps/rom-integrity.json' },
    [ordered]@{ id = 'copyright-and-version-tail'; start = 0xFFDD; end = 0xFFEF; source = 'original ROM bytes' },
    [ordered]@{ id = 'reset-fallback-pointer-cells'; start = 0x1000; end = 0x1003; source = 'ROM reset bytes 7CEA/7CF4/7D26' },
    [ordered]@{ id = 'known-config-flag-block'; start = 0xFF30; end = 0xFF50; source = 'docs/recovery/BRANCH-PREREQUISITES.txt; evidence/mpu4/maps/nudge-encoding-checkpoint.json' },
    [ordered]@{ id = 'reset-pointer-and-identity-area'; start = 0xFF20; end = 0xFF2F; source = 'docs/recovery/DEEP-ANALYSIS.txt' }
)

$rangeBytes = Get-RangeBytes $rangeStart $rangeEnd
$computedRangeSha1 = Get-BytesHash $rangeBytes 'SHA1'
$computedRangeSha256 = Get-BytesHash $rangeBytes 'SHA256'
Add-Check 'exact-range-start' ($rangeStart -eq 0x1010) '1010'
Add-Check 'exact-range-end' ($rangeEnd -eq 0x13EF) '13EF'
Add-Check 'exact-range-length' (($rangeEnd - $rangeStart + 1) -eq $rangeLength) ("actual=" + ($rangeEnd - $rangeStart + 1) + " expected=" + $rangeLength + " hex=03E0")
Add-Check 'exact-range-file-offsets' (($rangeStart -eq 4112) -and ($rangeEnd -eq 5103)) 'file offsets 4112-5103'
Add-Check 'exact-range-expected-bytes' (Test-AllFill $rangeBytes 0xFF) 'all bytes FF'
Add-Check 'exact-range-sha1' ($computedRangeSha1 -eq $rangeSha1) ("actual=" + $computedRangeSha1)
Add-Check 'exact-range-sha256' ($computedRangeSha256 -eq $rangeSha256) ("actual=" + $computedRangeSha256)

$rangeOverlaps = New-Object System.Collections.ArrayList
foreach ($p in $protectedRanges) {
    if (Test-Overlap $rangeStart $rangeEnd $p.start $p.end) {
        [void]$rangeOverlaps.Add([ordered]@{ id = $p.id; start = ('{0:X4}' -f $p.start); end = ('{0:X4}' -f $p.end) })
    }
}
Add-Check 'exact-range-no-protected-overlap' ($rangeOverlaps.Count -eq 0) ("overlaps=" + $rangeOverlaps.Count)

$rangeIntegrityRecords = New-Object System.Collections.ArrayList
foreach ($record in $integrity.records) {
    $rs = [Convert]::ToInt32([string]$record.start, 16)
    $re = [Convert]::ToInt32([string]$record.end, 16)
    if (Test-Overlap $rangeStart $rangeEnd $rs $re) {
        [void]$rangeIntegrityRecords.Add([ordered]@{
            base = [string]$record.base
            start = [string]$record.start
            end = [string]$record.end
            gate = [string]$record.gate
            enabled = [bool]$record.enabled
        })
    }
}
Add-Check 'exact-range-outside-integrity-records' ($rangeIntegrityRecords.Count -eq 0) ("overlapping records=" + $rangeIntegrityRecords.Count)
Add-Check 'exact-range-before-active-start' ($rangeEnd -lt [Convert]::ToInt32([string]$active.start, 16)) ("13EF < " + $active.start)

$leftGuard = Get-RangeBytes 0x1000 0x100F
$rightGuard = Get-RangeBytes 0x13F0 0x13FF
$protectedCells = Get-RangeBytes 0x1000 0x1003
Add-Check 'guard-left-expected-bytes' ((Test-AllFill $leftGuard 0xFF) -and ($leftGuard.Length -eq 16)) '1000-100F all FF length 16'
Add-Check 'guard-left-protected-cells' ((Test-AllFill $protectedCells 0xFF) -and ((Get-RomHex 0x1000 4) -eq 'FFFFFFFF')) '1000-1003 all FF (dormant reset fallback pointer cells)'
Add-Check 'guard-right-expected-bytes' ((Test-AllFill $rightGuard 0xFF) -and ($rightGuard.Length -eq 16)) '13F0-13FF all FF length 16'
Add-Check 'guard-right-next-start' ((Get-RomHex 0x1400 8) -eq '343631A9145D8E01') ("1400-1407=" + (Get-RomHex 0x1400 8))
Add-Check 'guard-left-no-overlap' (-not (Test-Overlap 0x1000 0x100F $rangeStart $rangeEnd)) 'left guard ends before approved range'
Add-Check 'guard-right-no-overlap' (-not (Test-Overlap 0x13F0 0x13FF $rangeStart $rangeEnd)) 'right guard starts after approved range'

$nativeRefs = Find-NativeAssemblyTokens $rangeStart $rangeEnd
$vmRefs = Find-VmListingTokens $rangeStart $rangeEnd
$opcodePatterns = Find-OpcodeAdjacentPatterns $rangeStart $rangeEnd
$computedPatternOffsets = @($opcodePatterns | ForEach-Object { [string]$_.offset })
Add-Check 'known-native-reference-count' ($nativeRefs.Count -eq 0) ("curated textual native assembly matches=" + $nativeRefs.Count)
Add-Check 'known-vm-reference-count' ($vmRefs.Count -eq 0) ("curated textual VM listing matches=" + $vmRefs.Count)
Add-Check 'opcode-adjacent-pattern-count' ($opcodePatterns.Count -eq 18) ("actual=" + $opcodePatterns.Count + " expected=18")
Add-Check 'opcode-adjacent-pattern-offsets' (($computedPatternOffsets -join ',') -eq ($opcodePatternOffsets -join ',')) ("actual=" + ($computedPatternOffsets -join ','))
Add-Check 'opcode-patterns-classified-unresolved' (@($opcodePatterns | Where-Object { $_.classification -ne 'unresolved_opcode_adjacent_pattern_not_a_decoded_reference' }).Count -eq 0) 'all patterns are unresolved heuristic, not decoded references'

$proposalPath = Join-Path $repo 'evidence/mpu4/integrity/il-extension-range-proposal.json'
$proposalExists = Test-Path -LiteralPath $proposalPath -PathType Leaf
Add-Check 'proposal-file-exists' $proposalExists $proposalPath
$proposal = $null
$proposalSha256 = ''
$proposalErrors = @()
$proposalStatus = $null
$approvalStatus = $null
if ($proposalExists) {
    $proposalBytes = [System.IO.File]::ReadAllBytes($proposalPath)
    $proposalSha256 = Get-BytesHash $proposalBytes 'SHA256'
    $proposal = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $proposalStatus = [string]$proposal.status
    if ($null -ne $proposal.approval) { $approvalStatus = [string]$proposal.approval.status }
    $proposalErrors = @(Get-ProposalErrors $proposal)
}
Add-Check 'proposal-status' ((Get-ErrorsByPrefix $proposalErrors 'status:').Count -eq 0) 'approved-reserved-not-allocated with exact ROM identity'
Add-Check 'proposal-approval-record' ((Get-ErrorsByPrefix $proposalErrors 'approval:').Count -eq 0) 'John quote/date/revision/range/guards bound; no invented separate approval or overclaim'
Add-Check 'proposal-range' ((Get-ErrorsByPrefix $proposalErrors 'range:').Count -eq 0) ('1010-13EF length=992 sha1=' + $rangeSha1)
Add-Check 'proposal-mapping' ((Get-ErrorsByPrefix $proposalErrors 'mapping:').Count -eq 0) 'bank 0 / same file offsets / curated evidence / prior MAME conclusion labeled not reverified'
Add-Check 'proposal-guards' ((Get-ErrorsByPrefix $proposalErrors 'guard:').Count -eq 0) '1000-100F and 13F0-13FF all FF; 1400 start'
Add-Check 'proposal-integrity' ((Get-ErrorsByPrefix $proposalErrors 'integrity:').Count -eq 0) 'outside active 1400-FFFF; table/fields/vectors unchanged'
Add-Check 'proposal-known-references' ((Get-ErrorsByPrefix $proposalErrors 'refs:').Count -eq 0) '0 native, 0 VM, 18 unresolved opcode-adjacent details and method limits'
Add-Check 'proposal-claims' ((Get-ErrorsByPrefix $proposalErrors 'claims:').Count -eq 0) 'reservation approved; no allocated/written/compiled/linked/booted/hardware claim'
Add-Check 'proposal-scope' ((Get-ErrorsByPrefix $proposalErrors 'scope:').Count -eq 0) 'no allocator/linker/emitter/ROM write/output/MAME claim'
Add-Check 'proposal-prior-candidate' ((Get-ErrorsByPrefix $proposalErrors 'prior:').Count -eq 0) 'historical C1 1004-13FF relation recorded as curated and not reverified'
Add-Check 'proposal-user-test' ((Get-ErrorsByPrefix $proposalErrors 'usertest:').Count -eq 0) 'John-reported MFME observation; not reproduced, not hardware proof'
Add-Check 'proposal-evidence-classes' (((Get-ErrorsByPrefix $proposalErrors 'evidence:').Count -eq 0) -and ((Get-ErrorsByPrefix $proposalErrors 'evidence-empty:').Count -eq 0)) 'human approval, static, curated prior, trace-backed, user-reported, hypothesis, synthetic, not established'
Add-Check 'proposal-review-summary' ((Get-ErrorsByPrefix $proposalErrors 'review:').Count -eq 0) 'approval summary, next bounded task and risks present'
Add-Check 'proposal-json-consistent' ($proposalErrors.Count -eq 0) ("errors=" + $proposalErrors.Count + " sha256=" + $proposalSha256)

if ($proposalExists) {
    $computedPatternMap = @{}
    foreach ($pattern in $opcodePatterns) { $computedPatternMap[[string]$pattern.offset] = $pattern }
    $detailMismatches = New-Object System.Collections.ArrayList
    $detailNotUnresolved = New-Object System.Collections.ArrayList
    foreach ($detail in @($proposal.proposal.knownReferenceChecks.opcodeAdjacentPatternDetails)) {
        $offset = [string]$detail.offset
        $actual = $computedPatternMap[$offset]
        if ($null -eq $actual) {
            [void]$detailMismatches.Add($offset + ':missing-on-rom')
        }
        else {
            if (([string]$detail.opcode -ne [string]$actual.opcode) -or ([string]$detail.operand -ne [string]$actual.operand)) {
                [void]$detailMismatches.Add($offset + ':opcode-or-operand')
            }
        }
        if ([string]$detail.classification -notmatch '^unresolved_') { [void]$detailNotUnresolved.Add($offset) }
    }
    Add-Check 'opcode-pattern-details-match-rom' ($detailMismatches.Count -eq 0) ("mismatches=" + ($detailMismatches -join ','))
    Add-Check 'opcode-pattern-details-all-unresolved' ($detailNotUnresolved.Count -eq 0) ("non-unresolved=" + ($detailNotUnresolved -join ','))

    $priorC1 = $proposal.proposal.inputs.priorCandidate
    $priorC1Ok = (($null -ne $priorC1) -and
        ([string]$priorC1.cpuStart -eq '1004') -and
        ([string]$priorC1.cpuEnd -eq '13FF') -and
        ([int]$priorC1.length -eq 1020) -and
        ([string]$priorC1.sha256 -eq 'd7e44f57783f8cc4890c29047cd04e1a50d7f8ab0b48fed2dc891c134430187a') -and
        ($rangeStart -ge 0x1004) -and ($rangeEnd -le 0x13FF))
    Add-Check 'prior-c1-curated-record' $priorC1Ok 'historical C1 1004-13FF is a recorded superset; not re-audited from private artifacts'
}
else {
    Add-Check 'opcode-pattern-details-match-rom' $false 'proposal unavailable'
    Add-Check 'opcode-pattern-details-all-unresolved' $false 'proposal unavailable'
    Add-Check 'prior-c1-curated-record' $false 'proposal unavailable'
}

function Add-NegativeRangeControl([string]$id, [int]$start, [int]$end, [string]$reason) {
    $expectedLength = $end - $start + 1
    $exact = (($start -eq $rangeStart) -and ($end -eq $rangeEnd) -and ($expectedLength -eq $rangeLength))
    $bounds = (($start -ge 0x1000) -and ($end -le 0xFFFF))
    $overlaps = New-Object System.Collections.ArrayList
    foreach ($p in $protectedRanges) {
        if (Test-Overlap $start $end $p.start $p.end) { [void]$overlaps.Add($p.id) }
    }
    $covered = $false
    foreach ($record in $integrity.records) {
        $rs = [Convert]::ToInt32([string]$record.start, 16)
        $re = [Convert]::ToInt32([string]$record.end, 16)
        if (Test-Overlap $start $end $rs $re) { $covered = $true; break }
    }
    $rejected = (-not ($exact -and $bounds -and ($expectedLength -eq $rangeLength) -and ($overlaps.Count -eq 0) -and (-not $covered)))
    Add-Check $id $rejected ("{0:X4}-{1:X4}; reason={2}; exact={3}; bounds={4}; length={5}; protected={6}; integrity={7}" -f $start, $end, $reason, $exact, $bounds, $expectedLength, ($overlaps -join ','), $covered)
    [void]$negativeControls.Add([ordered]@{
        id = $id
        proposedRange = ('{0:X4}-{1:X4}' -f $start, $end)
        expected = 'reject'
        rejected = $rejected
        reason = $reason
    })
}

$negativeControls = New-Object System.Collections.ArrayList
Add-NegativeRangeControl 'negative-left-guard-overlap' 0x100F 0x13EF 'overlaps left guard 1000-100F'
Add-NegativeRangeControl 'negative-right-guard-overlap' 0x1010 0x13F0 'overlaps right guard 13F0-13FF'
Add-NegativeRangeControl 'negative-shifted-start' 0x1011 0x13F0 'not the exact approved range'
Add-NegativeRangeControl 'negative-wrong-length' 0x1010 0x13EE 'wrong inclusive length 991'
Add-NegativeRangeControl 'negative-protected-cells-overlap' 0x1000 0x13EF 'overlaps dormant reset fallback pointer cells 1000-1003'
Add-NegativeRangeControl 'negative-integrity-start-overlap' 0x1010 0x1400 'overlaps active integrity start 1400'
Add-NegativeRangeControl 'negative-vector-overlap' 0xFFF0 0xFFFF 'overlaps CPU vector table'
Add-NegativeRangeControl 'negative-integrity-table-overlap' 0xFFB0 0xFFDB 'overlaps firmware integrity record table/metadata'
Add-NegativeRangeControl 'negative-active-field-overlap' 0xFFD1 0xFFD5 'overlaps active checksum fields'
Add-NegativeRangeControl 'negative-out-of-bounds-high' 0xFFF0 0x1000F 'end exceeds 16-bit CPU image'
Add-NegativeRangeControl 'negative-out-of-bounds-low' 0x0FF0 0x1010 'start below mapped ROM window 1000'
Add-NegativeRangeControl 'negative-naive-config-flag-overlap' 0xFF48 0xFF9F 'naive padding run overlaps known config flags'
Add-NegativeRangeControl 'negative-naive-reset-pointer-overlap' 0x1000 0x13FF 'naive large run overlaps dormant reset fallback pointer cells'

$tampered = [byte[]]$rangeBytes.Clone()
$tampered[0] = $tampered[0] -bxor 0xFF
$tamperedSha256 = Get-BytesHash $tampered 'SHA256'
$tamperedRejected = (($tamperedSha256 -ne $rangeSha256) -and (-not (Test-AllFill $tampered 0xFF)))
Add-Check 'negative-expected-byte-mismatch' $tamperedRejected ("tampered byte SHA256=" + $tamperedSha256 + " expected=" + $rangeSha256)
[void]$negativeControls.Add([ordered]@{
    id = 'negative-expected-byte-mismatch'
    proposedRange = '1010-13EF'
    expected = 'reject'
    rejected = $tamperedRejected
    reason = 'single-byte tamper changes range hash and fails all-FF check'
})

if ($proposalExists) {
    $badStatus = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badStatus.status = 'proposed-awaiting-John-confirmation'
    $badStatusErrors = @(Get-ProposalErrors $badStatus)
    $badStatusRejected = ((Get-ErrorsByPrefix $badStatusErrors 'status:').Count -gt 0)
    Add-Check 'negative-proposal-status-pending' $badStatusRejected 'stale pending status is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-status-pending'; expected = 'reject'; rejected = $badStatusRejected; reason = 'stale pending status is rejected' })

    $badApprovalMissing = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalMissing.PSObject.Properties.Remove('approval')
    $badApprovalMissingErrors = @(Get-ProposalErrors $badApprovalMissing)
    $badApprovalMissingRejected = ((Get-ErrorsByPrefix $badApprovalMissingErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-missing' $badApprovalMissingRejected 'missing approval is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-missing'; expected = 'reject'; rejected = $badApprovalMissingRejected; reason = 'missing approval is rejected' })

    $badApprovalStatus = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalStatus.approval.status = 'pending'
    $badApprovalStatusErrors = @(Get-ProposalErrors $badApprovalStatus)
    $badApprovalStatusRejected = ((Get-ErrorsByPrefix $badApprovalStatusErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-status' $badApprovalStatusRejected 'approval status=pending is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-status'; expected = 'reject'; rejected = $badApprovalStatusRejected; reason = 'approval status=pending is rejected' })

    $badApprovalRevision = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalRevision.approval.revision.sha1 = ('0' * 40)
    $badApprovalRevisionErrors = @(Get-ProposalErrors $badApprovalRevision)
    $badApprovalRevisionRejected = ((Get-ErrorsByPrefix $badApprovalRevisionErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-revision-mismatch' $badApprovalRevisionRejected 'approval bound to a different ROM SHA1 is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-revision-mismatch'; expected = 'reject'; rejected = $badApprovalRevisionRejected; reason = 'approval bound to a different ROM SHA1 is rejected' })

    $badApprovalRange = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalRange.approval.range.cpuEnd = '13F0'
    $badApprovalRangeErrors = @(Get-ProposalErrors $badApprovalRange)
    $badApprovalRangeRejected = ((Get-ErrorsByPrefix $badApprovalRangeErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-range-mismatch' $badApprovalRangeRejected 'approval bound to a different range is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-range-mismatch'; expected = 'reject'; rejected = $badApprovalRangeRejected; reason = 'approval bound to a different range is rejected' })

    $badApprovalGuard = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalGuard.approval.guards.right = '13F1-13FF'
    $badApprovalGuardErrors = @(Get-ProposalErrors $badApprovalGuard)
    $badApprovalGuardRejected = ((Get-ErrorsByPrefix $badApprovalGuardErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-guard-mismatch' $badApprovalGuardRejected 'approval bound to different guards is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-guard-mismatch'; expected = 'reject'; rejected = $badApprovalGuardRejected; reason = 'approval bound to different guards is rejected' })

    $badApprovalDate = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalDate.approval.approvedOn = '2026-10-19'
    $badApprovalDateErrors = @(Get-ProposalErrors $badApprovalDate)
    $badApprovalDateRejected = ((Get-ErrorsByPrefix $badApprovalDateErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-date' $badApprovalDateRejected 'wrong approval date is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-date'; expected = 'reject'; rejected = $badApprovalDateRejected; reason = 'wrong approval date is rejected' })

    $badApprovalStatement = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalStatement.approval.approvalStatement = 'range approved'
    $badApprovalStatementErrors = @(Get-ProposalErrors $badApprovalStatement)
    $badApprovalStatementRejected = ((Get-ErrorsByPrefix $badApprovalStatementErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-statement' $badApprovalStatementRejected 'summarized/non-exact approval statement is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-statement'; expected = 'reject'; rejected = $badApprovalStatementRejected; reason = 'nonexact approval quotation is rejected' })

    $badSeparateApproval = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badSeparateApproval.approval.separateApprovalForBoundedDevelopment = $true
    $badSeparateApprovalErrors = @(Get-ProposalErrors $badSeparateApproval)
    $badSeparateApprovalRejected = ((Get-ErrorsByPrefix $badSeparateApprovalErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-invented-separate-approval' $badSeparateApprovalRejected 'invented separate linker authorization requirement is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-invented-separate-approval'; expected = 'reject'; rejected = $badSeparateApprovalRejected; reason = 'invented separate linker authorization requirement is rejected' })

    $badApprovalAllocation = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalAllocation.approval.allocationPerformed = $true
    $badApprovalAllocationErrors = @(Get-ProposalErrors $badApprovalAllocation)
    $badApprovalAllocationRejected = ((Get-ErrorsByPrefix $badApprovalAllocationErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-allocation-overclaim' $badApprovalAllocationRejected 'approval.allocationPerformed=true is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-allocation-overclaim'; expected = 'reject'; rejected = $badApprovalAllocationRejected; reason = 'approval allocation overclaim is rejected' })

    $badApprovalBoot = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalBoot.approval.bootedByUs = $true
    $badApprovalBootErrors = @(Get-ProposalErrors $badApprovalBoot)
    $badApprovalBootRejected = ((Get-ErrorsByPrefix $badApprovalBootErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-boot-overclaim' $badApprovalBootRejected 'approval.bootedByUs=true is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-boot-overclaim'; expected = 'reject'; rejected = $badApprovalBootRejected; reason = 'approval boot overclaim is rejected' })

    $badApprovalHardware = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badApprovalHardware.approval.hardwareValidated = $true
    $badApprovalHardwareErrors = @(Get-ProposalErrors $badApprovalHardware)
    $badApprovalHardwareRejected = ((Get-ErrorsByPrefix $badApprovalHardwareErrors 'approval:').Count -gt 0)
    Add-Check 'negative-approval-hardware-overclaim' $badApprovalHardwareRejected 'approval.hardwareValidated=true is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-approval-hardware-overclaim'; expected = 'reject'; rejected = $badApprovalHardwareRejected; reason = 'approval hardware overclaim is rejected' })

    $badRange = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badRange.proposal.cpuEnd = '13F0'
    $badRangeErrors = @(Get-ProposalErrors $badRange)
    $badRangeRejected = ((Get-ErrorsByPrefix $badRangeErrors 'range:').Count -gt 0)
    Add-Check 'negative-proposal-range-wrong' $badRangeRejected 'cpuEnd=13F0 is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-range-wrong'; expected = 'reject'; rejected = $badRangeRejected; reason = 'cpuEnd=13F0 is rejected' })

    $badHash = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badHash.proposal.expectedSha256 = ('0' * 64)
    $badHashErrors = @(Get-ProposalErrors $badHash)
    $badHashRejected = ((Get-ErrorsByPrefix $badHashErrors 'range:').Count -gt 0)
    Add-Check 'negative-proposal-hash-wrong' $badHashRejected 'zero range SHA256 is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-hash-wrong'; expected = 'reject'; rejected = $badHashRejected; reason = 'zero range SHA256 is rejected' })

    $badGuard = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badGuard.proposal.guards.right.expectedHex = ('0' * 32)
    $badGuardErrors = @(Get-ProposalErrors $badGuard)
    $badGuardRejected = ((Get-ErrorsByPrefix $badGuardErrors 'guard:').Count -gt 0)
    Add-Check 'negative-proposal-guard-wrong' $badGuardRejected 'right guard non-FF is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-guard-wrong'; expected = 'reject'; rejected = $badGuardRejected; reason = 'right guard non-FF is rejected' })

    $badIntegrity = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badIntegrity.proposal.integrity.rangeOutsideActiveRecord = $false
    $badIntegrityErrors = @(Get-ProposalErrors $badIntegrity)
    $badIntegrityRejected = ((Get-ErrorsByPrefix $badIntegrityErrors 'integrity:').Count -gt 0)
    Add-Check 'negative-proposal-integrity-wrong' $badIntegrityRejected 'rangeOutsideActiveRecord=false is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-integrity-wrong'; expected = 'reject'; rejected = $badIntegrityRejected; reason = 'rangeOutsideActiveRecord=false is rejected' })

    $badClaims = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badClaims.proposal.claims.allocated = $true
    $badClaimsErrors = @(Get-ProposalErrors $badClaims)
    $badClaimsRejected = ((Get-ErrorsByPrefix $badClaimsErrors 'claims:').Count -gt 0)
    Add-Check 'negative-proposal-claim-allocated' $badClaimsRejected 'claims.allocated=true is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-claim-allocated'; expected = 'reject'; rejected = $badClaimsRejected; reason = 'claims.allocated=true is rejected' })

    $badClaimsBoot = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badClaimsBoot.proposal.claims.bootedByUs = $true
    $badClaimsBootErrors = @(Get-ProposalErrors $badClaimsBoot)
    $badClaimsBootRejected = ((Get-ErrorsByPrefix $badClaimsBootErrors 'claims:').Count -gt 0)
    Add-Check 'negative-proposal-claim-booted' $badClaimsBootRejected 'claims.bootedByUs=true is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-claim-booted'; expected = 'reject'; rejected = $badClaimsBootRejected; reason = 'claims.bootedByUs=true is rejected' })

    $badClaimsHardware = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badClaimsHardware.proposal.claims.hardwareValidated = $true
    $badClaimsHardwareErrors = @(Get-ProposalErrors $badClaimsHardware)
    $badClaimsHardwareRejected = ((Get-ErrorsByPrefix $badClaimsHardwareErrors 'claims:').Count -gt 0)
    Add-Check 'negative-proposal-claim-hardware' $badClaimsHardwareRejected 'claims.hardwareValidated=true is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-claim-hardware'; expected = 'reject'; rejected = $badClaimsHardwareRejected; reason = 'claims.hardwareValidated=true is rejected' })

    $badUserTest = Get-Content -Raw -LiteralPath $proposalPath | ConvertFrom-Json
    $badUserTest.proposal.userReportedMfmeTest.reproducedByWorker = $true
    $badUserTestErrors = @(Get-ProposalErrors $badUserTest)
    $badUserTestRejected = ((Get-ErrorsByPrefix $badUserTestErrors 'usertest:').Count -gt 0)
    Add-Check 'negative-proposal-usertest-overclaim' $badUserTestRejected 'reproducedByWorker=true is rejected'
    [void]$negativeControls.Add([ordered]@{ id = 'negative-proposal-usertest-overclaim'; expected = 'reject'; rejected = $badUserTestRejected; reason = 'reproducedByWorker=true is rejected' })
}

$passCount = @($checks | Where-Object { $_.ok -eq $true }).Count
$failCount = @($checks | Where-Object { $_.ok -eq $false }).Count
Write-Log ''
Write-Log ("Checks: {0} PASS, {1} FAIL" -f $passCount, $failCount)
Write-Log ("Approved range: 1010-13EF length={0} sha1={1} sha256={2}" -f $rangeLength, $computedRangeSha1, $computedRangeSha256)
Write-Log ("Guards: 1000-100F={0} 13F0-13FF={1} 1400-1407={2}" -f (Get-RomHex 0x1000 16), (Get-RomHex 0x13F0 16), (Get-RomHex 0x1400 8))
Write-Log ("Approval: {0}; optional source checks: {1}" -f $approvalStatus, $optionalSource.status)

$resultPatternDetails = @()
$resultMethod = $null
if ($proposalExists) {
    $resultPatternDetails = @($proposal.proposal.knownReferenceChecks.opcodeAdjacentPatternDetails)
    $resultMethod = $proposal.proposal.knownReferenceChecks.opcodeAdjacentMethod
}

$result = [ordered]@{
    schemaVersion = 2
    taskId = 'il-extension-approval-28'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    status = if ($script:failed) { 'static-check-failed' } else { 'static-check-passed' }
    input = [ordered]@{
        path = $romFile
        length = $rom.Length
        sha1 = $sha1
        sha256 = $sha256
        requiredLength = $romLength
        requiredSha1 = $romSha1
        requiredSha256 = $romSha256
    }
    proposal = [ordered]@{
        path = 'evidence/mpu4/integrity/il-extension-range-proposal.json'
        sha256 = $proposalSha256
        status = $proposalStatus
        approvalStatus = $approvalStatus
        validationErrors = @($proposalErrors)
    }
    range = [ordered]@{
        cpuStart = '1010'
        cpuEnd = '13EF'
        fileStart = 4112
        fileEnd = 5103
        length = $rangeLength
        lengthHex = '03E0'
        expectedFill = 'FF'
        sha1 = $computedRangeSha1
        sha256 = $computedRangeSha256
        allExpectedFill = (Test-AllFill $rangeBytes 0xFF)
    }
    guards = [ordered]@{
        left = [ordered]@{ start = '1000'; end = '100F'; expectedHex = (Get-RomHex 0x1000 16); protectedCells = (Get-RomHex 0x1000 4) }
        right = [ordered]@{ start = '13F0'; end = '13FF'; expectedHex = (Get-RomHex 0x13F0 16); nextStart = (Get-RomHex 0x1400 8) }
    }
    approval = [ordered]@{
        status = $approvalStatus
        approvedBy = if ($null -ne $proposal.approval) { [string]$proposal.approval.approvedBy } else { $null }
        approvedOn = if ($null -ne $proposal.approval) { [string]$proposal.approval.approvedOn } else { $null }
        exactRange = '1010-13EF'
        guards = '1000-100F/13F0-13FF'
        boundedDevelopmentCovered = if ($null -ne $proposal.approval) { [bool]$proposal.approval.boundedDevelopmentCovered } else { $false }
        allocationPerformed = if ($null -ne $proposal.approval) { [bool]$proposal.approval.allocationPerformed } else { $false }
        bootedByUs = if ($null -ne $proposal.approval) { [bool]$proposal.approval.bootedByUs } else { $false }
        hardwareValidated = if ($null -ne $proposal.approval) { [bool]$proposal.approval.hardwareValidated } else { $false }
    }
    knownReferences = [ordered]@{
        decodedNativeReferenceCount = $nativeRefs.Count
        decodedVmListingReferenceCount = $vmRefs.Count
        opcodeAdjacentPatternCount = $opcodePatterns.Count
        opcodeAdjacentPatternOffsets = @($computedPatternOffsets)
        opcodeAdjacentPatternDetails = $resultPatternDetails
        method = $resultMethod
        classification = 'Unresolved heuristic only; not decoded native or VM references.'
    }
    evidenceScope = [ordered]@{
        reproducedFromInputRom = @(
            'ROM length, SHA1 and SHA256',
            'exact range bytes, fill and hashes',
            'left/right guard bytes and protected cells',
            'integrity active fields, table metadata values and outer gate bit',
            'CPU vector bytes',
            'the 18 opcode-adjacent offsets, opcodes and operands',
            'the zero-match curated native/VM textual scans'
        )
        curatedPriorConclusions = @(
            'MAME 0.281 memmap and setup_rom_banks conclusion with historical source hashes',
            'historical task 25 candidate C1 1004-13FF proper-superset relation',
            'incompleteness of the curated native/VM reference inventory'
        )
        notReverifiedHere = @(
            'MAME 0.281 source files were not downloaded or re-read',
            'the prior audit private candidate artifact was not used',
            'no complete disassembly or reference graph exists'
        )
        optionalSourceChecks = $optionalSource
    }
    negativeControls = @($negativeControls.ToArray())
    checks = @($checks.ToArray())
    summary = [ordered]@{ pass = $passCount; fail = $failCount }
    limitations = @(
        'Padding appearance alone is not proof of free space; human approval is a reservation decision.',
        'The reference inventory is incomplete; zero decoded matches is not a complete no-use proof.',
        'The 18 opcode-adjacent patterns are unresolved heuristics, not decoded references.',
        'The opcode scan does not decode instruction lengths, addressing modes or reachability.',
        'Bank-0 mapping is established only for this selected 64 KiB set.',
        'The MAME source conclusion is curated prior evidence, not reverified unless explicitly requested.',
        'The user-reported MFME observation was not reproduced and is not hardware proof.',
        'No ROM write, allocator, linker, emitter, MAME run or hardware test was performed.'
    )
}

$resultPath = Join-Path $outDir 'range-proposal-check.json'
[System.IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 16), (New-Object System.Text.UTF8Encoding($false)))
$logPath = Join-Path $outDir 'range-proposal-check.log'
[System.IO.File]::WriteAllLines($logPath, $log, (New-Object System.Text.UTF8Encoding($false)))

if ($script:failed) { exit 1 }
exit 0
