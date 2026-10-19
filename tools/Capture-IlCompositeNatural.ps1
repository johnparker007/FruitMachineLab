[CmdletBinding()]
param(
    [ValidateSet('Capture','Analyze','Verify')][string]$Mode = 'Capture',
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$BuiltRom,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$OriginalRom,
    [string]$RunDirectory,
    [string]$EvidencePath,
    [string]$PriorTracePath,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [string]$ReanalysisSourceRun,
    [ValidateRange(1,180)][int]$SecondsToRun = 180,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'

$script:Protocol = 'il-composite-natural-v1'
$script:Root = Split-Path $PSScriptRoot -Parent
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:OriginalSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
$script:OriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$script:BuiltSha1 = 'DC6381B9883AAFDE372D2C2AA14C817BAE839B21'
$script:BuiltSha256 = '761F34BAAC06C6F8F5DA963CCADEB276FAE9196EE1C4D9060BC915A314E3903D'
$script:MapSha256 = '9A560CA7818C7A8F56AC4E314BB5DF19E81F4EFABB23982CCC092CA648B5BCF8'
$script:FieldsHex = 'E93F3C61B5'
$script:OriginalFieldsHex = '3E761E2605'
$script:MameSha256 = '0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$script:BodyHex = '795BFF80787E795BFF807AAF792F'
$script:ExpectedDiff = @(4112,4113,4114,4115,4117,4118,4119,4120,4121,4123,4124,4125,4126,4127,40724,40725,65489,65490,65491,65492,65493)
$script:PreviousTraceSha256 = '39A1CB2FD46FA36D66C6C4B261483D298644A22FC2690BF95C4A9697265917D9'
$script:ReplaySha256 = '4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$script:InputLuaSha256 = '23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94'
$script:CoinPulseFrames = @(2100,2101,2102,2103)
$script:StartPulseFrames = @(2221,2222,2223,2224)
$script:NextFixtureActionFrame = 2400

if ([string]::IsNullOrWhiteSpace($BuiltRom)) { $BuiltRom = Join-Path $script:Root 'artifacts/deepseek/il-composite-immutability-34/il-verifier-20261019-01/composite/built-repaired.p1' }
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path (Split-Path $BuiltRom -Parent) 'composite-source-map.json' }
if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path (Split-Path $BuiltRom -Parent) 'build-report.json' }
if ([string]::IsNullOrWhiteSpace($OriginalRom)) { $OriginalRom = Join-Path $script:Root 'artifacts/deepseek/general-14/roms/original.p1' }
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { $EvidencePath = Join-Path $script:Root 'evidence/mpu4/integrity/il-composite-natural.json' }
if ([string]::IsNullOrWhiteSpace($PriorTracePath)) { $PriorTracePath = Join-Path $script:Root 'evidence/mpu4/integrity/il-lua-vm-trace.json' }
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:Root 'evidence/mpu4/skill-cash/actions.csv' }
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) { $InputLuaPath = Join-Path $script:Root 'evidence/mpu4/skill-cash/input.lua' }

function Get-HashValue {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-StringSha256 {
    param([string]$Text)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($script:Utf8.GetBytes($Text)))).Replace('-','').ToUpperInvariant() }
    finally { $hash.Dispose() }
}

function Write-JsonFile {
    param([string]$Path,$Object,[int]$Depth = 30)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),$script:Utf8)
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON file is missing: $Path" }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function ConvertTo-HexInt {
    param([string]$Text)
    return [Convert]::ToInt32($Text,16)
}

function Format-Hex16 {
    param([int]$Value)
    return ('{0:X4}' -f ($Value -band 0xFFFF))
}

function Format-Hex8 {
    param([int]$Value)
    return ('{0:X2}' -f ($Value -band 0xFF))
}

function ConvertTo-HexBytes {
    param([byte[]]$Bytes,[int]$Address,[int]$Length)
    $parts = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Length; $i++) { $parts.Add((Format-Hex8 $Bytes[($Address + $i) -band 0xFFFF])) }
    return ($parts -join '')
}

function Assert-FileIdentity {
    param([string]$Path,[string]$Sha1,[string]$Sha256,[string]$Label,[int]$Length = 65536)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualLength = (Get-Item -LiteralPath $Path).Length
    if ($actualLength -ne $Length) { throw "$Label length is $actualLength, expected $Length" }
    $actualSha1 = Get-HashValue $Path 'SHA1'
    $actualSha256 = Get-HashValue $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{ path=[IO.Path]::GetFullPath($Path); length=$actualLength; sha1=$actualSha1; sha256=$actualSha256 }
}

function Assert-FileHashIdentity {
    param([string]$Path,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualSha256 = Get-HashValue $Path 'SHA256'
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{
        path = [IO.Path]::GetFullPath($Path)
        length = (Get-Item -LiteralPath $Path).Length
        sha256 = $actualSha256
    }
}

function Get-ReplaySchedule {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Replay fixture is missing: $Path" }
    $coin = $null
    $start = $null
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^(\d+),(\d+),([^,]+),(\d+),([^,]+),') {
            $entry = [ordered]@{
                firstFrame = [int]$Matches[1]
                lastFrame = [int]$Matches[2]
                port = [string]$Matches[3]
                mask = [int]$Matches[4]
                reason = [string]$Matches[5]
            }
            if ($null -eq $coin -and $entry.reason -eq 'short_coin') { $coin = $entry }
            if ($null -eq $start -and $entry.reason -eq 'start_probe') { $start = $entry }
        }
    }
    if ($null -eq $coin) { throw 'Replay fixture has no short_coin event' }
    if ($null -eq $start) { throw 'Replay fixture has no start_probe event' }
    if ($coin.firstFrame -ne 2100 -or $coin.lastFrame -ne 2103 -or $coin.port -ne ':AUX2' -or $coin.mask -ne 128) {
        throw "Replay fixture coin event is $($coin.firstFrame)-$($coin.lastFrame) $($coin.port) mask=$($coin.mask), expected 2100-2103 :AUX2 mask=128"
    }
    if ($start.firstFrame -ne 2220 -or $start.lastFrame -ne 2232 -or $start.port -ne ':BLACK2' -or $start.mask -ne 128) {
        throw "Replay fixture start event is $($start.firstFrame)-$($start.lastFrame) $($start.port) mask=$($start.mask), expected the prior 2220-2232 :BLACK2 mask=128 schedule whose effective frames are 2221-2224"
    }
    return [ordered]@{ coin = $coin; start = $start }
}

function Get-InputProvenance {
    param([string]$Run)
    $levelsPath = Join-Path $Run 'input-levels.csv'
    if (!(Test-Path -LiteralPath $levelsPath -PathType Leaf)) { throw 'Tracked replay did not produce input-levels.csv' }
    $lines = @(Get-Content -LiteralPath $levelsPath)
    if ($lines.Count -lt 2) { throw 'input-levels.csv has no samples' }
    if ($lines[0] -ne 'frame,t,aux2,black2,coin_override') { throw "input-levels.csv header is not the tracked replay header: $($lines[0])" }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in $lines[1..($lines.Count - 1)]) {
        if ($line -notmatch '^(\d+),([0-9.]+),([0-9A-Fa-f]{2}),([0-9A-Fa-f]{2}),(\d+)$') { throw "input-levels.csv row is malformed: $line" }
        $rows.Add([ordered]@{
            frame = [int]$Matches[1]
            time = [double]$Matches[2]
            aux2 = [Convert]::ToInt32($Matches[3],16)
            black2 = [Convert]::ToInt32($Matches[4],16)
            coinOverride = [int]$Matches[5]
        })
    }
    if ($rows.Count -eq 0) { throw 'input-levels.csv has no parsed samples' }

    $coinRows = @($rows | Where-Object { $_.aux2 -ne 0 -or $_.coinOverride -ne 0 })
    if ($coinRows.Count -lt 4) { throw "input-levels.csv recorded only $($coinRows.Count) coin-active frames" }
    for ($i = 1; $i -lt $coinRows.Count; $i++) {
        if ($coinRows[$i].frame -le $coinRows[$i - 1].frame) { throw 'input-levels.csv coin-active rows are not strictly ordered' }
    }
    $coinFrames = @($coinRows | ForEach-Object { $_.frame })
    $expectedCoinFrames = @(2100,2101,2102,2103)
    if (($coinFrames -join ',') -ne ($expectedCoinFrames -join ',')) {
        throw "Tracked replay coin activity is '$($coinFrames -join ',')', expected the complete 2100,2101,2102,2103 window"
    }
    $startRows = @($rows | Where-Object { $_.black2 -ne 0 })
    for ($i = 1; $i -lt $startRows.Count; $i++) {
        if ($startRows[$i].frame -le $startRows[$i - 1].frame) { throw 'input-levels.csv start-active rows are not strictly ordered' }
    }
    $startFrames = @($startRows | ForEach-Object { $_.frame })
    $requiredStartFrames = @(2221,2222,2223,2224)
    if ($startFrames.Count -lt $requiredStartFrames.Count) {
        throw "input-levels.csv recorded only $($startFrames.Count) start-active frames, expected at least 2221,2222,2223,2224"
    }
    if ($startFrames[0] -ne $requiredStartFrames[0]) {
        throw "The start-active window begins at $($startFrames[0]), expected the prior effective frame 2221"
    }
    for ($i = 0; $i -lt $requiredStartFrames.Count; $i++) {
        if ($startFrames[$i] -ne $requiredStartFrames[$i]) {
            throw "The start-active window is '$($startFrames -join ',')', expected the complete required prefix 2221,2222,2223,2224"
        }
    }
    for ($i = 1; $i -lt $startFrames.Count; $i++) {
        if ($startFrames[$i] -ne $startFrames[$i - 1] + 1) { throw "The start-active window is not contiguous: '$($startFrames -join ',')'" }
    }
    if ($startFrames[$startFrames.Count - 1] -gt $startRows[0].frame + 11) {
        throw "The start-active window ends at $($startFrames[$startFrames.Count - 1]), beyond the replay fixture's 2220-2232 start probe"
    }
    $last = $rows[$rows.Count - 1]
    if ($last.frame -ge $script:NextFixtureActionFrame) {
        throw "The capture applied a fixture action at frame $($last.frame), at or after $($script:NextFixtureActionFrame); it should exit at the first complete call"
    }
    return [ordered]@{
        levelsPath = [IO.Path]::GetFullPath($levelsPath)
        levelsSha256 = Get-HashValue $levelsPath 'SHA256'
        sampleCount = $rows.Count
        firstFrame = $rows[0].frame
        lastFrame = $last.frame
        coinFrames = $coinFrames
        coinWindow = [ordered]@{
            first = $coinFrames[0]
            last = $coinFrames[$coinFrames.Count - 1]
            frames = $coinFrames
            requiredFrames = $expectedCoinFrames
        }
        coinStartTime = ('{0:F9}' -f $coinRows[0].time)
        startFrames = $startFrames
        requiredStartFrames = $requiredStartFrames
        startWindow = [ordered]@{
            first = $startFrames[0]
            last = $startFrames[$startFrames.Count - 1]
            frames = $startFrames
            requiredFrames = $requiredStartFrames
            fixtureProbeFirst = 2220
            fixtureProbeLast = 2232
        }
        startStartTime = ('{0:F9}' -f $startRows[0].time)
        nextFixtureActionFrame = $script:NextFixtureActionFrame
        laterFixtureActionsUnused = ($last.frame -lt $script:NextFixtureActionFrame)
    }
}

function Get-DiffOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare images of different length' }
    $offsets = New-Object 'System.Collections.Generic.List[int]'
    for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { [void]$offsets.Add($i) } }
    return $offsets.ToArray()
}

function Assert-ImageByte {
    param([byte[]]$Image,[int]$Address,[int]$Expected,[string]$Label)
    if ($Image[$Address] -ne $Expected) { throw "$Label at $(Format-Hex16 $Address) is $(Format-Hex8 $Image[$Address]), expected $(Format-Hex8 $Expected)" }
}

