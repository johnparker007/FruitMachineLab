param(
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$PatchSpec,
    [Parameter(Mandatory=$true)][string]$UnrepairedOutput,
    [Parameter(Mandatory=$true)][string]$RepairedOutput,
    [string]$ReportPath,
    [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'

$ExpectedOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$ExpectedOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$ExpectedOriginalLength = 65536
$PatchOffset = 30141
$PatchExpectedHex = '000A1014162F3C'
$PatchReplacementHex = '000C1014162F3C'
$AwardChangedOffset = 30142
$FieldBase = 0xFFD1
$ExpectedOriginalFields = '3E761E2605'
$Start = 0x1400
$End = 0xFFFF

function Get-HashHex([byte[]]$Bytes, [string]$Algorithm) {
    $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
    try { return [BitConverter]::ToString($hash.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Get-DisplayPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\') + '\'
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($root.Length).Replace('\','/') }
    return $full.Replace('\','/')
}

function Get-FileHashHex([string]$Path, [string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Test-SamePath([string]$Left, [string]$Right) {
    return [string]::Equals($Left, $Right, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-SafeTargetPaths([string]$OriginalPath, [string]$SpecPath, [string]$UnrepairedPath, [string]$RepairedPath, [string]$ReportPath) {
    $targets = New-Object System.Collections.Generic.List[object]
    $targets.Add([pscustomobject]@{ Name = 'unrepaired output'; Path = $UnrepairedPath })
    $targets.Add([pscustomobject]@{ Name = 'repaired output'; Path = $RepairedPath })
    if (![string]::IsNullOrWhiteSpace($ReportPath)) { $targets.Add([pscustomobject]@{ Name = 'report'; Path = $ReportPath }) }

    foreach ($target in $targets) {
        $directory = [IO.Path]::GetDirectoryName($target.Path)
        if ([string]::IsNullOrEmpty($directory) -or ![IO.Directory]::Exists($directory)) { throw "$($target.Name) directory does not exist: $directory" }
    }
    foreach ($target in $targets) {
        if (Test-SamePath $target.Path $OriginalPath) { throw "$($target.Name) must not alias the original ROM" }
        if (Test-SamePath $target.Path $SpecPath) { throw "$($target.Name) must not alias the patch specification" }
    }
    foreach ($target in $targets) {
        if ([IO.File]::Exists($target.Path) -or [IO.Directory]::Exists($target.Path)) { throw "$($target.Name) already exists: $($target.Path)" }
    }
    for ($i = 0; $i -lt $targets.Count; $i++) {
        for ($j = $i + 1; $j -lt $targets.Count; $j++) {
            if (Test-SamePath $targets[$i].Path $targets[$j].Path) { throw "Target paths must be distinct: $($targets[$i].Name) and $($targets[$j].Name)" }
        }
    }
}

function Assert-PreflightRejected([string]$Label, [string]$ExpectedPattern, [string]$OriginalPath, [string]$SpecPath, [string]$UnrepairedPath, [string]$RepairedPath, [string]$ReportPath) {
    try {
        Assert-SafeTargetPaths $OriginalPath $SpecPath $UnrepairedPath $RepairedPath $ReportPath
        throw "Preflight unexpectedly accepted $Label"
    }
    catch {
        if ($_.Exception.Message -eq "Preflight unexpectedly accepted $Label") { throw }
        if ($_.Exception.Message -notmatch $ExpectedPattern) { throw "Preflight rejected $Label for the wrong reason: $($_.Exception.Message)" }
        Write-Output ("Negative control rejected $Label`: " + $_.Exception.Message)
    }
}

function Convert-HexToBytes([string]$Hex) {
    if (($Hex.Length % 2) -ne 0) { throw 'Hex text has odd length' }
    $bytes = New-Object byte[] ($Hex.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
    return ,$bytes
}

function Get-Hex([byte[]]$Bytes) {
    return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join '')
}

function Get-ChangedOffsets([byte[]]$Before, [byte[]]$After) {
    $changed = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $Before.Length; $i++) {
        if ($Before[$i] -ne $After[$i]) { $changed.Add($i) }
    }
    return $changed.ToArray()
}

function Invoke-SumXor([byte[]]$Bytes, [int]$RangeStart, [int]$RangeEnd) {
    [int]$sum = 0
    [int]$xor = 0
    [int]$p = $RangeStart
    while ($true) {
        [int]$v = $Bytes[$p]
        $sum = ($sum + $v) -band 0xFF
        $xor = $xor -bxor $v
        if ($p -eq $RangeEnd) { break }
        $p++
        if ($p -eq 0xFFD1) { $p = 0xFFD6 }
    }
    return @($sum, $xor)
}

function Invoke-RotateAdd([byte[]]$Bytes, [int]$RangeStart, [int]$RangeEnd) {
    [int]$a = 0
    [int]$b = 0
    [int]$c = 0
    [int]$p = $RangeStart
    while ($true) {
        [int]$v = $Bytes[$p]
        $n = ($b -shr 7) -band 1
        $b = (($b -shl 1) -bor $c) -band 0xFF
        $c = $n
        $t = $a + $v + $c
        $a = $t -band 0xFF
        $c = ($t -shr 8) -band 1
        $n = $b -band 1
        $b = (($c -shl 7) -bor ($b -shr 1)) -band 0xFF
        $c = $n
        if ($p -eq $RangeEnd) { break }
        $p++
        if ($p -eq 0xFFD3) { $p = 0xFFD6 }
        if ($p -lt 0xFFD3) { $c = 1 } else { $c = 0 }
    }
    return $a
}

function Invoke-RotateSubXor([byte[]]$Bytes, [int]$RangeStart, [int]$RangeEnd) {
    [int]$a = 0
    [int]$b = 0
    [int]$c = 0
    [int]$p = $RangeStart
    while ($true) {
        [int]$v = $Bytes[$p]
        $n = ($b -shr 7) -band 1
        $b = ($b -shl 1) -band 0xFF
        $c = $n
        $t = $b + $c
        $b = $t -band 0xFF
        $c = ($t -shr 8) -band 1
        $t = $b - $v
        $b = $t -band 0xFF
        if ($t -lt 0) { $c = 1 } else { $c = 0 }
        $savedB = $b
        $b = $a
        for ($i = 0; $i -lt 3; $i++) {
            $c = $b -band 1
            $b = (($b -shr 1) -bor ($b -band 0x80)) -band 0xFF
            $a = (($c -shl 7) -bor ($a -shr 1)) -band 0xFF
        }
        $b = $savedB
        $a = $a -bxor $v
        if ($p -eq $RangeEnd) { break }
        $p++
        if ($p -eq 0xFFD4) { $p = 0xFFD6 }
    }
    return @($a, $b)
}

function Assert-OriginalIdentity([byte[]]$Bytes) {
    if ($Bytes.Length -ne $ExpectedOriginalLength) { throw "Unexpected ROM length: $($Bytes.Length)" }
    $sha1 = Get-HashHex $Bytes 'SHA1'
    if ($sha1 -ne $ExpectedOriginalSha1) { throw "Unexpected original ROM identity: SHA1 $sha1" }
    $sha256 = Get-HashHex $Bytes 'SHA256'
    if ($sha256 -ne $ExpectedOriginalSha256) { throw "Unexpected original ROM SHA256: $sha256" }
}

function Assert-PatchSpec($Spec) {
    $specNames = @($Spec.PSObject.Properties.Name | Sort-Object)
    $requiredNames = @('Description','Edits','InputLength','InputSha1','SchemaVersion' | Sort-Object)
    if ((Compare-Object $specNames $requiredNames)) { throw 'Patch specification members differ from schema 1' }
    if ([int]$Spec.SchemaVersion -ne 1) { throw "Unsupported patch schema version: $($Spec.SchemaVersion)" }
    if ([int]$Spec.InputLength -ne $ExpectedOriginalLength) { throw "Patch input length is not $ExpectedOriginalLength" }
    if ([string]$Spec.InputSha1 -ine $ExpectedOriginalSha1) { throw 'Patch input SHA1 is not the accepted original' }
    if ([string]::IsNullOrWhiteSpace([string]$Spec.Description)) { throw 'Patch description is empty' }
    $edits = @($Spec.Edits)
    if ($edits.Count -ne 1) { throw "Expected exactly one edit, found $($edits.Count)" }
    $edit = $edits[0]
    $editNames = @($edit.PSObject.Properties.Name | Sort-Object)
    $requiredEditNames = @('ExpectedHex','Offset','Provenance','ReplacementHex' | Sort-Object)
    if ((Compare-Object $editNames $requiredEditNames)) { throw 'Patch edit members differ from schema 1' }
    if ([int]$edit.Offset -ne $PatchOffset) { throw "Patch offset is not the accepted shared award table: $($edit.Offset)" }
    if ([string]$edit.ExpectedHex -ine $PatchExpectedHex) { throw "Patch expected bytes are not $PatchExpectedHex" }
    if ([string]$edit.ReplacementHex -ine $PatchReplacementHex) { throw "Patch replacement bytes are not $PatchReplacementHex" }
    if ([string]::IsNullOrWhiteSpace([string]$edit.Provenance)) { throw 'Patch provenance is empty' }
    $expected = Convert-HexToBytes $PatchExpectedHex
    $replacement = Convert-HexToBytes $PatchReplacementHex
    if ($expected.Length -ne $replacement.Length) { throw 'Patch expected/replacement lengths differ' }
    $changedWithin = @(Get-ChangedOffsets $expected $replacement)
    if ($changedWithin.Count -ne 1 -or $changedWithin[0] -ne ($AwardChangedOffset - $PatchOffset)) {
        throw 'Patch does not make exactly the accepted one-byte award change'
    }
}

function Assert-ProtectedBytes([byte[]]$Candidate, [byte[]]$Original) {
    foreach ($range in @(@(0x66A5,0x674F),@(0x719B,0x719B),@(0xFFB0,0xFFD0),@(0xFFD6,0xFFDB))) {
        for ($i = $range[0]; $i -le $range[1]; $i++) {
            if ($Candidate[$i] -ne $Original[$i]) { throw ('Protected checker/code/gate/range byte changed at 0x{0:X4}' -f $i) }
        }
    }
}

function New-PatchedImage([byte[]]$Original, $Spec) {
    $image = [byte[]]$Original.Clone()
    $edit = @($Spec.Edits)[0]
    $expected = Convert-HexToBytes ([string]$edit.ExpectedHex)
    $replacement = Convert-HexToBytes ([string]$edit.ReplacementHex)
    $offset = [int]$edit.Offset
    for ($i = 0; $i -lt $expected.Length; $i++) {
        if ($image[$offset + $i] -ne $expected[$i]) { throw ('Original expected patch byte differs at 0x{0:X4}' -f ($offset + $i)) }
    }
    for ($i = 0; $i -lt $replacement.Length; $i++) { $image[$offset + $i] = $replacement[$i] }
    $changed = @(Get-ChangedOffsets $Original $image)
    if ($changed.Count -ne 1 -or $changed[0] -ne $AwardChangedOffset) { throw 'Patch changed unexpected file offsets' }
    if ($image[$AwardChangedOffset] -ne 0x0C) { throw 'Patched award byte is not 0C' }
    return ,$image
}

function New-RepairedImage([byte[]]$Patched) {
    $image = [byte[]]$Patched.Clone()
    $sumXor = Invoke-SumXor $image $Start $End
    $image[$FieldBase] = [byte]$sumXor[0]
    $image[$FieldBase + 1] = [byte]$sumXor[1]
    $rotateAdd = Invoke-RotateAdd $image $Start $End
    $image[$FieldBase + 2] = [byte]$rotateAdd
    $rotateSubXor = Invoke-RotateSubXor $image $Start $End
    $image[$FieldBase + 3] = [byte]$rotateSubXor[0]
    $image[$FieldBase + 4] = [byte]$rotateSubXor[1]
    return ,$image
}

function Get-StoredFields([byte[]]$Image) { return (Get-Hex $Image[$FieldBase..($FieldBase + 4)]) }

function Assert-Fields([byte[]]$Image, [string]$ExpectedHex) {
    $stored = Get-StoredFields $Image
    if ($stored -ne $ExpectedHex) { throw "Stored fields are $stored, expected $ExpectedHex" }
    $sumXor = Invoke-SumXor $Image $Start $End
    $rotateAdd = Invoke-RotateAdd $Image $Start $End
    $rotateSubXor = Invoke-RotateSubXor $Image $Start $End
    $computed = ('{0:X2}{1:X2}{2:X2}{3:X2}{4:X2}' -f $sumXor[0],$sumXor[1],$rotateAdd,$rotateSubXor[0],$rotateSubXor[1])
    if ($computed -ne $ExpectedHex) { throw "Computed fields are $computed, expected $ExpectedHex" }
    return $computed
}

function Write-CreateNew([string]$Path, [byte[]]$Bytes) {
    $full = [IO.Path]::GetFullPath($Path)
    if (![IO.Directory]::Exists([IO.Path]::GetDirectoryName($full))) { throw "Output directory does not exist: $([IO.Path]::GetDirectoryName($full))" }
    $stream = New-Object -TypeName System.IO.FileStream -ArgumentList @($full, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try { $stream.Write($Bytes, 0, $Bytes.Length) }
    finally { $stream.Dispose() }
    $readback = [IO.File]::ReadAllBytes($full)
    if ((Get-HashHex $readback 'SHA256') -ne (Get-HashHex $Bytes 'SHA256')) { throw "Output readback mismatch: $full" }
}

function Test-NegativeControls([byte[]]$Original, $Spec, [byte[]]$Patched, [byte[]]$Repaired) {
    $tampered = [byte[]]$Original.Clone()
    $tampered[0] = $tampered[0] -bxor 0xFF
    try { Assert-OriginalIdentity $tampered; throw 'Wrong identity was not rejected' }
    catch { if ($_.Exception.Message -eq 'Wrong identity was not rejected') { throw }; Write-Output ('Negative control rejected wrong identity: ' + $_.Exception.Message) }

    $badEdit = [pscustomobject]@{
        ExpectedHex = '000B1014162F3C'
        Offset = $Spec.Edits[0].Offset
        Provenance = $Spec.Edits[0].Provenance
        ReplacementHex = $Spec.Edits[0].ReplacementHex
    }
    $badSpec = [pscustomobject]@{
        Description = $Spec.Description
        Edits = @($badEdit)
        InputLength = $Spec.InputLength
        InputSha1 = $Spec.InputSha1
        SchemaVersion = $Spec.SchemaVersion
    }
    try { Assert-PatchSpec $badSpec; throw 'Wrong expected patch byte was not rejected' }
    catch { if ($_.Exception.Message -eq 'Wrong expected patch byte was not rejected') { throw }; Write-Output ('Negative control rejected wrong expected patch byte: ' + $_.Exception.Message) }

    $unrelated = [byte[]]$Patched.Clone()
    $unrelated[0x1400] = $unrelated[0x1400] -bxor 0x01
    $changed = @(Get-ChangedOffsets $Original $unrelated)
    if ($changed.Count -eq 1 -and $changed[0] -eq $AwardChangedOffset) { throw 'Unrelated-byte negative control was not detected' }
    Write-Output ('Negative control rejected unrelated byte change: offsets ' + ($changed -join ','))

    $gate = [byte[]]$Patched.Clone()
    $gate[0xFFDB] = $gate[0xFFDB] -bxor 0x01
    try { Assert-ProtectedBytes $gate $Original; throw 'Gate change was not rejected' }
    catch { if ($_.Exception.Message -eq 'Gate change was not rejected') { throw }; Write-Output ('Negative control rejected gate change: ' + $_.Exception.Message) }

    $code = [byte[]]$Patched.Clone()
    $code[0x66DB] = $code[0x66DB] -bxor 0x01
    try { Assert-ProtectedBytes $code $Original; throw 'Checker code change was not rejected' }
    catch { if ($_.Exception.Message -eq 'Checker code change was not rejected') { throw }; Write-Output ('Negative control rejected checker code change: ' + $_.Exception.Message) }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-review08-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    try {
        $existing = Join-Path $tempRoot 'existing.p1'
        [IO.File]::WriteAllBytes($existing, [byte[]](0))
        try { Write-CreateNew $existing $Repaired; throw 'Existing output was not rejected' }
        catch {
            if ($_.Exception.Message -eq 'Existing output was not rejected') { throw }
            $inner = $_.Exception
            while ($null -ne $inner.InnerException) { $inner = $inner.InnerException }
            if ($inner -isnot [IO.IOException]) { throw }
            Write-Output ('Negative control rejected existing output: ' + $inner.Message)
        }
    }
    finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }

    $wrongOrder = [byte[]]$Patched.Clone()
    $sumXor = Invoke-SumXor $wrongOrder $Start $End
    $earlyRotateAdd = Invoke-RotateAdd $wrongOrder $Start $End
    $earlyRotateSubXor = Invoke-RotateSubXor $wrongOrder $Start $End
    $wrongOrder[$FieldBase] = [byte]$sumXor[0]
    $wrongOrder[$FieldBase + 1] = [byte]$sumXor[1]
    $wrongOrder[$FieldBase + 2] = [byte]$earlyRotateAdd
    $wrongOrder[$FieldBase + 3] = [byte]$earlyRotateSubXor[0]
    $wrongOrder[$FieldBase + 4] = [byte]$earlyRotateSubXor[1]
    if ((Get-StoredFields $wrongOrder) -eq (Get-StoredFields $Repaired)) { throw 'Unordered regeneration did not differ' }
    Write-Output ('Negative control rejected unordered regeneration: unordered={0} ordered={1}' -f (Get-StoredFields $wrongOrder), (Get-StoredFields $Repaired))
}

function Test-TargetPathPreflight([byte[]]$Original, [string]$SpecPath, [byte[]]$Unrepaired, [byte[]]$Repaired) {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-review08-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    try {
        $originalCopy = Join-Path $tempRoot 'original.p1'
        $specCopy = Join-Path $tempRoot 'patch.json'
        [IO.File]::WriteAllBytes($originalCopy, $Original)
        [IO.File]::Copy($SpecPath, $specCopy)
        $originalCopySha256 = Get-FileHashHex $originalCopy 'SHA256'
        $specCopySha256 = Get-FileHashHex $specCopy 'SHA256'

        function New-PreflightCase([string]$Name) {
            $directory = Join-Path $tempRoot $Name
            [IO.Directory]::CreateDirectory($directory) | Out-Null
            return [pscustomobject]@{
                Directory = $directory
                Unrepaired = Join-Path $directory 'unrepaired.p1'
                Repaired = Join-Path $directory 'repaired.p1'
                Report = Join-Path $directory 'report.json'
            }
        }

        function Assert-NoNewOutputs($Case) {
            if ([IO.File]::Exists($Case.Unrepaired) -or [IO.File]::Exists($Case.Repaired)) { throw "Preflight failure created an output in $($Case.Directory)" }
        }

        $case = New-PreflightCase 'report-alias-original'
        Assert-PreflightRejected 'report alias original' 'original ROM' $originalCopy $specCopy $case.Unrepaired $case.Repaired $originalCopy
        Assert-NoNewOutputs $case

        $case = New-PreflightCase 'report-alias-spec'
        Assert-PreflightRejected 'report alias specification' 'patch specification' $originalCopy $specCopy $case.Unrepaired $case.Repaired $specCopy
        Assert-NoNewOutputs $case

        $case = New-PreflightCase 'report-alias-unrepaired'
        Assert-PreflightRejected 'report alias unrepaired output' 'distinct' $originalCopy $specCopy $case.Unrepaired $case.Repaired $case.Unrepaired
        Assert-NoNewOutputs $case

        $case = New-PreflightCase 'report-alias-repaired'
        Assert-PreflightRejected 'report alias repaired output' 'distinct' $originalCopy $specCopy $case.Unrepaired $case.Repaired $case.Repaired
        Assert-NoNewOutputs $case

        $case = New-PreflightCase 'existing-report'
        [IO.File]::WriteAllBytes($case.Report, [Text.Encoding]::UTF8.GetBytes('existing report'))
        Assert-PreflightRejected 'existing report' 'already exists' $originalCopy $specCopy $case.Unrepaired $case.Repaired $case.Report
        Assert-NoNewOutputs $case
        if ([IO.File]::ReadAllText($case.Report) -ne 'existing report') { throw 'Preflight failure changed the existing report' }

        $case = New-PreflightCase 'existing-second-output'
        [IO.File]::WriteAllBytes($case.Repaired, [byte[]](1, 2, 3))
        Assert-PreflightRejected 'existing second output' 'already exists' $originalCopy $specCopy $case.Unrepaired $case.Repaired $case.Report
        if ([IO.File]::Exists($case.Unrepaired)) { throw 'Preflight failure created the first output' }
        if ((Get-FileHashHex $case.Repaired 'SHA256') -ne (Get-HashHex ([byte[]](1, 2, 3)) 'SHA256')) { throw 'Preflight failure changed the existing second output' }

        $case = New-PreflightCase 'unique-targets'
        Assert-SafeTargetPaths $originalCopy $specCopy $case.Unrepaired $case.Repaired $case.Report
        Write-CreateNew $case.Unrepaired $Unrepaired
        Write-CreateNew $case.Repaired $Repaired
        $reportBytes = [Text.Encoding]::UTF8.GetBytes('{"negative_control":true}')
        Write-CreateNew $case.Report $reportBytes
        if ((Get-FileHashHex $case.Unrepaired 'SHA256') -ne (Get-HashHex $Unrepaired 'SHA256')) { throw 'Unrepaired positive write differs' }
        if ((Get-FileHashHex $case.Repaired 'SHA256') -ne (Get-HashHex $Repaired 'SHA256')) { throw 'Repaired positive write differs' }
        if ([IO.File]::ReadAllText($case.Report) -ne '{"negative_control":true}') { throw 'Report positive write differs' }
        try { Write-CreateNew $case.Report ([Text.Encoding]::UTF8.GetBytes('{"negative_control":false}')); throw 'Existing report was overwritten' }
        catch {
            if ($_.Exception.Message -eq 'Existing report was overwritten') { throw }
            $inner = $_.Exception
            while ($null -ne $inner.InnerException) { $inner = $inner.InnerException }
            if ($inner -isnot [IO.IOException]) { throw }
            Write-Output ('Negative control rejected existing report write: ' + $inner.Message)
        }
        if ([IO.File]::ReadAllText($case.Report) -ne '{"negative_control":true}') { throw 'Existing report changed after create-new rejection' }

        if ((Get-FileHashHex $originalCopy 'SHA256') -ne $originalCopySha256) { throw 'Negative controls modified the original ROM copy' }
        if ((Get-FileHashHex $specCopy 'SHA256') -ne $specCopySha256) { throw 'Negative controls modified the patch specification copy' }
        Write-Output 'PASS target preflight aliases, existing targets, positive create-only outputs/report and input preservation'
    }
    finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

$originalPath = [IO.Path]::GetFullPath($OriginalRom)
$specPath = [IO.Path]::GetFullPath($PatchSpec)
$unrepairedPath = [IO.Path]::GetFullPath($UnrepairedOutput)
$repairedPath = [IO.Path]::GetFullPath($RepairedOutput)
$reportPath = if ([string]::IsNullOrWhiteSpace($ReportPath)) { $null } else { [IO.Path]::GetFullPath($ReportPath) }
Assert-SafeTargetPaths $originalPath $specPath $unrepairedPath $repairedPath $reportPath

$original = [IO.File]::ReadAllBytes($originalPath)
Assert-OriginalIdentity $original
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
Assert-PatchSpec $spec

$specSha256 = Get-FileHashHex $specPath 'SHA256'
$originalSha1 = Get-HashHex $original 'SHA1'
$originalSha256 = Get-HashHex $original 'SHA256'
$originalFields = Get-StoredFields $original
if ($originalFields -ne $ExpectedOriginalFields) { throw "Original stored fields are $originalFields, expected $ExpectedOriginalFields" }
$originalComputed = Assert-Fields $original $ExpectedOriginalFields

$patched = New-PatchedImage $original $spec
$patchedSumXor = Invoke-SumXor $patched $Start $End
$patchedOriginalFieldRotateAdd = Invoke-RotateAdd $patched $Start $End
$repaired = New-RepairedImage $patched
$repairedFields = Get-StoredFields $repaired
$repairedComputed = Assert-Fields $repaired $repairedFields

Assert-ProtectedBytes $patched $original
Assert-ProtectedBytes $repaired $original
$unrepairedChanged = @(Get-ChangedOffsets $original $patched)
$repairedChanged = @(Get-ChangedOffsets $original $repaired)
$repairChanged = @(Get-ChangedOffsets $patched $repaired)
$expectedUnrepairedChanged = @($AwardChangedOffset)
$expectedRepairedChanged = @($AwardChangedOffset) + @($FieldBase..($FieldBase + 4))
$expectedRepairChanged = @($FieldBase..($FieldBase + 4))
if ((Compare-Object $unrepairedChanged $expectedUnrepairedChanged)) { throw ('Unexpected unrepaired changed offsets: ' + ($unrepairedChanged -join ',')) }
if ((Compare-Object $repairedChanged $expectedRepairedChanged)) { throw ('Unexpected repaired changed offsets: ' + ($repairedChanged -join ',')) }
if ((Compare-Object $repairChanged $expectedRepairChanged)) { throw ('Unexpected field repair offsets: ' + ($repairChanged -join ',')) }

if ($NegativeControl) {
    Test-NegativeControls $original $spec $patched $repaired
    Test-TargetPathPreflight $original $specPath $patched $repaired
    if ((Get-HashHex ([IO.File]::ReadAllBytes($originalPath)) 'SHA256') -ne $originalSha256) { throw 'Original ROM changed during negative controls' }
    if ((Get-FileHashHex $specPath 'SHA256') -ne $specSha256) { throw 'Patch specification changed during negative controls' }
}

Write-CreateNew $unrepairedPath $patched
Write-CreateNew $repairedPath $repaired
$unrepairedReadback = [IO.File]::ReadAllBytes($unrepairedPath)
$repairedReadback = [IO.File]::ReadAllBytes($repairedPath)

$report = [ordered]@{
    schema_version = 1
    classification = 'Static algorithm execution and deterministic regeneration for the existing equal-size shared-award edit. The repaired image has not been certified as gameplay-equivalent or hardware-compatible; natural MAME startup evidence is separate.'
    input = [ordered]@{
        path = [IO.Path]::GetFileName($originalPath)
        length = $original.Length
        sha1 = $originalSha1
        sha256 = $originalSha256
    }
    patch = [ordered]@{
        path = Get-DisplayPath $specPath
        sha256 = $specSha256
        offset = $PatchOffset
        expected_hex = $PatchExpectedHex
        replacement_hex = $PatchReplacementHex
        changed_offsets = $unrepairedChanged
        source = 'evidence/mpu4/patches/skill-cash-level1-12.json'
    }
    dependency_order = [ordered]@{
        sum_xor = 'computed first; excludes FFD1-FFD5, so it reads no expected fields'
        rotate_add = 'computed after sum/xor; excludes FFD3-FFD5 but reads regenerated FFD1-FFD2'
        rotate_sub_xor = 'computed last; excludes FFD4-FFD5 but reads regenerated FFD1-FFD3'
        source = 'evidence/mpu4/native/66db.json: 66df-66f1 sums, 6701-6713 rotate-add, 671f-6740 rotate-sub-xor and skip redirects'
    }
    original = [ordered]@{
        stored_fields = $originalFields
        computed_fields = $originalComputed
    }
    unrepaired = [ordered]@{
        path = Get-DisplayPath $unrepairedPath
        length = $patched.Length
        sha1 = (Get-HashHex $patched 'SHA1')
        sha256 = (Get-HashHex $patched 'SHA256')
        readback_sha256 = (Get-HashHex $unrepairedReadback 'SHA256')
        stored_fields = (Get-StoredFields $patched)
        computed_sum_xor = ('{0:X2}{1:X2}' -f $patchedSumXor[0],$patchedSumXor[1])
        computed_rotate_add_with_original_fields = ('{0:X2}' -f $patchedOriginalFieldRotateAdd)
        changed_offsets = $unrepairedChanged
    }
    repaired = [ordered]@{
        path = Get-DisplayPath $repairedPath
        length = $repaired.Length
        sha1 = (Get-HashHex $repaired 'SHA1')
        sha256 = (Get-HashHex $repaired 'SHA256')
        readback_sha256 = (Get-HashHex $repairedReadback 'SHA256')
        stored_fields = $repairedFields
        computed_fields = $repairedComputed
        changed_offsets = $repairedChanged
        field_offsets_changed_by_repair = $repairChanged
    }
    retained = [ordered]@{
        checker_code = '66A5-674F unchanged'
        outer_gate = '719B unchanged'
        disabled_records = 'FFB0-FFD0 unchanged'
        active_record_metadata = 'FFD6-FFDB unchanged'
        all_other_bytes = 'unchanged'
    }
    limitations = @(
        'Only the existing single-byte shared-award edit at 75BE is accepted.',
        'This regenerates the active gate-00 record fields only; disabled records are preserved, not enabled.',
        'No relocation, code edit, additional game rule, gameplay equivalence, MAME loader hash repair or hardware compatibility is claimed.',
        'Natural original/unrepaired/repaired startup comparison is recorded separately.'
    )
}
if ($null -ne $reportPath) {
    $reportBytes = [Text.Encoding]::UTF8.GetBytes(($report | ConvertTo-Json -Depth 10))
    Write-CreateNew $reportPath $reportBytes
    Write-Output "Report $reportPath"
}
Write-Output ($report | ConvertTo-Json -Depth 10)
exit 0
