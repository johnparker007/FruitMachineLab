[CmdletBinding()]
param(
    [string]$OriginalRunDirectory,
    [string]$ChangedRunDirectory,
    [string]$EarlyOriginalRunDirectory,
    [string]$EarlyChangedRunDirectory,
    [string]$OriginalRom,
    [string]$ChangedRom,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$ReplayPath,
    [string]$OutputPath,
    [switch]$RequireTargetComparison
)
$ErrorActionPreference = 'Stop'

$script:N9OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:N9OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:N9ChangedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$script:N9ChangedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$script:N9SourceMapSha256 = '0c39a6d0d1beac32ca0f64bfec5ce848b2297be41180d0234d2bfdf491df21a9'
$script:N9BuildReportSha256 = 'ae7e0fb2c0121e0b4e62d38e82511841644fcdf922b2d9e54de79b3d7e57f61a'
$script:N9ReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:N9MameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:N9ExpectedChangedOffsets = @(0x9EDC,0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5)
$script:N9ExpectedScripted = @(
    @{reason='take_nudge_entry';first=23734;last=23746;port=':BLACK2';mask=1},
    @{reason='nudge1_request';first=23746;last=23752;port=':BLACK2';mask=2},
    @{reason='nudge1_repeat';first=23769;last=23775;port=':BLACK2';mask=4},
    @{reason='paid_start';first=24400;last=24412;port=':BLACK2';mask=128},
    @{reason='ordinary_paid_nudge1';first=26136;last=26142;port=':BLACK2';mask=2}
)

function Get-N9Hash {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Read-N9Json {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing JSON: $Path" }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Write-N9Json {
    param([string]$Path,$Object,[int]$Depth=14)
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),(New-Object System.Text.UTF8Encoding($false)))
}

function Assert-N9Rom {
    param([string]$Path,[string]$ExpectedSha1,[string]$ExpectedSha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -ne 65536) { throw "$Label length is $length, expected 65536" }
    $sha1 = Get-N9Hash $Path 'SHA1'
    $sha256 = Get-N9Hash $Path 'SHA256'
    if ($sha1 -ine $ExpectedSha1) { throw "$Label SHA1 is $sha1, expected $ExpectedSha1" }
    if ($sha256 -ine $ExpectedSha256) { throw "$Label SHA256 is $sha256, expected $ExpectedSha256" }
    return [ordered]@{length=$length;sha1=$sha1;sha256=$sha256}
}

function Get-N9ChangedOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length ROM images' }
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($i=0;$i -lt $A.Length;$i++) { if ($A[$i] -ne $B[$i]) { [void]$list.Add($i) } }
    return $list.ToArray()
}

function Format-N9Offsets {
    param([int[]]$Offsets)
    return (($Offsets | ForEach-Object { '{0:X4}' -f $_ }) -join ',')
}

function Get-N9Field {
    param([string]$Line,[string]$Name)
    $m = [regex]::Match($Line, ('\b' + [regex]::Escape($Name) + '=([0-9A-Fa-f]+)'))
    if (!$m.Success) { throw "Missing field $Name in line: $Line" }
    return $m.Groups[1].Value.ToUpperInvariant()
}

function Get-N9OptionalField {
    param([string]$Line,[string]$Name)
    $m = [regex]::Match($Line, ('\b' + [regex]::Escape($Name) + '=([0-9A-Fa-f]+)'))
    if (!$m.Success) { return $null }
    return $m.Groups[1].Value.ToUpperInvariant()
}

function Get-N9Lines {
    param([string]$RunDirectory,[string]$Name)
    $path = Join-Path $RunDirectory $Name
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing run file: $path" }
    return @(Get-Content -LiteralPath $path)
}

function Assert-N9RunArguments {
    param($RunArgs,[string]$RunDirectory)
    $RunArgs = @($RunArgs)
    if ($RunArgs -notcontains '-noreadconfig') { throw 'Run arguments do not disable configuration reads' }
    foreach ($bad in @('-playback','-state','-state_directory_load','-load','-autosave')) {
        if ($RunArgs -contains $bad) { throw "Run arguments contain forbidden option $bad" }
    }
    if (@($RunArgs | Where-Object { $_ -like ((Join-Path $RunDirectory 'roms') + '*') }).Count -eq 0) { throw 'Run arguments do not isolate the ROM path' }
}

function Assert-N9StateDirectory {
    param([string]$RunDirectory)
    $stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $RunDirectory 'state') -Recurse -File -ErrorAction SilentlyContinue)
    if ($stateFiles.Count -ne 0) { throw 'State directory contains files; a save state may have been seeded' }
}

function Assert-N9DebuggerCommands {
    param([string[]]$Lines)
    foreach ($line in $Lines) {
        if ($line -match '(?i)^\s*(set|load|state|playback|record)\b') { throw "Debugger command contains forbidden operation: $line" }
        if ($line -match '(?i)(?:^|[;{,]\s*)\s*(pc|y|x|u|s|cc|dp|a|b)\s*=') { throw "Debugger command writes CPU state: $line" }
        if ($line -match '(?i)[bw]@[0-9a-fx+()]+\s*=') { throw "Debugger command writes memory: $line" }
    }
}