function Test-CompositeMapContract {
    param($Map,$Build,[byte[]]$Built,[byte[]]$Original)

    if ([int]$Map.SchemaVersion -ne 1 -and $null -ne $Map.SchemaVersion) { throw 'Source map schemaVersion is not 1' }
    if ([string]$Map.OriginalRomSha1 -ine $script:OriginalSha1) { throw 'Source map original SHA1 is wrong' }
    if ([string]$Map.OriginalRomSha256 -ine $script:OriginalSha256) { throw 'Source map original SHA256 is wrong' }
    if ([string]$Map.OutputImageSha1 -ine $script:BuiltSha1) { throw 'Source map output SHA1 is wrong' }
    if ([string]$Map.OutputImageSha256 -ine $script:BuiltSha256) { throw 'Source map output SHA256 is wrong' }
    if ([string]$Map.BuildId -ine $script:BuiltSha256) { throw 'Source map BuildId is not the exact built image SHA256' }
    if ([int]$Map.HeaderAddress -ne 0x1010) { throw 'Source map header address is not 1010' }
    if ([string]$Map.HeaderHex -ine '00F8') { throw 'Source map header cell is not 00F8' }
    if ([int]$Map.BodyStart -ne 0x1012) { throw 'Source map body start is not 1012' }
    if ([int]$Map.BodyEndExclusive -ne 0x1020) { throw 'Source map body end is not 1020' }
    if (([string]$Map.Classification) -notmatch 'static_compiled_map_not_execution_proof') { throw 'Source map classification is not the static compiled map class' }

    if ([string]$Build.originalRomSha1 -ine $script:OriginalSha1) { throw 'Build report original SHA1 is wrong' }
    if ([string]$Build.originalRomSha256 -ine $script:OriginalSha256) { throw 'Build report original SHA256 is wrong' }
    if ([string]$Build.outputImageSha1 -ine $script:BuiltSha1) { throw 'Build report output SHA1 is wrong' }
    if ([string]$Build.outputImageSha256 -ine $script:BuiltSha256) { throw 'Build report output SHA256 is wrong' }
    if ([string]$Build.headerAddress -ine '1010') { throw 'Build report header address is not 1010' }
    if ([string]$Build.headerBytes -ine '00F8') { throw 'Build report header bytes are not 00F8' }
    if ([string]$Build.bodyStart -ine '1012') { throw 'Build report body start is not 1012' }
    if ([string]$Build.bodyEndExclusive -ine '1020') { throw 'Build report body end is not 1020' }
    if ([string]$Build.bodyHex -ine $script:BodyHex) { throw 'Build report body bytes differ from the certified body' }
    if ([string]$Build.callerTokenAddress -ine '9F14') { throw 'Build report caller address is not 9F14' }
    if ([string]$Build.callerExpectedToken -ine '9ED7') { throw 'Build report expected caller token is not 9ED7' }
    if ([string]$Build.callerReplacementToken -ine '1010') { throw 'Build report replacement caller token is not 1010' }
    if ([string]$Build.callerSavedReturnCursor -ine '9F16') { throw 'Build report saved cursor is not 9F16' }
    if ([string]$Build.callerPostReturnToken -ine '75A9') { throw 'Build report post-return token is not 75A9' }
    if ([string]$Build.integrityRepairedFieldsHex -ine $script:FieldsHex) { throw 'Build report integrity fields are wrong' }
    if ([string]$Build.integrityOriginalFieldsHex -ine $script:OriginalFieldsHex) { throw 'Build report original fields are wrong' }

    $actualDiff = @(Get-DiffOffsets $Original $Built)
    if (($actualDiff -join ',') -ne ($script:ExpectedDiff -join ',')) { throw "Built image diff is not the accepted 21-byte set: $($actualDiff -join ',')" }
    $buildDiff = @($Build.changedOffsets | ForEach-Object { [int]$_ })
    if (($buildDiff -join ',') -ne ($script:ExpectedDiff -join ',')) { throw 'Build report changedOffsets differ from the accepted set' }
    $repairDiff = @($Build.repairChangedOffsets | ForEach-Object { [int]$_ })
    if (($repairDiff -join ',') -ne ((@(65489,65490,65491,65492,65493)) -join ',')) { throw 'Build report repairChangedOffsets are not FFD1-FFD5' }

    if ((ConvertTo-HexBytes $Built 0x1010 16) -ine ('00F8' + $script:BodyHex)) { throw 'Built header/body bytes are not the accepted extension content' }
    if ((ConvertTo-HexBytes $Built 0x9F14 4) -ine '101075A9') { throw 'Built caller/successor bytes are not 1010/75A9' }
    if ((ConvertTo-HexBytes $Built 0x9ED7 16) -ine ('00F8' + $script:BodyHex)) { throw 'Original 9ED7/9ED9 definition was not preserved' }
    if ((ConvertTo-HexBytes $Built 0xFFD1 5) -ine $script:FieldsHex) { throw 'Built integrity fields are not E93F3C61B5' }
    if ((ConvertTo-HexBytes $Original 0xFFD1 5) -ine $script:OriginalFieldsHex) { throw 'Original integrity fields are not 3E761E2605' }
    for ($address = 0x1000; $address -le 0x100F; $address++) { Assert-ImageByte $Built $address 0xFF 'low guard' }
    for ($address = 0x13F0; $address -le 0x13FF; $address++) { Assert-ImageByte $Built $address 0xFF 'high guard' }

    $nodes = @($Map.Nodes)
    if ($nodes.Count -ne 5) { throw "Source map has $($nodes.Count) nodes, expected 5" }
    $nodeByIndex = @{}
    foreach ($node in $nodes) {
        $index = [int]$node.Index
        if ($index -lt 0 -or $index -gt 4) { throw "Source map node index $index is out of range" }
        if ($nodeByIndex.ContainsKey($index)) { throw "Duplicate source map node index $index" }
        $nodeByIndex[$index] = $node
        $address = [int]$node.Address
        $token = [int]$node.Token
        $handler = [int]$node.HandlerAddress
        if ((([int]$Built[$address] -shl 8) -bor [int]$Built[$address + 1]) -ne $token) { throw "Source map node token differs at $(Format-Hex16 $address)" }
        if ((([int]$Built[$token] -shl 8) -bor [int]$Built[$token + 1]) -ne $handler) { throw "Node token $(Format-Hex16 $token) does not point at handler $(Format-Hex16 $handler)" }
        $bytesHex = [string]$node.BytesHex
        if ((ConvertTo-HexBytes $Built $address ($bytesHex.Length / 2)) -ine $bytesHex) { throw "Source map node bytes differ at $(Format-Hex16 $address)" }
        if ($null -ne $node.OperandAddress) {
            $operandAddress = [int]$node.OperandAddress
            $operandValue = [int]$node.OperandValue
            if ((([int]$Built[$operandAddress] -shl 8) -bor [int]$Built[$operandAddress + 1]) -ne $operandValue) { throw "Source map inline operand differs at $(Format-Hex16 $operandAddress)" }
        }
    }
    for ($index = 0; $index -le 4; $index++) { if (!$nodeByIndex.ContainsKey($index)) { throw "Source map is missing node $index" } }

    $entries = @($Map.Entries)
    if ($entries.Count -ne 20) { throw "Source map has $($entries.Count) entries, expected 20" }
    foreach ($entry in $entries) {
        $address = [int]$entry.Address
        if ([int]$entry.ImageByte -ne [int]$Built[$address]) { throw "Source map entry byte differs at $(Format-Hex16 $address)" }
    }

    $phases = @($Map.Phases)
    if ($phases.Count -ne 13) { throw "Source map has $($phases.Count) phases, expected 13" }
    $expectedPhases = @(
        @{ Name='caller-dispatch'; Pc=0x00FC; X=-1; Y=0x9F14; Token=0x9ED7; Replacement=0x1010; Handler=-1; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='header-trampoline-entry'; Pc=0x00F8; X=0x1012; Y=0x9F16; Token=0x00F8; Replacement=-1; Handler=-1; InlineAddress=-1; InlineValue=-1; Saved=0x9F16 },
        @{ Name='body-prefetch-0'; Pc=0x00FC; X=0x1012; Y=0x1012; Token=0x795B; Replacement=-1; Handler=0x795D; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='handler-0'; Pc=0x795D; X=0x795D; Y=0x1014; Token=0x795B; Replacement=-1; Handler=0x795D; InlineAddress=0x1014; InlineValue=0xFF80; Saved=-1 },
        @{ Name='body-prefetch-1'; Pc=0x00FC; X=0x795D; Y=0x1016; Token=0x787E; Replacement=-1; Handler=0x7880; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='handler-1'; Pc=0x7880; X=0x7880; Y=0x1018; Token=0x787E; Replacement=-1; Handler=0x7880; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='body-prefetch-2'; Pc=0x00FC; X=0x7880; Y=0x1018; Token=0x795B; Replacement=-1; Handler=0x795D; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='handler-2'; Pc=0x795D; X=0x795D; Y=0x101A; Token=0x795B; Replacement=-1; Handler=0x795D; InlineAddress=0x101A; InlineValue=0xFF80; Saved=-1 },
        @{ Name='body-prefetch-3'; Pc=0x00FC; X=0x795D; Y=0x101C; Token=0x7AAF; Replacement=-1; Handler=0x7AB1; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='handler-3'; Pc=0x7AB1; X=0x7AB1; Y=0x101E; Token=0x7AAF; Replacement=-1; Handler=0x7AB1; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='body-prefetch-4'; Pc=0x00FC; X=0x7AB1; Y=0x101E; Token=0x792F; Replacement=-1; Handler=0x7931; InlineAddress=-1; InlineValue=-1; Saved=-1 },
        @{ Name='return-handler'; Pc=0x7931; X=0x7931; Y=0x1020; Token=0x792F; Replacement=-1; Handler=0x7931; InlineAddress=-1; InlineValue=-1; Saved=0x9F16 },
        @{ Name='post-return-prefetch'; Pc=0x00FC; X=0x7931; Y=0x9F16; Token=0x75A9; Replacement=-1; Handler=-1; InlineAddress=-1; InlineValue=-1; Saved=-1 }
    )
    for ($i = 0; $i -lt $expectedPhases.Count; $i++) {
        $actual = $phases[$i]
        $expected = $expectedPhases[$i]
        if ([string]$actual.Phase -ne $expected.Name) { throw "Source map phase $i is $($actual.Phase), expected $($expected.Name)" }
        if ([int]$actual.Pc -ne $expected.Pc) { throw "Source map phase $($expected.Name) PC is $($actual.Pc)" }
        $actualX = if ($null -eq $actual.X) { -1 } else { [int]$actual.X }
        if ($actualX -ne $expected.X) { throw "Source map phase $($expected.Name) X is $actualX" }
        if ([int]$actual.Y -ne $expected.Y) { throw "Source map phase $($expected.Name) Y is $($actual.Y)" }
        if ([int]$actual.Token -ne $expected.Token) { throw "Source map phase $($expected.Name) token is $($actual.Token)" }
        $actualReplacement = if ($null -eq $actual.ReplacementToken) { -1 } else { [int]$actual.ReplacementToken }
        if ($actualReplacement -ne $expected.Replacement) { throw "Source map phase $($expected.Name) replacement token is $actualReplacement" }
        $actualHandler = if ($null -eq $actual.HandlerAddress) { -1 } else { [int]$actual.HandlerAddress }
        if ($actualHandler -ne $expected.Handler) { throw "Source map phase $($expected.Name) handler is $actualHandler" }
        $actualInlineAddress = if ($null -eq $actual.InlineOperandAddress) { -1 } else { [int]$actual.InlineOperandAddress }
        if ($actualInlineAddress -ne $expected.InlineAddress) { throw "Source map phase $($expected.Name) inline address is $actualInlineAddress" }
        $actualInlineValue = if ($null -eq $actual.InlineOperandValue) { -1 } else { [int]$actual.InlineOperandValue }
        if ($actualInlineValue -ne $expected.InlineValue) { throw "Source map phase $($expected.Name) inline value is $actualInlineValue" }
        $actualSaved = if ($null -eq $actual.SavedCursor) { -1 } else { [int]$actual.SavedCursor }
        if ($actualSaved -ne $expected.Saved) { throw "Source map phase $($expected.Name) saved cursor is $actualSaved" }
        if (([string]$actual.Classification) -notmatch 'static_compiled_map_not_execution_proof') { throw "Source map phase $($expected.Name) is not classified static" }
    }

    $caller = $Map.Caller
    if ([int]$caller.TokenAddress -ne 0x9F14) { throw 'Source map caller token address is not 9F14' }
    if ([int]$caller.OriginalToken -ne 0x9ED7) { throw 'Source map caller original token is not 9ED7' }
    if ([int]$caller.ReplacementToken -ne 0x1010) { throw 'Source map caller replacement token is not 1010' }
    if ([int]$caller.HeaderAddress -ne 0x1010) { throw 'Source map caller header is not 1010' }
    if ([int]$caller.HeaderValue -ne 0x00F8) { throw 'Source map caller header value is not 00F8' }
    if ([int]$caller.BodyStart -ne 0x1012) { throw 'Source map caller body start is not 1012' }
    if ([int]$caller.BodyEndExclusive -ne 0x1020) { throw 'Source map caller body end is not 1020' }
    if ([int]$caller.SavedReturnCursor -ne 0x9F16) { throw 'Source map saved return cursor is not 9F16' }
    if ([int]$caller.PostReturnTokenAddress -ne 0x9F16) { throw 'Source map post-return address is not 9F16' }
    if ([int]$caller.PostReturnToken -ne 0x75A9) { throw 'Source map post-return token is not 75A9' }

    return [ordered]@{
        mapSha256 = $script:MapSha256
        builtSha256 = $script:BuiltSha256
        nodeCount = $nodes.Count
        entryCount = $entries.Count
        phaseCount = $phases.Count
        changedOffsetCount = $actualDiff.Count
        integrityFields = $script:FieldsHex
    }
}

