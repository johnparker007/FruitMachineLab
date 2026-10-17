param(
    [Parameter(Mandatory=$true)][string]$OriginalRunDirectory,
    [Parameter(Mandatory=$true)][string]$RepeatRunDirectory,
    [Parameter(Mandatory=$true)][string]$RepairedRunDirectory,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'

$OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$RepairedSha1 = 'ae040f3f130934972b9e651d4dbe36ff24fb4954'
$RepairedSha256 = '66162b920b05c537a5c7bce098d883b0551951ed46aa97cd98600a3d7b789796'

function Get-HashHex([string]$Path, [string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Read-Json([string]$Path) { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) }
function Get-Field([string]$Line, [string]$Name) {
    $m = [regex]::Match($Line, ('\b' + [regex]::Escape($Name) + '=([0-9A-Fa-f]+)'))
    if (!$m.Success) { throw "Missing field $Name in: $Line" }
    return $m.Groups[1].Value.ToUpperInvariant()
}
function Find-MarkerIndex([string[]]$Lines, [string]$Pattern) {
    for ($i = 0; $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match $Pattern) { return $i } }
    return -1
}
function Require-Marker([string[]]$Lines, [string]$Pattern, [string]$Key) {
    $i = Find-MarkerIndex $Lines $Pattern
    if ($i -lt 0) { throw "Missing marker $Key" }
    return $i
}
function Assert-Run([string]$RunDirectory, [string]$Variant) {
    $provenance = Read-Json (Join-Path $RunDirectory 'provenance.json')
    $observation = Read-Json (Join-Path $RunDirectory 'observation.json')
    if ($observation.exit_code -ne 0) { throw "Run exit is not zero: $Variant" }
    $rawExitPath = Join-Path $RunDirectory 'exit-code.txt'
    if (!(Test-Path -LiteralPath $rawExitPath -PathType Leaf)) { throw "Missing raw exit file: $Variant" }
    $rawExit = 0
    if (![int]::TryParse((Get-Content -LiteralPath $rawExitPath -Raw).Trim(), [ref]$rawExit)) { throw "Invalid raw exit file: $Variant" }
    if ($rawExit -ne 0 -or $observation.exit_code -ne $rawExit) { throw "Run exit code does not match raw exit file: $Variant" }
    if ($provenance.variant -ne $Variant) { throw "Provenance variant mismatch: $Variant" }
    if ($provenance.input_mode -ne 'CoinStart') { throw "Unexpected input mode: $Variant" }
    if ($observation.rom_unchanged -ne $true) { throw "ROM copy changed: $Variant" }
    if ($observation.debug_log_sha256 -ne (Get-HashHex (Join-Path $RunDirectory 'debug.log') 'SHA256')) { throw "Debug log hash mismatch: $Variant" }
    if ($observation.console_sha256 -ne (Get-HashHex (Join-Path $RunDirectory 'console.txt') 'SHA256')) { throw "Console hash mismatch: $Variant" }
    if ($observation.input_lua_sha256 -ne (Get-HashHex (Join-Path $RunDirectory 'input.lua') 'SHA256')) { throw "Input Lua hash mismatch: $Variant" }
    if ($observation.actions_sha256 -ne (Get-HashHex (Join-Path $RunDirectory 'actions.csv') 'SHA256')) { throw "Actions hash mismatch: $Variant" }
    if ($observation.input_levels_sha256 -ne (Get-HashHex (Join-Path $RunDirectory 'input-levels.csv') 'SHA256')) { throw "Input-level hash mismatch: $Variant" }

    $expectedSha1 = if ($Variant -eq 'Original') { $OriginalSha1 } else { $RepairedSha1 }
    $expectedSha256 = if ($Variant -eq 'Original') { $OriginalSha256 } else { $RepairedSha256 }
    $runRomPath = Join-Path $RunDirectory 'roms/m4addr/a6ls.p1'
    if (!(Test-Path -LiteralPath $runRomPath -PathType Leaf)) { throw "Missing run ROM image: $Variant" }
    $rawRunSha1 = Get-HashHex $runRomPath 'SHA1'
    $rawRunSha256 = Get-HashHex $runRomPath 'SHA256'
    if ($rawRunSha1 -ne $expectedSha1 -or $rawRunSha256 -ne $expectedSha256) { throw "Run ROM image identity mismatch: $Variant" }
    if ($provenance.original_rom_sha1 -ne $OriginalSha1 -or $observation.original_rom_sha1 -ne $OriginalSha1) { throw "Original identity provenance mismatch: $Variant" }
    if ($provenance.run_rom_sha1 -ne $rawRunSha1 -or $provenance.run_rom_sha256 -ne $rawRunSha256) { throw "Provenance run image hash mismatch: $Variant" }
    if ($provenance.expected_rom_sha1 -ne $expectedSha1 -or $observation.expected_rom_sha1 -ne $expectedSha1) { throw "Variant identity mismatch: $Variant" }
    if ($provenance.expected_rom_sha256 -ne $expectedSha256 -or $observation.expected_rom_sha256 -ne $expectedSha256) { throw "Variant SHA256 mismatch: $Variant" }
    if ($observation.run_rom_sha1_after -ne $rawRunSha1 -or $observation.run_rom_sha256_after -ne $rawRunSha256) { throw "Post-run variant identity mismatch: $Variant" }

    $lines = @(Get-Content -LiteralPath (Join-Path $RunDirectory 'debug.log'))
    $specs = @(
        @{ Key='reset'; Pattern='^PLAY_RESET pc=7CD1\b' },
        @{ Key='init'; Pattern='^PLAY_INIT_ENTRY pc=6750\b' },
        @{ Key='checksum_return'; Pattern='^PLAY_ROM_CHECK_RETURN pc=677E\b' },
        @{ Key='vm_entry'; Pattern='^PLAY_VM_ENTRY pc=76C7\b' },
        @{ Key='main_first_native'; Pattern='^PLAY_MAIN_FIRST_NATIVE pc=496A\b' },
        @{ Key='attract_lamp_range'; Pattern='^PLAY_ATTRACT_LAMP_RANGE pc=4AC0\b' },
        @{ Key='lamp_init'; Pattern='^PLAY_LAMP_INIT pc=171D\b' },
        @{ Key='reel_refresh'; Pattern='^PLAY_REEL_REFRESH pc=2BEB\b' },
        @{ Key='status_service'; Pattern='^PLAY_STATUS_SERVICE pc=482F\b' },
        @{ Key='paid_spin_setup'; Pattern='^PLAY_PAID_SPIN_SETUP pc=61D6\b' },
        @{ Key='award_table_read'; Pattern='^PLAY_AWARD_TABLE_READ address=75C0 value=14\b' }
    )
    $markers = [ordered]@{}
    $lastCycle = [uint64]0
    $lastIndex = -1
    foreach ($spec in $specs) {
        $i = Require-Marker $lines $spec.Pattern $spec.Key
        if ($i -le $lastIndex) { throw "Marker order regressed at $($spec.Key): $Variant" }
        $lastIndex = $i
        $line = $lines[$i]
        $cycle = [Convert]::ToUInt64((Get-Field $line 'cycle'),16)
        if ($cycle -lt $lastCycle) { throw "Marker cycle order regressed at $($spec.Key): $Variant" }
        $lastCycle = $cycle
        $markers[$spec.Key] = [ordered]@{ line = $line; cycle = ('{0:X16}' -f $cycle) }
    }
    $award = $markers['award_table_read'].line
    if ((Get-Field $award 'credit2f0') -ne '04') { throw "Award lookup credit state unexpected: $Variant" }
    if ((Get-Field $award 'address') -ne '75C0' -or (Get-Field $award 'value') -ne '14') { throw "Award lookup content unexpected: $Variant" }

    $actions = @(Import-Csv -LiteralPath (Join-Path $RunDirectory 'actions.csv'))
    if ($actions.Count -ne 2) { throw "Unexpected input event count: $Variant" }
    if ($actions[0].port -ne ':AUX2' -or $actions[0].mask -ne '128' -or [double]$actions[0].first_t -ne 35.0 -or [double]$actions[0].last_t -ne 35.05) { throw "Coin event mismatch: $Variant" }
    if ($actions[1].port -ne ':BLACK2' -or $actions[1].mask -ne '128' -or [double]$actions[1].first_t -ne 37.0 -or [double]$actions[1].last_t -ne 37.2) { throw "Start event mismatch: $Variant" }
    $levels = @(Import-Csv -LiteralPath (Join-Path $RunDirectory 'input-levels.csv'))
    $creditMax = ($levels | ForEach-Object { [Convert]::ToInt32($_.credit2f0,16) } | Measure-Object -Maximum).Maximum
    if ($creditMax -lt 1) { throw "No credit observed after coin: $Variant" }
    $coinFieldSeen = $false
    $startFieldSeen = $false
    foreach ($row in $levels) {
        $t = [double]$row.t
        $aux = [Convert]::ToInt32($row.aux2,16)
        $black = [Convert]::ToInt32($row.black2,16)
        if (($aux -band 128) -ne 0) {
            if ($t -lt 34.9 -or $t -gt 35.1) { throw "Coin field value outside controlled window: $Variant" }
            $coinFieldSeen = $true
        }
        if (($black -band 128) -ne 0) {
            if ($t -lt 36.9 -or $t -gt 37.3) { throw "Start field value outside controlled window: $Variant" }
            $startFieldSeen = $true
        }
    }
    if (!$coinFieldSeen) { throw "Coin field value not observed: $Variant" }
    if (!$startFieldSeen) { throw "Start field value not observed: $Variant" }
    return [ordered]@{
        source_run = [IO.Path]::GetFullPath($RunDirectory)
        variant = $Variant
        provenance = $provenance
        observation = $observation
        markers = $markers
        actions = $actions
        credit_max_after_coin = $creditMax
    }
}

function Get-RunSummary($r) {
    return [ordered]@{
        source_run = $r.source_run
        variant = $r.variant
        exit_code = $r.observation.exit_code
        expected_rom_sha1 = $r.observation.expected_rom_sha1
        expected_rom_sha256 = $r.observation.expected_rom_sha256
        run_rom_sha1_after = $r.observation.run_rom_sha1_after
        run_rom_sha256_after = $r.observation.run_rom_sha256_after
        rom_unchanged = $r.observation.rom_unchanged
        debug_log_sha256 = $r.observation.debug_log_sha256
        console_sha256 = $r.observation.console_sha256
        input_lua_sha256 = $r.observation.input_lua_sha256
        actions_sha256 = $r.observation.actions_sha256
        input_levels_sha256 = $r.observation.input_levels_sha256
        credit_max_after_coin = $r.credit_max_after_coin
        markers = $r.markers
        actions = $r.actions
    }
}
$original = Assert-Run $OriginalRunDirectory 'Original'
$repeat = Assert-Run $RepeatRunDirectory 'Original'
$repaired = Assert-Run $RepairedRunDirectory 'Repaired'
$originalMarkers = @(Get-Content -LiteralPath (Join-Path $OriginalRunDirectory 'debug.log') | Where-Object { $_ -match '^PLAY_' })
$repeatMarkers = @(Get-Content -LiteralPath (Join-Path $RepeatRunDirectory 'debug.log') | Where-Object { $_ -match '^PLAY_' })
if (Compare-Object $originalMarkers $repeatMarkers) { throw 'Independent original repeat marker lines differ' }
if ($original.markers['award_table_read'].line -ne $repaired.markers['award_table_read'].line) { throw 'Original/repaired award lookup marker differs' }
foreach ($key in $original.markers.Keys) {
    if ($original.markers[$key].cycle -ne $repaired.markers[$key].cycle) { throw "Original/repaired cycle differs at $key" }
}

$negativeResults = @()
if ($NegativeControl) {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fml-play-curator-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    try {
        function New-RunCopy([string]$Source, [string]$Name) {
            $target = Join-Path $tempRoot $Name
            Copy-Item -LiteralPath $Source -Destination $target -Recurse
            return $target
        }
        function Expect-Reject([string]$Name, [scriptblock]$Action) {
            $failed = $false
            try { & $Action } catch { $failed = $true }
            if (!$failed) { throw "Negative control was accepted: $Name" }
            return $Name
        }
        function Update-ObservedHash([string]$RunDirectory, [string]$Field, [string]$RelativePath) {
            $p = Join-Path $RunDirectory 'observation.json'
            $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
            $j.$Field = Get-HashHex (Join-Path $RunDirectory $RelativePath) 'SHA256'
            $j | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $p
        }
        $negativeResults += Expect-Reject 'award_value' {
            $r = New-RunCopy $RepairedRunDirectory 'award_value'
            $p = Join-Path $r 'debug.log'
            (Get-Content -LiteralPath $p -Raw).Replace('address=75C0 value=14','address=75C0 value=0C') | Set-Content -LiteralPath $p
            Update-ObservedHash $r 'debug_log_sha256' 'debug.log'
            Assert-Run $r 'Repaired' | Out-Null
        }
        $negativeResults += Expect-Reject 'missing_coin' {
            $r = New-RunCopy $OriginalRunDirectory 'missing_coin'
            $p = Join-Path $r 'actions.csv'
            (Get-Content -LiteralPath $p | Where-Object { $_ -notmatch ':AUX2' }) | Set-Content -LiteralPath $p
            Update-ObservedHash $r 'actions_sha256' 'actions.csv'
            Assert-Run $r 'Original' | Out-Null
        }
        $negativeResults += Expect-Reject 'marker_order' {
            $r = New-RunCopy $OriginalRunDirectory 'marker_order'
            $p = Join-Path $r 'debug.log'
            $lines = @(Get-Content -LiteralPath $p)
            $vm = $lines | Where-Object { $_ -match '^PLAY_VM_ENTRY ' }
            $lines = @($lines | Where-Object { $_ -notmatch '^PLAY_VM_ENTRY ' })
            $index = [Array]::IndexOf($lines, ($lines | Where-Object { $_ -match '^PLAY_PAID_SPIN_SETUP ' } | Select-Object -First 1))
            $lines = $lines[0..$index] + $vm + $lines[($index+1)..($lines.Count-1)]
            $lines | Set-Content -LiteralPath $p
            Update-ObservedHash $r 'debug_log_sha256' 'debug.log'
            Assert-Run $r 'Original' | Out-Null
        }
        $negativeResults += Expect-Reject 'rom_identity' {
            $r = New-RunCopy $RepairedRunDirectory 'rom_identity'
            $p = Join-Path $r 'roms/m4addr/a6ls.p1'
            $bytes = [IO.File]::ReadAllBytes($p)
            $bytes[0] = $bytes[0] -bxor 0xFF
            [IO.File]::WriteAllBytes($p, $bytes)
            Assert-Run $r 'Repaired' | Out-Null
        }
        $negativeResults += Expect-Reject 'rom_unchanged_false' {
            $r = New-RunCopy $OriginalRunDirectory 'rom_unchanged_false'
            $p = Join-Path $r 'observation.json'
            $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
            $j.rom_unchanged = $false
            $j | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $p
            Assert-Run $r 'Original' | Out-Null
        }
        $negativeResults += Expect-Reject 'debug_log_hash' {
            $r = New-RunCopy $OriginalRunDirectory 'debug_log_hash'
            Add-Content -LiteralPath (Join-Path $r 'debug.log') -Value 'tamper'
            Assert-Run $r 'Original' | Out-Null
        }
        $negativeResults += Expect-Reject 'nonzero_exit' {
            $r = New-RunCopy $OriginalRunDirectory 'nonzero_exit'
            '1' | Set-Content -LiteralPath (Join-Path $r 'exit-code.txt')
            Assert-Run $r 'Original' | Out-Null
        }
        $negativeResults += Expect-Reject 'start_event' {
            $r = New-RunCopy $OriginalRunDirectory 'start_event'
            $p = Join-Path $r 'actions.csv'
            (Get-Content -LiteralPath $p).Replace('37.000000,37.200000,:BLACK2,128,start','38.000000,38.200000,:BLACK2,128,start') | Set-Content -LiteralPath $p
            Update-ObservedHash $r 'actions_sha256' 'actions.csv'
            Assert-Run $r 'Original' | Out-Null
        }
    }
    finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

$origMarkers = @($original.markers.Values | ForEach-Object { $_.line })
$repMarkers = @($repaired.markers.Values | ForEach-Object { $_.line })
$repeatMarkers2 = @($repeat.markers.Values | ForEach-Object { $_.line })
function JsonQuote([string]$Value) { return '"' + $Value.Replace('\','\\').Replace('"','\"').Replace("`r",'').Replace("`n",'\n') + '"' }
function JsonArray([string[]]$Values) { return "[`n    " + (($Values | ForEach-Object { JsonQuote $_ }) -join ",`n    ") + "`n  ]" }
$json = "{`n" +
  "  `"schema`": 1,`n" +
  "  `"observed`": " + (JsonQuote 'Natural reset through post-VM attract, controlled coin/start, paid spin setup and natural shared-award table read') + ",`n" +
  "  `"classification`": {`n" +
  "    `"natural`": " + (JsonQuote 'Real MAME 0.281 execution on the unmodified original and the previously generated integrity-repaired image; fresh isolated directories; no PC/RAM/state/ROM injection.') + ",`n" +
  "    `"controlled`": " + (JsonQuote 'Only MAME ioport field values for AUX2 coin 128 at 35.0s and BLACK2 Start 128 at 37.0-37.2s. These are input events, not passive play.') + ",`n" +
  "    `"static`": " + (JsonQuote 'The shared table address 75BD and the changed byte 75BE come from the existing ROM patch and prior static recovery.') + ",`n" +
  "    `"hypothesis`": " + (JsonQuote 'Why the ordinary paid path reads table index 75C0 rather than the patched index 75BE is not established here.') + ",`n" +
  "    `"synthetic`": " + (JsonQuote 'Curator negative controls alter copied raw artifacts only and are rejected; they are not natural execution evidence.') + "`n" +
  "  },`n" +
  "  `"mame_sha256`": " + (JsonQuote $original.provenance.mame_sha256) + ",`n" +
  "  `"original_rom`": {`"sha1`": " + (JsonQuote $OriginalSha1) + ", `"sha256`": " + (JsonQuote $OriginalSha256) + "},`n" +
  "  `"repaired_rom`": {`"sha1`": " + (JsonQuote $RepairedSha1) + ", `"sha256`": " + (JsonQuote $RepairedSha256) + "},`n" +
  "  `"original_run`": {`n" +
  "    `"source_run`": " + (JsonQuote $original.source_run) + ",`n" +
  "    `"debug_log_sha256`": " + (JsonQuote $original.observation.debug_log_sha256) + ",`n" +
  "    `"console_sha256`": " + (JsonQuote $original.observation.console_sha256) + ",`n" +
  "    `"markers`": " + (JsonArray $origMarkers) + "`n" +
  "  },`n" +
  "  `"original_repeat`": {`n" +
  "    `"source_run`": " + (JsonQuote $repeat.source_run) + ",`n" +
  "    `"debug_log_sha256`": " + (JsonQuote $repeat.observation.debug_log_sha256) + ",`n" +
  "    `"markers_identical`": true`n" +
  "  },`n" +
  "  `"repaired_run`": {`n" +
  "    `"source_run`": " + (JsonQuote $repaired.source_run) + ",`n" +
  "    `"debug_log_sha256`": " + (JsonQuote $repaired.observation.debug_log_sha256) + ",`n" +
  "    `"console_sha256`": " + (JsonQuote $repaired.observation.console_sha256) + ",`n" +
  "    `"markers`": " + (JsonArray $repMarkers) + "`n" +
  "  },`n" +
  "  `"differential`": {`"identical_marker_cycles`": true, `"identical_award_read`": true, `"award_address`": `"75C0`", `"original_value`": `"14`", `"repaired_value`": `"14`", `"patched_byte`": `"75BE`", `"patched_byte_consumed_on_this_path`": false},`n" +
  "  `"negative_controls`": " + (JsonArray @($negativeResults)) + ",`n" +
  "  `"limitations`": " + (JsonArray @(
      'One cold reset per image; MAME only; no physical hardware.',
      'The runtime did not observe the FC99/FCA7 condition-12 preplay block with the selected debugger instrumentation. The observed input-ready evidence is credit present after coin and Start accepted into paid spin setup 61D6.',
      'The natural lookup read index 75C0, not the patched 75BE, so the 10->12 edit is not exercised by this path.',
      'No complete paid game, payout, reel result or Skill Cash feature is claimed.',
      'MAME loader CRC/SHA warnings for the repaired image remain expected and are not a firmware-integrity result.')) + "`n" +
  "}`n"
$outFull = [IO.Path]::GetFullPath($OutputPath)
$parent = Split-Path -Parent $outFull
if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
$json | Set-Content -LiteralPath $outFull
$txt = @(
    'Natural play boundary evidence',
    'original ' + $OriginalSha1 + ' -> ' + $OriginalSha256,
    'repaired ' + $RepairedSha1 + ' -> ' + $RepairedSha256,
    'markers:',
    $originalMarkers,
    'repaired award read: ' + $repaired.markers['award_table_read'].line,
    'original repeat marker lines identical',
    'negative controls: ' + ($negativeResults -join ', ')
)
$txt | Set-Content -LiteralPath ([IO.Path]::ChangeExtension($outFull,'.txt'))
Write-Output $outFull