function Get-N9RunFacts {
    param([string]$RunDirectory,[string]$ExpectedSha1,[string]$ExpectedSha256,[string]$Variant)
    $prov = Read-N9Json (Join-Path $RunDirectory 'provenance.json')
    $obs = Read-N9Json (Join-Path $RunDirectory 'observation.json')
    $runArgs = Read-N9Json (Join-Path $RunDirectory 'arguments.json')
    $pre = Read-N9Json (Join-Path $RunDirectory 'pre-run-empty.json')
    $runRom = Join-Path $RunDirectory 'roms/m4addr/a6ls.p1'
    $runIdentity = Assert-N9Rom $runRom $ExpectedSha1 $ExpectedSha256 "run ROM in $RunDirectory"
    if ([string]$prov.variant -ne $Variant) { throw "Provenance variant is $($prov.variant), expected $Variant" }
    if ([string]$prov.original_rom_sha1 -ine $script:N9OriginalSha1) { throw 'Provenance original SHA1 mismatch' }
    if ([string]$prov.original_rom_sha256 -ine $script:N9OriginalSha256) { throw 'Provenance original SHA256 mismatch' }
    if ([string]$prov.variant_rom_sha1 -ine $ExpectedSha1) { throw 'Provenance variant SHA1 mismatch' }
    if ([string]$prov.variant_rom_sha256 -ine $ExpectedSha256) { throw 'Provenance variant SHA256 mismatch' }
    if ([string]$prov.run_rom_sha1_before -ine $ExpectedSha1) { throw 'Provenance pre-run ROM SHA1 mismatch' }
    if ([string]$prov.run_rom_sha256_before -ine $ExpectedSha256) { throw 'Provenance pre-run ROM SHA256 mismatch' }
    if ([string]$prov.replay_sha256 -ine $script:N9ReplaySha256) { throw 'Provenance replay hash mismatch' }
    if ([string]$prov.mame_sha256 -ine $script:N9MameSha256) { throw 'Provenance MAME hash mismatch' }
    if ([string]$prov.starting_nvram -ne 'absent') { throw 'Provenance does not declare absent NVRAM' }
    if ([string]$prov.starting_configuration -notmatch 'absent') { throw 'Provenance does not declare absent configuration' }
    if ([bool]$prov.save_state_loaded) { throw 'Provenance declares a loaded save state' }
    if ([bool]$prov.debugger_writes) { throw 'Provenance declares debugger writes' }
    if ([int]$prov.seconds_to_run -gt 1200) { throw 'Run exceeded the 1200 emulated-second bound' }
    foreach ($p in $pre.PSObject.Properties) { if ([int]$p.Value -ne 0) { throw "Pre-run directory $($p.Name) was not empty" } }
    if ([string]$obs.variant -ne $Variant) { throw 'Observation variant mismatch' }
    if ([int]$obs.exit_code -ne 0) { throw 'MAME exit code is not zero' }
    if ([bool]$obs.timed_out) { throw 'MAME timed out' }
    if (![bool]$obs.rom_unchanged) { throw 'Run ROM changed during execution' }
    $actualLogHash = Get-N9Hash (Join-Path $RunDirectory 'debug.log') 'SHA256'
    if ([string]$obs.debug_log_sha256 -ine $actualLogHash) { throw 'Observation debug-log hash does not match the raw log' }
    $actualConsoleHash = Get-N9Hash (Join-Path $RunDirectory 'console.txt') 'SHA256'
    if ([string]$obs.console_sha256 -ine $actualConsoleHash) { throw 'Observation console hash does not match the raw console output' }
    if ([int]$obs.replay_event_count -ne 1249) { throw 'Observation replay event count is not 1249' }
    if ([bool]$obs.integrity_failure) { throw 'Observation records a firmware integrity failure' }
    if ([int]$obs.reset_markers -lt 3) { throw 'Observation did not record three 7CD1 reset markers' }
    if ([int]$obs.checksum_returns -lt 2) { throw 'Observation did not record two checksum returns' }
    if ([int]$obs.vm_entry_count -lt 1) { throw 'Observation did not record a VM entry' }
    Assert-N9RunArguments $runArgs $RunDirectory
    Assert-N9StateDirectory $RunDirectory
    Assert-N9DebuggerCommands (Get-N9Lines $RunDirectory 'debugger.cmd')
    $log = Get-N9Lines $RunDirectory 'debug.log'
    $verify = @($log | Where-Object { $_ -match '^ILBOOT_ROM_VERIFY_ENTRY ' })
    if ($verify.Count -lt 1) { throw 'No firmware verification marker in the run' }
    $expectedFields = if ($Variant -eq 'Original') { '3E761E2605' } else { 'BEF69E7CC7' }
    foreach ($line in $verify) { if ((Get-N9Field $line 'expected') -ne $expectedFields) { throw "Firmware verification expected fields are not $expectedFields" } }
    if (@($log | Where-Object { $_ -match '^ILBOOT_ROM_VERIFY_FAILED ' }).Count -ne 0) { throw 'Firmware verification failed in the run' }
    return [ordered]@{
        run=$RunDirectory; variant=$Variant; provenance=$prov; observation=$obs; arguments=$runArgs; log=$log;
        run_rom=$runIdentity; changed_offsets=Format-N9Offsets (Get-N9ChangedOffsets ([IO.File]::ReadAllBytes($OriginalRom)) ([IO.File]::ReadAllBytes((Join-Path $RunDirectory 'roms/m4addr/a6ls.p1'))))
    }
}