function ConvertTo-LuaString {
    param([string]$Text)
    return '"' + $Text.Replace('\','\\').Replace('"','\"') + '"'
}

function ConvertTo-LuaInt {
    param($Value)
    if ($null -eq $Value) { return '-1' }
    return ('0x{0:X}' -f [int]$Value)
}

function Get-CompositeMapLuaText {
    param($Map)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  protocol = "{0}",' -f $script:Protocol))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $Map.OutputImageSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $Map.OriginalRomSha256))
    [void]$sb.AppendLine(('  headerAddress = 0x{0:X},' -f [int]$Map.HeaderAddress))
    [void]$sb.AppendLine(('  headerValue = 0x{0:X},' -f (ConvertTo-HexInt ([string]$Map.HeaderHex))))
    [void]$sb.AppendLine(('  bodyStart = 0x{0:X},' -f [int]$Map.BodyStart))
    [void]$sb.AppendLine(('  bodyEndExclusive = 0x{0:X},' -f [int]$Map.BodyEndExclusive))
    [void]$sb.AppendLine('  caller = {')
    [void]$sb.AppendLine(('    address = 0x{0:X},' -f [int]$Map.Caller.TokenAddress))
    [void]$sb.AppendLine(('    originalToken = 0x{0:X},' -f [int]$Map.Caller.OriginalToken))
    [void]$sb.AppendLine(('    replacementToken = 0x{0:X},' -f [int]$Map.Caller.ReplacementToken))
    [void]$sb.AppendLine(('    savedCursor = 0x{0:X},' -f [int]$Map.Caller.SavedReturnCursor))
    [void]$sb.AppendLine(('    postReturnToken = 0x{0:X}' -f [int]$Map.Caller.PostReturnToken))
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  nodes = {')
    foreach ($node in @($Map.Nodes)) {
        $bytes = New-Object 'System.Collections.Generic.List[string]'
        $text = [string]$node.BytesHex
        for ($i = 0; $i -lt $text.Length; $i += 2) { $bytes.Add(('0x{0}' -f $text.Substring($i,2))) }
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine(('      index = {0},' -f [int]$node.Index))
        [void]$sb.AppendLine(('      address = 0x{0:X},' -f [int]$node.Address))
        [void]$sb.AppendLine(('      token = 0x{0:X},' -f [int]$node.Token))
        [void]$sb.AppendLine(('      operation = {0},' -f (ConvertTo-LuaString ([string]$node.Operation))))
        [void]$sb.AppendLine(('      handlerAddress = 0x{0:X},' -f [int]$node.HandlerAddress))
        [void]$sb.AppendLine(('      operandAddress = {0},' -f (ConvertTo-LuaInt $node.OperandAddress)))
        [void]$sb.AppendLine(('      operandValue = {0},' -f (ConvertTo-LuaInt $node.OperandValue)))
        [void]$sb.AppendLine(('      bytes = {{ {0} }}' -f ($bytes -join ', ')))
        [void]$sb.AppendLine('    },')
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  phases = {')
    foreach ($phase in @($Map.Phases)) {
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine(('      name = {0},' -f (ConvertTo-LuaString ([string]$phase.Phase))))
        [void]$sb.AppendLine(('      pc = 0x{0:X},' -f [int]$phase.Pc))
        [void]$sb.AppendLine(('      x = {0},' -f (ConvertTo-LuaInt $phase.X)))
        [void]$sb.AppendLine(('      y = 0x{0:X},' -f [int]$phase.Y))
        [void]$sb.AppendLine(('      token = 0x{0:X},' -f [int]$phase.Token))
        [void]$sb.AppendLine(('      replacementToken = {0},' -f (ConvertTo-LuaInt $phase.ReplacementToken)))
        [void]$sb.AppendLine(('      handlerAddress = {0},' -f (ConvertTo-LuaInt $phase.HandlerAddress)))
        [void]$sb.AppendLine(('      inlineOperandAddress = {0},' -f (ConvertTo-LuaInt $phase.InlineOperandAddress)))
        [void]$sb.AppendLine(('      inlineOperandValue = {0},' -f (ConvertTo-LuaInt $phase.InlineOperandValue)))
        [void]$sb.AppendLine(('      savedCursor = {0}' -f (ConvertTo-LuaInt $phase.SavedCursor)))
        [void]$sb.AppendLine('    },')
    }
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('}')
    return $sb.ToString()
}

function Write-CompositeMapLua {
    param([string]$Path,$Map)
    [IO.File]::WriteAllText($Path,(Get-CompositeMapLuaText $Map),$script:Utf8)
}

function Get-CompositeConfigLuaText {
    param($Config)
    $entries = New-Object 'System.Collections.Generic.List[object]'
    if ($Config -is [System.Collections.IDictionary]) {
        foreach ($key in $Config.Keys) { $entries.Add([ordered]@{ key=[string]$key; value=$Config[$key] }) }
    }
    else {
        foreach ($property in $Config.PSObject.Properties) { $entries.Add([ordered]@{ key=[string]$property.Name; value=$property.Value }) }
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    foreach ($entry in $entries) {
        $key = $entry.key
        $value = $entry.value
        if ($value -is [int] -or $value -is [long]) { [void]$sb.AppendLine(('  {0} = {1},' -f $key,$value)) }
        else { [void]$sb.AppendLine(('  {0} = {1},' -f $key,(ConvertTo-LuaString ([string]$value)))) }
    }
    [void]$sb.AppendLine('}')
    return $sb.ToString()
}

function Write-CompositeConfigLua {
    param([string]$Path,$Config)
    [IO.File]::WriteAllText($Path,(Get-CompositeConfigLuaText $Config),$script:Utf8)
}

function Invoke-ProcessRecord {
    param([string]$FilePath,[string[]]$Arguments,[string]$WorkingDirectory,[string]$StdOutPath,[string]$StdErrPath,[int]$TimeoutSeconds)
    $quoted = foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') { '"' + $text.Replace('"','\"') + '"' } else { $text }
    }
    $argumentString = ($quoted -join ' ')
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = [IO.Path]::GetFullPath($FilePath)
    $startInfo.Arguments = $argumentString
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $startUtc = [DateTime]::UtcNow
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) { throw "Failed to start process: $FilePath" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $exitCode = $null
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
        }
        if ($process.HasExited) { $exitCode = $process.ExitCode }
        [IO.File]::WriteAllText($StdOutPath,$stdoutTask.GetAwaiter().GetResult(),$script:Utf8)
        [IO.File]::WriteAllText($StdErrPath,$stderrTask.GetAwaiter().GetResult(),$script:Utf8)
    }
    finally {
        $stopwatch.Stop()
        if (-not $process.HasExited) {
            & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
            if ($process.HasExited) { $exitCode = $process.ExitCode }
        }
        $process.Dispose()
    }
    return [ordered]@{
        commandLine = $argumentString
        startUtc = $startUtc.ToString('o')
        endUtc = [DateTime]::UtcNow.ToString('o')
        wallSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds,3)
        timeoutSeconds = $TimeoutSeconds
        timedOut = $timedOut
        exitCode = $exitCode
    }
}

function Invoke-StrictEventsParse {
    param([string]$EventsPath,[string]$OutputPath)
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $pwsh) { throw 'pwsh is required for strict System.Text.Json event validation' }
    $helper = Join-Path $script:Root 'tests/worker/Test-IlEventJson.ps1'
    if (!(Test-Path -LiteralPath $helper -PathType Leaf)) { throw "Strict JSON helper is missing: $helper" }
    $record = Invoke-ProcessRecord -FilePath $pwsh.Source -Arguments @('-NoProfile','-File',$helper,'-Mode','Parse','-EventsPath',$EventsPath,'-OutputPath',$OutputPath) -WorkingDirectory $script:Root -StdOutPath ($OutputPath + '.stdout.log') -StdErrPath ($OutputPath + '.stderr.log') -TimeoutSeconds 120
    if ($record.timedOut -or $record.exitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath ($OutputPath + '.stderr.log')) { Get-Content -LiteralPath ($OutputPath + '.stderr.log') -Raw } else { '' }
        throw "Strict JSONL parse failed (exit=$($record.exitCode) timedOut=$($record.timedOut)): $stderr"
    }
    if (!(Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw 'Strict JSONL parser did not write a summary' }
    $summary = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
    if (-not [bool]$summary.pass) { throw 'Strict JSONL parser reported a failure' }
    return [ordered]@{ summary=$summary; sha256=(Get-HashValue $EventsPath 'SHA256'); recordCount=[int]$summary.nonblank }
}

function Get-MetadataPath {
    param([string]$Run,[string]$Name)
    return (Join-Path $Run $Name)
}

function Assert-EventIdentity {
    param($Event,[string]$BuildSha,[string]$MapSha,[string]$LuaSha,[string]$MameSha,[string]$SessionId)
    if ([string]$Event.buildSha256 -ine $BuildSha) { throw "Event $($Event.event) build identity is wrong" }
    if ([string]$Event.mapSha256 -ine $MapSha) { throw "Event $($Event.event) map identity is wrong" }
    if ([string]$Event.luaSha256 -ine $LuaSha) { throw "Event $($Event.event) Lua identity is wrong" }
    if ([string]$Event.mameSha256 -ine $MameSha) { throw "Event $($Event.event) MAME identity is wrong" }
    if ([string]$Event.sessionId -ine $SessionId) { throw "Event $($Event.event) session id is wrong" }
}

