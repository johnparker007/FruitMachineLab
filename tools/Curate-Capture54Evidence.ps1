param(
    [string]$RunDirectory = 'artifacts/deepseek/capture-53/natural-irq-6b4d-valid',
    [string]$SourceRun = 'artifacts/deepseek/gate-28/natural-service',
    [string]$RejectedRun = 'artifacts/deepseek/capture-53/natural-irq-6b4d',
    [string]$MamePath = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$OutputDirectory = 'artifacts/deepseek/capture-54',
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p) {
    if ([IO.Path]::IsPathRooted($p)) { return [IO.Path]::GetFullPath($p) }
    return [IO.Path]::GetFullPath((Join-Path $root $p))
}
function HashFile([string]$p, [string]$alg = 'SHA256') {
    return ([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($alg).ComputeHash([IO.File]::ReadAllBytes($p))) -replace '-', '')
}
function HashBytes([byte[]]$bytes, [string]$alg = 'SHA256') {
    return ([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create($alg).ComputeHash($bytes)) -replace '-', '')
}
function Hx([string]$s) { return [Convert]::ToInt64($s, 16) }
function U16([byte[]]$bytes, [int]$addr) { return (([int]$bytes[$addr] -shl 8) -bor [int]$bytes[$addr + 1]) }
function Write-Json([string]$path, $obj) {
    $json = $obj | ConvertTo-Json -Depth 16
    [IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))
}
function Add-Check($list, [string]$id, [bool]$ok, [string]$detail) {
    $list.Add([ordered]@{ id = $id; ok = $ok; detail = $detail }) | Out-Null
}
function Get-RomInfo([string]$romDir) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $romDir 'm4addr.zip'
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entry = $zip.GetEntry('a6ls.p1')
        if (-not $entry) { throw 'Missing a6ls.p1 in m4addr.zip' }
        $ms = [IO.MemoryStream]::new()
        $stream = $entry.Open()
        $stream.CopyTo($ms)
        $stream.Dispose()
        $bytes = $ms.ToArray()
        $ms.Dispose()
    }
    finally { $zip.Dispose() }
    return [ordered]@{
        zipPath = $zipPath
        zipSha256 = HashFile $zipPath
        entry = 'a6ls.p1'
        bytes = $bytes
        length = $bytes.Length
        sha1 = HashBytes $bytes 'SHA1'
        sha256 = HashBytes $bytes 'SHA256'
    }
}
function Get-StackBytes([int]$mask) {
    $c = 0
    foreach ($bit in @(0x80, 0x40, 0x20, 0x10)) { if (($mask -band $bit) -ne 0) { $c += 2 } }
    foreach ($bit in @(0x08, 0x04, 0x02, 0x01)) { if (($mask -band $bit) -ne 0) { $c += 1 } }
    return $c
}
function Get-RegList([int]$mask, [bool]$pull) {
    if ($pull) {
        $order = @(@(0x01, 'CC'), @(0x02, 'A'), @(0x04, 'B'), @(0x08, 'DP'), @(0x10, 'X'), @(0x20, 'Y'), @(0x40, 'U'), @(0x80, 'PC'))
    }
    else {
        $order = @(@(0x80, 'PC'), @(0x40, 'Y'), @(0x20, 'U'), @(0x10, 'X'), @(0x08, 'DP'), @(0x04, 'B'), @(0x02, 'A'), @(0x01, 'CC'))
    }
    $parts = [Collections.Generic.List[string]]::new()
    $both = (($mask -band 0x06) -eq 0x06)
    $addedD = $false
    foreach ($item in $order) {
        $bit = [int]$item[0]
        $name = [string]$item[1]
        if (($mask -band $bit) -eq 0) { continue }
        if ($both -and ($name -eq 'A' -or $name -eq 'B')) {
            if (-not $addedD) { $parts.Add('D'); $addedD = $true }
            continue
        }
        $parts.Add($name)
    }
    return ($parts -join ',')
}
function Decode-Instruction([byte[]]$rom, [int]$addr) {
    if ($addr -lt 0 -or $addr -ge $rom.Length) { throw "ROM address out of range: $addr" }
    $op = [int]$rom[$addr]
    $len = 0; $text = ''; $kind = ''; $target = $null; $mask = 0
    if ($op -eq 0x10) {
        $op2 = [int]$rom[$addr + 1]
        if ($op2 -eq 0x27 -or $op2 -eq 0x26) {
            $len = 4
            $rel = ((([int]$rom[$addr + 2]) -shl 8) -bor ([int]$rom[$addr + 3]))
            if ($rel -ge 32768) { $rel -= 65536 }
            $target = ($addr + 4 + $rel) -band 0xFFFF
            if ($op2 -eq 0x27) { $kind = 'LBEQ'; $text = ('LBEQ ${0:X4}' -f $target) }
            else { $kind = 'LBNE'; $text = ('LBNE ${0:X4}' -f $target) }
        }
        else { throw ('Unsupported prefixed opcode 10 {0:X2} at {1:X4}' -f $op2, $addr) }
    }
    else {
        switch ($op) {
            0x0D { $len = 2; $kind = 'TST'; $text = ('TST <${0:X2}' -f [int]$rom[$addr + 1]) }
            0x0F { $len = 2; $kind = 'CLR'; $text = ('CLR <${0:X2}' -f [int]$rom[$addr + 1]) }
            0x16 {
                $len = 3; $kind = 'LBRA'
                $rel = ((([int]$rom[$addr + 1]) -shl 8) -bor ([int]$rom[$addr + 2]))
                if ($rel -ge 32768) { $rel -= 65536 }
                $target = ($addr + 3 + $rel) -band 0xFFFF
                $text = ('LBRA ${0:X4}' -f $target)
            }
            0x26 {
                $len = 2; $kind = 'BNE'
                $rel = [int]$rom[$addr + 1]; if ($rel -ge 128) { $rel -= 256 }
                $target = ($addr + 2 + $rel) -band 0xFFFF
                $text = ('BNE ${0:X4}' -f $target)
            }
            0x27 {
                $len = 2; $kind = 'BEQ'
                $rel = [int]$rom[$addr + 1]; if ($rel -ge 128) { $rel -= 256 }
                $target = ($addr + 2 + $rel) -band 0xFFFF
                $text = ('BEQ ${0:X4}' -f $target)
            }
            0x34 { $len = 2; $kind = 'PSHS'; $mask = [int]$rom[$addr + 1]; $text = ('PSHS {0}' -f (Get-RegList $mask $false)) }
            0x35 { $len = 2; $kind = 'PULS'; $mask = [int]$rom[$addr + 1]; $text = ('PULS {0}' -f (Get-RegList $mask $true)) }
            0x39 { $len = 1; $kind = 'RTS'; $text = 'RTS' }
            0x7D { $len = 3; $kind = 'TST'; $word = (([int]$rom[$addr + 1] -shl 8) -bor [int]$rom[$addr + 2]); $text = ('TST ${0:X4}' -f $word) }
            0x84 { $len = 2; $kind = 'ANDA'; $text = ('ANDA #${0:X2}' -f [int]$rom[$addr + 1]) }
            0x8E { $len = 3; $kind = 'LDX'; $word = (([int]$rom[$addr + 1] -shl 8) -bor [int]$rom[$addr + 2]); $text = ('LDX #${0:X4}' -f $word) }
            0x96 { $len = 2; $kind = 'LDA'; $text = ('LDA <${0:X2}' -f [int]$rom[$addr + 1]) }
            0xB1 { $len = 3; $kind = 'CMPA'; $word = (([int]$rom[$addr + 1] -shl 8) -bor [int]$rom[$addr + 2]); $text = ('CMPA ${0:X4}' -f $word) }
            0xB6 { $len = 3; $kind = 'LDA'; $word = (([int]$rom[$addr + 1] -shl 8) -bor [int]$rom[$addr + 2]); $text = ('LDA ${0:X4}' -f $word) }
            0xBD { $len = 3; $kind = 'JSR'; $word = (([int]$rom[$addr + 1] -shl 8) -bor [int]$rom[$addr + 2]); $target = $word; $text = ('JSR ${0:X4}' -f $word) }
            0xBF { $len = 3; $kind = 'STX'; $word = (([int]$rom[$addr + 1] -shl 8) -bor [int]$rom[$addr + 2]); $text = ('STX ${0:X4}' -f $word) }
            default { throw ('Unsupported opcode {0:X2} at {1:X4}' -f $op, $addr) }
        }
    }
    return [ordered]@{ len = $len; text = $text; kind = $kind; target = $target; mask = $mask }
}
function Parse-HexFields([string]$line) {
    $h = [ordered]@{}
    foreach ($m in [regex]::Matches($line, '([A-Za-z0-9_]+)=([0-9A-Fa-f]+)')) {
        $h[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    return $h
}
function Get-TreeFingerprint([string]$dir) {
    $files = @(Get-ChildItem -LiteralPath $dir -Recurse -File | Sort-Object FullName)
    $entries = @()
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($dir.Length).TrimStart('\', '/')
        $entries += [ordered]@{ path = $rel.Replace('\', '/'); bytes = $f.Length; sha256 = (HashFile $f.FullName) }
    }
    $json = $entries | ConvertTo-Json -Depth 6
    return [ordered]@{
        fileCount = $entries.Count
        aggregateSha256 = (HashBytes ([Text.Encoding]::UTF8.GetBytes($json)))
        entries = $entries
    }
}
function Get-SourceFingerprint([string]$dir) {
    $entries = @()
    foreach ($n in @('input.lua', 'replay-actions.csv')) {
        $p = Join-Path $dir $n
        $entries += [ordered]@{ path = $n; bytes = (Get-Item -LiteralPath $p).Length; sha256 = (HashFile $p) }
    }
    return [ordered]@{ fileCount = $entries.Count; aggregateSha256 = (HashBytes ([Text.Encoding]::UTF8.GetBytes(($entries | ConvertTo-Json -Depth 6)))); entries = $entries }
}
function Set-CaseArgumentsPaths([string]$caseRun, [string]$originalRun) {
    $p = Join-Path $caseRun 'arguments.json'
    $a = @(Get-Content -LiteralPath $p -Raw | ConvertFrom-Json)
    for ($i = 0; $i -lt $a.Count; $i++) {
        $a[$i] = ([string]$a[$i]).Replace($originalRun, $caseRun)
    }
    [IO.File]::WriteAllText($p, ($a | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
}
function New-DerivedInput([string]$sourceText) {
    $once = [regex]::Matches($sourceText, [regex]::Escape('local setup_callbacks_to_skip=36')).Count
    if ($once -ne 1) { throw "Expected one skip-guard assignment, found $once" }
    $step1 = $sourceText.Replace('local setup_callbacks_to_skip=36', 'local setup_callbacks_to_skip=0')
    $assertPattern = "\r?\n if setup_callbacks_to_skip>0 then\r?\n  assert\(m\.time:as_double\(\)<0\.001,'Unexpected running frame during debugger setup'\)\r?\n  setup_callbacks_to_skip=setup_callbacks_to_skip-1\r?\n  return\r?\n end"
    $assertCount = [regex]::Matches($step1, $assertPattern).Count
    if ($assertCount -ne 1) { throw "Expected one startup assertion block, found $assertCount" }
    return [regex]::Replace($step1, $assertPattern, '')
}
function Invoke-Validation {
    param(
        [string]$RunDirectory,
        [string]$SourceRun,
        [string]$RejectedRun,
        [string]$MamePath,
        [string]$RomDirectory,
        $RomInfo,
        [string]$MameSha256
    )
    $checks = [Collections.Generic.List[object]]::new()
    $facts = [ordered]@{}
    try {
        $run = Abs $RunDirectory
        $source = Abs $SourceRun
        $rejected = Abs $RejectedRun
        $rom = $RomInfo
        if (-not $rom) { $rom = Get-RomInfo $RomDirectory }
        $mameHash = $MameSha256
        if (-not $mameHash) { $mameHash = HashFile $MamePath }
        $romBytes = [byte[]]$rom.bytes

        $expectedRomSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
        $expectedRomZip = 'E2553AFA6B8E9DEF55BD920E4BED77A4324696C1E358B73BE70BFD2C58179989'
        $expectedMame = '0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
        $expectedSourceInput = '7C664323A5725E9FB294CB201B17B855564AF2E4A500560ED499F1EE45179D0D'
        $expectedDerivedInput = 'BC93C0699861A2B3DE402489DD09BEA95E0438C27A1F79698430B7E68A475957'
        $expectedReplay = '4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
        Add-Check $checks 'rom' ($rom.sha1 -eq $expectedRomSha1 -and $rom.length -eq 65536 -and $rom.zipSha256 -eq $expectedRomZip) "entry=$($rom.entry) bytes=$($rom.length) sha1=$($rom.sha1) zipSha256=$($rom.zipSha256)"
        Add-Check $checks 'mame' ($mameHash -eq $expectedMame) "sha256=$mameHash"
        $facts['rom'] = [ordered]@{ entry = $rom.entry; bytes = $rom.length; sha1 = $rom.sha1; zipSha256 = $rom.zipSha256; sha256 = $rom.sha256 }
        $facts['mameSha256'] = $mameHash

        $runFiles = @('debug.log', 'routine.trace', 'debugger.cmd', 'arguments.json', 'input.lua', 'replay-actions.csv', 'provenance.json', 'exit-code.txt', 'console.txt', 'stderr.txt', 'fec3.bin', 'fec6.bin', '6b4d-entry.bin', '5330-entry.bin', '5330-call-site.bin', '51b1-entry.bin', 'fc4d.bin')
        $missing = @($runFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $run $_)) })
        Add-Check $checks 'required-files' ($missing.Count -eq 0) "missing=$($missing -join ',')"
        if ($missing.Count -gt 0) { throw "Missing required files: $($missing -join ', ')" }

        $sourceInput = Join-Path $source 'input.lua'
        $sourceReplay = Join-Path $source 'replay-actions.csv'
        Add-Check $checks 'source-files' ((Test-Path -LiteralPath $sourceInput) -and (Test-Path -LiteralPath $sourceReplay)) "$sourceInput; $sourceReplay"
        if (-not (Test-Path -LiteralPath $sourceInput)) { throw 'Missing source input.lua' }
        if (-not (Test-Path -LiteralPath $sourceReplay)) { throw 'Missing source replay-actions.csv' }
        $sourceInputHash = HashFile $sourceInput
        $sourceReplayHash = HashFile $sourceReplay
        Add-Check $checks 'source-hashes' ($sourceInputHash -eq $expectedSourceInput -and $sourceReplayHash -eq $expectedReplay) "input=$sourceInputHash replay=$sourceReplayHash"
        $facts['source'] = [ordered]@{ inputLuaSha256 = $sourceInputHash; replayActionsSha256 = $sourceReplayHash }

        $runInputText = [IO.File]::ReadAllText((Join-Path $run 'input.lua'))
        $runInputHash = HashFile (Join-Path $run 'input.lua')
        $runReplayHash = HashFile (Join-Path $run 'replay-actions.csv')
        Add-Check $checks 'replay-run-hash' ($runReplayHash -eq $expectedReplay) "sha256=$runReplayHash"
        try {
            $derived = New-DerivedInput ([IO.File]::ReadAllText($sourceInput))
            $derivedHash = HashBytes ([Text.Encoding]::UTF8.GetBytes($derived)) 'SHA256'
            Add-Check $checks 'input-derivation' ($derived -ceq $runInputText -and $derivedHash -eq $runInputHash -and $runInputHash -eq $expectedDerivedInput) "derived=$derivedHash run=$runInputHash expected=$expectedDerivedInput"
            $facts['inputDerivation'] = [ordered]@{ sourceSha256 = $sourceInputHash; derivedSha256 = $derivedHash; runSha256 = $runInputHash; patch = 'skip guard 36->0; removed only startup frame assertion; replay/event code unchanged' }
        }
        catch {
            Add-Check $checks 'input-derivation' $false $_.Exception.Message
        }

        $provenance = Get-Content -LiteralPath (Join-Path $run 'provenance.json') -Raw | ConvertFrom-Json
        $debuggerHash = HashFile (Join-Path $run 'debugger.cmd')
        $argumentsHash = HashFile (Join-Path $run 'arguments.json')
        $traceHash = HashFile (Join-Path $run 'routine.trace')
        Add-Check $checks 'provenance-fields' ($provenance.rom_entry -eq 'a6ls.p1' -and $provenance.rom_sha1 -eq $expectedRomSha1 -and [int]$provenance.rom_bytes -eq 65536 -and $provenance.rom_zip_sha256 -eq $expectedRomZip -and $provenance.mame_sha256 -eq $expectedMame -and $provenance.mame_version -eq '0.281' -and $provenance.source_input_lua_sha256 -eq $expectedSourceInput -and $provenance.derived_input_lua_sha256 -eq $expectedDerivedInput -and $provenance.source_replay_actions_sha256 -eq $expectedReplay -and $provenance.input_lua_patch -match 'removed only' -and $provenance.classification -match 'controlled replay natural' -and $provenance.classification -match 'no RAM/register/PTM/ACK/end-state injection' -and $provenance.watchpoint -match 'no memory write') 'provenance pins ROM/MAME/input/replay/classification/watchpoint'
        Add-Check $checks 'debugger-hash' ($provenance.debugger_sha256 -eq $debuggerHash) "computed=$debuggerHash provenance=$($provenance.debugger_sha256)"
        $facts['provenance'] = [ordered]@{ debuggerSha256 = $debuggerHash; argumentsSha256 = $argumentsHash; routineTraceSha256 = $traceHash; secondsToRun = [int]$provenance.seconds_to_run; hardTimeoutSeconds = [int]$provenance.hard_timeout_seconds; eventCap = [int]$provenance.event_cap; instructionCap = [int]$provenance.instruction_cap }

        $expectedArgs = @('m4addr', '-noreadconfig', '-rompath', (Abs $RomDirectory), '-cfg_directory', (Join-Path $run 'cfg'), '-nvram_directory', (Join-Path $run 'nvram'), '-input_directory', (Join-Path $run 'inp'), '-snapshot_directory', (Join-Path $run 'snap'), '-comment_directory', (Join-Path $run 'comments'), '-state_directory', (Join-Path $run 'state'), '-diff_directory', (Join-Path $run 'diff'), '-autoboot_delay', '0', '-autoboot_script', (Join-Path $run 'input.lua'), '-debug', '-debugger', 'windows', '-debugscript', (Join-Path $run 'debugger.cmd'), '-debuglog', '-video', 'none', '-sound', 'none', '-window', '-skip_gameinfo', '-nothrottle', '-seconds_to_run', '430')
        $argsActual = @(Get-Content -LiteralPath (Join-Path $run 'arguments.json') -Raw | ConvertFrom-Json)
        $argEqual = ($argsActual.Count -eq $expectedArgs.Count)
        if ($argEqual) {
            for ($i = 0; $i -lt $expectedArgs.Count; $i++) {
                if ([string]$argsActual[$i] -ne [string]$expectedArgs[$i]) { $argEqual = $false; break }
            }
        }
        $deny = @('-state', '-playback', '-record', '-playback_file', '-state_file', '-inp')
        $denied = @($argsActual | Where-Object { $deny -contains [string]$_ })
        Add-Check $checks 'arguments-isolation' ($argEqual -and $denied.Count -eq 0) "exact=$argEqual denied=$($denied -join ',')"
        $allDirsInside = $true
        foreach ($opt in @('-cfg_directory', '-nvram_directory', '-input_directory', '-snapshot_directory', '-comment_directory', '-state_directory', '-diff_directory')) {
            $idx = [Array]::IndexOf($argsActual, $opt)
            if ($idx -lt 0 -or $idx + 1 -ge $argsActual.Count) { $allDirsInside = $false; continue }
            $p = [IO.Path]::GetFullPath([string]$argsActual[$idx + 1])
            if (-not $p.StartsWith($run, [StringComparison]::OrdinalIgnoreCase)) { $allDirsInside = $false }
        }
        Add-Check $checks 'arguments-directories-inside-run' $allDirsInside "all writable MAME directories under $run"
        $facts['arguments'] = [ordered]@{ exact = $argEqual; denied = $denied; directoriesInsideRun = $allDirsInside; valued = $expectedArgs }

        $exitCode = (Get-Content -LiteralPath (Join-Path $run 'exit-code.txt') -Raw).Trim()
        Add-Check $checks 'exit-code' ($exitCode -eq '0') "exit=$exitCode"
        $console = Get-Content -LiteralPath (Join-Path $run 'console.txt') -Raw
        $stderr = Get-Content -LiteralPath (Join-Path $run 'stderr.txt') -Raw
        Add-Check $checks 'console' (($console + $stderr) -match 'Exited via the debugger' -and $stderr -notmatch '(?i)error|exception|failed') "console=$($console.Trim()) stderr=$($stderr.Trim())"
        $facts['exit'] = [ordered]@{ code = $exitCode; console = $console.Trim(); stderr = $stderr.Trim() }

        $debugLines = @(Get-Content -LiteralPath (Join-Path $run 'debug.log'))
        $headerOk = $debugLines.Count -gt 1 -and $debugLines[0] -match 'MAME debugger version 0\.281 \(mame0281\)' -and $debugLines[1] -match 'Currently targeting m4addr'
        Add-Check $checks 'debug-log-header' $headerOk "first=$($debugLines[0]) second=$($debugLines[1])"
        $badEvents = @($debugLines | Where-Object { $_ -match '^(MISSINGPAIR|OVERFLOW_stack) ' })
        $completionOk = ($debugLines -contains 'Stopped at breakpoint 7') -and ($debugLines[-1] -eq '>quit') -and $badEvents.Count -eq 0
        Add-Check $checks 'debug-log-completion' $completionOk "lines=$($debugLines.Count) stoppedBreakpoint7=$($debugLines -contains 'Stopped at breakpoint 7') badEventLines=$($badEvents.Count)"

        $anchor = [ordered]@{}
        $anchorPrefixes = @('FC', 'TRACE_ENTRY', 'E6B4D', 'E5330', 'C5330', 'E51B1', 'TRACE_RETURN')
        $anchorCountsOk = $true
        foreach ($prefix in $anchorPrefixes) {
            $matches = @($debugLines | Where-Object { $_ -match ('^' + [regex]::Escape($prefix) + ' ') })
            Add-Check $checks ('anchor-' + $prefix) ($matches.Count -eq 1) "count=$($matches.Count)"
            if ($matches.Count -ne 1) { $anchorCountsOk = $false; continue }
            $anchor[$prefix] = Parse-HexFields $matches[0]
        }
        Add-Check $checks 'anchor-counts' $anchorCountsOk 'each required anchor exactly once'
        if (-not $anchor.Contains('TRACE_ENTRY') -or -not $anchor.Contains('TRACE_RETURN')) { throw 'Missing TRACE_ENTRY or TRACE_RETURN' }
        $entryS = Hx $anchor['TRACE_ENTRY']['s']
        $entryCyc = Hx $anchor['TRACE_ENTRY']['cyc']
        $returnS = Hx $anchor['TRACE_RETURN']['s']
        $returnCyc = Hx $anchor['TRACE_RETURN']['cyc']
        $retword = Hx $anchor['TRACE_RETURN']['retword']
        Add-Check $checks 'entry-return-s' ($entryS -eq $returnS -and $entryS -eq 0x0786 -and $retword -eq 0xFEC6 -and $anchor['TRACE_ENTRY']['pc'] -eq 'FEC3' -and $anchor['TRACE_RETURN']['pc'] -eq 'FEC6') "entryS=$('{0:X4}' -f $entryS) returnS=$('{0:X4}' -f $returnS) retword=$('{0:X4}' -f $retword)"
        $entryBytesOk = ([int]$romBytes[0xFEC3] -eq 0xBD -and [int]$romBytes[0xFEC4] -eq 0x6B -and [int]$romBytes[0xFEC5] -eq 0x4D -and [int]$romBytes[0xFEC6] -eq 0xBD)
        Add-Check $checks 'entry-rom-bytes' $entryBytesOk ('FEC3={0:X2} {1:X2} {2:X2} FEC6={3:X2}' -f $romBytes[0xFEC3], $romBytes[0xFEC4], $romBytes[0xFEC5], $romBytes[0xFEC6])
        $elapsed = Hx $anchor['TRACE_RETURN']['elapsed']
        Add-Check $checks 'elapsed' ($elapsed -eq 0xAA -and ($returnCyc - $entryCyc) -eq 0xAA) "elapsed=$('{0:X}' -f $elapsed) cycleDelta=$('{0:X}' -f ($returnCyc - $entryCyc))"

        $traceLines = @(Get-Content -LiteralPath (Join-Path $run 'routine.trace'))
        Add-Check $checks 'trace-count' ($traceLines.Count -eq 32 -and $traceLines.Count -le [int]$provenance.instruction_cap) "lines=$($traceLines.Count) cap=$($provenance.instruction_cap)"
        $traceRegex = '^cyc=([0-9A-Fa-f]{16})\s+A=([0-9A-Fa-f]{2})\s+B=([0-9A-Fa-f]{2})\s+X=([0-9A-Fa-f]{4})\s+Y=([0-9A-Fa-f]{4})\s+U=([0-9A-Fa-f]{4})\s+S=([0-9A-Fa-f]{4})\s+CC=([0-9A-Fa-f]{2})\s+([0-9A-Fa-f]{4}):\s+(.+?)\s*$'
        $parsed = [Collections.Generic.List[object]]::new()
        $formatOk = $true
        foreach ($line in $traceLines) {
            $m = [regex]::Match($line, $traceRegex)
            if (-not $m.Success) { $formatOk = $false; continue }
            $parsed.Add([ordered]@{ cyc = $m.Groups[1].Value; a = $m.Groups[2].Value; b = $m.Groups[3].Value; x = $m.Groups[4].Value; y = $m.Groups[5].Value; u = $m.Groups[6].Value; s = $m.Groups[7].Value; cc = $m.Groups[8].Value; addr = $m.Groups[9].Value; text = $m.Groups[10].Value; raw = $line })
        }
        Add-Check $checks 'trace-format' ($formatOk -and $parsed.Count -eq $traceLines.Count) "parsed=$($parsed.Count)/$($traceLines.Count)"
        if ($parsed.Count -ne 32) { throw "Trace parse count $($parsed.Count) != 32" }
        $lastParsed = $parsed[$parsed.Count - 1]
        $cyclesOk = $true
        for ($i = 1; $i -lt $parsed.Count; $i++) { if ((Hx $parsed[$i].cyc) -le (Hx $parsed[$i - 1].cyc)) { $cyclesOk = $false } }
        Add-Check $checks 'trace-cycles' $cyclesOk "strictly increasing $($parsed[0].cyc)..$($lastParsed.cyc)"
        Add-Check $checks 'trace-anchors' ((Hx $parsed[0].cyc) -eq (Hx $anchor['E6B4D']['cyc']) -and (Hx $lastParsed.cyc) -eq $returnCyc -and $parsed[0].addr -eq '6B4D' -and $lastParsed.addr -eq 'FEC6' -and $parsed[0].a -eq $anchor['E6B4D']['a'] -and $parsed[0].b -eq $anchor['E6B4D']['b'] -and $parsed[0].x -eq $anchor['E6B4D']['x'] -and $parsed[0].y -eq $anchor['E6B4D']['y'] -and $parsed[0].u -eq $anchor['E6B4D']['u'] -and $parsed[0].s -eq $anchor['E6B4D']['s'] -and $parsed[0].cc -eq $anchor['E6B4D']['cc'] -and $lastParsed.a -eq $anchor['TRACE_RETURN']['a'] -and $lastParsed.b -eq $anchor['TRACE_RETURN']['b'] -and $lastParsed.x -eq $anchor['TRACE_RETURN']['x'] -and $lastParsed.y -eq $anchor['TRACE_RETURN']['y'] -and $lastParsed.u -eq $anchor['TRACE_RETURN']['u'] -and $lastParsed.s -eq $anchor['TRACE_RETURN']['s'] -and $lastParsed.cc -eq $anchor['TRACE_RETURN']['cc']) 'first=E6B4D anchor, last=TRACE_RETURN anchor, cycles/registers match'

        $decodeOk = $true
        $controlOk = $true
        $stackOk = $true
        $controlErrors = [Collections.Generic.List[string]]::new()
        $stackErrors = [Collections.Generic.List[string]]::new()
        $decodedList = [Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt $parsed.Count; $i++) {
            $p = $parsed[$i]
            $addr = [Convert]::ToInt32($p.addr, 16)
            try { $d = Decode-Instruction $romBytes $addr }
            catch { $decodeOk = $false; $decodedList.Add($null); continue }
            $decodedList.Add($d)
            $normalizedActual = ($p.text -replace '\s+', ' ').Trim()
            $normalizedExpected = ($d.text -replace '\s+', ' ').Trim()
            if ($normalizedActual -cne $normalizedExpected) { $decodeOk = $false }
            if ($i -lt $parsed.Count - 1) {
                $nextAddr = [Convert]::ToInt32($parsed[$i + 1].addr, 16)
                if ($d.kind -eq 'RTS') {
                    # Return target is proved by the S restoration and return-word anchors, not by fallthrough.
                }
                elseif ($d.kind -eq 'PULS' -and (($d.mask -band 0x80) -ne 0)) {
                    if ($nextAddr -ne $retword) { $controlOk = $false; $controlErrors.Add(('{0}: PULS..PC target {1:X4} but next {2:X4}' -f $p.addr, $retword, $nextAddr)) }
                }
                elseif ($d.kind -eq 'JSR') {
                    if ($nextAddr -ne [int]$d.target) { $controlOk = $false; $controlErrors.Add(('{0}: JSR target {1:X4} but next {2:X4}' -f $p.addr, [int]$d.target, $nextAddr)) }
                }
                elseif ($d.kind -in @('BEQ', 'BNE', 'LBEQ', 'LBNE', 'LBRA')) {
                    $z = (((Hx $p.cc) -band 0x04) -ne 0)
                    $taken = ($nextAddr -eq [int]$d.target)
                    if ($d.kind -in @('BEQ', 'LBEQ')) { $expectedTaken = $z }
                    elseif ($d.kind -in @('BNE', 'LBNE')) { $expectedTaken = (-not $z) }
                    else { $expectedTaken = $true }
                    if ($taken -ne $expectedTaken) { $controlOk = $false; $controlErrors.Add(('{0}: {1} target {2:X4} next {3:X4} Z={4} taken={5} expected={6}' -f $p.addr, $d.kind, [int]$d.target, $nextAddr, $z, $taken, $expectedTaken)) }
                }
                else {
                    if ($nextAddr -ne (($addr + $d.len) -band 0xFFFF)) { $controlOk = $false; $controlErrors.Add(('{0}: {1} len {2} expected next {3:X4} but next {4:X4}' -f $p.addr, $d.kind, $d.len, (($addr + $d.len) -band 0xFFFF), $nextAddr)) }
                }
                $effect = 0
                if ($d.kind -eq 'JSR') { $effect = -2 }
                elseif ($d.kind -eq 'RTS') { $effect = 2 }
                elseif ($d.kind -eq 'PSHS') { $effect = -(Get-StackBytes ([int]$d.mask)) }
                elseif ($d.kind -eq 'PULS') { $effect = Get-StackBytes ([int]$d.mask) }
                if ($effect -ne 0) {
                    if ((Hx $parsed[$i + 1].s) -ne ((Hx $p.s) + $effect)) { $stackOk = $false; $stackErrors.Add(('{0}: {1} S {2:X4}->{3:X4} expected {4:X4}' -f $p.addr, $d.kind, (Hx $p.s), (Hx $parsed[$i + 1].s), ((Hx $p.s) + $effect))) }
                }
            }
        }
        Add-Check $checks 'trace-opcode-rom' $decodeOk 'each trace mnemonic/operand equals independent decode of actual a6ls.p1 bytes'
        Add-Check $checks 'trace-control-flow' $controlOk ("instruction lengths and taken/not-taken branch targets match instruction flags; errors=" + ($controlErrors -join ' | '))
        Add-Check $checks 'trace-stack' $stackOk ("S changes exactly for JSR/RTS/PSHS/PULS; errors=" + ($stackErrors -join ' | '))
        $facts['trace'] = [ordered]@{ lines = $traceLines.Count; firstCycle = $parsed[0].cyc; lastCycle = $lastParsed.cyc; entryS = ('{0:X4}' -f $entryS); returnS = ('{0:X4}' -f $returnS); retword = ('{0:X4}' -f $retword); elapsed = ('{0:X}' -f $elapsed); path = @($parsed | ForEach-Object { $_.addr + ': ' + ($_.text -replace '\s+', ' ') }); rows = @($traceLines) }

        $sw = [Collections.Generic.List[object]]::new()
        foreach ($line in $debugLines) {
            if ($line -match '^SW ') { $sw.Add((Parse-HexFields $line)) }
        }
        $eventCap = [int]$provenance.event_cap
        $overflowEvents = @($debugLines | Where-Object { $_ -match '^OVERFLOW_stack ' })
        Add-Check $checks 'event-cap' ($sw.Count -le $eventCap -and $overflowEvents.Count -eq 0) "watchEvents=$($sw.Count) cap=$eventCap overflowEvents=$($overflowEvents.Count)"
        $fec6Taps = @($sw | Where-Object { $_['pc'] -eq 'FEC6' })
        $lowTap = @($fec6Taps | Where-Object { (Hx $_['cyc']) -eq $entryCyc -and (Hx $_['s']) -eq ($entryS - 1) -and (Hx $_['wpaddr']) -eq ($entryS - 1) -and (Hx $_['new']) -eq ($retword -band 0xFF) })
        $highTap = @($fec6Taps | Where-Object { (Hx $_['cyc']) -eq $entryCyc -and (Hx $_['s']) -eq ($entryS - 2) -and (Hx $_['wpaddr']) -eq ($entryS - 2) -and (Hx $_['new']) -eq (($retword -shr 8) -band 0xFF) })
        $otherTaps = @($fec6Taps | Where-Object { -not ((Hx $_['cyc']) -eq $entryCyc -and (Hx $_['s']) -in @(($entryS - 1), ($entryS - 2))) })
        $tapOk = ($highTap.Count -eq 1 -and $lowTap.Count -eq 1 -and $fec6Taps.Count -eq 2 -and $otherTaps.Count -eq 0)
        Add-Check $checks 'fec3-push-watchpoint' $tapOk "fec6Taps=$($fec6Taps.Count) high=$($highTap.Count) low=$($lowTap.Count) other=$($otherTaps.Count) cycle=$('{0:X}' -f $entryCyc) entryS=$('{0:X4}' -f $entryS)"
        if ($highTap.Count -eq 1) {
            $h = $highTap[0]
            $contextOk = ((Hx $h['opm3']) -eq [int]$romBytes[0xFEC3] -and (Hx $h['opm2']) -eq [int]$romBytes[0xFEC4] -and (Hx $h['opm1']) -eq [int]$romBytes[0xFEC5] -and (Hx $h['op0']) -eq [int]$romBytes[0xFEC6] -and (Hx $h['op1']) -eq [int]$romBytes[0xFEC7] -and (Hx $h['op2']) -eq [int]$romBytes[0xFEC8] -and (Hx $h['opm4']) -eq [int]$romBytes[0xFEC2])
            Add-Check $checks 'watchpoint-opcode-context' $contextOk 'FEC2..FEC9 bytes match selected JSR and following FEC6 JSR in actual ROM'
        }
        else { Add-Check $checks 'watchpoint-opcode-context' $false 'no unique high tap' }
        $facts['watchpoint'] = [ordered]@{
            acceptedEntryS = ('{0:X4}' -f $entryS)
            acceptedEntryCycle = ('{0:X}' -f $entryCyc)
            retword = ('{0:X4}' -f $retword)
            acceptedTaps = @($fec6Taps | ForEach-Object { [ordered]@{ pc = $_['pc']; cycle = $_['cyc']; s = $_['s']; wpaddr = $_['wpaddr']; old = $_['old']; new = $_['new'] } })
            otherFec6TapCount = $otherTaps.Count
            selectionRule = 'pc=FEC6 AND cycle=TRACE_ENTRY.cycle AND (S,wpaddr)=(entryS-1,entryS-2) AND new=return-word low byte then high byte'
        }

        $rejectedEntryS = $null; $rejectedTaps = @(); $rejectedTraceHasCycle = $null; $rejectedHasE5330 = $null; $rejectedHasC5330 = $null
        if (Test-Path -LiteralPath (Join-Path $rejected 'debug.log')) {
            $rejLines = @(Get-Content -LiteralPath (Join-Path $rejected 'debug.log'))
            $rejEntry = @($rejLines | Where-Object { $_ -match '^TRACE_ENTRY ' })
            if ($rejEntry.Count -eq 1) { $rejectedEntryS = Hx (Parse-HexFields $rejEntry[0])['s'] }
            $rejectedTaps = @($rejLines | Where-Object { $_ -match '^SW ' -and $_ -match 'pc=FEC6' } | ForEach-Object { $h = Parse-HexFields $_; [ordered]@{ s = $h['s']; wpaddr = $h['wpaddr']; old = $h['old']; new = $h['new'] } })
            $rejectedHasE5330 = [bool]($rejLines -match '^E5330 ')
            $rejectedHasC5330 = [bool]($rejLines -match '^C5330 ')
            if (Test-Path -LiteralPath (Join-Path $rejected 'routine.trace')) { $rejectedTraceHasCycle = [bool](@(Get-Content -LiteralPath (Join-Path $rejected 'routine.trace')) -match '^cyc=') }
        }
        $rejectedValuesOk = ($rejectedTaps.Count -eq 2 -and $rejectedTaps[0].new -eq 'C6' -and $rejectedTaps[1].new -eq 'FE')
        $sourceOccurrenceOk = ($rejectedEntryS -eq 0x078D -and $rejectedTaps.Count -eq 2 -and (Hx $rejectedTaps[0].s) -eq 0x078C -and (Hx $rejectedTaps[1].s) -eq 0x078B -and $rejectedValuesOk -and $entryS -ne 0x078C -and $rejectedTraceHasCycle -eq $false)
        Add-Check $checks 'watchpoint-source-occurrence' $sourceOccurrenceOk "acceptedEntryS=$('{0:X4}' -f $entryS) acceptedTaps=$((@($fec6Taps | ForEach-Object { $_['s'] })) -join ',') rejectedEntryS=$('{0:X4}' -f $rejectedEntryS) rejectedTaps=$((@($rejectedTaps | ForEach-Object { $_.s })) -join ',') rejectedTraceHasCycle=$rejectedTraceHasCycle rejectedE5330=$rejectedHasE5330 rejectedC5330=$rejectedHasC5330"
        $facts['watchpointContradiction'] = [ordered]@{
            quotedInCapture53Result = 'FEC6 tap quoted at cycle 0x3C58DAC, S=078C with 078C=FE, 078B=C6'
            quotedCycle = '0x3C58DAC is the accepted-run entry/tap cycle; it is not the rejected-run cycle'
            quotedValuesBelongTo = 'rejected first run natural-irq-6b4d, whose actual taps are S=078C new C6 and S=078B new FE and whose TRACE_ENTRY S=078D; the quote also reverses the two bytes'
            acceptedRunActual = 'FEC6 taps S=0785 new C6 (low byte) then S=0784 new FE (high byte), same cycle as accepted TRACE_ENTRY S=0786'
            correction = 'Do not pair a FEC6 tap with a selected FEC3 JSR by PC alone; require cycle plus S/wpaddr plus return-word bytes. The 078C/078B quote belongs to the rejected run and must not be used with the accepted entry S=0786.'
            rejectedRun = [ordered]@{ entryS = ('{0:X4}' -f $rejectedEntryS); taps = $rejectedTaps; traceHasCycleColumns = $rejectedTraceHasCycle; hasE5330 = $rejectedHasE5330; hasC5330 = $rejectedHasC5330 }
        }

        $binNames = @('fec3.bin', 'fec6.bin', '6b4d-entry.bin', '5330-entry.bin', '5330-call-site.bin', '51b1-entry.bin', 'fc4d.bin')
        $binOk = $true
        foreach ($n in $binNames) { if ((Get-Item -LiteralPath (Join-Path $run $n)).Length -ne 2048) { $binOk = $false } }
        Add-Check $checks 'saved-size' $binOk 'all snapshot/save files are 2048 bytes'
        $bins = [ordered]@{}
        foreach ($n in $binNames) { $bins[$n.Replace('.bin', '')] = [IO.File]::ReadAllBytes((Join-Path $run $n)) }
        $fec3 = $bins['fec3']; $e6b4d = $bins['6b4d-entry']; $e5330 = $bins['5330-entry']; $c5330 = $bins['5330-call-site']; $e51b1 = $bins['51b1-entry']; $fec6 = $bins['fec6']
        $anchorRows = @(
            @('0x83', 'FF', [int]$fec3[0x83]), @('0x02', '00', [int]$fec3[0x02]), @('byte 0x323', '00', [int]$fec3[0x323]), @('word 0x323', '000C', (U16 $fec3 0x323)), @('0x84', 'FF', [int]$fec3[0x84]), @('0x85', '00', [int]$fec3[0x85]), @('0x7C', '00', [int]$fec3[0x7C]), @('0x71', '00', [int]$fec3[0x71]), @('0x72', '00', [int]$fec3[0x72]), @('word 0x3A5', '0000', (U16 $fec3 0x3A5)), @('word 0x3A6', '0000', (U16 $fec3 0x3A6)), @('word 0x7A', '0000', (U16 $fec3 0x7A)), @('0x73', '00', [int]$fec3[0x73]), @('0x38F', '2F', [int]$fec3[0x38F]), @('0x7D', '00', [int]$fec3[0x7D]), @('0x80', '00', [int]$fec3[0x80]), @('0x3DA', '00', [int]$fec3[0x3DA])
        )
        $anchorOk = $true
        foreach ($r in $anchorRows) {
            $got = if ($r[0] -like 'word*') { '{0:X4}' -f [int]$r[2] } else { '{0:X2}' -f ([int]$r[2] -band 0xFF) }
            if ($got -ne $r[1]) { $anchorOk = $false }
        }
        $debugAnchorOk = ($anchor['TRACE_ENTRY']['m83'] -eq 'FF' -and $anchor['TRACE_ENTRY']['m2'] -eq '00' -and $anchor['TRACE_ENTRY']['m323'] -eq '0C' -and $anchor['TRACE_ENTRY']['m85'] -eq '00' -and $anchor['TRACE_ENTRY']['m7c'] -eq '00' -and $anchor['TRACE_ENTRY']['m71'] -eq '00' -and $anchor['TRACE_ENTRY']['m72'] -eq '00' -and $anchor['TRACE_ENTRY']['m3a5'] -eq '00' -and $anchor['TRACE_ENTRY']['m3a6'] -eq '00' -and $anchor['TRACE_ENTRY']['m7a'] -eq '0000' -and $anchor['TRACE_ENTRY']['m73'] -eq '00' -and $anchor['TRACE_ENTRY']['q719b'] -eq '00' -and $anchor['TRACE_ENTRY']['msg'] -eq '2F')
        Add-Check $checks 'saved-anchors' ($anchorOk -and $debugAnchorOk) '2KB RAM bytes/words match logged anchors; m323 is w@0x323 (=000C), while byte 0x323=00 used by CMPA'
        $facts['anchors'] = [ordered]@{ rows = @($anchorRows | ForEach-Object { [ordered]@{ name = $_[0]; expected = $_[1]; actual = if ($_[0] -like 'word*') { '{0:X4}' -f [int]$_[2] } else { '{0:X2}' -f ([int]$_[2] -band 0xFF) } } }); note = 'debug field m323 is a word read (w@0x323=000C); CMPA $0323 reads byte 0x323=00; both are pinned above' }

        function Get-Deltas([byte[]]$a, [byte[]]$b) {
            $d = [Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt $a.Length; $i++) { if ($a[$i] -ne $b[$i]) { $d.Add([ordered]@{ addr = $i; old = $a[$i]; new = $b[$i] }) } }
            return $d
        }
        $deltaSets = @(
            @('fec3->6b4d', (Get-Deltas $fec3 $e6b4d), @(0x785)),
            @('6b4d->5330', (Get-Deltas $e6b4d $e5330), @(0x782, 0x783)),
            @('5330->6b6a', (Get-Deltas $e5330 $c5330), @()),
            @('6b6a->51b1', (Get-Deltas $c5330 $e51b1), @()),
            @('51b1->fec6', (Get-Deltas $e51b1 $fec6), @(0x780, 0x781, 0x782, 0x783))
        )
        $deltaOk = $true
        $deltaRows = @()
        foreach ($ds in $deltaSets) {
            $actualAddrs = @($ds[1] | ForEach-Object { $_.addr })
            if (($actualAddrs -join ',') -ne (($ds[2] | ForEach-Object { [string]$_ }) -join ',')) { $deltaOk = $false }
            $rows = @($ds[1] | ForEach-Object { [ordered]@{ addr = ('{0:X4}' -f $_.addr); old = ('{0:X2}' -f $_.old); new = ('{0:X2}' -f $_.new) } })
            $deltaRows += [ordered]@{ transition = $ds[0]; expectedAddresses = @($ds[2] | ForEach-Object { '{0:X4}' -f $_ }); actual = $rows }
        }
        Add-Check $checks 'saved-deltas' $deltaOk 'only explained stack bytes change; 5330 empty path and 51B1->51B3 introduce no additional RAM deltas'
        $facts['deltas'] = $deltaRows

        $entryPia = $anchor['TRACE_ENTRY']['piaA']
        $fcPia = $anchor['FC']['piaA']
        $piaOk = ($entryPia -match '^[0-9A-Fa-f]{12}$' -and $fcPia -match '^[0-9A-Fa-f]{12}$' -and $anchor['E6B4D']['piaA'] -eq $entryPia -and $anchor['E5330']['piaA'] -eq $entryPia -and $anchor['E51B1']['piaA'] -eq $entryPia)
        Add-Check $checks 'external-inputs' $piaOk "entryPiaA=$entryPia fcPiaA=$fcPia msg=$($anchor['TRACE_ENTRY']['msg']) q719b=$($anchor['TRACE_ENTRY']['q719b'])"
        $facts['externalInputs'] = [ordered]@{ entryPiaA = $entryPia; fcPiaA = $fcPia; msg38F = $anchor['TRACE_ENTRY']['msg']; q719b = $anchor['TRACE_ENTRY']['q719b']; note = 'PIA/device reads and q719b are logged external observations outside the 2KB RAM save; they were read only, never injected' }

        $zeroBranchesOk = ($anchor['E6B4D']['m73'] -eq '00' -and $anchor['E6B4D']['m71'] -eq '00' -and $anchor['E6B4D']['m72'] -eq '00' -and $anchor['E6B4D']['m7a'] -eq '0000' -and $anchor['E5330']['m73'] -eq '00')
        Add-Check $checks 'zero-branch-preconditions' $zeroBranchesOk '0x73=00, 0x71=00, 0x72=00, word 0x7A=0000 in the executed path'
        $facts['supported'] = @('6B4D TST 0x83=FF, (0x02&0x80)=00 equals byte 0x323=00, BEQ 6B65 CLR 0x85', '6B67 JSR 5330; 0x73=00 -> 5332 BEQ 53A9; CLR 0x7D; CLR 0x80; RTS 6B6A', '6B6A TST 0x7C=00 -> 6B72; 0x71=00; 0x72=00; word 0x3A5=0000 -> LBEQ 51B1', '51B1 PSHS X,D; 0x84 negative/Z=0 -> 51B9; LDA 0x03DA=00; LDX #03A8; STX 03D8; STX 03D6; LBRA 5282', '5282 PULS D,X,PC -> FEC6')
        $facts['unsupportedNotInferred'] = @('0x73 != 0 path at 5334 (tests 0x71/0x72/word 0x7A) is not executed', '0x71 != 0, 0x72 != 0, word 0x3A5 != 0 branches not executed', 'no 6B4D/5330 helper semantics beyond this exact zero-state instruction path', 'no pulse/active serial, timer cadence, Live integration, or audio claim')

        $debuggerLines = @(Get-Content -LiteralPath (Join-Path $run 'debugger.cmd'))
        $structOk = $true
        $structDetail = [Collections.Generic.List[string]]::new()
        foreach ($line in $debuggerLines) {
            $t = $line.Trim()
            if ($t -eq '') { continue }
            if ($t -match '^temp\d+=0$' -or $t -eq 'go' -or $t -eq 'quit') { continue }
            if ($t -match '^(bpset|wpset)\s') {
                $brace = [regex]::Match($t, '\{(.*)\}\s*$')
                if (-not $brace.Success) { $structOk = $false; $structDetail.Add("missing-action-block: $t"); continue }
                $actions = $brace.Groups[1].Value -split ';'
                foreach ($a in $actions) {
                    $x = $a.Trim()
                    if ($x -eq '') { continue }
                    if ($x -match '^printf\s+"') { continue }
                    if ($x -match '^save\s+[A-Za-z0-9_.-]+,\s*0,\s*800$') { continue }
                    if ($x -match '^temp\d+\s*=\s*[^;]+$') { continue }
                    if ($x -eq 'go' -or $x -eq 'quit') { continue }
                    if ($x -match '^trace\s') { continue }
                    if ($x -eq 'traceflush') { continue }
                    if ($x -match '^tracelog\s+".*"$') { continue }
                    $structOk = $false; $structDetail.Add("unexpected-action: $x")
                }
                continue
            }
            $structOk = $false; $structDetail.Add("unexpected-command: $t")
        }
        Add-Check $checks 'debugger-structure' $structOk "allowed=temp/bpset/wpset/go/quit; actions=printf/save/temp/trace/tracelog/go/quit; violations=$($structDetail -join ' | ')"
        $facts['debugger'] = [ordered]@{ sha256 = $debuggerHash; topLevelCommands = @($debuggerLines | Where-Object { $_.Trim() -ne '' } | ForEach-Object { ($_ -split ' ')[0] }); injectionCommandsFound = @($structDetail); note = 'no memory/register/device write, load, restore, state, or playback command' }

        $facts['classification'] = 'certified existing controlled replay natural run; no new MAME execution in capture-54; breakpoints/watchpoints/reads/2KB saves/instruction trace only'
        $facts['sourceRun'] = 'artifacts/deepseek/gate-28/natural-service'
        $facts['acceptedRun'] = 'artifacts/deepseek/capture-53/natural-irq-6b4d-valid'
        $facts['rejectedRunPath'] = 'artifacts/deepseek/capture-53/natural-irq-6b4d'
    }
    catch {
        Add-Check $checks 'validator-exception' $false $_.Exception.Message
    }
    $failed = @($checks | Where-Object { -not $_.ok })
    return [ordered]@{ pass = ($failed.Count -eq 0); checks = @($checks); failedIds = @($failed | ForEach-Object { $_.id }); facts = $facts }
}
function Copy-Directory([string]$src, [string]$dst) {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    foreach ($item in @(Get-ChildItem -LiteralPath $src -Force)) {
        Copy-Item -LiteralPath $item.FullName -Destination $dst -Recurse -Force
    }
}
function Invoke-NegativeControls {
    param($OriginalRun, $OriginalSource, $RejectedRun, $RomInfo, $MameSha256, $MamePath, $RomDirectory, $OriginalRunFingerprint, $OriginalSourceFingerprint)
    $tempBase = Join-Path ([IO.Path]::GetTempPath()) 'opencode'
    New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
    $tempRoot = Join-Path $tempBase ('capture54-selftest-' + [guid]::NewGuid().ToString('N'))
    $pristineRun = Join-Path $tempRoot 'pristine-run'
    $pristineSource = Join-Path $tempRoot 'pristine-source'
    try {
        Copy-Directory $OriginalRun $pristineRun
        New-Item -ItemType Directory -Path $pristineSource -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $OriginalSource 'input.lua') -Destination $pristineSource
        Copy-Item -LiteralPath (Join-Path $OriginalSource 'replay-actions.csv') -Destination $pristineSource
        $cases = @(
            @{ name = 'wrong-s'; expected = 'entry-return-s'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'debug.log'; $lines = @(Get-Content -LiteralPath $p)
                    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^TRACE_ENTRY ') { $lines[$i] = $lines[$i] -replace ' s=0786', ' s=078C'; break } }
                    [IO.File]::WriteAllLines($p, $lines, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'wrong-cycle'; expected = 'fec3-push-watchpoint'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'debug.log'; $lines = @(Get-Content -LiteralPath $p); $done = $false
                    for ($i = 0; $i -lt $lines.Count; $i++) { if (-not $done -and $lines[$i] -match '^SW ' -and $lines[$i] -match 'pc=FEC6') { $lines[$i] = $lines[$i] -replace 'cyc=0000000003C58DAC', 'cyc=0000000003C58DAB'; $done = $true } }
                    [IO.File]::WriteAllLines($p, $lines, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'missing-instruction'; expected = 'trace-count'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'routine.trace'; $lines = @(Get-Content -LiteralPath $p)
                    $lines = @($lines | Where-Object { $_ -notmatch '^cyc=.* 6B53: ' })
                    [IO.File]::WriteAllLines($p, $lines, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'register'; expected = 'trace-anchors'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'routine.trace'; $lines = @(Get-Content -LiteralPath $p)
                    $lines[0] = $lines[0] -replace 'A=00', 'A=01'
                    [IO.File]::WriteAllLines($p, $lines, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'opcode'; expected = 'trace-opcode-rom'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'routine.trace'; $lines = @(Get-Content -LiteralPath $p)
                    $lines[0] = $lines[0] -replace 'TST    <\$83', 'CLR    <$83'
                    [IO.File]::WriteAllLines($p, $lines, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'delta'; expected = 'saved-deltas'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'fec6.bin'; $b = [IO.File]::ReadAllBytes($p); $b[0x500] = $b[0x500] -bxor 0xFF
                    [IO.File]::WriteAllBytes($p, $b)
                }
            },
            @{ name = 'tampered-debugger'; expected = 'debugger-structure'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'debugger.cmd'; $lines = @(Get-Content -LiteralPath $p) + 'set 0x83=0'
                    [IO.File]::WriteAllLines($p, $lines, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'source'; expected = 'input-derivation'; source = $true; apply = {
                    param($r, $s)
                    $p = Join-Path $s 'input.lua'; $t = [IO.File]::ReadAllText($p)
                    $t = $t.Replace('local setup_callbacks_to_skip=36', 'local setup_callbacks_to_skip=35')
                    [IO.File]::WriteAllText($p, $t, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'argument'; expected = 'arguments-isolation'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'arguments.json'; $a = @(Get-Content -LiteralPath $p -Raw | ConvertFrom-Json); $a += '-state'
                    [IO.File]::WriteAllText($p, ($a | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'exit'; expected = 'exit-code'; apply = {
                    param($r, $s)
                    [IO.File]::WriteAllText((Join-Path $r 'exit-code.txt'), '1', [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'mispair-selected-fec6'; expected = 'fec3-push-watchpoint'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'debug.log'; $lines = @(Get-Content -LiteralPath $p); $n = 0
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        if ($lines[$i] -match '^SW ' -and $lines[$i] -match 'pc=FEC6') {
                            if ($n -eq 0) { $lines[$i] = $lines[$i] -replace 's=0785', 's=078C' -replace 'wpaddr=0785', 'wpaddr=078C' }
                            elseif ($n -eq 1) { $lines[$i] = $lines[$i] -replace 's=0784', 's=078B' -replace 'wpaddr=0784', 'wpaddr=078B' }
                            $n++
                        }
                    }
                    [IO.File]::WriteAllLines($p, $lines, [Text.UTF8Encoding]::new($false))
                }
            },
            @{ name = 'missing-low-watch'; expected = 'fec3-push-watchpoint'; apply = {
                    param($r, $s)
                    $p = Join-Path $r 'debug.log'; $lines = @(Get-Content -LiteralPath $p); $n = 0; $out = [Collections.Generic.List[string]]::new()
                    foreach ($line in $lines) {
                        if ($line -match '^SW ' -and $line -match 'pc=FEC6') { $n++; if ($n -eq 2) { continue } }
                        $out.Add($line)
                    }
                    [IO.File]::WriteAllLines($p, @($out), [Text.UTF8Encoding]::new($false))
                }
            }
        )
        $results = @()
        foreach ($case in $cases) {
            $caseRun = Join-Path $tempRoot ('case-' + $case.name + '-run')
            Copy-Directory $pristineRun $caseRun
            Set-CaseArgumentsPaths $caseRun $OriginalRun
            $caseSource = $pristineSource
            if ($case.ContainsKey('source') -and $case.source) {
                $caseSource = Join-Path $tempRoot ('case-' + $case.name + '-source')
                Copy-Directory $pristineSource $caseSource
            }
            & $case.apply $caseRun $caseSource
            $vr = Invoke-Validation -RunDirectory $caseRun -SourceRun $caseSource -RejectedRun $RejectedRun -MamePath $MamePath -RomDirectory $RomDirectory -RomInfo $RomInfo -MameSha256 $MameSha256
            $hit = ($vr.failedIds -contains $case.expected)
            $results += [ordered]@{ name = $case.name; expectedFailure = $case.expected; passed = $hit; failedIds = @($vr.failedIds) }
        }
        $afterRun = Get-TreeFingerprint $OriginalRun
        $afterSource = Get-SourceFingerprint $OriginalSource
        $originalsUnchanged = ($afterRun.aggregateSha256 -eq $OriginalRunFingerprint.aggregateSha256 -and $afterSource.aggregateSha256 -eq $OriginalSourceFingerprint.aggregateSha256)
        $allPass = (@($results | Where-Object { -not $_.passed }).Count -eq 0 -and $originalsUnchanged)
        return [ordered]@{ pass = $allPass; cases = $results; originalsUnchanged = $originalsUnchanged; originalRunFingerprint = $OriginalRunFingerprint.aggregateSha256; originalSourceFingerprint = $OriginalSourceFingerprint.aggregateSha256 }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$runPath = Abs $RunDirectory
$sourcePath = Abs $SourceRun
$rejectedPath = Abs $RejectedRun
$mame = Abs $MamePath
$romDir = Abs $RomDirectory
$outDir = Abs $OutputDirectory
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$romInfo = Get-RomInfo $romDir
$mameHash = HashFile $mame
$runFingerprint = Get-TreeFingerprint $runPath
$sourceFingerprint = Get-SourceFingerprint $sourcePath

$validation = Invoke-Validation -RunDirectory $runPath -SourceRun $sourcePath -RejectedRun $rejectedPath -MamePath $mame -RomDirectory $romDir -RomInfo $romInfo -MameSha256 $mameHash
$negative = $null
if ($SelfTest) {
    $negative = Invoke-NegativeControls -OriginalRun $runPath -OriginalSource $sourcePath -RejectedRun $rejectedPath -RomInfo $romInfo -MameSha256 $mameHash -MamePath $mame -RomDirectory $romDir -OriginalRunFingerprint $runFingerprint -OriginalSourceFingerprint $sourceFingerprint
}
$runAfter = Get-TreeFingerprint $runPath
$sourceAfter = Get-SourceFingerprint $sourcePath
$originalsUnchanged = ($runAfter.aggregateSha256 -eq $runFingerprint.aggregateSha256 -and $sourceAfter.aggregateSha256 -eq $sourceFingerprint.aggregateSha256)

$curated = [ordered]@{
    attempt = 2
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    classification = 'certified existing evidence only; no new MAME run'
    acceptedRun = 'artifacts/deepseek/capture-53/natural-irq-6b4d-valid'
    rejectedRun = 'artifacts/deepseek/capture-53/natural-irq-6b4d'
    sourceRun = 'artifacts/deepseek/gate-28/natural-service'
    rom = $validation.facts['rom']
    mame = [ordered]@{ sha256 = $validation.facts['mameSha256']; version = '0.281' }
    source = $validation.facts['source']
    inputDerivation = $validation.facts['inputDerivation']
    arguments = $validation.facts['arguments']
    debugger = $validation.facts['debugger']
    trace = $validation.facts['trace']
    watchpoint = $validation.facts['watchpoint']
    watchpointContradiction = $validation.facts['watchpointContradiction']
    anchors = $validation.facts['anchors']
    deltas = $validation.facts['deltas']
    externalInputs = $validation.facts['externalInputs']
    supported = $validation.facts['supported']
    unsupportedNotInferred = $validation.facts['unsupportedNotInferred']
    limits = 'One existing natural occurrence only. Trace begins at 6B4D; the FEC3 JSR is proved by entry S, ROM bytes, and cycle/S/wpaddr/return-word-matched watchpoint. Nonzero 0x73/0x71/0x72/0x7A paths are not executed and are not inferred.'
}
Write-Json (Join-Path $outDir 'curated.json') $curated
$validationOut = [ordered]@{
    attempt = 2
    pass = $validation.pass
    run = 'artifacts/deepseek/capture-53/natural-irq-6b4d-valid'
    sourceRun = 'artifacts/deepseek/gate-28/natural-service'
    checks = $validation.checks
    failedIds = $validation.failedIds
    originalsUnchanged = $originalsUnchanged
    originalRunFingerprint = $runFingerprint.aggregateSha256
    originalSourceFingerprint = $sourceFingerprint.aggregateSha256
}
Write-Json (Join-Path $outDir 'validation.json') $validationOut
if ($SelfTest) { Write-Json (Join-Path $outDir 'negative-controls.json') $negative }

$manifestPaths = @(
    'tools/Curate-Capture54Evidence.ps1',
    'artifacts/deepseek/capture-54/curated.json',
    'artifacts/deepseek/capture-54/validation.json'
)
if ($SelfTest) { $manifestPaths += 'artifacts/deepseek/capture-54/negative-controls.json' }
if (Test-Path -LiteralPath (Join-Path $outDir 'result.md')) { $manifestPaths += 'artifacts/deepseek/capture-54/result.md' }
$manifestPaths += @(
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/debug.log',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/routine.trace',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/debugger.cmd',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/arguments.json',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/input.lua',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/replay-actions.csv',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/provenance.json',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/fec3.bin',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/fec6.bin',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/6b4d-entry.bin',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/5330-entry.bin',
    'artifacts/deepseek/capture-53/natural-irq-6b4d-valid/51b1-entry.bin'
)
$manifest = @()
foreach ($rel in $manifestPaths) {
    $p = Abs $rel
    if (Test-Path -LiteralPath $p) {
        $manifest += [ordered]@{ path = $rel; bytes = (Get-Item -LiteralPath $p).Length; sha256 = (HashFile $p) }
    }
}
Write-Json (Join-Path $outDir 'manifest.json') $manifest
$manifestCheck = $true
$manifestVerifyRows = @()
foreach ($entry in $manifest) {
    $p = Abs $entry.path
    $ok = $true
    $actualBytes = $null
    $actualSha = $null
    if (-not (Test-Path -LiteralPath $p)) { $ok = $false }
    else {
        $actualBytes = (Get-Item -LiteralPath $p).Length
        $actualSha = HashFile $p
        if ($actualBytes -ne [int]$entry.bytes -or $actualSha -ne $entry.sha256) { $ok = $false }
    }
    if (-not $ok) { $manifestCheck = $false }
    $manifestVerifyRows += [ordered]@{ path = $entry.path; expectedBytes = [int]$entry.bytes; actualBytes = $actualBytes; expectedSha256 = $entry.sha256; actualSha256 = $actualSha; ok = $ok }
}
$manifestCheckObj = [ordered]@{
    attempt = 2
    pass = $manifestCheck
    entryCount = $manifest.Count
    manifestSha256 = (HashFile (Join-Path $outDir 'manifest.json'))
    verifiedUtc = [DateTime]::UtcNow.ToString('o')
    entries = $manifestVerifyRows
}
Write-Json (Join-Path $outDir 'manifest-check.json') $manifestCheckObj
Write-Output ('validation_pass=' + $validation.pass)
Write-Output ('failed_ids=' + (($validation.failedIds) -join ','))
Write-Output ('negative_pass=' + ($(if ($SelfTest) { $negative.pass } else { 'not-run' })))
Write-Output ('originals_unchanged=' + $originalsUnchanged)
Write-Output ('manifest_check=' + $manifestCheck)
Write-Output ('curated=' + (Join-Path $outDir 'curated.json'))
Write-Output ('manifest=' + (Join-Path $outDir 'manifest.json'))
if (-not $validation.pass) { exit 1 }
if ($SelfTest -and -not $negative.pass) { exit 2 }
if (-not $manifestCheck) { exit 3 }