function Assert-N9Inputs {
    param([string]$RunDirectory,[switch]$RequireHistoricalScripted)
    $replayHash = Get-N9Hash (Join-Path $RunDirectory 'replay-actions.csv') 'SHA256'
    if ($replayHash -ine $script:N9ReplaySha256) { throw "Run replay SHA256 is $replayHash, expected $($script:N9ReplaySha256)" }
    $replayRows = @(Get-Content -LiteralPath (Join-Path $RunDirectory 'replay-actions.csv') | Where-Object { $_ -match '^\d+' })
    if ($replayRows.Count -ne 1249) { throw "Run replay event count is $($replayRows.Count), expected 1249" }
    $first = $replayRows[0] -split ','
    $second = $replayRows[1] -split ','
    if ($first[0] -ne '2100' -or $first[1] -ne '2103' -or $first[2] -ne ':AUX2' -or $first[3] -ne '128') { throw 'Replay first event is not the accepted coin event' }
    if ($second[0] -ne '2220' -or $second[1] -ne '2232' -or $second[2] -ne ':BLACK2' -or $second[3] -ne '128') { throw 'Replay second event is not the accepted Start event' }
    $fields = @(Get-Content -LiteralPath (Join-Path $RunDirectory 'input-fields.txt'))
    $required = @(':AUX2 Coin 4 mask=128',':BLACK2 1 Player Start mask=128',':BLACK2 Collect / Take Feature mask=1',':BLACK2 Hold 1/Nudge 1 mask=2',':BLACK2 Hold 2/Nudge 2 mask=4',':BLACK2 Hold 3/Nudge 3 mask=8',':BLACK2 Hi mask=16',':BLACK2 Lo mask=32',':BLACK2 Exchange Feature mask=64')
    foreach ($r in $required) { if ($fields -notcontains $r) { throw "Input field inventory is missing '$r'" } }
    $scripted = New-Object 'System.Collections.Generic.List[object]'
    foreach ($row in Get-Content -LiteralPath (Join-Path $RunDirectory 'actions.csv')) {
        if ($row -notmatch '^\d+') { continue }
        $p = $row -split ','
        if ($p.Count -lt 5) { throw "Malformed scripted-pulse row: $row" }
        $scripted.Add([ordered]@{first=[int]$p[0];last=[int]$p[1];port=$p[2];mask=[int]$p[3];reason=$p[4]})
    }
    if ($RequireHistoricalScripted) {
        if ($scripted.Count -ne 5) { throw "Control scripted-pulse count is $($scripted.Count), expected 5" }
        for ($i=0;$i -lt 5;$i++) {
            $e = $script:N9ExpectedScripted[$i]; $a = $scripted[$i]
            if ($a.first -ne $e.first -or $a.last -ne $e.last -or $a.port -ne $e.port -or $a.mask -ne $e.mask -or $a.reason -ne $e.reason) {
                throw "Scripted pulse $i differs from the declared historical pulse"
            }
        }
    }
    $levels = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $RunDirectory 'input-levels.csv')) {
        if ($line -notmatch '^\d+,') { continue }
        $p = $line -split ','
        $levels[[int]$p[0]] = [ordered]@{aux=[Convert]::ToInt32($p[2],16);black=[Convert]::ToInt32($p[3],16)}
    }
    if ($levels.Count -lt 100) { throw 'Input-level log is unexpectedly short' }
    $maxFrame = ($levels.Keys | Measure-Object -Maximum).Maximum
    $all = @()
    foreach ($row in $replayRows) { $p=$row -split ','; $all += [ordered]@{first=[int]$p[0];last=[int]$p[1];port=$p[2];mask=[int]$p[3];reason=$p[4];source='replay'} }
    foreach ($e in $scripted) { $all += [ordered]@{first=$e.first;last=$e.last;port=$e.port;mask=$e.mask;reason=$e.reason;source='scripted'} }
    $observed = @($all | Where-Object { $_.first -le $maxFrame })
    foreach ($e in $observed) {
        $lastCheck = [Math]::Min($e.last+1,$maxFrame)
        for ($f=$e.first; $f -le $lastCheck; $f++) {
            if (!$levels.ContainsKey($f)) { throw "Input-level log has no frame $f for $($e.source)/$($e.reason)" }
            $val = if ($e.port -eq ':AUX2') { $levels[$f].aux } else { $levels[$f].black }
            $expectedPressed = ($f -ge ($e.first+1) -and $f -le $e.last)
            $pressed = (($val -band $e.mask) -ne 0)
            if ($expectedPressed -and !$pressed) { throw "Input $($e.port)/$($e.mask) not asserted at observed press frame $f" }
            if (!$expectedPressed -and $f -eq ($e.last+1) -and $f -le $maxFrame -and $pressed) {
                $overlap = @($observed | Where-Object { $_.port -eq $e.port -and (($_.mask -band $e.mask) -ne 0) -and $f -ge ($_.first+1) -and $f -le $_.last }).Count
                if ($overlap -eq 0) { throw "Input $($e.port)/$($e.mask) not released after observed frame $($e.last)" }
            }
        }
    }
    $physical = @(Get-Content -LiteralPath (Join-Path $RunDirectory 'physical-inputs.csv') | Where-Object { $_ -match '^\d' })
    if ($physical.Count -ne $observed.Count) { throw "Merged physical-input count $($physical.Count) does not match observed event count $($observed.Count)" }
    return [ordered]@{replay_sha256=$replayHash;replay_events=1249;scripted=$scripted;observed_events=$observed.Count;max_frame=$maxFrame;levels=$levels}
}

function Get-N9TargetFacts {
    param([string[]]$Lines,[string]$Label)
    $tail = @($Lines | Where-Object { $_ -match '^TAIL y=EE16 ' })
    $term = @($Lines | Where-Object { $_ -match '^TERM y=EE22 ' })
    $pf = @($Lines | Where-Object { $_ -match '^PF y=' })
    $he = @($Lines | Where-Object { $_ -match '^HE pc=' })
    $ct = @($Lines | Where-Object { $_ -match '^CT pc=' })
    return [ordered]@{tail=$tail;term=$term;pf=$pf;he=$he;ct=$ct}
}