function Assert-RunLocalAssets {
    param([string]$Run,$Metadata,$Map,$ConfigJson,[string]$InputPolicy)
    $luaPath = Join-Path $Run 'IlCompositeNatural.lua'
    $mapLuaPath = Join-Path $Run 'composite-map.lua'
    $configLuaPath = Join-Path $Run 'session-config.lua'
    $configJsonPath = Join-Path $Run 'session-config.json'
    $observerPath = Join-Path $Run 'observer.lua'

    $luaIdentity = Assert-FileHashIdentity $luaPath ([string]$Metadata.lua.capturedSha256) 'run-local observer Lua'
    $mapLuaHash = Get-HashValue $mapLuaPath 'SHA256'
    $expectedMapLuaHash = Get-StringSha256 (Get-CompositeMapLuaText $Map)
    if ($mapLuaHash -ine $expectedMapLuaHash) { throw "Run-local composite-map.lua SHA256 is $mapLuaHash, expected canonical $expectedMapLuaHash" }
    $configJsonHash = Get-HashValue $configJsonPath 'SHA256'
    $configLuaHash = Get-HashValue $configLuaPath 'SHA256'
    $expectedConfigLuaHash = Get-StringSha256 (Get-CompositeConfigLuaText $ConfigJson)
    if ($configLuaHash -ine $expectedConfigLuaHash) { throw "Run-local session-config.lua SHA256 is $configLuaHash, expected canonical $expectedConfigLuaHash" }
    $observerHash = Get-HashValue $observerPath 'SHA256'
    $observerText = [IO.File]::ReadAllText($observerPath,$script:Utf8)
    $expectedObserverText = if ($InputPolicy -eq 'tracked_physical_replay') { "dofile('input.lua')`ndofile('IlCompositeNatural.lua')`n" } else { "dofile('IlCompositeNatural.lua')`n" }
    if ($observerText -cne $expectedObserverText) { throw 'Run-local observer.lua is not the canonical observer composition for its input policy' }

    if ([string]$ConfigJson.protocol -ne $script:Protocol) { throw 'Run-local session-config.json protocol mismatch' }
    if ([string]$ConfigJson.sessionId -ine [string]$Metadata.sessionId) { throw 'Run-local session-config.json session id differs from metadata' }
    if ([string]$ConfigJson.inputPolicy -ne $InputPolicy) { throw 'Run-local session-config.json input policy differs from metadata' }
    if ([string]$ConfigJson.expectedImageSha256 -ine $script:BuiltSha256) { throw 'Run-local session-config.json image identity is wrong' }
    if ([string]$ConfigJson.expectedOriginalRomSha256 -ine $script:OriginalSha256) { throw 'Run-local session-config.json original identity is wrong' }
    if ([string]$ConfigJson.expectedSourceMapSha256 -ine $script:MapSha256) { throw 'Run-local session-config.json map identity is wrong' }
    if ([string]$ConfigJson.expectedMameSha256 -ine $script:MameSha256) { throw 'Run-local session-config.json MAME identity is wrong' }
    if ([string]$ConfigJson.expectedLuaSha256 -ine [string]$Metadata.lua.capturedSha256) { throw 'Run-local session-config.json Lua identity differs from the captured observer' }
    if ([int]$ConfigJson.secondsToRun -ne [int]$Metadata.seconds_to_run) { throw 'Run-local session-config.json seconds do not match metadata' }
    if ([int]$ConfigJson.wallTimeoutSeconds -ne [int]$Metadata.wall_timeout_seconds) { throw 'Run-local session-config.json wall timeout does not match metadata' }
    if ($InputPolicy -eq 'tracked_physical_replay') {
        if ([string]$ConfigJson.expectedReplaySha256 -ine $script:ReplaySha256) { throw 'Run-local session-config.json replay identity is wrong' }
        if ([string]$ConfigJson.expectedInputLuaSha256 -ine $script:InputLuaSha256) { throw 'Run-local session-config.json input Lua identity is wrong' }
    }

    $legacyAbsent = $null -eq $Metadata.run_local_assets
    if (-not $legacyAbsent) {
        if ([string]$Metadata.run_local_assets.lua -ine $luaIdentity.sha256) { throw 'Metadata run-local Lua hash differs from the actual observer copy' }
        if ([string]$Metadata.run_local_assets.map_lua -ine $mapLuaHash) { throw 'Metadata run-local map Lua hash differs from the actual copy' }
        if ([string]$Metadata.run_local_assets.config_lua -ine $configLuaHash) { throw 'Metadata run-local config Lua hash differs from the actual copy' }
        if ([string]$Metadata.run_local_assets.config_json -ine $configJsonHash) { throw 'Metadata run-local config JSON hash differs from the actual copy' }
        if ([string]$Metadata.run_local_assets.observer -ine $observerHash) { throw 'Metadata run-local observer hash differs from the actual copy' }
    }

    return [ordered]@{
        lua = $luaIdentity
        mapLua = [ordered]@{ path=[IO.Path]::GetFullPath($mapLuaPath); sha256=$mapLuaHash; canonicalSha256=$expectedMapLuaHash }
        configLua = [ordered]@{ path=[IO.Path]::GetFullPath($configLuaPath); sha256=$configLuaHash; canonicalSha256=$expectedConfigLuaHash }
        configJson = [ordered]@{ path=[IO.Path]::GetFullPath($configJsonPath); sha256=$configJsonHash }
        observer = [ordered]@{ path=[IO.Path]::GetFullPath($observerPath); sha256=$observerHash; canonicalText=$expectedObserverText }
        metadataBinding = if ($legacyAbsent) { 'legacy_metadata_assets_absent_recomputed_from_run' } else { 'metadata_run_local_assets_match' }
        legacyMetadataAssetsAbsent = $legacyAbsent
        currentSourceLuaDiffers = ((Get-HashValue (Join-Path $script:Root 'tools/lua/IlCompositeNatural.lua') 'SHA256') -ine $luaIdentity.sha256)
    }
}

function Get-CompositeAnalysis {
    param([string]$Run,[string]$BuiltPath,[string]$SourceMapPath,[string]$BuildReportPath,[string]$OriginalPath,[string]$PriorPath,[string]$ReanalysisSourceRun,[switch]$SkipStrictParse)

    $run = [IO.Path]::GetFullPath($Run)
    if (!(Test-Path -LiteralPath $run -PathType Container)) { throw "Run directory is missing: $run" }
    $metadataPath = Get-MetadataPath $run 'session-metadata.json'
    $metadata = Read-JsonFile $metadataPath
    if ([string]$metadata.protocol -ne $script:Protocol) { throw 'Session metadata protocol mismatch' }

    $builtPath = if ([string]::IsNullOrWhiteSpace($BuiltPath)) { [string]$metadata.built_rom.path } else { $BuiltPath }
    $sourceMapPath = if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { [string]$metadata.source_map.path } else { $SourceMapPath }
    $buildReportPath = if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { [string]$metadata.build_report.path } else { $BuildReportPath }
    $originalPath = if ([string]::IsNullOrWhiteSpace($OriginalPath)) { [string]$metadata.original_rom.path } else { $OriginalPath }
    $priorPath = if ([string]::IsNullOrWhiteSpace($PriorPath)) { Join-Path $script:Root 'evidence/mpu4/integrity/il-lua-vm-trace.json' } else { $PriorPath }

    $originalIdentity = Assert-FileIdentity $originalPath $script:OriginalSha1 $script:OriginalSha256 'analysis original ROM'
    $builtIdentity = Assert-FileIdentity $builtPath $script:BuiltSha1 $script:BuiltSha256 'analysis built ROM'
    $mapHash = Get-HashValue $sourceMapPath 'SHA256'
    if ($mapHash -ine $script:MapSha256) { throw "Source map SHA256 is $mapHash, expected $script:MapSha256" }
    $buildHash = Get-HashValue $buildReportPath 'SHA256'
    if ($buildHash -ine [string]$metadata.build_report.sha256) { throw "Build report SHA256 is $buildHash, expected $($metadata.build_report.sha256)" }
    if ([string]$metadata.source_map.sha256 -ine $mapHash) { throw 'Session metadata source map hash differs from the analysed map' }
    if ([string]$metadata.built_rom.sha256 -ine $script:BuiltSha256) { throw 'Session metadata built ROM hash is wrong' }
    if ([string]$metadata.original_rom.sha256 -ine $script:OriginalSha256) { throw 'Session metadata original ROM hash is wrong' }

    $built = [IO.File]::ReadAllBytes($builtPath)
    $original = [IO.File]::ReadAllBytes($originalPath)
    $map = Read-JsonFile $sourceMapPath
    $build = Read-JsonFile $buildReportPath
    $contract = Test-CompositeMapContract $map $build $built $original

    $runRomPath = Join-Path $run 'roms/m4addr/a6ls.p1'
    $runRomIdentity = Assert-FileIdentity $runRomPath $script:BuiltSha1 $script:BuiltSha256 'isolated run ROM after execution'
    $stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'state') -Recurse -File -ErrorAction SilentlyContinue)
    if ($stateFiles.Count -ne 0) { throw 'State directory contains files; a save state may have been loaded or written' }

    if ([bool]$metadata.save_state_loaded) { throw 'Session metadata claims a save state was loaded' }
    if ([bool]$metadata.state_injection) { throw 'Session metadata claims state injection' }
    if ([bool]$metadata.input_injection) { throw 'Session metadata claims state injection disguised as input injection' }
    if ([bool]$metadata.debugger_writes) { throw 'Session metadata claims debugger writes' }
    if ([string]$metadata.starting_nvram -ne 'absent') { throw 'Session did not start with absent NVRAM' }
    if ([string]$metadata.starting_configuration -notmatch 'absent') { throw 'Session did not start with absent configuration' }
    $evidenceClass = if ($null -eq $metadata.evidence_class) { 'natural' } else { [string]$metadata.evidence_class }
    if ($evidenceClass -notin @('natural','synthetic_checker_fixture')) { throw "Session evidence class is not supported: $evidenceClass" }

    $inputPolicy = [string]$metadata.input_policy
    $inputProvenance = $null
    if ($inputPolicy -eq 'tracked_physical_replay') {
        if (-not [bool]$metadata.input_replay_used) { throw 'Session metadata does not claim tracked physical input replay' }
        $replayPath = Join-Path $run 'replay-actions.csv'
        $inputLuaPath = Join-Path $run 'input.lua'
        $replayIdentity = Assert-FileHashIdentity $replayPath $script:ReplaySha256 'tracked replay fixture'
        $inputLuaIdentity = Assert-FileHashIdentity $inputLuaPath $script:InputLuaSha256 'tracked input Lua'
        if ($null -eq $metadata.input_replay) { throw 'Session metadata is missing the input replay provenance block' }
        if ([string]$metadata.input_replay.sha256 -ine $script:ReplaySha256) { throw 'Session metadata replay hash is not the prior tracked fixture' }
        if ([string]$metadata.input_replay.input_lua_sha256 -ine $script:InputLuaSha256) { throw 'Session metadata input Lua hash is not the prior tracked script' }
        if ([string]$metadata.input_replay.classification -ne 'tracked_physical_input_replay_no_state_injection') { throw 'Session metadata input replay classification is wrong' }
        $replaySchedule = Get-ReplaySchedule $replayPath
        $levelProvenance = Get-InputProvenance $run
        $inputProvenance = [ordered]@{
            policy = 'tracked_physical_replay'
            used = $true
            classification = 'tracked_physical_input_replay_no_state_injection'
            replay = [ordered]@{
                path = $replayIdentity.path
                length = $replayIdentity.length
                sha256 = $replayIdentity.sha256
                coinEvent = $replaySchedule.coin
                startEvent = $replaySchedule.start
            }
            inputLua = $inputLuaIdentity
            observed = $levelProvenance
            stateInjection = $false
            inputInjection = $false
        }
    }
    elseif ($inputPolicy -eq 'none') {
        if ($null -ne $metadata.input_replay_used -and [bool]$metadata.input_replay_used) { throw 'No-input history claims input replay use' }
        $inputProvenance = [ordered]@{
            policy = 'none'
            used = $false
            classification = 'preserved_no_input_attempt_history'
            note = 'Preserved il-composite-natural-35 no-input attempt; it is not revised tracked-replay evidence.'
            stateInjection = $false
            inputInjection = $false
        }
    }
    else {
        throw "Session input policy is not tracked_physical_replay or preserved no-input history: $inputPolicy"
    }

    $runConfigJson = Read-JsonFile (Join-Path $run 'session-config.json')
    $runLocalAssets = Assert-RunLocalAssets $run $metadata $map $runConfigJson $inputPolicy

    $eventsPath = Join-Path $run 'events.jsonl'
    if (!(Test-Path -LiteralPath $eventsPath -PathType Leaf)) { throw "Event log is missing: $eventsPath" }
    $parseInfo = $null
    if ($SkipStrictParse) {
        $records = New-Object 'System.Collections.Generic.List[object]'
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $eventsPath) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $records.Add(($line | ConvertFrom-Json -ErrorAction Stop))
        }
        $parseInfo = [ordered]@{ sha256=(Get-HashValue $eventsPath 'SHA256'); recordCount=$records.Count; strict=$false }
    }
    else {
        $strictPath = Join-Path $run 'events-strict.json'
        $strict = Invoke-StrictEventsParse $eventsPath $strictPath
        $records = New-Object 'System.Collections.Generic.List[object]'
        foreach ($record in @($strict.summary.records)) { $records.Add($record) }
        $parseInfo = [ordered]@{ sha256=$strict.sha256; recordCount=$strict.recordCount; strict=$true; summaryPath=[IO.Path]::GetFullPath($strictPath); summarySha256=(Get-HashValue $strictPath 'SHA256') }
    }
    if ($records.Count -eq 0) { throw 'Event log is empty' }

    $ready = @($records | Where-Object { [string]$_.event -eq 'session_ready' })
    if ($ready.Count -ne 1) { throw "Event log has $($ready.Count) session_ready records, expected 1" }
    $readyEvent = $ready[0]
    if ([string]$readyEvent.imageSha256 -ine $script:BuiltSha256) { throw 'Session ready image identity is wrong' }
    if ([string]$readyEvent.originalRomSha256 -ine $script:OriginalSha256) { throw 'Session ready original identity is wrong' }
    if ([string]$readyEvent.sourceMapSha256 -ine $mapHash) { throw 'Session ready map identity is wrong' }
    if ([string]$readyEvent.buildReportSha256 -ine $buildHash) { throw 'Session ready build report identity is wrong' }
    if ([string]$readyEvent.luaSha256 -ine [string]$metadata.lua.capturedSha256) { throw 'Session ready Lua identity is wrong' }
    if ([string]$readyEvent.mameSha256 -ine $script:MameSha256) { throw 'Session ready MAME identity is wrong' }
    if ([string]$readyEvent.inputPolicy -ne $inputPolicy) { throw "Session ready input policy is $($readyEvent.inputPolicy), expected $inputPolicy" }
    if ($inputPolicy -eq 'tracked_physical_replay') {
        if ([string]$readyEvent.replaySha256 -ine $script:ReplaySha256) { throw 'Session ready replay identity is wrong' }
        if ([string]$readyEvent.inputLuaSha256 -ine $script:InputLuaSha256) { throw 'Session ready input Lua identity is wrong' }
    }
    if ([string]$readyEvent.boundarySource -ne 'native_debugger_bpset') { throw 'Session boundaries are not native debugger breakpoints' }

    $complete = @($records | Where-Object { [string]$_.event -eq 'session_complete' })
    if ($complete.Count -ne 1) { throw "Event log has $($complete.Count) session_complete records, expected 1" }
    $completeEvent = $complete[0]
    $timeouts = @($records | Where-Object { [string]$_.event -eq 'session_timeout' })
    $failures = @($records | Where-Object { [string]$_.event -in @('startup_failure','protocol_failure') })
    $failure = if ($failures.Count -gt 0) { $failures[0] } else { $null }
    if ($failures.Count -gt 1) { throw "Event log contains $($failures.Count) failure records" }

    $phaseEvents = @($records | Where-Object { [string]$_.event -eq 'phase' })
    $phases = @($map.Phases)
    if ($phaseEvents.Count -gt $phases.Count) { throw "Event log has $($phaseEvents.Count) phase records, expected at most $($phases.Count)" }

    $allowedEventTypes = @('session_ready','phase','session_timeout','startup_failure','protocol_failure','session_complete')
    $readyIndex = -1
    $completeIndex = -1
    $phaseIndexes = New-Object 'System.Collections.Generic.List[int]'
    $terminalIndex = -1
    for ($i = 0; $i -lt $records.Count; $i++) {
        $type = [string]$records[$i].event
        if ($type -notin $allowedEventTypes) { throw "Event log contains unexpected event type '$type' at record $i" }
        if ($type -eq 'session_ready') {
            if ($readyIndex -ge 0) { throw 'Event log contains duplicate session_ready records' }
            $readyIndex = $i
        }
        elseif ($type -eq 'session_complete') {
            if ($completeIndex -ge 0) { throw 'Event log contains duplicate session_complete records' }
            $completeIndex = $i
        }
        elseif ($type -eq 'phase') { [void]$phaseIndexes.Add($i) }
        else { $terminalIndex = $i }
    }
    if ($readyIndex -ne 0) { throw "session_ready is at record $readyIndex, expected the first record" }
    if ($completeIndex -ne $records.Count - 1) { throw "session_complete is at record $completeIndex, expected the last record" }
    if ($timeouts.Count -gt 1) { throw "Event log contains $($timeouts.Count) session_timeout records" }
    if ($failures.Count -gt 1) { throw "Event log contains $($failures.Count) failure records" }
    if (($timeouts.Count + $failures.Count) -gt 1) { throw 'Event log contains more than one terminal failure/timeout record' }
    if ($phaseIndexes.Count -gt 0) {
        if ($phaseIndexes[0] -ne 1) { throw "The first phase record is at index $($phaseIndexes[0]), expected immediately after session_ready" }
        for ($i = 0; $i -lt $phaseIndexes.Count; $i++) {
            if ($phaseIndexes[$i] -ne (1 + $i)) { throw "Phase records are not contiguous at record $($phaseIndexes[$i])" }
        }
    }
    $lastPhaseIndex = if ($phaseIndexes.Count -gt 0) { $phaseIndexes[$phaseIndexes.Count - 1] } else { 0 }
    if ($terminalIndex -ge 0) {
        if ($terminalIndex -le $lastPhaseIndex) { throw "Terminal failure/timeout at record $terminalIndex precedes the last observed phase at record $lastPhaseIndex" }
        if ($terminalIndex -ge $completeIndex) { throw "Terminal failure/timeout at record $terminalIndex is not before session_complete" }
    }
    $completeClaim = ([string]$completeEvent.complete -eq 'true')
    $reason = [string]$completeEvent.reason
    if ($completeClaim -and $terminalIndex -ge 0) { throw 'Session claims completion despite a terminal failure/timeout record' }

    $expectedUOffset = @{
        'caller-dispatch' = 0; 'header-trampoline-entry' = 0; 'body-prefetch-0' = 0; 'handler-0' = 0;
        'body-prefetch-1' = -2; 'handler-1' = -2; 'body-prefetch-2' = 0; 'handler-2' = 0;
        'body-prefetch-3' = -2; 'handler-3' = -2; 'body-prefetch-4' = 0; 'return-handler' = 0;
        'post-return-prefetch' = 0
    }
    $expectedSOffset = @{
        'caller-dispatch' = 0; 'header-trampoline-entry' = 0; 'body-prefetch-0' = -2; 'handler-0' = -2;
        'body-prefetch-1' = -2; 'handler-1' = -2; 'body-prefetch-2' = -2; 'handler-2' = -2;
        'body-prefetch-3' = -2; 'handler-3' = -2; 'body-prefetch-4' = -2; 'return-handler' = -2;
        'post-return-prefetch' = 0
    }

    $phaseRecords = New-Object 'System.Collections.Generic.List[object]'
    $u0 = $null
    $s0 = $null
    $inputWord = $null
    $sumWord = $null
    $resultWord = $null
    for ($i = 0; $i -lt $phaseEvents.Count; $i++) {
        $event = $phaseEvents[$i]
        $expected = $phases[$i]
        $name = [string]$expected.Phase
        Assert-EventIdentity $event $script:BuiltSha256 $mapHash ([string]$metadata.lua.capturedSha256) $script:MameSha256 ([string]$metadata.sessionId)
        if ([string]$event.phase -ne $name) { throw "Phase $i is $($event.phase), expected $name" }
        if ([int]$event.phaseIndex -ne $i) { throw "Phase $name index is $($event.phaseIndex)" }
        if ((ConvertTo-HexInt ([string]$event.pc)) -ne [int]$expected.Pc) { throw "Phase $name PC $($event.pc) is not $(Format-Hex16 ([int]$expected.Pc))" }
        if ($null -ne $expected.X -and (ConvertTo-HexInt ([string]$event.x)) -ne [int]$expected.X) { throw "Phase $name X $($event.x) is not $(Format-Hex16 ([int]$expected.X))" }
        if ((ConvertTo-HexInt ([string]$event.y)) -ne [int]$expected.Y) { throw "Phase $name Y $($event.y) is not $(Format-Hex16 ([int]$expected.Y))" }
        $expectedToken = if ($null -ne $expected.ReplacementToken) { [int]$expected.ReplacementToken } else { [int]$expected.Token }
        if ((ConvertTo-HexInt ([string]$event.token)) -ne $expectedToken) { throw "Phase $name token $($event.token) is not $(Format-Hex16 $expectedToken)" }
        $expectedTokenAddress = if ($name -eq 'header-trampoline-entry') { 0x1010 } elseif ($null -ne $expected.HandlerAddress -and [int]$expected.Pc -eq [int]$expected.HandlerAddress) { (([int]$expected.Y) - 2) -band 0xFFFF } else { [int]$expected.Y }
        if ((ConvertTo-HexInt ([string]$event.tokenAddress)) -ne $expectedTokenAddress) { throw "Phase $name token address $($event.tokenAddress) is not $(Format-Hex16 $expectedTokenAddress)" }
        if ($null -ne $expected.HandlerAddress) {
            if ([string]$event.handlerAddress -ine (Format-Hex16 ([int]$expected.HandlerAddress))) { throw "Phase $name handler address is $($event.handlerAddress)" }
        }
        if ($null -ne $expected.InlineOperandAddress) {
            if ((ConvertTo-HexInt ([string]$event.inlineOperandAddress)) -ne [int]$expected.InlineOperandAddress) { throw "Phase $name inline address is $($event.inlineOperandAddress)" }
            if ((ConvertTo-HexInt ([string]$event.inlineOperandValue)) -ne [int]$expected.InlineOperandValue) { throw "Phase $name inline value is $($event.inlineOperandValue)" }
        }
        if ($name -eq 'header-trampoline-entry') {
            if ([string]$event.controlStack0 -ine '9F3F') { throw "Phase $name pre-PSHS control stack top is $($event.controlStack0), expected 9F3F" }
            $headerSavedCursor = [string]$event.savedCursor
            if (![string]::IsNullOrWhiteSpace($headerSavedCursor) -and $headerSavedCursor -ine '9F16') {
                throw "Phase $name saved cursor is $headerSavedCursor; only the legacy captured map echo 9F16 is tolerated and ignored"
            }
        }
        if ($name -eq 'body-prefetch-0' -or $name -eq 'return-handler') {
            if ([string]$event.controlStack0 -ine '9F16') { throw "Phase $name saved control-stack cursor is $($event.controlStack0), expected 9F16" }
            if ([string]$event.savedCursor -ine '9F16') { throw "Phase $name saved cursor is $($event.savedCursor), expected 9F16" }
        }
        if ($null -eq $u0) {
            $u0 = ConvertTo-HexInt ([string]$event.u)
            $s0 = ConvertTo-HexInt ([string]$event.s)
            $inputWord = ConvertTo-HexInt ([string]$event.dataStack0)
            $sumWord = (($inputWord + 0xFF80) -band 0xFFFF)
            $resultWord = ($sumWord -bxor 0xFF80)
            if ($inputWord -ne 0x0000) { throw ("Observed input word is $(Format-Hex16 $inputWord), expected 0000") }
        }
        $expectedU = ($u0 + [int]$expectedUOffset[$name]) -band 0xFFFF
        $expectedS = ($s0 + [int]$expectedSOffset[$name]) -band 0xFFFF
        if ((ConvertTo-HexInt ([string]$event.u)) -ne $expectedU) { throw "Phase $name U $($event.u) is not $(Format-Hex16 $expectedU) from caller U $(Format-Hex16 $u0)" }
        if ((ConvertTo-HexInt ([string]$event.s)) -ne $expectedS) { throw "Phase $name S $($event.s) is not $(Format-Hex16 $expectedS) from caller S $(Format-Hex16 $s0)" }
        $expectedTop = $null
        $expectedSecond = $null
        switch ($name) {
            'caller-dispatch' { $expectedTop = $inputWord }
            'header-trampoline-entry' { $expectedTop = $inputWord }
            'body-prefetch-0' { $expectedTop = $inputWord }
            'handler-0' { $expectedTop = $inputWord }
            'body-prefetch-1' { $expectedTop = 0xFF80 }
            'handler-1' { $expectedTop = 0xFF80 }
            'body-prefetch-2' { $expectedTop = $sumWord }
            'handler-2' { $expectedTop = $sumWord }
            'body-prefetch-3' { $expectedTop = 0xFF80; $expectedSecond = $sumWord }
            'handler-3' { $expectedTop = 0xFF80; $expectedSecond = $sumWord }
            'body-prefetch-4' { $expectedTop = $resultWord }
            'return-handler' { $expectedTop = $resultWord }
            'post-return-prefetch' { $expectedTop = $resultWord }
        }
        if ($null -ne $expectedTop -and (ConvertTo-HexInt ([string]$event.dataStack0)) -ne $expectedTop) { throw "Phase $name top stack word $($event.dataStack0) is not $(Format-Hex16 $expectedTop)" }
        if ($null -ne $expectedSecond -and (ConvertTo-HexInt ([string]$event.dataStack1)) -ne $expectedSecond) { throw "Phase $name second stack word $($event.dataStack1) is not $(Format-Hex16 $expectedSecond)" }
        $phaseRecords.Add([ordered]@{
            phase = $name
            pc = [string]$event.pc
            x = [string]$event.x
            y = [string]$event.y
            u = [string]$event.u
            s = [string]$event.s
            token = [string]$event.token
            tokenAddress = [string]$event.tokenAddress
            dataStack0 = [string]$event.dataStack0
            dataStack1 = [string]$event.dataStack1
            controlStack0 = [string]$event.controlStack0
            savedCursor = [string]$event.savedCursor
            savedCursorAuthoritative = ($name -eq 'body-prefetch-0' -or $name -eq 'return-handler')
            savedCursorSource = if ($name -eq 'body-prefetch-0' -or $name -eq 'return-handler') { 'live_control_stack_top' } elseif ($name -eq 'header-trampoline-entry' -and -not [string]::IsNullOrWhiteSpace([string]$event.savedCursor)) { 'legacy_map_echo_ignored' } else { '' }
            inlineOperandAddress = [string]$event.inlineOperandAddress
            inlineOperandValue = [string]$event.inlineOperandValue
            handlerAddress = [string]$event.handlerAddress
            a = [string]$event.a
            b = [string]$event.b
            d = [string]$event.d
            cc = [string]$event.cc
            emulatedTime = [string]$event.emulatedTime
        })
    }

    $bodyCursorRecord = $phaseRecords | Where-Object { $_.phase -eq 'body-prefetch-0' } | Select-Object -First 1
    $returnCursorRecord = $phaseRecords | Where-Object { $_.phase -eq 'return-handler' } | Select-Object -First 1
    $headerCursorRecord = $phaseRecords | Where-Object { $_.phase -eq 'header-trampoline-entry' } | Select-Object -First 1
    $observedSavedCursorLive = if ($null -ne $returnCursorRecord) { [string]$returnCursorRecord.controlStack0 } elseif ($null -ne $bodyCursorRecord) { [string]$bodyCursorRecord.controlStack0 } else { '' }
    $headerSavedCursorCaptured = if ($null -ne $headerCursorRecord) { [string]$headerCursorRecord.savedCursor } else { '' }

    if ($completeClaim -and $phaseEvents.Count -ne $phases.Count) { throw 'Session claims completion without all ordered phases' }
    if ($evidenceClass -eq 'natural' -and ($phaseEvents.Count -gt 0 -or $completeClaim) -and -not $inputProvenance.used) {
        throw 'A natural composite phase or completion claim requires tracked physical input replay provenance'
    }
    if ($inputProvenance.used -and $phaseEvents.Count -gt 0) {
        $firstPhaseTime = [double]$phaseRecords[0].emulatedTime
        if ($firstPhaseTime -le [double]$inputProvenance.observed.startStartTime) {
            throw "First composite phase at $firstPhaseTime s did not follow the tracked start pulse at $($inputProvenance.observed.startStartTime) s"
        }
    }
    $runRecordPath = Join-Path $run 'run-record.json'
    if (!(Test-Path -LiteralPath $runRecordPath -PathType Leaf)) { throw "MAME run record is missing: $runRecordPath" }
    $runRecord = Read-JsonFile $runRecordPath
    if ($null -eq $runRecord.exitCode) { throw 'MAME run record has no exit code' }
    if ($null -eq $runRecord.timedOut) { throw 'MAME run record has no timeout flag' }
    if ([bool]$runRecord.timedOut) { throw 'MAME run record reports a wall timeout; no complete claim is allowed' }
    if ([int]$runRecord.exitCode -ne 0) { throw "MAME run record exit code is $($runRecord.exitCode); no complete claim is allowed" }
    $exitCodePath = Join-Path $run 'exit-code.txt'
    if (!(Test-Path -LiteralPath $exitCodePath -PathType Leaf)) { throw "MAME exit-code.txt is missing: $exitCodePath" }
    $exitCodeText = (Get-Content -LiteralPath $exitCodePath -Raw).Trim()
    if ($exitCodeText -ne [string][int]$runRecord.exitCode) { throw "exit-code.txt is '$exitCodeText', expected $($runRecord.exitCode)" }
    $phaseComplete = ($phaseEvents.Count -eq $phases.Count -and $completeClaim -and $reason -eq 'composite_call_complete')
    $status = 'blocked_not_reached'
    if ($phaseComplete) {
        if ($evidenceClass -eq 'natural') { $status = 'complete_natural_composite_call' }
        else { $status = 'synthetic_fixture_complete_not_evidence' }
    }
    elseif ($reason -eq 'emulated_budget' -or $reason -eq 'wall_timeout') {
        $status = 'blocked_not_reached'
    }
    else {
        $status = 'blocked_incomplete'
    }

    if ($phaseComplete) {
        if ($null -eq $returnCursorRecord) { throw 'Session claims completion without a live return-handler saved cursor' }
        if ([string]$returnCursorRecord.controlStack0 -ine '9F16') { throw "Session claims completion with return-handler controlStack0 $($returnCursorRecord.controlStack0), expected 9F16" }
        if ([int]$completeEvent.observed -ne $phases.Count) { throw 'Session complete observed count is wrong' }
        if ([string]$completeEvent.inputWord -ine '0000') { throw 'Session complete input word is not 0000' }
        if ([string]$completeEvent.resultWord -ine '0000') { throw 'Session complete result word is not 0000' }
        if ([string]$completeEvent.netU -ine '0000') { throw 'Session complete U delta is not zero' }
        if ([string]$completeEvent.netS -ine '0000') { throw 'Session complete S delta is not zero' }
        if ([string]$completeEvent.postY -ine '9F16') { throw 'Session complete post-return Y is not 9F16' }
        if ([string]$completeEvent.postToken -ine '75A9') { throw 'Session complete post-return token is not 75A9' }
        $handlerSequence = ($phaseRecords | Where-Object { $_.handlerAddress -ne '' -and $_.pc -eq $_.handlerAddress } | ForEach-Object { $_.pc }) -join ','
        if ($handlerSequence -ine '795D,7880,795D,7AB1,7931') { throw "Observed handler sequence is $handlerSequence" }
        $post = $phaseRecords[$phaseRecords.Count - 1]
        if ($post.phase -ne 'post-return-prefetch') { throw 'Final observed phase is not post-return-prefetch' }
        if ($post.y -ine '9F16' -or $post.token -ine '75A9' -or $post.u -ine (Format-Hex16 $u0) -or $post.s -ine (Format-Hex16 $s0)) { throw 'Post-return phase does not restore the caller cursor and stacks' }
        if ($post.dataStack0 -ine '0000') { throw 'Post-return result word is not 0000' }
    }

    $priorHash = Get-HashValue $priorPath 'SHA256'
    if ($priorHash -ine $script:PreviousTraceSha256) { throw "Prior trace SHA256 is $priorHash, expected $script:PreviousTraceSha256" }
    $prior = Read-JsonFile $priorPath
    $priorCall = $prior.runs.original.observation.call
    $priorValues = [ordered]@{
        path = [IO.Path]::GetFullPath($priorPath)
        sha256 = $priorHash
        classification = 'prior_trace_comparison_not_new_control_run'
        inputWord = [string]$priorCall.node_prefetches[0].top
        result = [string]$priorCall.result
        savedCursor = [string]$priorCall.saved_cursor
        postReturnToken = [string]$priorCall.post_return.token
        postReturnS = [string]$priorCall.post_return.s
        handlers = (@($priorCall.handler_entries) | ForEach-Object { [string]$_.pc }) -join ','
    }
    $returnObserved = ($phaseRecords.Count -gt 0 -and $phaseRecords[$phaseRecords.Count - 1].phase -eq 'post-return-prefetch')
    $priorComparison = [ordered]@{
        prior = $priorValues
        observedInputWord = if ($null -ne $inputWord) { Format-Hex16 $inputWord } else { '' }
        observedResultWord = if ($returnObserved -and $null -ne $resultWord) { Format-Hex16 $resultWord } else { '' }
        observedSavedCursor = $observedSavedCursorLive
        observedSavedCursorSource = if ($null -ne $returnCursorRecord) { 'return-handler live controlStack0' } elseif ($null -ne $bodyCursorRecord) { 'body-prefetch-0 live controlStack0' } else { 'not observed' }
        observedPostReturnToken = if ($returnObserved) { $phaseRecords[$phaseRecords.Count - 1].token } else { '' }
        inputMatches = ($null -ne $inputWord -and $priorValues.inputWord -ieq (Format-Hex16 $inputWord))
        resultMatches = ($returnObserved -and $null -ne $resultWord -and $priorValues.result -ieq (Format-Hex16 $resultWord))
        savedCursorMatches = (-not [string]::IsNullOrWhiteSpace($observedSavedCursorLive) -and $priorValues.savedCursor -ieq $observedSavedCursorLive)
        postReturnTokenMatches = ($returnObserved -and $priorValues.postReturnToken -ieq $phaseRecords[$phaseRecords.Count - 1].token)
        note = 'Prior original trace is a comparison reference only; no new original control run was made. Saved cursor is compared only from a live body-prefetch-0 or return-handler controlStack0; the header map echo is not used.'
    }

    $debugLogPath = Join-Path $run 'debug.log'
    $consolePath = Join-Path $run 'console.txt'
    $readyPath = Join-Path $run 'ready.txt'
    $completePath = Join-Path $run 'session-complete.txt'
    $currentLuaSha256 = Get-HashValue (Join-Path $script:Root 'tools/lua/IlCompositeNatural.lua') 'SHA256'
    $currentToolSha256 = Get-HashValue $PSCommandPath 'SHA256'
    $capturedLuaSha256 = [string]$metadata.lua.capturedSha256
    $capturedToolSha256 = [string]$metadata.capture_tool.sha256
    $completePostFieldsPresent = @('resultWord','postY','postS','postToken','netU','netS' | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$completeEvent.$_) }).Count
    $verificationGap = [ordered]@{
        present = ($currentLuaSha256 -ine $capturedLuaSha256) -or ($currentToolSha256 -ine $capturedToolSha256)
        capturedLuaSha256 = $capturedLuaSha256
        currentLuaSha256 = $currentLuaSha256
        luaChangedAfterCapture = ($currentLuaSha256 -ine $capturedLuaSha256)
        capturedToolSha256 = $capturedToolSha256
        currentToolSha256 = $currentToolSha256
        toolChangedAfterCapture = ($currentToolSha256 -ine $capturedToolSha256)
        completeEventPostFieldsPresent = $completePostFieldsPresent
        completeEventPostFieldsUsed = $false
        failedCapturePostFieldsIgnored = (-not $returnObserved -and $completePostFieldsPresent -gt 0)
        luaExecutedForAnalysis = $false
        rerunPerformed = $false
        note = 'The raw capture was not rerun. Any observer/checker change after this capture is reported as a verification gap, not substituted for the captured bytes. Result/post-return fields are used only when the final observed phase is post-return-prefetch; historical failed-run fields are retained in the raw event but ignored.'
    }

    $reanalysis = $null
    if (![string]::IsNullOrWhiteSpace($ReanalysisSourceRun)) {
        $sourceRun = [IO.Path]::GetFullPath($ReanalysisSourceRun)
        $sourceEvents = Join-Path $sourceRun 'events.jsonl'
        if (!(Test-Path -LiteralPath $sourceEvents -PathType Leaf)) { throw "Reanalysis source run has no events.jsonl: $sourceRun" }
        $reanalysis = [ordered]@{
            classification = 'read_only_private_copy_reanalysis'
            sourceRunDirectory = $sourceRun
            sourceEventsSha256 = Get-HashValue $sourceEvents 'SHA256'
            analysisRunDirectory = $run
            rawArtifactModified = $false
            luaExecuted = $false
            note = 'The original raw run was copied and reanalysed offline. No raw file was edited and no MAME or Lua process was started.'
        }
    }

    $analysis = [ordered]@{
        status = $status
        evidenceClass = $evidenceClass
        classification = if ($evidenceClass -eq 'natural') { 'Natural fresh-boot MAME 0.281 observation of the exact compiled composite image using the existing tracked physical coin/start replay. Boundaries come only from native debugger breakpoints; the Lua periodic callback is the stopped-state driver. No save/load state, PC/register/RAM seed, debugger write or synthetic state injection.' } else { 'Synthetic checker fixture. This is not natural execution evidence and cannot satisfy the composite-call acceptance.' }
        protocol = $script:Protocol
        sessionId = [string]$metadata.sessionId
        originalRom = $originalIdentity
        builtRom = $builtIdentity
        runRom = $runRomIdentity
        sourceMap = [ordered]@{ path=[IO.Path]::GetFullPath($sourceMapPath); sha256=$mapHash; contract=$contract }
        buildReport = [ordered]@{ path=[IO.Path]::GetFullPath($buildReportPath); sha256=$buildHash }
        lua = $metadata.lua
        mame = $metadata.mame
        frontend = $metadata.frontend
        run = [ordered]@{
            directory = $run
            mameRecord = $runRecord
            exitCode = if ($null -ne $runRecord) { $runRecord.exitCode } else { $null }
            timedOut = if ($null -ne $runRecord) { $runRecord.timedOut } else { $null }
            strictJsonPass = [bool]$parseInfo.strict
            eventRecordCount = $parseInfo.recordCount
            eventsSha256 = $parseInfo.sha256
            strictSummaryPath = $parseInfo.summaryPath
            strictSummarySha256 = $parseInfo.summarySha256
            debugLogSha256 = if (Test-Path -LiteralPath $debugLogPath) { Get-HashValue $debugLogPath 'SHA256' } else { '' }
            consoleSha256 = if (Test-Path -LiteralPath $consolePath) { Get-HashValue $consolePath 'SHA256' } else { '' }
            readySha256 = if (Test-Path -LiteralPath $readyPath) { Get-HashValue $readyPath 'SHA256' } else { '' }
            sessionCompleteSha256 = if (Test-Path -LiteralPath $completePath) { Get-HashValue $completePath 'SHA256' } else { '' }
            stateFiles = $stateFiles.Count
            inputPolicy = $inputPolicy
            inputReplayUsed = [bool]$inputProvenance.used
            saveStateLoaded = [bool]$metadata.save_state_loaded
            inputInjection = [bool]$metadata.input_injection
            stateInjection = [bool]$metadata.state_injection
            debuggerWrites = [bool]$metadata.debugger_writes
            startingNvram = [string]$metadata.starting_nvram
            startingConfiguration = [string]$metadata.starting_configuration
        }
        inputProvenance = $inputProvenance
        runLocalAssets = $runLocalAssets
        reanalysis = $reanalysis
        failure = if ($null -eq $failure) { $null } else { [ordered]@{
            event = [string]$failure.event
            code = [string]$failure.code
            message = [string]$failure.message
            observed = [string]$failure.observed
            expected = [string]$failure.expected
        } }
        verificationGap = $verificationGap
        session = [ordered]@{
            reason = $reason
            failureCode = if ($null -ne $failure) { [string]$failure.code } else { '' }
            completeClaim = $completeClaim
            timeoutRecords = $timeouts.Count
            terminalRecordCount = $timeouts.Count + $failures.Count
            eventSequenceValidated = $true
            readyIsFirst = ($readyIndex -eq 0)
            completeIsLast = ($completeIndex -eq $records.Count - 1)
            phaseCount = $phaseEvents.Count
            expectedPhaseCount = $phases.Count
            completeEventPostFieldsPresent = $completePostFieldsPresent
            completeEventPostFieldsUsed = $false
        }
        blocker = if ($phaseComplete) { $null } else { [ordered]@{
            status = if ($null -ne $failure) { 'protocol_failure' } else { 'not_reached' }
            reason = $reason
            observedPhaseCount = $phaseEvents.Count
            expectedPhaseCount = $phases.Count
            emulatedSeconds = [string]$completeEvent.emulatedTime
            inputPolicy = $inputPolicy
            inputReplayUsed = [bool]$inputProvenance.used
            failureCode = if ($null -ne $failure) { [string]$failure.code } else { '' }
            priorTraceFirstCallEmulatedTime = '37.076473837'
            priorTraceFirstCallBasis = 'Prior trace documented first 9F14/9ED9 call at 37.076473837 s after tracked physical inputs; the curated prior trace did not store a scalar call time.'
            priorTraceInputSchedule = 'Tracked replay coin pulse at fixture frames 2100-2103 and prior effective start frames 2221-2224.'
            note = if ($null -ne $failure) {
                'The single revised tracked-replay capture stopped on an observer protocol failure. No third capture was made; the raw capture and this failure are preserved.'
            } elseif ($inputProvenance.used) {
                'One bounded tracked physical-input replay run. No retry, save state, PC/register/RAM seed or debugger state write was made.'
            } else {
                'Preserved il-composite-natural-35 no-input history: one bounded no-input run only; no replay, retry or second attempt was made for that attempt.'
            }
        } }
        phases = $phaseRecords.ToArray()
        call = [ordered]@{
            callerAddress = '9F14'
            callerReplacementToken = '1010'
            headerAddress = '1010'
            headerValue = '00F8'
            bodyStart = '1012'
            bodyEndExclusive = '1020'
            trampolinePc = '00F8'
            trampolineX = '1012'
            savedCursor = $observedSavedCursorLive
            savedCursorAuthority = if ($null -ne $returnCursorRecord) { 'return-handler live controlStack0' } elseif ($null -ne $bodyCursorRecord) { 'body-prefetch-0 live controlStack0' } else { 'not observed' }
            headerSavedCursorMapEcho = $headerSavedCursorCaptured
            headerSavedCursorAuthoritative = $false
            postReturnY = if ($returnObserved) { $phaseRecords[$phaseRecords.Count - 1].y } else { '' }
            postReturnToken = if ($returnObserved) { $phaseRecords[$phaseRecords.Count - 1].token } else { '' }
            inputWord = if ($null -ne $inputWord) { Format-Hex16 $inputWord } else { '' }
            sumWord = if ($null -ne $sumWord) { Format-Hex16 $sumWord } else { '' }
            resultWord = if ($returnObserved -and $null -ne $resultWord) { Format-Hex16 $resultWord } else { '' }
            netU = if ($returnObserved) { Format-Hex16 (((ConvertTo-HexInt $phaseRecords[$phaseRecords.Count - 1].u) - $u0) -band 0xFFFF) } else { '' }
            netS = if ($returnObserved) { Format-Hex16 (((ConvertTo-HexInt $phaseRecords[$phaseRecords.Count - 1].s) - $s0) -band 0xFFFF) } else { '' }
            complete = $phaseComplete
            returnObserved = $returnObserved
        }
        priorTraceComparison = $priorComparison
        limitations = @(
            'MAME success is not physical MPU4 hardware compatibility.',
            'Only the single composite call reached from the naturally observed 9F14 caller site is claimed.',
            'The broader purpose of the 9F12 caller remains unresolved.',
            'No paid-gate, full-game or hardware claim is made.'
        )
    }
    return $analysis
}