function Assert-N9ControlTarget {
    param($Facts,[string]$RunRomPath)
    if ($Facts.tail.Count -ne 1) { throw 'Control must have exactly one TAIL y=EE16 line' }
    if ($Facts.term.Count -ne 1) { throw 'Control must have exactly one TERM y=EE22 line' }
    if ($Facts.pf.Count -ne 7) { throw "Control pre-fetch phase sequence has $($Facts.pf.Count) entries, expected 7" }
    if ($Facts.he.Count -ne 5) { throw "Control handler phase sequence has $($Facts.he.Count) entries, expected 5" }
    $tail = $Facts.tail[0]; $term = $Facts.term[0]
    if ((Get-N9Field $tail 'token') -ne '7ECB') { throw 'Control TAIL token is not 7ECB' }
    if ((Get-N9Field $tail 'u') -ne '0672' -or (Get-N9Field $tail 's') -ne '07A6') { throw 'Control TAIL U/S prestate differs' }
    if ((Get-N9Field $tail 'b0305') -ne '10' -or (Get-N9Field $tail 'c') -ne '000000') { throw 'Control TAIL 0305/counter prestate differs' }
    if ((Get-N9Field $tail 'credit') -ne '02' -or (Get-N9Field $tail 'bank') -ne '0010') { throw 'Control TAIL credit/bank prestate differs' }
    $rom = [IO.File]::ReadAllBytes($RunRomPath)
    if (($rom[0x9EDB].ToString('X2') + $rom[0x9EDC].ToString('X2')) -ne 'FF80') { throw 'Control run image does not hold FF80 at 9EDB..9EDC' }
    $pfY = @($Facts.pf | ForEach-Object { Get-N9Field $_ 'y' })
    if (($pfY -join ',') -ne 'EBCA,9ED9,9EDD,9EDF,9EE3,9EE5,EBCC') { throw "Control pre-fetch phase sequence is $($pfY -join ',')" }
    $hePc = @($Facts.he | ForEach-Object { Get-N9Field $_ 'pc' })
    if (($hePc -join ',') -ne '795D,7880,795D,7AB1,7931') { throw "Control handler phase sequence is $($hePc -join ',')" }
    if ($Facts.ct.Count -ne 1) { throw 'Control must have exactly one composite CT line' }
    $ct = $Facts.ct[0]
    if ((Get-N9Field $ct 'x') -ne '9ED9' -or (Get-N9Field $ct 'y') -ne 'EBCC' -or (Get-N9Field $ct 's') -ne '07A4') { throw 'Control composite transfer fields differ' }
    $expectPf = @(
        @{y='EBCA';token='9ED7';u='066A';top='0000';second='1F40';s='07A4';sw0='EE22'},
        @{y='9ED9';token='795B';u='066A';top='0000';second='1F40';s='07A2';sw0='EBCC';op0='FF80'},
        @{y='9EDD';token='787E';u='0668';top='FF80';second='0000';s='07A2';sw0='EBCC'},
        @{y='9EDF';token='795B';u='066A';top='FF80';second='1F40';s='07A2';sw0='EBCC';op0='FF80'},
        @{y='9EE3';token='7AAF';u='0668';top='FF80';second='FF80';s='07A2';sw0='EBCC'},
        @{y='9EE5';token='792F';u='066A';top='0000';second='1F40';s='07A2';sw0='EBCC'},
        @{y='EBCC';token='7CB3';u='066A';top='0000';second='1F40';s='07A4';sw0='EE22'}
    )
    for ($i=0;$i -lt 7;$i++) {
        $line=$Facts.pf[$i]; $e=$expectPf[$i]
        if ((Get-N9Field $line 'y') -ne $e.y -or (Get-N9Field $line 'token') -ne $e.token) { throw "Control PF $i Y/token mismatch" }
        foreach ($k in @('u','top','second','s','sw0')) { if ((Get-N9Field $line $k) -ne $e[$k]) { throw "Control PF $($e.y) field $k mismatch" } }
        if ($e.ContainsKey('op0') -and (Get-N9Field $line 'op0') -ne $e.op0) { throw "Control PF $($e.y) inline operand mismatch" }
        if ((Get-N9Field $line 'b0305') -ne '10' -or (Get-N9Field $line 'c') -ne '000000' -or (Get-N9Field $line 'credit') -ne '02' -or (Get-N9Field $line 'bank') -ne '0010') { throw "Control PF $($e.y) relevant state mismatch" }
        if ((Get-N9Field $line 'rom9edb') -ne 'FF80') { throw "Control PF $($e.y) does not read FF80 at 9EDB" }
    }
    $expectHe = @(
        @{pc='795D';token='795B';x='795D';y='9EDB';u='066A';top='0000';second='1F40';s='07A2'},
        @{pc='7880';token='787E';x='7880';y='9EDF';u='0668';top='FF80';second='0000';s='07A2'},
        @{pc='795D';token='795B';x='795D';y='9EE1';u='066A';top='FF80';second='1F40';s='07A2'},
        @{pc='7AB1';token='7AAF';x='7AB1';y='9EE5';u='0668';top='FF80';second='FF80';s='07A2'},
        @{pc='7931';token='792F';x='7931';y='9EE7';u='066A';top='0000';second='1F40';s='07A2';sw0='EBCC'}
    )
    for ($i=0;$i -lt 5;$i++) {
        $line=$Facts.he[$i]; $e=$expectHe[$i]
        foreach ($k in @('pc','token','x','y','u','top','second','s')) { if ((Get-N9Field $line $k) -ne $e[$k]) { throw "Control HE $i field $k mismatch" } }
        if ($e.ContainsKey('sw0') -and (Get-N9Field $line 'sw0') -ne $e.sw0) { throw 'Control return handler does not hold EBCC on the control stack' }
        if ((Get-N9Field $line 'b0305') -ne '10' -or (Get-N9Field $line 'c') -ne '000000') { throw "Control HE $i relevant state mismatch" }
    }
    if ((Get-N9Field $term 'token') -ne '9FA0' -or (Get-N9Field $term 'u') -ne '0672' -or (Get-N9Field $term 's') -ne '07A6') { throw 'Control TERM terminal state differs' }
    if ((Get-N9Field $term 'b0305') -ne '10' -or (Get-N9Field $term 'c') -ne 'FFE0C0' -or (Get-N9Field $term 'credit') -ne '02' -or (Get-N9Field $term 'bank') -ne '0010') { throw 'Control TERM counter/credit/bank differ' }
    $expectedOriginal = (((0xFF80 + 0x0000) -band 0xFFFF) -bxor 0xFF80)
    if ($expectedOriginal -ne 0) { throw 'Original 16-bit arithmetic self-check failed' }
}