function Write-EvidenceSummary {
    param([string]$Path,$Analysis)
    $attempt1Run = Join-Path $script:Root 'artifacts/deepseek/il-composite-natural-35/run-01'
    $attempt1Events = Join-Path $attempt1Run 'events.jsonl'
    $attempt1 = [ordered]@{
        taskId = 'il-composite-natural-35'
        resultStatus = 'blocked_not_reached'
        evidenceClass = 'natural'
        attemptClassification = 'no_input_attempt_history_not_renamed_or_evaded'
        inputPolicy = 'none'
        inputReplayUsed = $false
        reason = 'emulated_budget'
        phaseCount = 0
        expectedPhaseCount = 13
        emulatedSeconds = '180.000000000'
        runDirectory = [IO.Path]::GetFullPath($attempt1Run)
        eventsSha256 = if (Test-Path -LiteralPath $attempt1Events -PathType Leaf) { Get-HashValue $attempt1Events 'SHA256' } else { '912CD4442EB623B59A8786386D0D937D0343AF61C1EA758D6D6743AC16CF86F3' }
        note = 'First natural composite-boundary attempt. One bounded no-input fresh boot observed none of the thirteen phases. Preserved unchanged as an unsuccessful attempt.'
    }
    $attempt2 = [ordered]@{
        taskId = 'il-composite-replay-36'
        resultStatus = $Analysis.status
        evidenceClass = $Analysis.evidenceClass
        attemptClassification = if ($Analysis.inputProvenance.used) { 'revised_tracked_physical_input_replay_attempt' } else { 'preserved_no_input_history_reanalysis' }
        inputPolicy = $Analysis.inputProvenance.policy
        inputReplayUsed = [bool]$Analysis.inputProvenance.used
        reason = $Analysis.session.reason
        phaseCount = $Analysis.session.phaseCount
        expectedPhaseCount = $Analysis.session.expectedPhaseCount
        failure = $Analysis.failure
        runDirectory = if ($null -ne $Analysis.reanalysis) { $Analysis.reanalysis.sourceRunDirectory } else { [IO.Path]::GetFullPath($Analysis.run.directory) }
        analysisRunDirectory = [IO.Path]::GetFullPath($Analysis.run.directory)
        eventsSha256 = $Analysis.run.eventsSha256
        call = $Analysis.call
        note = if ($Analysis.call.complete) { 'Second attempt completed the natural composite call using the existing tracked coin/start replay. The invocation remains the same natural composite boundary as attempt 1.' } elseif ($null -ne $Analysis.failure) { "Second attempt reached the revised replay input and stopped on an observer protocol failure ($($Analysis.failure.code)); no third capture was made." } else { 'Second attempt did not complete; no third attempt was made.' }
    }
    $unsuccessfulAttempts = if ($Analysis.call.complete) { 1 } else { 2 }
    $evidence = [ordered]@{
        taskId = 'il-composite-replay-36'
        schemaVersion = 1
        resultStatus = $Analysis.status
        evidenceClass = $Analysis.evidenceClass
        classification = $Analysis.classification
        boundaryHistory = [ordered]@{
            boundary = 'natural-composite-1010-call-from-9F14'
            attempts = 2
            unsuccessfulAttempts = $unsuccessfulAttempts
            successfulAttempts = if ($Analysis.call.complete) { 1 } else { 0 }
            attempt1 = $attempt1
            attempt2 = $attempt2
            note = 'The attempt-1 failure remains distinct and is not renamed to evade the two-attempt boundary. Attempt 2 is the single authorized revised tracked-physical-input replay capture.'
        }
        originalRom = $Analysis.originalRom
        builtRom = $Analysis.builtRom
        sourceMap = $Analysis.sourceMap
        buildReport = $Analysis.buildReport
        lua = $Analysis.lua
        mame = $Analysis.mame
        frontend = $Analysis.frontend
        inputProvenance = $Analysis.inputProvenance
        runLocalAssets = $Analysis.runLocalAssets
        reanalysis = $Analysis.reanalysis
        failure = $Analysis.failure
        verificationGap = $Analysis.verificationGap
        run = $Analysis.run
        session = $Analysis.session
        blocker = $Analysis.blocker
        call = $Analysis.call
        phases = $Analysis.phases
        priorTraceComparison = $Analysis.priorTraceComparison
        limitations = $Analysis.limitations
        generatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-JsonFile $Path $evidence 30
}

function Invoke-Capture {
    param([string]$Run)
    $run = [IO.Path]::GetFullPath($Run)
    if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only run directory: $run" }
    foreach ($path in @($MameExecutable,$RomDirectory,$BuiltRom,$SourceMapPath,$BuildReportPath,$OriginalRom,$PriorTracePath,$ReplayPath,$InputLuaPath)) {
        if (!(Test-Path -LiteralPath $path)) { throw "Required input is missing: $path" }
    }
    $originalIdentity = Assert-FileIdentity $OriginalRom $script:OriginalSha1 $script:OriginalSha256 'original ROM'
    $builtIdentity = Assert-FileIdentity $BuiltRom $script:BuiltSha1 $script:BuiltSha256 'built ROM'
    $replaySourceIdentity = Assert-FileHashIdentity $ReplayPath $script:ReplaySha256 'tracked replay fixture'
    $inputLuaSourceIdentity = Assert-FileHashIdentity $InputLuaPath $script:InputLuaSha256 'tracked input Lua'
    $replaySchedule = Get-ReplaySchedule $ReplayPath
    $mameHash = Get-HashValue $MameExecutable 'SHA256'
    if ($mameHash -ine $script:MameSha256) { throw "MAME SHA256 is $mameHash, expected $script:MameSha256" }
    $mapHash = Get-HashValue $SourceMapPath 'SHA256'
    if ($mapHash -ine $script:MapSha256) { throw "Source map SHA256 is $mapHash, expected $script:MapSha256" }
    $buildHash = Get-HashValue $BuildReportPath 'SHA256'
    $built = [IO.File]::ReadAllBytes($BuiltRom)
    $original = [IO.File]::ReadAllBytes($OriginalRom)
    $map = Read-JsonFile $SourceMapPath
    $build = Read-JsonFile $BuildReportPath
    $contract = Test-CompositeMapContract $map $build $built $original

    New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
    foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
        New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
    }
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    Copy-Item -LiteralPath $BuiltRom -Destination $runRom -ErrorAction Stop
    $runRomIdentity = Assert-FileIdentity $runRom $script:BuiltSha1 $script:BuiltSha256 'isolated run ROM before launch'
    Copy-Item -LiteralPath $SourceMapPath -Destination (Join-Path $run 'composite-source-map.json') -ErrorAction Stop
    Copy-Item -LiteralPath $BuildReportPath -Destination (Join-Path $run 'build-report.json') -ErrorAction Stop
    $runReplayPath = Join-Path $run 'replay-actions.csv'
    $runInputLuaPath = Join-Path $run 'input.lua'
    Copy-Item -LiteralPath $ReplayPath -Destination $runReplayPath -ErrorAction Stop
    Copy-Item -LiteralPath $InputLuaPath -Destination $runInputLuaPath -ErrorAction Stop
    $runReplayIdentity = Assert-FileHashIdentity $runReplayPath $script:ReplaySha256 'isolated replay fixture copy'
    $runInputLuaIdentity = Assert-FileHashIdentity $runInputLuaPath $script:InputLuaSha256 'isolated input Lua copy'
    Copy-Item -LiteralPath (Join-Path $script:Root 'tools/lua/IlCompositeNatural.lua') -Destination (Join-Path $run 'IlCompositeNatural.lua') -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlCompositeNatural.lua')`n",$script:Utf8)
    $capturedLuaPath = Join-Path $run 'IlCompositeNatural.lua'
    $luaSourcePath = Join-Path $script:Root 'tools/lua/IlCompositeNatural.lua'
    $luaSourceHash = Get-HashValue $luaSourcePath 'SHA256'
    $luaCapturedHash = Get-HashValue $capturedLuaPath 'SHA256'
    if ($luaSourceHash -ine $luaCapturedHash) { throw 'Captured Lua hash differs from the tracked Lua source' }
    $toolHash = Get-HashValue $PSCommandPath 'SHA256'
    Write-CompositeMapLua (Join-Path $run 'composite-map.lua') $map

    $sessionId = [guid]::NewGuid().ToString('D')
    $config = [ordered]@{
        schemaVersion = 1
        protocol = $script:Protocol
        sessionId = $sessionId
        secondsToRun = $SecondsToRun
        wallTimeoutSeconds = $WallTimeoutSeconds
        inputPolicy = 'tracked_physical_replay'
        expectedReplaySha256 = $script:ReplaySha256
        expectedInputLuaSha256 = $script:InputLuaSha256
        expectedImageSha256 = $script:BuiltSha256
        expectedOriginalRomSha256 = $script:OriginalSha256
        expectedSourceMapSha256 = $mapHash
        expectedBuildReportSha256 = $buildHash
        expectedLuaSha256 = $luaCapturedHash
        expectedMameSha256 = $mameHash
    }
    Write-CompositeConfigLua (Join-Path $run 'session-config.lua') $config
    Write-JsonFile (Join-Path $run 'session-config.json') $config 8
    $runLocalAssets = [ordered]@{
        lua = $luaCapturedHash
        map_lua = Get-HashValue (Join-Path $run 'composite-map.lua') 'SHA256'
        config_lua = Get-HashValue (Join-Path $run 'session-config.lua') 'SHA256'
        config_json = Get-HashValue (Join-Path $run 'session-config.json') 'SHA256'
        observer = Get-HashValue (Join-Path $run 'observer.lua') 'SHA256'
    }
    if ($runLocalAssets.map_lua -ine (Get-StringSha256 (Get-CompositeMapLuaText $map))) { throw 'Captured composite-map.lua is not the canonical rendering of the source map' }
    if ($runLocalAssets.config_lua -ine (Get-StringSha256 (Get-CompositeConfigLuaText $config))) { throw 'Captured session-config.lua is not the canonical rendering of the session config' }

    $preRunCounts = [ordered]@{}
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        $preRunCounts[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count
        if ($preRunCounts[$name] -ne 0) { throw "Pre-run directory $name is not empty" }
    }
    $preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
    if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
    Write-JsonFile (Join-Path $run 'pre-run-empty.json') $preRunCounts 6

    $versionOut = Join-Path $run 'mame-version.txt'
    $versionErr = Join-Path $run 'mame-version.err.txt'
    $versionRecord = Invoke-ProcessRecord -FilePath $MameExecutable -Arguments @('-version') -WorkingDirectory $run -StdOutPath $versionOut -StdErrPath $versionErr -TimeoutSeconds 60
    if ($versionRecord.timedOut -or $versionRecord.exitCode -ne 0) { throw "MAME -version failed: exit=$($versionRecord.exitCode)" }
    $mameVersion = ((Get-Content -LiteralPath $versionOut -Raw).Trim() -split "`r?`n")[0]
    if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }

    $bgfxPath = [IO.Path]::GetFullPath((Join-Path (Split-Path ([IO.Path]::GetFullPath($MameExecutable)) -Parent) 'bgfx'))
    if (!(Test-Path -LiteralPath $bgfxPath -PathType Container)) { throw "Installed BGFX asset directory is missing: $bgfxPath" }

    $arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
        '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
        '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
        '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
        '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','imgui','-debuglog',
        '-video','bgfx','-sound','none','-window','-skip_gameinfo','-nothrottle',
        '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
        '-autoboot_script',(Join-Path $run 'observer.lua'),
        '-bgfx_path',$bgfxPath)
    Write-JsonFile (Join-Path $run 'arguments.json') @($arguments) 6
    $metadata = [ordered]@{
        protocol = $script:Protocol
        sessionId = $sessionId
        original_rom = $originalIdentity
        built_rom = $builtIdentity
        run_rom_before = $runRomIdentity
        source_map = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $run 'composite-source-map.json')); sha256=$mapHash }
        build_report = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $run 'build-report.json')); sha256=$buildHash }
        lua = [ordered]@{
            sourcePath = [IO.Path]::GetFullPath($luaSourcePath)
            sourceSha256 = $luaSourceHash
            capturedPath = [IO.Path]::GetFullPath($capturedLuaPath)
            capturedSha256 = $luaCapturedHash
        }
        capture_tool = [ordered]@{ path=[IO.Path]::GetFullPath($PSCommandPath); sha256=$toolHash }
        run_local_assets = $runLocalAssets
        input_replay = [ordered]@{
            path = $runReplayIdentity.path
            length = $runReplayIdentity.length
            sha256 = $runReplayIdentity.sha256
            input_lua_path = $runInputLuaIdentity.path
            input_lua_sha256 = $runInputLuaIdentity.sha256
            coin_event = $replaySchedule.coin
            start_event = $replaySchedule.start
            classification = 'tracked_physical_input_replay_no_state_injection'
        }
        mame = [ordered]@{ executable=[IO.Path]::GetFullPath($MameExecutable); sha256=$mameHash; version=$mameVersion }
        frontend = [ordered]@{
            debugger = 'imgui'
            video = 'bgfx'
            bgfx_path = $bgfxPath
            focus_stealing = $false
        }
        contract = $contract
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
        starting_nvram = 'absent'
        starting_configuration = 'absent; -noreadconfig'
        save_state_loaded = $false
        state_injection = $false
        input_injection = $false
        input_replay_used = $true
        input_policy = 'tracked_physical_replay'
        evidence_class = 'natural'
        debugger_writes = $false
        classification = 'Fresh-isolated natural compiled-image run using the existing tracked physical coin/start replay with read-only native debugger boundary stops. No save state, PC/register/RAM seed, debugger write or synthetic state injection.'
    }
    Write-JsonFile (Join-Path $run 'session-metadata.json') $metadata 30

    $previousMap = $env:FML_IL_COMPOSITE_MAP
    $previousConfig = $env:FML_IL_COMPOSITE_CONFIG
    $previousReplay = $env:MPU4_REPLAY
    $previousPolicy = $env:MPU4_POLICY
    try {
        $env:FML_IL_COMPOSITE_MAP = 'composite-map.lua'
        $env:FML_IL_COMPOSITE_CONFIG = 'session-config.lua'
        $env:MPU4_REPLAY = $runReplayPath
        $env:MPU4_POLICY = '7'
        $runRecord = Invoke-ProcessRecord -FilePath $MameExecutable -Arguments $arguments -WorkingDirectory $run -StdOutPath (Join-Path $run 'console.txt') -StdErrPath (Join-Path $run 'console.err.txt') -TimeoutSeconds $WallTimeoutSeconds
    }
    finally {
        $env:FML_IL_COMPOSITE_MAP = $previousMap
        $env:FML_IL_COMPOSITE_CONFIG = $previousConfig
        $env:MPU4_REPLAY = $previousReplay
        $env:MPU4_POLICY = $previousPolicy
    }
    $runRecord.commandId = 'il-composite-replay-capture-36'
    $runRecord.description = 'One fresh-boot compiled-image MAME observation at native composite boundaries with the existing tracked physical coin/start replay'
    Write-JsonFile (Join-Path $run 'run-record.json') $runRecord 8
    [IO.File]::WriteAllText((Join-Path $run 'exit-code.txt'),[string]$runRecord.exitCode,$script:Utf8)

    if ($runRecord.timedOut) { throw "MAME exceeded the ${WallTimeoutSeconds}s wall cap; partial run preserved at $run" }
    if ($runRecord.exitCode -ne 0) { throw "MAME exited $($runRecord.exitCode); inspect $run" }
    if (!(Test-Path -LiteralPath (Join-Path $run 'events.jsonl') -PathType Leaf)) { throw "Lua observer did not produce events.jsonl; inspect $run" }

    $analysis = Get-CompositeAnalysis -Run $run -BuiltPath $runRom -SourceMapPath (Join-Path $run 'composite-source-map.json') -BuildReportPath (Join-Path $run 'build-report.json') -OriginalPath $OriginalRom -PriorPath $PriorTracePath
    Write-JsonFile (Join-Path $run 'observation.json') $analysis 40
    Write-EvidenceSummary $EvidencePath $analysis
    return [ordered]@{
        run = $run
        status = $analysis.status
        complete = $analysis.call.complete
        phases = $analysis.session.phaseCount
        expectedPhases = $analysis.session.expectedPhaseCount
        strictJsonPass = $analysis.run.strictJsonPass
        inputPolicy = $analysis.inputProvenance.policy
        inputReplayUsed = $analysis.inputProvenance.used
        coinFrames = $analysis.inputProvenance.observed.coinFrames
        startFrames = $analysis.inputProvenance.observed.startFrames
        failureCode = $analysis.session.failureCode
        evidence = [IO.Path]::GetFullPath($EvidencePath)
        evidenceSha256 = Get-HashValue $EvidencePath 'SHA256'
        eventsSha256 = $analysis.run.eventsSha256
        resultWord = $analysis.call.resultWord
        netU = $analysis.call.netU
        netS = $analysis.call.netS
    }
}

function Invoke-Analyze {
    param([string]$Run)
    if ([string]::IsNullOrWhiteSpace($Run)) { throw 'RunDirectory is required for Analyze and Verify' }
    $analysis = Get-CompositeAnalysis -Run $Run -BuiltPath $BuiltRom -SourceMapPath $SourceMapPath -BuildReportPath $BuildReportPath -OriginalPath $OriginalRom -PriorPath $PriorTracePath -ReanalysisSourceRun $ReanalysisSourceRun
    Write-JsonFile (Join-Path ([IO.Path]::GetFullPath($Run)) 'observation.json') $analysis 40
    if ($Mode -eq 'Analyze') { Write-EvidenceSummary $EvidencePath $analysis }
    return [ordered]@{
        run = [IO.Path]::GetFullPath($Run)
        status = $analysis.status
        complete = $analysis.call.complete
        phases = $analysis.session.phaseCount
        expectedPhases = $analysis.session.expectedPhaseCount
        strictJsonPass = $analysis.run.strictJsonPass
        eventRecordCount = $analysis.run.eventRecordCount
        eventsSha256 = $analysis.run.eventsSha256
        inputPolicy = $analysis.inputProvenance.policy
        inputReplayUsed = $analysis.inputProvenance.used
        coinFrames = if ($analysis.inputProvenance.used) { $analysis.inputProvenance.observed.coinFrames } else { @() }
        startFrames = if ($analysis.inputProvenance.used) { $analysis.inputProvenance.observed.startFrames } else { @() }
        failureCode = $analysis.session.failureCode
        resultWord = $analysis.call.resultWord
        netU = $analysis.call.netU
        netS = $analysis.call.netS
        evidence = if ($Mode -eq 'Analyze') { [IO.Path]::GetFullPath($EvidencePath) } else { $null }
    }
}

if ($Mode -eq 'Capture') {
    if ([string]::IsNullOrWhiteSpace($RunDirectory)) { throw 'RunDirectory is required for Capture' }
    $result = Invoke-Capture $RunDirectory
}
else {
    $result = Invoke-Analyze $RunDirectory
}
Write-Output (ConvertTo-Json -InputObject $result -Depth 8)