function Assert-N9EarlyPair {
    param([string[]]$OriginalLines,[string[]]$ChangedLines,[string]$OriginalRomPath,[string]$ChangedRomPath)
    $ol = @($OriginalLines | Where-Object { $_ -match '^E9L ' })
    $or = @($OriginalLines | Where-Object { $_ -match '^E9R ' })
    $cl = @($ChangedLines | Where-Object { $_ -match '^E9L ' })
    $cr = @($ChangedLines | Where-Object { $_ -match '^E9R ' })
    if ($ol.Count -ne 8 -or $or.Count -ne 8 -or $cl.Count -ne 8 -or $cr.Count -ne 8) { throw 'Early 9ED9 diagnostic must contain eight literal and eight return observations per image' }
    $orom=[IO.File]::ReadAllBytes($OriginalRomPath); $crom=[IO.File]::ReadAllBytes($ChangedRomPath)
    if (($orom[0x9EDB].ToString('X2')+$orom[0x9EDC].ToString('X2')) -ne 'FF80') { throw 'Early original image is not FF80 at 9EDB..9EDC' }
    if (($crom[0x9EDB].ToString('X2')+$crom[0x9EDC].ToString('X2')) -ne 'FF00') { throw 'Early changed image is not FF00 at 9EDB..9EDC' }
    $allowedLiteral = @('token','rom9edb','cycle')
    $allowedReturn = @('top','rom9edb','cycle')
    for ($i=0;$i -lt 8;$i++) {
        $a=$ol[$i]; $b=$cl[$i]
        if ((Get-N9Field $a 'y') -ne '9EDB' -or (Get-N9Field $b 'y') -ne '9EDB' -or (Get-N9Field $a 'x') -ne '795D' -or (Get-N9Field $b 'x') -ne '795D') { throw "Early literal $i phase mismatch" }
        if ((Get-N9Field $a 'rom9edb') -ne 'FF80' -or (Get-N9Field $b 'rom9edb') -ne 'FF00') { throw "Early literal $i operand mismatch" }
        if ((Get-N9Field $a 'token') -ne 'FF80' -or (Get-N9Field $b 'token') -ne 'FF00') { throw "Early literal $i operand-read mismatch" }
        foreach ($k in @('y','x','u','top','second','third','fourth','s','sw0','sw1','sw2','b0305','c','credit','bank')) {
            if ($k -eq 'y' -or $k -eq 'x') { continue }
            if ((Get-N9Field $a $k) -ne (Get-N9Field $b $k)) { throw "Early literal $i field $k differs beyond the expected operand" }
        }
        $ar=$or[$i]; $br=$cr[$i]
        if ((Get-N9Field $ar 'y') -ne '9EE7' -or (Get-N9Field $br 'y') -ne '9EE7' -or (Get-N9Field $ar 'x') -ne '7931' -or (Get-N9Field $br 'x') -ne '7931') { throw "Early return $i phase mismatch" }
        if ((Get-N9Field $ar 'top') -ne '0000' -or (Get-N9Field $br 'top') -ne '0080') { throw "Early return $i result is not the expected 0000/0080 difference" }
        if ((Get-N9Field $ar 'rom9edb') -ne 'FF80' -or (Get-N9Field $br 'rom9edb') -ne 'FF00') { throw "Early return $i operand provenance mismatch" }
        if ((Get-N9Field $ar 'token') -ne '00F8' -or (Get-N9Field $br 'token') -ne '00F8') { throw "Early return $i successor-token mismatch" }
        foreach ($k in @('u','second','third','fourth','s','sw0','sw1','sw2','b0305','c','credit','bank')) {
            if ((Get-N9Field $ar $k) -ne (Get-N9Field $br $k)) { throw "Early return $i field $k differs beyond the expected result" }
        }
    }
    $expectedOriginal = (((0xFF80 + 0x0000) -band 0xFFFF) -bxor 0xFF80)
    $expectedChanged = (((0xFF00 + 0x0000) -band 0xFFFF) -bxor 0xFF80)
    if ($expectedOriginal -ne 0 -or $expectedChanged -ne 0x80) { throw '16-bit early arithmetic self-check failed' }
}

function Get-N9EarliestStateMismatch {
    param([string]$OriginalStatePath,[string]$ChangedStatePath)
    $a = @(Import-Csv -LiteralPath $OriginalStatePath)
    $b = @(Import-Csv -LiteralPath $ChangedStatePath)
    $mapB = @{}; foreach ($r in $b) { $mapB[$r.t] = $r }
    $header = @($a[0].PSObject.Properties.Name)
    $ignore = @('t','pc','y','u','s')
    foreach ($ra in $a) {
        $key = $ra.t
        if (!$mapB.ContainsKey($key)) { continue }
        $rb = $mapB[$key]
        foreach ($name in $header) {
            if ($ignore -contains $name) { continue }
            if ([string]$ra.$name -ne [string]$rb.$name) {
                return [ordered]@{key=$key; field=$name; original=[string]$ra.$name; changed=[string]$rb.$name; original_row=$ra; changed_row=$rb}
            }
        }
    }
    return $null
}

function Invoke-N9Curation {
    param(
        [string]$OriginalRunDirectory,
        [string]$ChangedRunDirectory,
        [string]$EarlyOriginalRunDirectory,
        [string]$EarlyChangedRunDirectory,
        [string]$OriginalRom,
        [string]$ChangedRom,
        [string]$SourceMapPath,
        [string]$BuildReportPath,
        [string]$ReplayPath,
        [string]$OutputPath,
        [switch]$RequireTargetComparison
    )
    $OriginalRunDirectory = [IO.Path]::GetFullPath($OriginalRunDirectory)
    $ChangedRunDirectory = [IO.Path]::GetFullPath($ChangedRunDirectory)
    $EarlyOriginalRunDirectory = [IO.Path]::GetFullPath($EarlyOriginalRunDirectory)
    $EarlyChangedRunDirectory = [IO.Path]::GetFullPath($EarlyChangedRunDirectory)
    $OriginalRom = [IO.Path]::GetFullPath($OriginalRom)
    $ChangedRom = [IO.Path]::GetFullPath($ChangedRom)
    $SourceMapPath = [IO.Path]::GetFullPath($SourceMapPath)
    $BuildReportPath = [IO.Path]::GetFullPath($BuildReportPath)
    $ReplayPath = [IO.Path]::GetFullPath($ReplayPath)
    $OutputPath = [IO.Path]::GetFullPath($OutputPath)
    if (!(Test-Path -LiteralPath $ReplayPath -PathType Leaf)) { throw "Tracked replay is missing: $ReplayPath" }
    $trackedReplayHash = Get-N9Hash $ReplayPath 'SHA256'
    if ($trackedReplayHash -ine $script:N9ReplaySha256) { throw "Tracked replay SHA256 is $trackedReplayHash, expected $($script:N9ReplaySha256)" }
    $generated = [DateTime]::UtcNow.ToString('o')
    $original = Assert-N9Rom $OriginalRom $script:N9OriginalSha1 $script:N9OriginalSha256 'original ROM'
    $changed = Assert-N9Rom $ChangedRom $script:N9ChangedSha1 $script:N9ChangedSha256 'changed ROM'
    $offsets = Get-N9ChangedOffsets ([IO.File]::ReadAllBytes($OriginalRom)) ([IO.File]::ReadAllBytes($ChangedRom))
    $offsetText = Format-N9Offsets $offsets
    if ($offsetText -ne '9EDC,FFD1,FFD2,FFD3,FFD4,FFD5') { throw "Changed image offsets are $offsetText, expected 9EDC,FFD1,FFD2,FFD3,FFD4,FFD5" }
    $romO=[IO.File]::ReadAllBytes($OriginalRom); $romC=[IO.File]::ReadAllBytes($ChangedRom)
    if (($romO[0x9EDB].ToString('X2')+$romO[0x9EDC].ToString('X2')) -ne 'FF80') { throw 'Original image operand is not FF80' }
    if (($romC[0x9EDB].ToString('X2')+$romC[0x9EDC].ToString('X2')) -ne 'FF00') { throw 'Changed image operand is not FF00' }
    $mapHash = Get-N9Hash $SourceMapPath 'SHA256'
    if ($mapHash -ine $script:N9SourceMapSha256) { throw 'Source map is not the accepted 9ED9 build map' }
    $buildHash = Get-N9Hash $BuildReportPath 'SHA256'
    if ($buildHash -ine $script:N9BuildReportSha256) { throw 'Build report is not the accepted 9ED9 build report' }
    $map = Read-N9Json $SourceMapPath
    if ([string]$map.originalRomSha256 -ine $script:N9OriginalSha256) { throw 'Source map original image binding mismatch' }
    if ([string]$map.outputImageSha256 -ine $script:N9ChangedSha256) { throw 'Source map is not bound to the changed image' }
    if ([string]$map.bodyStart -ne '9ED9' -or [string]$map.bodyEndExclusive -ne '9EE7') { throw 'Source map body span is not 9ED9..9EE7' }
    $mapByAddress = @{}; foreach ($entry in @($map.entries)) { $mapByAddress[[string]$entry.address] = $entry }
    $nodeExpected = @(@{a='9ED9';t='795B';o='vm_push_inline_word_literal'},@{a='9EDD';t='787E';o='vm_add_words'},@{a='9EDF';t='795B';o='vm_push_inline_word_literal'},@{a='9EE3';t='7AAF';o='vm_bitwise_xor'},@{a='9EE5';t='792F';o='vm_return_to_caller_stream'})
    foreach ($n in $nodeExpected) {
        if (!$mapByAddress.ContainsKey($n.a)) { throw "Source map has no node at $($n.a)" }
        $e=$mapByAddress[$n.a]
        if ([string]$e.token -ne $n.t -or [string]$e.operation -ne $n.o) { throw "Source map node $($n.a) token/operation mismatch" }
    }
    $build = Read-N9Json $BuildReportPath
    if ([string]$build.original.sha256 -ine $script:N9OriginalSha256) { throw 'Build report original identity mismatch' }
    if ([string]$build.repaired.sha256 -ine $script:N9ChangedSha256) { throw 'Build report repaired identity mismatch' }
    if ((@($build.repaired.changedOffsetsHex) -join ',') -ne '9EDC,FFD1,FFD2,FFD3,FFD4,FFD5') { throw 'Build report changed offsets differ' }

    $control = Get-N9RunFacts $OriginalRunDirectory $script:N9OriginalSha1 $script:N9OriginalSha256 'Original'
    $changedFacts = Get-N9RunFacts $ChangedRunDirectory $script:N9ChangedSha1 $script:N9ChangedSha256 'Changed'
    $earlyControl = Get-N9RunFacts $EarlyOriginalRunDirectory $script:N9OriginalSha1 $script:N9OriginalSha256 'Original'
    $earlyChanged = Get-N9RunFacts $EarlyChangedRunDirectory $script:N9ChangedSha1 $script:N9ChangedSha256 'Changed'
    if ($control.changed_offsets -ne '') { throw 'Control run image unexpectedly differs from the original' }
    if ($changedFacts.changed_offsets -ne '9EDC,FFD1,FFD2,FFD3,FFD4,FFD5') { throw 'Changed run image changed-offset set differs' }
    if ($earlyControl.changed_offsets -ne '') { throw 'Early control run image unexpectedly differs from the original' }
    if ($earlyChanged.changed_offsets -ne '9EDC,FFD1,FFD2,FFD3,FFD4,FFD5') { throw 'Early changed run changed-offset set differs' }

    $controlInputs = Assert-N9Inputs $OriginalRunDirectory -RequireHistoricalScripted
    $changedInputs = Assert-N9Inputs $ChangedRunDirectory
    $earlyControlInputs = Assert-N9Inputs $EarlyOriginalRunDirectory
    $earlyChangedInputs = Assert-N9Inputs $EarlyChangedRunDirectory
    if ($earlyControlInputs.scripted.Count -ne 0 -or $earlyChangedInputs.scripted.Count -ne 0) { throw 'Early diagnostic runs unexpectedly contain scripted pulses' }

    $controlFacts = Get-N9TargetFacts $control.log 'control'
    Assert-N9ControlTarget $controlFacts (Join-Path $OriginalRunDirectory 'roms/m4addr/a6ls.p1')
    $changedTargetFacts = Get-N9TargetFacts $changedFacts.log 'changed'
    $changedReached = ($changedTargetFacts.tail.Count -eq 1 -and $changedTargetFacts.term.Count -eq 1)
    $physicalIdentical = $false
    if ($controlInputs.scripted.Count -eq $changedInputs.scripted.Count) {
        $physicalIdentical = $true
        for ($i=0;$i -lt $controlInputs.scripted.Count;$i++) {
            $a=$controlInputs.scripted[$i]; $b=$changedInputs.scripted[$i]
            if ($a.first -ne $b.first -or $a.last -ne $b.last -or $a.port -ne $b.port -or $a.mask -ne $b.mask -or $a.reason -ne $b.reason) { $physicalIdentical=$false; break }
        }
    }
    $gate = $null
    if (!$changedReached) {
        if ($changedTargetFacts.pf.Count -ne 0 -or $changedTargetFacts.he.Count -ne 0 -or $changedTargetFacts.ct.Count -ne 0) { throw 'Changed run has partial target hooks without a complete EE16/EE22 window' }
        Assert-N9EarlyPair $earlyControl.log $earlyChanged.log $OriginalRom $ChangedRom
        $mismatch = Get-N9EarliestStateMismatch (Join-Path $EarlyOriginalRunDirectory 'state.csv') (Join-Path $EarlyChangedRunDirectory 'state.csv')
        if ($null -eq $mismatch) { throw 'Early original/changed runs show no sampled state mismatch' }
        if ($mismatch.key -ne '49.050000000') { throw "Earliest sampled meaningful state mismatch is at $($mismatch.key), expected 49.050000000" }
        if ($mismatch.field -ne 'reel3') { throw "Earliest sampled mismatch field is $($mismatch.field), expected reel3" }
        if ($mismatch.original -ne '61AE' -or $mismatch.changed -ne '6191') { throw 'Earliest sampled reel3 values differ from the recorded gate' }
        $controlStateRows = @(Import-Csv -LiteralPath (Join-Path $EarlyOriginalRunDirectory 'state.csv'))
        $changedStateRows = @(Import-Csv -LiteralPath (Join-Path $EarlyChangedRunDirectory 'state.csv'))
        $controlLater = @($controlStateRows | Where-Object { $_.t -eq '100.050000000' })
        $changedLater = @($changedStateRows | Where-Object { $_.t -eq '100.050000000' })
        if ($controlLater.Count -ne 1 -or $changedLater.Count -ne 1) { throw 'Missing the 100.050 s sampled state row' }
        if ($controlLater[0].credit_candidate -ne '00001E' -or $changedLater[0].credit_candidate -ne '000012') { throw 'Later sampled credit_candidate values differ from the recorded gate' }
        if ($controlLater[0].state_2f0 -ne '05' -or $changedLater[0].state_2f0 -ne '0B') { throw 'Later sampled credit values differ from the recorded gate' }
        $gate = [ordered]@{
            status = 'changed_did_not_reach_ee16'
            reason = 'The intentional 9EDC FF80->FF00 edit changes earlier natural 9ED9 results, so the fixed historical replay/scripted-pulse schedule drives the changed image to a different feature/accounting state before EE16.'
            control_reached_ee16 = $true
            control_reached_ee22 = $true
            changed_reached_ee16 = $false
            changed_reached_ee22 = $false
            physical_inputs_identical = $physicalIdentical
            control_scripted_reasons = @($controlInputs.scripted | ForEach-Object { $_.reason })
            changed_scripted_reasons = @($changedInputs.scripted | ForEach-Object { $_.reason })
            early_9ed9_observations_per_image = 8
            early_operand = [ordered]@{control='FF80';changed='FF00'}
            early_return_top = [ordered]@{control='0000';changed='0080'}
            arithmetic = '((operand + 0000) AND FFFF) XOR FF80 gives 0000 for FF80 and 0080 for FF00; 16-bit wrap and XOR semantics preserved'
            earliest_sampled_state_mismatch = [ordered]@{t=$mismatch.key;field=$mismatch.field;control=$mismatch.original;changed=$mismatch.changed;control_row=$mismatch.original_row;changed_row=$mismatch.changed_row}
            later_sampled_credit_mismatch = [ordered]@{t='100.050000000';control_credit_candidate=$controlLater[0].credit_candidate;changed_credit_candidate=$changedLater[0].credit_candidate;control_credit_2f0=$controlLater[0].state_2f0;changed_credit_2f0=$changedLater[0].state_2f0;control_row=$controlLater[0];changed_row=$changedLater[0]}
            attribution = 'The same eight natural 9ED9 calls differ only in the inline operand and returned top word before the first sampled state mismatch; the edit is the only semantic ROM difference.'
        }
        if ($RequireTargetComparison) { throw 'Changed run did not reach EE16/EE22; target comparison was required' }
    } else {
        Assert-N9ControlTarget $changedTargetFacts (Join-Path $ChangedRunDirectory 'roms/m4addr/a6ls.p1')
        if (!$physicalIdentical) { throw 'Changed run reached the target but its physical inputs differ from the control run' }
        Assert-N9EarlyPair $earlyControl.log $earlyChanged.log $OriginalRom $ChangedRom
    }

    $phase = [ordered]@{
        control = [ordered]@{
            reached=$true; ee16=$controlFacts.tail[0]; ee22=$controlFacts.term[0]; prefetch_y=@($controlFacts.pf | ForEach-Object { Get-N9Field $_ 'y' }); handlers=@($controlFacts.he | ForEach-Object { Get-N9Field $_ 'pc' }); composite=$controlFacts.ct[0]
        }
        changed = [ordered]@{
            reached=$changedReached
            ee16=$(if($changedReached){$changedTargetFacts.tail[0]}else{$null})
            ee22=$(if($changedReached){$changedTargetFacts.term[0]}else{$null})
            prefetch_y=@($changedTargetFacts.pf | ForEach-Object { Get-N9Field $_ 'y' })
            handlers=@($changedTargetFacts.he | ForEach-Object { Get-N9Field $_ 'pc' })
            composite=$(if($changedTargetFacts.ct.Count -gt 0){$changedTargetFacts.ct[0]}else{$null})
        }
    }
    $result = [ordered]@{
        schema_version = 1
        task = 'il-natural-06'
        generated_utc = $generated
        classification = 'Natural fresh-boot MAME 0.281 comparison with the tracked physical replay and declared scripted pulses. The original control reaches EE16/EE22 and 9ED9; the changed image does not reach EE16 with the same historical schedule. No seeded state, save state, debugger write or RAM/PC/register injection was used.'
        result_status = if ($changedReached) { 'target_comparison_complete' } else { 'gate_changed_did_not_reach_ee16' }
        target_classification = 'natural_execution'
        identities = [ordered]@{
            original = $original
            changed = $changed
            changed_offsets_hex = $offsetText
            control_run_rom = $control.run_rom
            changed_run_rom = $changedFacts.run_rom
        }
        build_binding = [ordered]@{
            source_map_sha256 = $mapHash
            build_report_sha256 = $buildHash
            output_image_sha256 = [string]$map.outputImageSha256
            body_start = [string]$map.bodyStart
            body_end_exclusive = [string]$map.bodyEndExclusive
            entries = $nodeExpected
        }
        runs = [ordered]@{
            control = [ordered]@{directory=$OriginalRunDirectory; debug_log_sha256=[string]$control.observation.debug_log_sha256; replay_sha256=$controlInputs.replay_sha256; scripted_count=$controlInputs.scripted.Count; observed_events=$controlInputs.observed_events}
            changed = [ordered]@{directory=$ChangedRunDirectory; debug_log_sha256=[string]$changedFacts.observation.debug_log_sha256; replay_sha256=$changedInputs.replay_sha256; scripted_count=$changedInputs.scripted.Count; observed_events=$changedInputs.observed_events}
            early_control = [ordered]@{directory=$EarlyOriginalRunDirectory; debug_log_sha256=[string]$earlyControl.observation.debug_log_sha256; replay_sha256=$earlyControlInputs.replay_sha256; scripted_count=$earlyControlInputs.scripted.Count}
            early_changed = [ordered]@{directory=$EarlyChangedRunDirectory; debug_log_sha256=[string]$earlyChanged.observation.debug_log_sha256; replay_sha256=$earlyChangedInputs.replay_sha256; scripted_count=$earlyChangedInputs.scripted.Count}
        }
        physical_inputs = [ordered]@{
            replay_path='evidence/mpu4/skill-cash/actions.csv'
            replay_sha256=$script:N9ReplaySha256
            replay_event_count=1249
            control_scripted=@($controlInputs.scripted | ForEach-Object { [ordered]@{first_frame=$_.first;last_frame=$_.last;port=$_.port;mask=$_.mask;reason=$_.reason} })
            changed_scripted=@($changedInputs.scripted | ForEach-Object { [ordered]@{first_frame=$_.first;last_frame=$_.last;port=$_.port;mask=$_.mask;reason=$_.reason} })
            control_observed_max_frame=$controlInputs.max_frame
            changed_observed_max_frame=$changedInputs.max_frame
            observed_port_lag_frames=1
            press_release_convention='scheduler press=first, scheduler release=last (exclusive); observed port assertion begins at first+1 and ends at last, with observed release at last+1'
            identical=$physicalIdentical
        }
        control_target = [ordered]@{
            ee16=$controlFacts.tail[0]
            prefetch=@($controlFacts.pf)
            handlers=@($controlFacts.he)
            composite=$controlFacts.ct[0]
            ee22=$controlFacts.term[0]
            literal=@('795B','FF80','787E','795B','FF80','7AAF','792F')
            expected_output_top='0000'
            downstream_counter_07d5_07d7='FFE0C0'
        }
        changed_target = if ($changedReached) { [ordered]@{ee16=$changedTargetFacts.tail[0];prefetch=@($changedTargetFacts.pf);handlers=@($changedTargetFacts.he);composite=$changedTargetFacts.ct[0];ee22=$changedTargetFacts.term[0]} } else { [ordered]@{reached=$false;prefetch=@();handlers=@();ee16=$null;ee22=$null} }
        gate = $gate
        negative_checks = [ordered]@{
            wrong_rom_identity='rejected by Assert-N9Rom'
            stale_or_relabelled_map='rejected by map hash and outputImageSha256 binding'
            altered_replay='rejected by replay SHA256 and event checks'
            missing_or_wrong_phase_hooks='rejected by exact PF/HE sequence and field checks'
            altered_prestate='rejected by TAIL/PF/HE fields'
            seeded_state_or_debugger_writes='rejected by pre-run emptiness, state directory, arguments and debugger command checks'
            bad_stack_return='rejected by 7931 sw0=EBCC and EBCC U/S checks'
            tampered_logs_or_json='rejected by raw debug-log/console hashes and observation cross-checks'
            changed_claims_success_without_target='rejected by RequireTargetComparison or missing TAIL/TERM'
        }
        limitations = @(
            'The changed image did not reach the EE16/EE22 window with the fixed historical schedule; no changed-target prestate, XOR output or downstream 07D5 counter was observed.',
            'The earliest sampled meaningful state mismatch is at 100.050 s in the 6-frame state log, not a continuous-time first divergence.',
            'Physical MPU4 hardware compatibility remains separate.'
        )
    }
    Write-N9Json $OutputPath $result 16
    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-N9Curation -OriginalRunDirectory $OriginalRunDirectory -ChangedRunDirectory $ChangedRunDirectory -EarlyOriginalRunDirectory $EarlyOriginalRunDirectory -EarlyChangedRunDirectory $EarlyChangedRunDirectory -OriginalRom $OriginalRom -ChangedRom $ChangedRom -SourceMapPath $SourceMapPath -BuildReportPath $BuildReportPath -ReplayPath $ReplayPath -OutputPath $OutputPath -RequireTargetComparison:$RequireTargetComparison | Out-Null
    Write-Output $OutputPath
}





