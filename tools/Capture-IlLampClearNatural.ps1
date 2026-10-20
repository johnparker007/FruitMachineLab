[CmdletBinding()]
param(
    [ValidateSet('PrepareOnly','Run','Analyze','Verify')][string]$Mode = 'PrepareOnly',
    [string]$MameExecutable = 'E:\Arcade\MAME0266\mame281.exe',
    [string]$RomDirectory = 'E:\Arcade\MAME0266\roms',
    [string]$BuiltRom,
    [string]$SourceMapPath,
    [string]$BuildReportPath,
    [string]$CheckerReportPath,
    [string]$OriginalRom,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [string]$RunDirectory,
    [ValidateRange(1,180)][int]$SecondsToRun = 180,
    [ValidateRange(60,1800)][int]$WallTimeoutSeconds = 900,
    [switch]$PrepareOnly,
    [switch]$Run,
    [switch]$LibraryOnly
)
$ErrorActionPreference = 'Stop'

if ($PrepareOnly -and $Run) { throw 'Use only one of -PrepareOnly or -Run' }
if ($PrepareOnly) { $Mode = 'PrepareOnly' }
elseif ($Run) { $Mode = 'Run' }

$script:TaskId = 'il-lamp-clear-observer-72'
$script:Protocol = 'il-lamp-clear-natural-v1'
$script:Root = Split-Path $PSScriptRoot -Parent
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:MameLaunched = $false

$script:OriginalSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
$script:OriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$script:BuiltSha1 = 'F2083249845955D91945E589807C22E730D78FC3'
$script:BuiltSha256 = '347D475E20C194F374DF85A04894BC68D89E05043CA89C5B031316868240EB88'
$script:MapSha256 = '1845ED2A98B8347B8618D7E9A6E7AFD68B3CF14532C20268AAE273DD782E83B1'
$script:ReportSha256 = '7AB2A92DF65F77E822FD92F30D8B966E96CA3C762873201F438FFAFD2011416D'
$script:CheckerReportSha256 = '5AD340A519808DA82903DB15E0055DC31384E5684F6ECCF685364DCE89B42630'
$script:MameSha256 = '0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$script:MameVersion = '0.281'
$script:ReplaySha256 = '4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$script:InputLuaSha256 = '23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94'
$script:CoinPulseFrames = @(2100,2101,2102,2103)
$script:StartPulseFrames = @(2221,2222,2223,2224)
$script:NextFixtureActionFrame = 2400
$script:BodyHex = '795BFF80787E795BFF807AAF7963007963809C44792F'
$script:PayloadHex = '00F8795BFF80787E795BFF807AAF7963007963809C44792F'
$script:CallerHex = '101075A9'
$script:ExpectedDiff = @(4112,4113,4114,4115,4117,4118,4119,4120,4121,4123,4124,4125,4126,4127,4128,4129,4130,4131,4132,4133,4134,4135,40724,40725,65489,65490,65491,65492,65493)
$script:UnrepairedDiff = @(4112,4113,4114,4115,4117,4118,4119,4120,4121,4123,4124,4125,4126,4127,4128,4129,4130,4131,4132,4133,4134,4135,40724,40725)
$script:RepairOnlyDiff = @(65489,65490,65491,65492,65493)
$script:FieldsHex = 'E93F3C61B5'
$script:OriginalFieldsHex = '3E761E2605'

if ([string]::IsNullOrWhiteSpace($BuiltRom)) { $BuiltRom = Join-Path $script:Root 'artifacts/deepseek/il-lamp-clear-build-71/supervisor-worker-final/positive-01/lamp-clear-repaired.p1' }
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path (Split-Path $BuiltRom -Parent) 'lamp-clear-pattern-source-map.json' }
if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path (Split-Path $BuiltRom -Parent) 'build-report.json' }
if ([string]::IsNullOrWhiteSpace($CheckerReportPath)) { $CheckerReportPath = Join-Path $script:Root 'artifacts/deepseek/il-lamp-clear-build-71/supervisor-worker-final/checker-report.json' }
if ([string]::IsNullOrWhiteSpace($OriginalRom)) { $OriginalRom = Join-Path $script:Root 'artifacts/deepseek/il-natural-06/runs/original-01/roms/m4addr/a6ls.p1' }
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
    param([string]$Path,$Object,[int]$Depth = 40)
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

function Format-Hex16 { param([int]$Value) return ('{0:X4}' -f ($Value -band 0xFFFF)) }
function Format-Hex8 { param([int]$Value) return ('{0:X2}' -f ($Value -band 0xFF)) }
function ConvertTo-HexInt { param([string]$Text) return [Convert]::ToInt32($Text,16) }

function ConvertTo-HexBytes {
    param([byte[]]$Bytes,[int]$Address,[int]$Length)
    $parts = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Length; $i++) { $parts.Add((Format-Hex8 $Bytes[($Address + $i) -band 0xFFFF])) }
    return ($parts -join '')
}

function ConvertTo-LuaInt {
    param($Value)
    if ($null -eq $Value) { return 'nil' }
    return ('0x{0:X}' -f [int]$Value)
}

function ConvertTo-LuaString {
    param([string]$Text)
    return '"' + $Text.Replace('\','\\').Replace('"','\"') + '"'
}

function ConvertTo-LuaByteTable {
    param([string]$Hex)
    $parts = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Hex.Length; $i += 2) { $parts.Add(('0x{0}' -f $Hex.Substring($i,2))) }
    return ('{ ' + ($parts -join ', ') + ' }')
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

function Get-DiffOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare images of different length' }
    $offsets = New-Object 'System.Collections.Generic.List[int]'
    for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { [void]$offsets.Add($i) } }
    return $offsets.ToArray()
}

function Get-PhaseStackContract {
    # controlTop is the expected 16-bit word at S for ordinary VM phases. Native
    # prologue/epilogue phases have controlTop=$null because their frame is
    # derived from the live 49C5 entry A/B/X and the ROM push/pull bytes.
    # savedCursorOffset is the byte offset from S at which the semantic saved
    # cursor is located; it is not assumed to be the top word for native frames.
    return @{
        'caller-dispatch' = @{ controlTop=0x9F3F; savedCursorOffset=0; role='caller-control-top' }
        'header-trampoline-entry' = @{ controlTop=0x9F3F; savedCursorOffset=0; role='pending-y-before-pshs' }
        'body-prefetch-0' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-0' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-1' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-1' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-2' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-2' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-3' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-3' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-4' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-4' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-5' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-5' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-6' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'shared-handler-entry' = @{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'service-trampoline-jrs-entry' = @{ controlTop=0x9B18; savedCursorOffset=0; role='trampoline-control-top' }
        'service-trampoline-pshu' = @{ controlTop=0x9B18; savedCursorOffset=0; role='trampoline-control-top' }
        'shared-body-entry' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-fetch-word' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-rotate' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-add' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-fetch-byte' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-swap' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-entry' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-pulu-pattern' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-load-index' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-discard-index' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-branch-continuation' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-saves-y' = @{ controlTop=0x9B24; savedCursorOffset=2; role='native-y-below-shared' }
        'bridge-jsr-entry' = @{ controlTop=0x777E; savedCursorOffset=4; role='native-return-below-shared' }
        'native-prologue-save-regs' = @{ controlTop=$null; savedCursorOffset=8; role='native-saved-registers'; nativeStage='afterRegs' }
        'native-prologue-save-mask' = @{ controlTop=$null; savedCursorOffset=9; role='native-saved-mask'; nativeStage='afterMask' }
        'native-prologue-deepest' = @{ controlTop=$null; savedCursorOffset=10; role='native-saved-cc'; nativeStage='afterCc' }
        'native-epilogue-puls-cc' = @{ controlTop=$null; savedCursorOffset=9; role='native-after-puls-cc'; nativeStage='afterPulsCc' }
        'native-epilogue-puls-a' = @{ controlTop=$null; savedCursorOffset=8; role='native-after-puls-a'; nativeStage='afterPulsA' }
        'native-return' = @{ controlTop=0x9B24; savedCursorOffset=2; role='native-return-y-below-shared' }
        'bridge-restores-y' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-prefetch-return' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-return-handler' = @{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-returned-to-1026' = @{ controlTop=0x9F16; savedCursorOffset=0; role='outer-cursor-top' }
        'outer-return-handler' = @{ controlTop=0x9F16; savedCursorOffset=0; role='outer-cursor-top' }
        'outer-returned-to-9F16' = @{ controlTop=0x9F3F; savedCursorOffset=0; role='outer-control-top' }
    }
}

function Get-NativeFrameContract {
    return [ordered]@{
        entryPc = 0x49C5
        entryS = 0x0790
        maskTableAddress = 0x49BD
        maskTableHex = '0102040810204080'
        pushes = @(
            [ordered]@{ pc=0x49C5; bytes='3416'; operation='PSHS A,B,X'; drop=4; layout=@('entryA','entryB','entryX') },
            [ordered]@{ pc=0x49CE; bytes='3404'; operation='PSHS B'; drop=1; layout=@('mask') },
            [ordered]@{ pc=0x49D0; bytes='3401'; operation='PSHS CC'; drop=1; layout=@('cc') },
            [ordered]@{ pc=0x49E0; bytes='3501'; operation='PULS CC'; pull=1; layout=@('cc') },
            [ordered]@{ pc=0x4A21; bytes='3502'; operation='PULS A'; pull=1; layout=@('mask') },
            [ordered]@{ pc=0x4A23; bytes='3596'; operation='PULS PC,X,B,A'; pull=6; layout=@('entryA','entryB','entryX','return') }
        )
        steps = [ordered]@{
            afterRegs = [ordered]@{ pc=0x49C7; sOffset=-4; topWord='entryAB'; returnOffset=4; yOffset=6; sharedCursorOffset=8; layout=@(@{offset=0;from='entryA'},@{offset=1;from='entryB'},@{offset=2;width=2;from='entryX'}) }
            afterMask = [ordered]@{ pc=0x49D0; sOffset=-5; topWord='maskEntryA'; returnOffset=5; yOffset=7; sharedCursorOffset=9; layout=@(@{offset=0;from='mask'},@{offset=1;from='entryA'},@{offset=2;from='entryB'},@{offset=3;width=2;from='entryX'}) }
            afterCc = [ordered]@{ pc=0x49D2; sOffset=-6; topWord='ccMask'; returnOffset=6; yOffset=8; sharedCursorOffset=10; layout=@(@{offset=0;from='cc'},@{offset=1;from='mask'},@{offset=2;from='entryA'},@{offset=3;from='entryB'},@{offset=4;width=2;from='entryX'}) }
            afterPulsCc = [ordered]@{ pc=0x49E2; sOffset=-5; topWord='maskEntryA'; returnOffset=5; yOffset=7; sharedCursorOffset=9; layout=@(@{offset=0;from='mask'},@{offset=1;from='entryA'},@{offset=2;from='entryB'},@{offset=3;width=2;from='entryX'}) }
            afterPulsA = [ordered]@{ pc=0x4A23; sOffset=-4; topWord='entryAB'; returnOffset=4; yOffset=6; sharedCursorOffset=8; layout=@(@{offset=0;from='entryA'},@{offset=1;from='entryB'},@{offset=2;width=2;from='entryX'}) }
            nativeReturn = [ordered]@{ pc=0x777E; sOffset=2; topWord='y'; returnOffset=$null; yOffset=0; sharedCursorOffset=2; layout=@(@{offset=0;from='y'}) }
        }
    }
}

function Get-TokenAddressForPhase {
    param($Phase)
    $name = [string]$Phase.Phase
    $y = [int]$Phase.Y
    if ($name -eq 'caller-dispatch') { return 0x9F14 }
    if ($name -eq 'header-trampoline-entry') { return 0x1010 }
    if ($name -like 'body-prefetch-*') { return $y }
    if ($name -like 'handler-*') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'shared-handler-entry') { return ($y - 2) -band 0xFFFF }
    if ($name -like 'service-trampoline-*') { return 0x1024 }
    if ($name -eq 'shared-body-entry') { return $y }
    if ($name -like 'shared-after-*') { return $y }
    if ($name -eq 'bridge-entry') { return ($y - 2) -band 0xFFFF }
    if ($name -like 'bridge-pulu-*' -or $name -like 'bridge-load-*' -or $name -like 'bridge-discard-*' -or $name -like 'bridge-branch-*' -or $name -like 'bridge-saves-*' -or $name -eq 'bridge-jsr-entry') { return ($y - 2) -band 0xFFFF }
    if ($name -like 'native-*') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'native-return') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'bridge-restores-y') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'shared-prefetch-return') { return $y }
    if ($name -eq 'shared-return-handler') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'shared-returned-to-1026') { return $y }
    if ($name -eq 'outer-return-handler') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'outer-returned-to-9F16') { return $y }
    throw "No token-address rule for phase $name"
}

function Get-ExpectedPhaseContract {
    param($Map)
    if ([int]$Map.Phases.Count -ne 43) { throw "Source map has $($Map.Phases.Count) phases, expected 43" }
    $stackContracts = Get-PhaseStackContract
    $expected = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt $Map.Phases.Count; $i++) {
        $p = $Map.Phases[$i]
        $name = [string]$p.Phase
        if (-not $stackContracts.ContainsKey($name)) { throw "No stack contract for phase $name" }
        $stack = $stackContracts[$name]
        $liveToken = if ($null -ne $p.ReplacementToken) { [int]$p.ReplacementToken } else { [int]$p.Token }
        $operandKind = [int]$p.OperandKind
        $operandWidth = 0
        if ($operandKind -eq 1) { $operandWidth = 2 }
        elseif ($operandKind -eq 2) { $operandWidth = 1 }
        $operandAddress = if ($operandWidth -gt 0) { [int]$p.OperandAddress } else { $null }
        $operandValue = if ($operandWidth -gt 0) { [int]$p.OperandValue } else { $null }
        if ($operandWidth -eq 2) { $operandText = Format-Hex16 $operandValue }
        elseif ($operandWidth -eq 1) { $operandText = Format-Hex8 $operandValue }
        else { $operandText = '' }
        $savedCursor = if ($null -ne $p.SavedCursor) { [int]$p.SavedCursor } else { $null }
        $expected.Add([ordered]@{
            name = $name
            pc = [int]$p.Pc
            x = if ($null -ne $p.X) { [int]$p.X } else { $null }
            y = [int]$p.Y
            u = [int]$p.U
            s = [int]$p.S
            token = [int]$p.Token
            liveToken = $liveToken
            tokenAddress = Get-TokenAddressForPhase $p
            handlerAddress = if ($null -ne $p.HandlerAddress) { [int]$p.HandlerAddress } else { $null }
            operandAddress = $operandAddress
            operandWidth = $operandWidth
            operandValue = $operandValue
            operandText = $operandText
            savedCursor = $savedCursor
            savedCursorOffset = [int]$stack.savedCursorOffset
            savedCursorRole = [string]$stack.role
            controlTop = if ($null -ne $stack.controlTop) { [int]$stack.controlTop } else { $null }
            nativeStage = if ($stack.ContainsKey('nativeStage')) { [string]$stack.nativeStage } else { $null }
            controlTopSource = if ($null -ne $stack.controlTop) { 'static_prediction' } else { 'live_native_entry_frame' }
            requireX = ($null -ne $p.X)
            classification = 'static_prediction_not_execution'
        })
    }
    return $expected.ToArray()
}

function Get-ExpectedBoundaryContract {
    $list = New-Object 'System.Collections.Generic.List[object]'
    $rows = @(
        @{ id='port-orcc50'; pc=0x49D5; bytes='1A50'; instruction='ORCC #$50'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-sta-0801'; pc=0x49D7; bytes='B70801'; instruction='STA $0801'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-stb-0802'; pc=0x49DA; bytes='F70802'; instruction='STB $0802'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-ldb-0803-preread'; pc=0x49DD; bytes='F60803'; instruction='LDB $0803'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-pulscc-pre'; pc=0x49E0; bytes='3501'; instruction='PULS CC'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='frame-write-00'; pc=0x49F8; bytes='E784'; instruction='STB ,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x00; skipWhen=$null },
        @{ id='frame-write-10'; pc=0x4A04; bytes='E78810'; instruction='STB $10,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x10; skipWhen=$null },
        @{ id='frame-write-20'; pc=0x4A11; bytes='E78820'; instruction='STB $20,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x20; skipWhen=$null },
        @{ id='frame-write-30'; pc=0x4A1E; bytes='E78830'; instruction='STB $30,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x30; skipWhen=$null },
        @{ id='port-f1-set-read'; pc=0x7793; bytes='96F1'; instruction='LDA <$F1'; kind='port_safe'; u=0x066C; s=0x0794; offset=$null; skipWhen=$null },
        @{ id='port-f1-set-write'; pc=0x7799; bytes='97F1'; instruction='STA <$F1'; kind='port_safe'; u=0x066C; s=0x0794; offset=$null; skipWhen='f1_set_zero' },
        @{ id='port-080c-set-write'; pc=0x779B; bytes='B7080C'; instruction='STA $080C'; kind='port_safe'; u=0x066C; s=0x0794; offset=$null; skipWhen='f1_set_zero' },
        @{ id='port-f1-clear-write'; pc=0x7786; bytes='97F1'; instruction='STA <$F1'; kind='port_safe'; u=0x066E; s=0x0794; offset=$null; skipWhen='f1_clear_zero' },
        @{ id='port-080c-clear-write'; pc=0x7788; bytes='B7080C'; instruction='STA $080C'; kind='port_safe'; u=0x066E; s=0x0794; offset=$null; skipWhen='f1_clear_zero' }
    )
    foreach ($r in $rows) {
        $condition = ('y==0x{0:x} && u==0x{1:x} && s==0x{2:x}' -f 0x9B24, [int]$r.u, [int]$r.s)
        $list.Add([ordered]@{
            id = [string]$r.id
            pc = [int]$r.pc
            bytes = [string]$r.bytes
            instruction = [string]$r.instruction
            kind = [string]$r.kind
            u = [int]$r.u
            s = [int]$r.s
            offset = $r.offset
            skipWhen = $r.skipWhen
            condition = $condition
        })
    }
    return $list.ToArray()
}

function Get-OrderedStagePlan {
    param($Phases,$Boundaries)
    $boundaryById = @{}
    foreach ($b in $Boundaries) { $boundaryById[[string]$b.id] = $b }
    $usedBoundaries = @{}
    $stages = New-Object 'System.Collections.Generic.List[object]'
    $phaseByName = @{}
    foreach ($p in $Phases) { $phaseByName[[string]$p.name] = $p }

    function Add-Stage {
        param([int]$Pc,[string[]]$PhaseNames,[string[]]$BoundaryIds,[string]$OnlyIf = $null,[string]$Branch = $null,[string]$Note = '')
        $y = $null
        foreach ($pn in $PhaseNames) { $y = [int]$phaseByName[$pn].y; break }
        if ([int]$Pc -eq 0x00FC) {
            if ($null -eq $y) { throw 'Dispatcher stage has no phase Y for its breakpoint predicate' }
            $condition = ('y==0x{0:x}' -f $y)
        }
        else { $condition = '1' }
        $stage = [ordered]@{
            id = ('stage-{0:D2}-{1}' -f ($stages.Count + 1), $(if ($PhaseNames.Count -gt 0) { $PhaseNames[0] } elseif ($BoundaryIds.Count -gt 0) { $BoundaryIds[0] } else { 'unnamed' }))
            ordinal = $stages.Count
            pc = [int]$Pc
            condition = $condition
            phaseNames = @($PhaseNames)
            boundaryIds = @($BoundaryIds)
            onlyIf = $OnlyIf
            branch = $Branch
            note = $Note
        }
        $stages.Add($stage)
        foreach ($id in $BoundaryIds) { $usedBoundaries[$id] = $true }
    }
    function Add-BoundaryStage {
        param([string]$Id,[string]$OnlyIf = $null)
        if (-not $boundaryById.ContainsKey($Id)) { throw "Boundary $Id is not defined" }
        if ($usedBoundaries.ContainsKey($Id)) { throw "Boundary $Id is already placed" }
        $b = $boundaryById[$Id]
        Add-Stage -Pc ([int]$b.pc) -PhaseNames @() -BoundaryIds @($Id) -OnlyIf $OnlyIf
    }

    foreach ($p in $Phases) {
        $name = [string]$p.name
        if ($name -eq 'bridge-pulu-pattern') {
            Add-Stage -Pc ([int]$p.pc) -PhaseNames @($name) -BoundaryIds @('port-f1-set-read') -Branch 'f1-entry' -Note '7793 phase and port-safe read share one physical stop'
            Add-BoundaryStage 'port-f1-set-write' 'f1EntryNonZero'
            Add-BoundaryStage 'port-080c-set-write' 'f1EntryNonZero'
        }
        elseif ($name -eq 'native-prologue-deepest') {
            Add-Stage -Pc ([int]$p.pc) -PhaseNames @($name) -BoundaryIds @()
            Add-BoundaryStage 'port-orcc50'
            Add-BoundaryStage 'port-sta-0801'
            Add-BoundaryStage 'port-stb-0802'
            Add-BoundaryStage 'port-ldb-0803-preread'
            Add-BoundaryStage 'port-pulscc-pre'
        }
        elseif ($name -eq 'native-epilogue-puls-cc') {
            Add-Stage -Pc ([int]$p.pc) -PhaseNames @($name) -BoundaryIds @()
            Add-BoundaryStage 'frame-write-00'
            Add-BoundaryStage 'frame-write-10'
            Add-BoundaryStage 'frame-write-20'
            Add-BoundaryStage 'frame-write-30'
        }
        elseif ($name -eq 'bridge-restores-y') {
            Add-Stage -Pc ([int]$p.pc) -PhaseNames @($name) -BoundaryIds @() -Branch 'f1-exit'
            Add-BoundaryStage 'port-f1-clear-write' 'f1ExitNonZero'
            Add-BoundaryStage 'port-080c-clear-write' 'f1ExitNonZero'
        }
        else {
            Add-Stage -Pc ([int]$p.pc) -PhaseNames @($name) -BoundaryIds @()
        }
    }
    $missing = @($Boundaries | Where-Object { -not $usedBoundaries.ContainsKey([string]$_.id) } | ForEach-Object { [string]$_.id })
    if ($missing.Count -ne 0) { throw "Ordered stage plan did not place boundaries: $($missing -join ',')" }
    return $stages.ToArray()
}

function Test-LampMapContract {
    param($Map,$Build,$Built,$Original,$CheckerReport)

    if ([string]$Map.OriginalRomSha1 -ine $script:OriginalSha1) { throw 'Source map original SHA1 is wrong' }
    if ([string]$Map.OriginalRomSha256 -ine $script:OriginalSha256) { throw 'Source map original SHA256 is wrong' }
    if ([string]$Map.OutputImageSha1 -ine $script:BuiltSha1) { throw 'Source map output SHA1 is wrong' }
    if ([string]$Map.OutputImageSha256 -ine $script:BuiltSha256) { throw 'Source map output SHA256 is wrong' }
    if ([string]$Map.BuildId -ine $script:BuiltSha256) { throw 'Source map BuildId is not the exact built image SHA256' }
    if ([int]$Map.HeaderAddress -ne 0x1010) { throw 'Source map header address is not 1010' }
    if ([string]$Map.HeaderHex -ine '00F8') { throw 'Source map header is not 00F8' }
    if ([int]$Map.BodyStart -ne 0x1012) { throw 'Source map body start is not 1012' }
    if ([int]$Map.BodyEndExclusive -ne 0x1028) { throw 'Source map body end is not 1028' }
    if ([int]$Map.AllocationEndInclusive -ne 0x1027) { throw 'Source map allocation end is not 1027' }
    if ([string]$Map.Classification -notmatch 'static_lamp_clear_pattern_map_bound_to_exact_output_sha256') { throw 'Source map classification is not the reviewed clear map' }
    if ([int]$Map.InlineOperands.Count -ne 4) { throw 'Source map inline operand count is not 4' }
    $patternOperand = @($Map.InlineOperands | Where-Object { [int]$_.Address -eq 0x1023 })
    if ($patternOperand.Count -ne 1 -or [int]$patternOperand[0].Value -ne 0x80 -or [int]$patternOperand[0].Width -ne 1) { throw 'Source map pattern operand at 1023 is not the clear 0080 byte' }
    if ([int]$Map.Boundaries.Count -ne 12) { throw 'Source map does not contain its twelve static ROM boundary regions' }

    if ([string]$Build.original.sha1 -ine $script:OriginalSha1) { throw 'Build report original SHA1 is wrong' }
    if ([string]$Build.original.sha256 -ine $script:OriginalSha256) { throw 'Build report original SHA256 is wrong' }
    if ([string]$Build.unrepaired.sha1 -ine 'BD7572208D18EAA98B8E49C5FC1FEC4BBDF9C351') { throw 'Build report unrepaired SHA1 is wrong' }
    if ([string]$Build.unrepaired.sha256 -ine '0CDA847916A051B09C187C54AD028F79A65A554CC592E0CF0580A0291A76AAEE') { throw 'Build report unrepaired SHA256 is wrong' }
    if ([string]$Build.repaired.sha1 -ine $script:BuiltSha1) { throw 'Build report output SHA1 is wrong' }
    if ([string]$Build.repaired.sha256 -ine $script:BuiltSha256) { throw 'Build report output SHA256 is wrong' }
    if ([bool]$Build.staticOnly -ne $true) { throw 'Build report is not marked static-only' }
    if ([bool]$Build.executionClaimed) { throw 'Build report wrongly claims execution' }
    if ([int]$Build.allocation.length -ne 24) { throw 'Build report allocation length is not 24' }
    if ((ConvertTo-HexInt ([string]$Build.allocation.start)) -ne 0x1010) { throw 'Build report allocation start is not 1010' }
    if ((ConvertTo-HexInt ([string]$Build.allocation.endInclusive)) -ne 0x1027) { throw 'Build report allocation end is not 1027' }
    if ([string]$Build.allocation.headerHex -ine '00F8') { throw 'Build report header is not 00F8' }
    if ([string]$Build.allocation.bodyHex -ine $script:BodyHex) { throw 'Build report body differs from the reviewed clear word' }
    if ([string]$Build.allocation.payloadHex -ine $script:PayloadHex) { throw 'Build report payload differs from the reviewed clear word' }
    if ([int]$Build.allocation.nodeCount -ne 8) { throw 'Build report node count is not 8' }
    if ([int]$Build.allocation.wordOperandCount -ne 2) { throw 'Build report word operand count is not 2' }
    if ([int]$Build.allocation.byteOperandCount -ne 2) { throw 'Build report byte operand count is not 2' }
    if ([int]$Build.allocation.inlineOperandCount -ne 4) { throw 'Build report inline operand count is not 4' }
    if ([bool]$Build.allocation.fullAllocationIsOriginalFF -ne $true) { throw 'Build report allocation was not originally FF' }
    if ([bool]$Build.allocation.bytes1014And101ARemainFF -ne $true) { throw 'Build report operand bytes 1014/101A were not preserved as FF' }
    if ([string]$Build.allocation.patternOperandAddress -ine '1023') { throw 'Build report pattern operand address is not 1023' }
    if ([string]$Build.allocation.patternOperandHex -ine '80') { throw 'Build report pattern operand is not 80' }
    if ([bool]$Build.allocation.only1023DiffersFrom8FPayload -ne $true) { throw 'Build report does not bind the clear payload to the reviewed 8F difference' }
    if ([string]$Build.caller.address -ine '9F14') { throw 'Build report caller address is not 9F14' }
    if ([string]$Build.caller.expectedToken -ine '9ED7') { throw 'Build report expected caller token is not 9ED7' }
    if ([string]$Build.caller.replacementToken -ine '1010') { throw 'Build report replacement caller token is not 1010' }
    if ([string]$Build.caller.successorAddress -ine '9F16') { throw 'Build report successor address is not 9F16' }
    if ([string]$Build.caller.successorToken -ine '75A9') { throw 'Build report successor token is not 75A9' }
    if ([string]$Build.integrity.repairedFieldsHex -ine $script:FieldsHex) { throw 'Build report integrity fields are wrong' }
    if ([string]$Build.integrity.originalFieldsHex -ine $script:OriginalFieldsHex) { throw 'Build report original integrity fields are wrong' }
    if ([string]$Build.predictedLampEffect.tableAddress -ine '72BF') { throw 'Build report lamp table address is not 72BF' }
    if ([string]$Build.predictedLampEffect.logicalId -ine '78') { throw 'Build report logical lamp id is not 78' }
    if ([int]$Build.predictedLampEffect.bit -ne 0) { throw 'Build report lamp bit is not 0' }
    if ([string]$Build.predictedLampEffect.maskHex -ine '01') { throw 'Build report lamp mask is not 01' }
    if ([string]$Build.predictedLampEffect.patternHex -ine '80') { throw 'Build report pattern is not 80' }
    if ([string]$Build.predictedLampEffect.effect -ine 'clear-mask-01-in-four-banks') { throw 'Build report does not describe the clear mask effect' }
    if ([string]$Build.predictedLampEffect.clearAlgebra -notmatch 'after = before & ~01') { throw 'Build report clear algebra is not before & ~mask' }
    if ([int]$Build.predictedLampEffect.clearAlgebraCoveredBeforeValues -ne 256) { throw 'Build report clear algebra does not cover all 256 before values' }
    if ([bool]$Build.predictedLampEffect.otherBitsUnchanged -ne $true) { throw 'Build report does not preserve non-mask bits' }
    if ([bool]$Build.predictedLampEffect.fullResponseByteClaimed) { throw 'Build report wrongly claims a full characteriser response byte' }
    if ([bool]$Build.predictedLampEffect.physicalLampOutputClaimed) { throw 'Build report wrongly claims physical lamp output' }
    if ([bool]$Build.predictedLampEffect.futureResponseUnknown -ne $true) { throw 'Build report does not mark the future 0803 response unknown' }
    if ([bool]$Build.predictedLampEffect.targetColumnDependsOnActual0803Response -ne $true) { throw 'Build report does not bind the target column to the actual 0803 response' }

    if ([string]$CheckerReport.romSha256 -ine $script:OriginalSha256) { throw 'Supervisor checker report ROM hash is not the original ROM' }
    if ([string]$CheckerReport.result -notin @('pass','PASS')) { throw 'Supervisor checker report is not a pass' }
    $failedChecks = @($CheckerReport.checks | Where-Object { -not [bool]$_.ok })
    if ($failedChecks.Count -ne 0) { throw "Supervisor checker report has $($failedChecks.Count) failed checks" }
    if ([string]$CheckerReport.clear.outputSha256 -ine $script:BuiltSha256) { throw 'Supervisor checker report does not bind the clear output SHA256' }
    if ([string]$CheckerReport.clear.mapBuildId -ine $script:BuiltSha256) { throw 'Supervisor checker report does not bind the clear map BuildId' }
    if ([int]$CheckerReport.clear.patternOperandValue -ne 0x80) { throw 'Supervisor checker report pattern operand is not 80' }

    $actualDiff = @(Get-DiffOffsets $Original $Built)
    if (($actualDiff -join ',') -ne ($script:ExpectedDiff -join ',')) { throw "Built image diff is not the reviewed 29-byte set: $($actualDiff -join ',')" }
    $buildDiff = @($Build.repaired.changedOffsets | ForEach-Object { [int]$_ })
    if (($buildDiff -join ',') -ne ($script:ExpectedDiff -join ',')) { throw 'Build report repaired changedOffsets differ from the reviewed set' }
    $unrepairedDiff = @($Build.unrepaired.changedOffsets | ForEach-Object { [int]$_ })
    if (($unrepairedDiff -join ',') -ne ($script:UnrepairedDiff -join ',')) { throw 'Build report unrepaired changedOffsets differ from the reviewed set' }
    $repairDiff = @($Build.integrity.repairChangedOffsets | ForEach-Object { [int]$_ })
    if (($repairDiff -join ',') -ne ($script:RepairOnlyDiff -join ',')) { throw 'Build report repairChangedOffsets are not FFD1-FFD5' }

    if ((ConvertTo-HexBytes $Built 0x1010 24) -ine $script:PayloadHex) { throw 'Built allocation is not the reviewed lamp word' }
    if ((ConvertTo-HexBytes $Built 0x9F14 4) -ine $script:CallerHex) { throw 'Built caller/successor bytes are not 1010/75A9' }
    if ((ConvertTo-HexBytes $Built 0xFFD1 5) -ine $script:FieldsHex) { throw 'Built integrity fields are not E93F3C61B5' }
    if ((ConvertTo-HexBytes $Original 0xFFD1 5) -ine $script:OriginalFieldsHex) { throw 'Original integrity fields are not 3E761E2605' }
    for ($address = 0x1000; $address -le 0x100F; $address++) { if ($Built[$address] -ne 0xFF) { throw "Low guard byte at $(Format-Hex16 $address) is not FF" } }
    for ($address = 0x13F0; $address -le 0x13FF; $address++) { if ($Built[$address] -ne 0xFF) { throw "High guard byte at $(Format-Hex16 $address) is not FF" } }
    for ($address = 0x1028; $address -le 0x13EF; $address++) { if ($Built[$address] -ne 0xFF) { throw "Unallocated extension byte at $(Format-Hex16 $address) is not FF" } }

    $nodes = @($Map.Nodes)
    if ($nodes.Count -ne 8) { throw "Source map has $($nodes.Count) nodes, expected 8" }
    $operands = @($Map.InlineOperands)
    if ($operands.Count -ne 4) { throw "Source map has $($operands.Count) inline operands, expected 4" }
    $entries = @($Map.Entries)
    if ($entries.Count -ne 44) { throw "Source map has $($entries.Count) entries, expected 44" }
    foreach ($entry in $entries) {
        $address = [int]$entry.Address
        if ([int]$entry.ImageByte -ne [int]$Built[$address]) { throw "Source map entry byte differs at $(Format-Hex16 $address)" }
    }
    $phases = @($Map.Phases)
    if ($phases.Count -ne 43) { throw "Source map has $($phases.Count) phases, expected 43" }
    $patternPhase = @($phases | Where-Object { [string]$_.Phase -eq 'handler-5' })
    if ($patternPhase.Count -ne 1 -or [int]$patternPhase[0].OperandAddress -ne 0x1023 -or [int]$patternPhase[0].OperandValue -ne 0x80) { throw 'Source map handler-5 pattern operand is not the clear byte at 1023' }
    foreach ($name in @('shared-after-rotate','shared-after-swap')) {
        $xPhase = @($phases | Where-Object { [string]$_.Phase -eq $name })
        if ($xPhase.Count -ne 1 -or $null -eq $xPhase[0].X -or [int]$xPhase[0].X -ne 0x0080) { throw "Source map $name X is not the clear 0080" }
    }
    $expectedNames = @(
        'caller-dispatch','header-trampoline-entry',
        'body-prefetch-0','handler-0','body-prefetch-1','handler-1','body-prefetch-2','handler-2',
        'body-prefetch-3','handler-3','body-prefetch-4','handler-4','body-prefetch-5','handler-5',
        'body-prefetch-6','shared-handler-entry','service-trampoline-jrs-entry','service-trampoline-pshu',
        'shared-body-entry','shared-after-fetch-word','shared-after-rotate','shared-after-add',
        'shared-after-fetch-byte','shared-after-swap','bridge-entry','bridge-pulu-pattern',
        'bridge-load-index','bridge-discard-index','bridge-branch-continuation','bridge-saves-y',
        'bridge-jsr-entry','native-prologue-save-regs','native-prologue-save-mask','native-prologue-deepest',
        'native-epilogue-puls-cc','native-epilogue-puls-a','native-return','bridge-restores-y',
        'shared-prefetch-return','shared-return-handler','shared-returned-to-1026','outer-return-handler',
        'outer-returned-to-9F16'
    )
    for ($i = 0; $i -lt $expectedNames.Count; $i++) {
        if ([string]$phases[$i].Phase -ne $expectedNames[$i]) { throw "Source map phase $i is $($phases[$i].Phase), expected $($expectedNames[$i])" }
    }
    $caller = $Map.Caller
    if ([int]$caller.TokenAddress -ne 0x9F14) { throw 'Source map caller token address is not 9F14' }
    if ([int]$caller.OriginalToken -ne 0x9ED7) { throw 'Source map caller original token is not 9ED7' }
    if ([int]$caller.ReplacementToken -ne 0x1010) { throw 'Source map caller replacement token is not 1010' }
    if ([int]$caller.OuterSavedReturnCursor -ne 0x9F16) { throw 'Source map outer saved cursor is not 9F16' }
    if ([int]$caller.SharedSavedReturnCursor -ne 0x1026) { throw 'Source map shared saved cursor is not 1026' }
    if ([int]$caller.PostReturnToken -ne 0x75A9) { throw 'Source map post-return token is not 75A9' }
    if ([int]$caller.ReturnHandlerAddress -ne 0x7931) { throw 'Source map return handler is not 7931' }
    if ([int]$Map.Semantics.DeepestS -ne 0x078A) { throw 'Source map deepest S is not 078A' }
    if ([int]$Map.Semantics.WholeCallSNet -ne 0) { throw 'Source map S net is not 0' }
    if ([int]$Map.Semantics.BodyUNet -ne 0) { throw 'Source map U net is not 0' }

    return [ordered]@{
        mapSha256 = $script:MapSha256
        buildReportSha256 = $script:ReportSha256
        builtSha256 = $script:BuiltSha256
        phaseCount = 43
        boundaryCount = 14
        staticMapBoundaryRegionCount = 12
        nodeCount = 8
        inlineOperandCount = 4
        entryCount = 44
        changedOffsetCount = $actualDiff.Count
        integrityFields = $script:FieldsHex
        clearPatternHex = '80'
        clearLogicalId = '78'
        clearMaskHex = '01'
        clearFrameBaseRule = '0x0100 + actual_response_derived_column'
        clearAlgebra = 'after = before & ~01'
        naturalExecutionClaimed = $false
    }
}

function Get-LampMapLuaText {
    param($Phases,$Boundaries,$Stages,$NativeFrame,$LuaSha)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  protocol = "{0}",' -f $script:Protocol))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $script:BuiltSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $script:OriginalSha256))
    [void]$sb.AppendLine(('  sourceMapSha256 = "{0}",' -f $script:MapSha256))
    [void]$sb.AppendLine(('  buildReportSha256 = "{0}",' -f $script:ReportSha256))
    [void]$sb.AppendLine(('  luaSha256 = "{0}",' -f $LuaSha))
    [void]$sb.AppendLine('  headerAddress = 0x1010,')
    [void]$sb.AppendLine('  headerValue = 0x00F8,')
    [void]$sb.AppendLine('  bodyStart = 0x1012,')
    [void]$sb.AppendLine('  bodyEndExclusive = 0x1028,')
    [void]$sb.AppendLine('  allocationEndInclusive = 0x1027,')
    [void]$sb.AppendLine(('  bodyHex = "{0}",' -f $script:BodyHex))
    [void]$sb.AppendLine('  callerAddress = 0x9F14,')
    [void]$sb.AppendLine('  callerLiveToken = 0x1010,')
    [void]$sb.AppendLine('  successorAddress = 0x9F16,')
    [void]$sb.AppendLine('  successorToken = 0x75A9,')
    [void]$sb.AppendLine('  requiredDp = 0x00,')
    [void]$sb.AppendLine('  frameBase = 0x0100,')
    [void]$sb.AppendLine('  frameBaseFormula = "0x0100 + responseDerivedColumn",')
    [void]$sb.AppendLine('  columnFormula = "((response0803 XOR savedLogicalIndex) & 0x78) >> 3",')
    [void]$sb.AppendLine('  clearAlgebra = "after = before & ~mask",')
    [void]$sb.AppendLine('  expectedPatternHex = "80",')
    [void]$sb.AppendLine('  expectedLogicalIdHex = "78",')
    [void]$sb.AppendLine('  expectedMaskHex = "01",')
    [void]$sb.AppendLine('  frameBank = { start = 0x0100, endInclusive = 0x013F },')
    [void]$sb.AppendLine('  originalDefinitionAddress = 0x9ED7,')
    [void]$sb.AppendLine('  originalDefinitionHex = "00F8795BFF80787E795BFF807AAF792F",')
    [void]$sb.AppendLine('  sharedCallAddress = 0x9C44,')
    [void]$sb.AppendLine('  sharedCallHex = "9B1572BF",')
    [void]$sb.AppendLine('  sharedHandlerAddress = 0x9B15,')
    [void]$sb.AppendLine('  sharedHandlerHex = "BD796E",')
    [void]$sb.AppendLine('  sharedBodyAddress = 0x9B18,')
    [void]$sb.AppendLine('  sharedBodyHex = "790D7B6D787E786B7B7D8050792F",')
    [void]$sb.AppendLine('  trampolineAddress = 0x796E,')
    [void]$sb.AppendLine('  trampolineHex = "3610AEE410AFE431840EFC",')
    [void]$sb.AppendLine('  bridgeCellAddress = 0x8050,')
    [void]$sb.AppendLine('  bridgeCellHex = "779149C5",')
    [void]$sb.AppendLine('  bridgeEntryAddress = 0x7791,')
    [void]$sb.AppendLine('  bridgeEntryHex = "370696F127078A0197F1B7080CA641334220D6",')
    [void]$sb.AppendLine('  bridgeContinuationAddress = 0x777A,')
    [void]$sb.AppendLine('  bridgeContinuationHex = "3420AD94352096F1270784FE97F1B7080C0EFC",')
    [void]$sb.AppendLine('  nativeServiceAddress = 0x49C5,')
    [void]$sb.AppendLine(('  nativeServiceHex = "{0}",' -f (ConvertTo-HexBytes ([IO.File]::ReadAllBytes($BuiltRom)) 0x49C5 96)))
    [void]$sb.AppendLine('  byteLiteralCellAddress = 0x7963,')
    [void]$sb.AppendLine('  byteLiteralCellHex = "79654FE6A036060EFC",')
    [void]$sb.AppendLine('  lampTableAddress = 0x72BF,')
    [void]$sb.AppendLine(('  lampTableHex = "{0}",' -f (ConvertTo-HexBytes ([IO.File]::ReadAllBytes($BuiltRom)) 0x72BF 48)))
    [void]$sb.AppendLine('  guardLowStart = 0x1000, guardLowEnd = 0x100F,')
    [void]$sb.AppendLine('  guardHighStart = 0x13F0, guardHighEnd = 0x13FF,')
    [void]$sb.AppendLine('  unallocatedStart = 0x1028, unallocatedEndInclusive = 0x13EF,')
    [void]$sb.AppendLine('  safeRam = {')
    [void]$sb.AppendLine('    { start = 0x00F1, endInclusive = 0x00F2 },')
    [void]$sb.AppendLine('    { start = 0x0100, endInclusive = 0x013F },')
    [void]$sb.AppendLine('    { start = 0x0668, endInclusive = 0x0675 },')
    [void]$sb.AppendLine('    { start = 0x078A, endInclusive = 0x079F }')
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  romRanges = {')
    [void]$sb.AppendLine('    { start = 0x1000, endInclusive = 0x13FF },')
    [void]$sb.AppendLine('    { start = 0x49BD, endInclusive = 0x49C4 },')
    [void]$sb.AppendLine('    { start = 0x49C5, endInclusive = 0x4A24 },')
    [void]$sb.AppendLine('    { start = 0x72BF, endInclusive = 0x72EE },')
    [void]$sb.AppendLine('    { start = 0x777A, endInclusive = 0x778C },')
    [void]$sb.AppendLine('    { start = 0x7791, endInclusive = 0x77A3 },')
    [void]$sb.AppendLine('    { start = 0x7963, endInclusive = 0x796B },')
    [void]$sb.AppendLine('    { start = 0x796E, endInclusive = 0x7978 },')
    [void]$sb.AppendLine('    { start = 0x8050, endInclusive = 0x8053 },')
    [void]$sb.AppendLine('    { start = 0x9B15, endInclusive = 0x9B25 },')
    [void]$sb.AppendLine('    { start = 0x9C44, endInclusive = 0x9C47 },')
    [void]$sb.AppendLine('    { start = 0x9ED7, endInclusive = 0x9EE6 },')
    [void]$sb.AppendLine('    { start = 0x9F14, endInclusive = 0x9F17 },')
    [void]$sb.AppendLine('    { start = 0xFFFE, endInclusive = 0xFFFF }')
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  phases = {')
    foreach ($p in $Phases) {
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine(('      name = {0},' -f (ConvertTo-LuaString $p.name)))
        [void]$sb.AppendLine(('      pc = 0x{0:X},' -f $p.pc))
        [void]$sb.AppendLine(('      x = {0},' -f (ConvertTo-LuaInt $p.x)))
        [void]$sb.AppendLine(('      y = 0x{0:X},' -f $p.y))
        [void]$sb.AppendLine(('      u = 0x{0:X},' -f $p.u))
        [void]$sb.AppendLine(('      s = 0x{0:X},' -f $p.s))
        [void]$sb.AppendLine(('      token = 0x{0:X},' -f $p.token))
        [void]$sb.AppendLine(('      liveToken = 0x{0:X},' -f $p.liveToken))
        [void]$sb.AppendLine(('      tokenAddress = 0x{0:X},' -f $p.tokenAddress))
        [void]$sb.AppendLine(('      handlerAddress = {0},' -f (ConvertTo-LuaInt $p.handlerAddress)))
        [void]$sb.AppendLine(('      operandAddress = {0},' -f (ConvertTo-LuaInt $p.operandAddress)))
        [void]$sb.AppendLine(('      operandWidth = {0},' -f $p.operandWidth))
        [void]$sb.AppendLine(('      operandValue = {0},' -f (ConvertTo-LuaInt $p.operandValue)))
        [void]$sb.AppendLine(('      operandText = {0},' -f (ConvertTo-LuaString $p.operandText)))
        [void]$sb.AppendLine(('      savedCursor = {0},' -f (ConvertTo-LuaInt $p.savedCursor)))
        [void]$sb.AppendLine(('      savedCursorOffset = {0},' -f $p.savedCursorOffset))
        [void]$sb.AppendLine(('      savedCursorRole = {0},' -f (ConvertTo-LuaString $p.savedCursorRole)))
        [void]$sb.AppendLine(('      controlTop = {0},' -f (ConvertTo-LuaInt $p.controlTop)))
        [void]$sb.AppendLine(('      controlTopSource = {0},' -f (ConvertTo-LuaString $p.controlTopSource)))
        [void]$sb.AppendLine(('      nativeStage = {0},' -f $(if ($null -ne $p.nativeStage) { ConvertTo-LuaString ([string]$p.nativeStage) } else { 'nil' })))
        [void]$sb.AppendLine(('      requireX = {0}' -f ($(if ($p.requireX) { 'true' } else { 'false' }))))
        [void]$sb.AppendLine('    },')
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  boundaries = {')
    foreach ($b in $Boundaries) {
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine(('      id = {0},' -f (ConvertTo-LuaString $b.id)))
        [void]$sb.AppendLine(('      pc = 0x{0:X},' -f $b.pc))
        [void]$sb.AppendLine(('      u = 0x{0:X},' -f $b.u))
        [void]$sb.AppendLine(('      s = 0x{0:X},' -f $b.s))
        [void]$sb.AppendLine(('      bytes = {0},' -f (ConvertTo-LuaString $b.bytes)))
        [void]$sb.AppendLine(('      instruction = {0},' -f (ConvertTo-LuaString $b.instruction)))
        [void]$sb.AppendLine(('      kind = {0},' -f (ConvertTo-LuaString $b.kind)))
        [void]$sb.AppendLine(('      offset = {0},' -f (ConvertTo-LuaInt $b.offset)))
        $skipWhen = if ($null -eq $b.skipWhen) { 'nil' } else { ConvertTo-LuaString ([string]$b.skipWhen) }
        [void]$sb.AppendLine(('      skipWhen = {0},' -f $skipWhen))
        [void]$sb.AppendLine(('      condition = {0}' -f (ConvertTo-LuaString $b.condition)))
        [void]$sb.AppendLine('    },')
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  stages = {')
    foreach ($s in $Stages) {
        $phaseNames = (@($s.phaseNames) | ForEach-Object { ConvertTo-LuaString ([string]$_) }) -join ', '
        $boundaryIds = (@($s.boundaryIds) | ForEach-Object { ConvertTo-LuaString ([string]$_) }) -join ', '
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine(('      id = {0},' -f (ConvertTo-LuaString $s.id)))
        [void]$sb.AppendLine(('      ordinal = {0},' -f $s.ordinal))
        [void]$sb.AppendLine(('      pc = 0x{0:X},' -f $s.pc))
        [void]$sb.AppendLine(('      condition = {0},' -f (ConvertTo-LuaString $s.condition)))
        [void]$sb.AppendLine(('      phaseNames = {{ {0} }},' -f $phaseNames))
        [void]$sb.AppendLine(('      boundaryIds = {{ {0} }},' -f $boundaryIds))
        [void]$sb.AppendLine(('      onlyIf = {0},' -f $(if (![string]::IsNullOrEmpty([string]$s.onlyIf)) { ConvertTo-LuaString ([string]$s.onlyIf) } else { 'nil' })))
        [void]$sb.AppendLine(('      branch = {0},' -f $(if (![string]::IsNullOrEmpty([string]$s.branch)) { ConvertTo-LuaString ([string]$s.branch) } else { 'nil' })))
        [void]$sb.AppendLine(('      note = {0}' -f (ConvertTo-LuaString ([string]$s.note))))
        [void]$sb.AppendLine('    },')
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  nativeFrame = {')
    [void]$sb.AppendLine(('    entryPc = 0x{0:X},' -f $NativeFrame.entryPc))
    [void]$sb.AppendLine(('    entryS = 0x{0:X},' -f $NativeFrame.entryS))
    [void]$sb.AppendLine(('    maskTableAddress = 0x{0:X},' -f $NativeFrame.maskTableAddress))
    [void]$sb.AppendLine(('    maskTableHex = {0},' -f (ConvertTo-LuaString $NativeFrame.maskTableHex)))
    [void]$sb.AppendLine('    steps = {')
    foreach ($key in $NativeFrame.steps.Keys) {
        $step = $NativeFrame.steps[$key]
        [void]$sb.AppendLine(('      {0} = {{ pc = 0x{1:X}, sOffset = {2}, topWord = "{3}", returnOffset = {4}, yOffset = {5}, sharedCursorOffset = {6} }},' -f $key,$step.pc,$step.sOffset,$step.topWord,(ConvertTo-LuaInt $step.returnOffset),$step.yOffset,$step.sharedCursorOffset))
    }
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('  }')
    [void]$sb.AppendLine('}')
    return $sb.ToString()
}

function Get-LampConfigLuaText {
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

function Write-LampConfigLua {
    param([string]$Path,$Config)
    [IO.File]::WriteAllText($Path,(Get-LampConfigLuaText $Config),$script:Utf8)
}

function Invoke-ProcessRecord {
    param([string]$FilePath,[string[]]$Arguments,[string]$WorkingDirectory,[string]$StdOutPath,[string]$StdErrPath,[int]$TimeoutSeconds)
    $quoted = foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') { '"' + $text.Replace('"','\"') + '"' } else { $text }
    }
    $arguments = ($quoted -join ' ')
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = [IO.Path]::GetFullPath($FilePath)
    $startInfo.Arguments = $arguments
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
        commandLine = $arguments
        startUtc = $startUtc.ToString('o')
        endUtc = [DateTime]::UtcNow.ToString('o')
        wallSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds,3)
        timeoutSeconds = $TimeoutSeconds
        timedOut = $timedOut
        exitCode = $exitCode
    }
}

function Get-ArgumentValues {
    param([string[]]$Arguments,[string]$Name)
    $values = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        if ($Arguments[$i] -ieq $Name) {
            if ($i + 1 -ge $Arguments.Count) { throw "MAME argument $Name has no value" }
            $values.Add([string]$Arguments[$i + 1])
            $i++
        }
    }
    return $values.ToArray()
}

function Assert-MameArgumentsTemplate {
    param([string]$RunPath,[string[]]$Arguments,[string]$BgfxPath)
    $launch = [IO.Path]::GetFullPath($RunPath).TrimEnd('\')
    if ($Arguments.Count -lt 2) { throw 'MAME argument template is empty' }
    if ($Arguments[0] -ine 'm4addr') { throw "MAME argument template system is $($Arguments[0]), expected m4addr" }
    foreach ($switch in @('-noreadconfig','-debug','-debuglog','-skip_gameinfo','-nothrottle')) {
        if (-not ($Arguments -contains $switch)) { throw "MAME argument template is missing $switch" }
    }
    $pairs = [ordered]@{ '-debugger'='imgui'; '-video'='bgfx'; '-sound'='none'; '-autoboot_delay'='0' }
    foreach ($key in $pairs.Keys) {
        $values = @(Get-ArgumentValues $Arguments $key)
        if ($values.Count -ne 1) { throw "MAME argument template has $($values.Count) $key values, expected 1" }
        if ($values[0] -ine $pairs[$key]) { throw "MAME argument template $key is $($values[0]), expected $($pairs[$key])" }
    }
    $seconds = @(Get-ArgumentValues $Arguments '-seconds_to_run')
    if ($seconds.Count -ne 1) { throw "MAME argument template has $($seconds.Count) -seconds_to_run values, expected 1" }
    $secondsValue = 0
    if (![int]::TryParse($seconds[0],[ref]$secondsValue) -or $secondsValue -lt 1 -or $secondsValue -gt 180) { throw "MAME argument template -seconds_to_run is $($seconds[0]), expected 1..180" }
    $directoryMap = [ordered]@{
        '-cfg_directory'='cfg'; '-nvram_directory'='nvram'; '-input_directory'='inp'; '-snapshot_directory'='snap';
        '-comment_directory'='comments'; '-state_directory'='state'; '-diff_directory'='diff'
    }
    foreach ($key in $directoryMap.Keys) {
        $values = @(Get-ArgumentValues $Arguments $key)
        if ($values.Count -ne 1) { throw "MAME argument template has $($values.Count) $key values, expected 1" }
        $actual = [IO.Path]::GetFullPath($values[0]).TrimEnd('\')
        $expected = [IO.Path]::GetFullPath((Join-Path $launch $directoryMap[$key])).TrimEnd('\')
        if ($actual -ine $expected) { throw "MAME argument template $key is $actual, expected isolated $expected" }
    }
    $romPaths = @(Get-ArgumentValues $Arguments '-rompath')
    if ($romPaths.Count -ne 1) { throw "MAME argument template has $($romPaths.Count) -rompath values, expected 1" }
    $romParts = @($romPaths[0].Split(';'))
    $expectedRunRoms = [IO.Path]::GetFullPath((Join-Path $launch 'roms')).TrimEnd('\')
    $actualFirstRom = [IO.Path]::GetFullPath($romParts[0]).TrimEnd('\')
    if ($actualFirstRom -ine $expectedRunRoms) { throw "MAME argument template first ROM path is $actualFirstRom, expected isolated $expectedRunRoms" }
    $observer = @(Get-ArgumentValues $Arguments '-autoboot_script')
    if ($observer.Count -ne 1) { throw "MAME argument template has $($observer.Count) -autoboot_script values, expected 1" }
    $expectedObserver = [IO.Path]::GetFullPath((Join-Path $launch 'observer.lua')).TrimEnd('\')
    $actualObserver = [IO.Path]::GetFullPath($observer[0]).TrimEnd('\')
    if ($actualObserver -ine $expectedObserver) { throw "MAME argument template autoboot script is $actualObserver, expected run-local $expectedObserver" }
    $bgfx = @(Get-ArgumentValues $Arguments '-bgfx_path')
    if ($bgfx.Count -ne 1) { throw "MAME argument template has $($bgfx.Count) -bgfx_path values, expected 1" }
    if ([IO.Path]::GetFullPath($bgfx[0]).TrimEnd('\') -ine [IO.Path]::GetFullPath($BgfxPath).TrimEnd('\')) { throw 'MAME argument template bgfx_path is not the installed asset directory' }
    $forbidden = @('-playback','-record','-state','-loadstate','-autosave','-debugscript','-snapshot','-aviwrite','-mngwrite','-wavwrite','-seed')
    foreach ($switch in $forbidden) {
        if ($Arguments -contains $switch) { throw "MAME argument template contains forbidden $switch" }
    }
    return [ordered]@{
        launchRunDirectory = $launch
        secondsToRun = $secondsValue
        romPath = $romPaths[0]
        observer = $actualObserver
        bgfxPath = [IO.Path]::GetFullPath($BgfxPath)
        isolatedDirectories = @($directoryMap.Keys)
        forbiddenSwitchesAbsent = $forbidden
    }
}

function Get-FrozenInputIdentities {
    $original = Assert-FileIdentity $OriginalRom $script:OriginalSha1 $script:OriginalSha256 'original ROM'
    $built = Assert-FileIdentity $BuiltRom $script:BuiltSha1 $script:BuiltSha256 'built lamp image'
    $map = Assert-FileHashIdentity $SourceMapPath $script:MapSha256 'final lamp source map'
    $report = Assert-FileHashIdentity $BuildReportPath $script:ReportSha256 'lamp build report'
    $checker = Assert-FileHashIdentity $CheckerReportPath $script:CheckerReportSha256 'supervisor checker report'
    $replay = Assert-FileHashIdentity $ReplayPath $script:ReplaySha256 'tracked replay fixture'
    $inputLua = Assert-FileHashIdentity $InputLuaPath $script:InputLuaSha256 'tracked input Lua'
    $mame = Assert-FileHashIdentity $MameExecutable $script:MameSha256 'MAME executable'
    $mameVersion = ([string](Get-Item -LiteralPath $MameExecutable).VersionInfo.ProductVersion).Trim()
    if ($mameVersion -ne $script:MameVersion) { throw "MAME ProductVersion is '$mameVersion', expected $($script:MameVersion)" }
    $bgfxPath = Join-Path (Split-Path ([IO.Path]::GetFullPath($MameExecutable)) -Parent) 'bgfx'
    if (!(Test-Path -LiteralPath $bgfxPath -PathType Container)) { throw "Installed BGFX asset directory is missing: $bgfxPath" }
    if (!(Test-Path -LiteralPath (Join-Path $bgfxPath 'shaders') -PathType Container)) { throw "Installed BGFX shader directory is missing: $bgfxPath\shaders" }
    $pluginsPath = Join-Path (Split-Path ([IO.Path]::GetFullPath($MameExecutable)) -Parent) 'plugins'
    return [ordered]@{
        originalRom = $original
        builtRom = $built
        sourceMap = $map
        buildReport = $report
        checkerReport = $checker
        replay = $replay
        inputLua = $inputLua
        mame = [ordered]@{
            executable = $mame.path
            length = $mame.length
            sha256 = $mame.sha256
            productVersion = $mameVersion
            expectedVersion = $script:MameVersion
            bgfxPath = [IO.Path]::GetFullPath($bgfxPath)
            bgfxShadersPresent = $true
            pluginsDirectoryPresent = (Test-Path -LiteralPath $pluginsPath -PathType Container)
            imguiSupport = 'pinned 0.281 build with -debugger imgui; plugins directory present'
        }
        replayPath = $ReplayPath
        inputLuaPath = $InputLuaPath
    }
}

function Test-FrozenInputRecheck {
    param($Before)
    $after = Get-FrozenInputIdentities
    foreach ($key in @('originalRom','builtRom','sourceMap','buildReport','checkerReport','replay','inputLua','mame')) {
        $b = $Before[$key]
        $a = $after[$key]
        if ($key -eq 'mame') {
            if ([string]$b.sha256 -ine [string]$a.sha256) { throw 'MAME executable changed during preparation' }
        }
        else {
            if ([string]$b.sha256 -ine [string]$a.sha256) { throw "$key changed during preparation" }
        }
    }
    return $after
}

function Write-PrepareFailure {
    param([string]$RunPath,[string]$Message)
    if (![string]::IsNullOrWhiteSpace($RunPath) -and (Test-Path -LiteralPath $RunPath -PathType Container)) {
        $path = Join-Path $RunPath 'prepare-failure.json'
        $payload = [ordered]@{
            taskId = $script:TaskId
            status = 'prepare_failed'
            mode = 'PrepareOnly'
            error = $Message
            mameLaunched = $false
            launchCount = 0
            retryAllowed = $false
            generatedUtc = [DateTime]::UtcNow.ToString('o')
        }
        try { Write-JsonFile $path $payload 10 } catch {}
    }
}

function Invoke-PrepareOnly {
    param([string]$RunPath)
    if ([string]::IsNullOrWhiteSpace($RunPath)) { throw 'RunDirectory is required for PrepareOnly' }
    $run = [IO.Path]::GetFullPath($RunPath)
    if (Test-Path -LiteralPath $run) { throw "PrepareOnly requires a fresh create-only directory: $run" }
    foreach ($path in @($MameExecutable,$RomDirectory,$BuiltRom,$SourceMapPath,$BuildReportPath,$CheckerReportPath,$OriginalRom,$ReplayPath,$InputLuaPath)) {
        if (!(Test-Path -LiteralPath $path)) { throw "Required input is missing: $path" }
    }
    $before = Get-FrozenInputIdentities
    $built = [IO.File]::ReadAllBytes($BuiltRom)
    $original = [IO.File]::ReadAllBytes($OriginalRom)
    $map = Read-JsonFile $SourceMapPath
    $build = Read-JsonFile $BuildReportPath
    $checker = Read-JsonFile $CheckerReportPath
    $contract = Test-LampMapContract $map $build $built $original $checker
    $phases = @(Get-ExpectedPhaseContract $map)
    $boundaries = @(Get-ExpectedBoundaryContract)
    $stages = @(Get-OrderedStagePlan $phases $boundaries)
    $nativeFrame = Get-NativeFrameContract
    if ($phases.Count -ne 43) { throw "Expected 43 phase contracts, got $($phases.Count)" }
    if ($boundaries.Count -ne 14) { throw "Expected 14 boundary contracts, got $($boundaries.Count)" }
    $boundedPhaseNames = @($phases | ForEach-Object { $_.name })
    $boundedBoundaryIds = @($boundaries | ForEach-Object { $_.id })
    $planPhaseNames = @($stages | ForEach-Object { @($_.phaseNames) } | ForEach-Object { $_ })
    $planBoundaryIds = @($stages | ForEach-Object { @($_.boundaryIds) } | ForEach-Object { $_ })
    if (($planPhaseNames -join ',') -ne ($boundedPhaseNames -join ',')) { throw 'Ordered stage plan does not preserve the 43 phase order' }
    if ((@($planBoundaryIds | Sort-Object) -join ',') -ne (@($boundedBoundaryIds | Sort-Object) -join ',')) { throw 'Ordered stage plan does not place every boundary exactly once' }
    if (@($planBoundaryIds).Count -ne 14) { throw "Ordered stage plan places $(@($planBoundaryIds).Count) boundaries, expected 14" }

    New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
    foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
        New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
    }
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    Copy-Item -LiteralPath $BuiltRom -Destination $runRom -ErrorAction Stop
    Copy-Item -LiteralPath $SourceMapPath -Destination (Join-Path $run 'lamp-clear-pattern-source-map.json') -ErrorAction Stop
    Copy-Item -LiteralPath $BuildReportPath -Destination (Join-Path $run 'build-report.json') -ErrorAction Stop
    Copy-Item -LiteralPath $CheckerReportPath -Destination (Join-Path $run 'checker-report.json') -ErrorAction Stop
    $runReplay = Join-Path $run 'replay-actions.csv'
    $runInputLua = Join-Path $run 'input.lua'
    Copy-Item -LiteralPath $ReplayPath -Destination $runReplay -ErrorAction Stop
    Copy-Item -LiteralPath $InputLuaPath -Destination $runInputLua -ErrorAction Stop
    Copy-Item -LiteralPath (Join-Path $script:Root 'tools/lua/IlLampClearNatural.lua') -Destination (Join-Path $run 'IlLampClearNatural.lua') -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlLampClearNatural.lua')`n",$script:Utf8)

    $runRomIdentity = Assert-FileIdentity $runRom $script:BuiltSha1 $script:BuiltSha256 'isolated run ROM before launch'
    $runReplayIdentity = Assert-FileHashIdentity $runReplay $script:ReplaySha256 'isolated replay fixture copy'
    $runInputLuaIdentity = Assert-FileHashIdentity $runInputLua $script:InputLuaSha256 'isolated input Lua copy'
    $luaCapturedPath = Join-Path $run 'IlLampClearNatural.lua'
    $luaSourcePath = Join-Path $script:Root 'tools/lua/IlLampClearNatural.lua'
    $luaSourceHash = Get-HashValue $luaSourcePath 'SHA256'
    $luaCapturedHash = Get-HashValue $luaCapturedPath 'SHA256'
    if ($luaSourceHash -ine $luaCapturedHash) { throw 'Captured Lua hash differs from the tracked Lua source' }
    $toolHash = Get-HashValue $PSCommandPath 'SHA256'

    $mapLuaPath = Join-Path $run 'lamp-clear-natural-map.lua'
    $mapLuaText = Get-LampMapLuaText $phases $boundaries $stages $nativeFrame $luaCapturedHash
    [IO.File]::WriteAllText($mapLuaPath,$mapLuaText,$script:Utf8)
    $planPath = Join-Path $run 'lamp-clear-natural-plan.json'
    $plan = [ordered]@{
        schemaVersion = 1
        protocol = $script:Protocol
        imageSha256 = $script:BuiltSha256
        sourceMapSha256 = $script:MapSha256
        luaSha256 = $luaCapturedHash
        phaseCount = 43
        boundaryCount = 14
        stageCount = $stages.Count
        phases = $phases
        boundaries = $boundaries
        stages = $stages
        nativeFrame = $nativeFrame
        classification = 'ordered_clear_arming_plan_derived_from_frozen_clear_map_and_rom_instruction_bytes'
    }
    Write-JsonFile $planPath $plan 50
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
        expectedSourceMapSha256 = $script:MapSha256
        expectedBuildReportSha256 = $script:ReportSha256
        expectedLuaSha256 = $luaCapturedHash
        expectedMameSha256 = $script:MameSha256
    }
    $configLuaPath = Join-Path $run 'session-config.lua'
    $configJsonPath = Join-Path $run 'session-config.json'
    Write-LampConfigLua $configLuaPath $config
    Write-JsonFile $configJsonPath $config 8

    $bgfxPath = [string]$before.mame.bgfxPath
    $arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+[IO.Path]::GetFullPath($RomDirectory)),
        '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
        '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
        '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
        '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','imgui','-debuglog',
        '-video','bgfx','-sound','none','-window','-skip_gameinfo','-nothrottle',
        '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
        '-autoboot_script',(Join-Path $run 'observer.lua'),'-bgfx_path',$bgfxPath)
    $templatePath = Join-Path $run 'arguments.template.json'
    Write-JsonFile $templatePath @($arguments) 6
    $templateValidation = Assert-MameArgumentsTemplate $run $arguments $bgfxPath

    $runLocalAssets = [ordered]@{
        lua = $luaCapturedHash
        map_lua = Get-HashValue $mapLuaPath 'SHA256'
        plan_json = Get-HashValue $planPath 'SHA256'
        config_lua = Get-HashValue $configLuaPath 'SHA256'
        config_json = Get-HashValue $configJsonPath 'SHA256'
        observer = Get-HashValue (Join-Path $run 'observer.lua') 'SHA256'
        arguments_template = Get-HashValue $templatePath 'SHA256'
        source_map = Get-HashValue (Join-Path $run 'lamp-clear-pattern-source-map.json') 'SHA256'
        build_report = Get-HashValue (Join-Path $run 'build-report.json') 'SHA256'
        checker_report = Get-HashValue (Join-Path $run 'checker-report.json') 'SHA256'
        rom = Get-HashValue $runRom 'SHA256'
        replay = Get-HashValue $runReplay 'SHA256'
        input_lua = Get-HashValue $runInputLua 'SHA256'
    }
    if ($runLocalAssets.map_lua -ine (Get-StringSha256 $mapLuaText)) { throw 'Generated lamp map Lua is not canonical' }
    if ($runLocalAssets.config_lua -ine (Get-StringSha256 (Get-LampConfigLuaText $config))) { throw 'Generated session config Lua is not canonical' }
    $observerText = [IO.File]::ReadAllText((Join-Path $run 'observer.lua'),$script:Utf8)
    if ($observerText -cne "dofile('input.lua')`ndofile('IlLampClearNatural.lua')`n") { throw 'Generated observer composition is not canonical' }

    $emptyCounts = [ordered]@{}
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        $emptyCounts[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count
        if ($emptyCounts[$name] -ne 0) { throw "Prepared directory $name is not empty" }
    }
    $romFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
    if (($romFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1' }

    $after = Test-FrozenInputRecheck $before
    $metadata = [ordered]@{
        protocol = $script:Protocol
        taskId = $script:TaskId
        mode = 'prepare-only'
        evidence_class = 'prepared_only_not_executed'
        sessionId = $sessionId
        original_rom = $before.originalRom
        built_rom = $before.builtRom
        run_rom_before = $runRomIdentity
        source_map = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $run 'lamp-clear-pattern-source-map.json')); sha256=$script:MapSha256 }
        build_report = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $run 'build-report.json')); sha256=$script:ReportSha256 }
        checker_report = [ordered]@{ path=[IO.Path]::GetFullPath((Join-Path $run 'checker-report.json')); sha256=$script:CheckerReportSha256 }
        contract = $contract
        lua = [ordered]@{ sourcePath=[IO.Path]::GetFullPath($luaSourcePath); sourceSha256=$luaSourceHash; capturedPath=[IO.Path]::GetFullPath($luaCapturedPath); capturedSha256=$luaCapturedHash }
        capture_tool = [ordered]@{ path=[IO.Path]::GetFullPath($PSCommandPath); sha256=$toolHash }
        ordered_plan = [ordered]@{ path=[IO.Path]::GetFullPath($planPath); sha256=$runLocalAssets.plan_json; stageCount=$stages.Count; phaseCount=43; boundaryCount=14; classification='ordered_arming_from_target_reachability_not_reset_all_breakpoints' }
        run_local_assets = $runLocalAssets
        input_replay = [ordered]@{
            path = $runReplayIdentity.path
            length = $runReplayIdentity.length
            sha256 = $runReplayIdentity.sha256
            input_lua_path = $runInputLuaIdentity.path
            input_lua_sha256 = $runInputLuaIdentity.sha256
            classification = 'tracked_physical_input_replay_no_state_injection'
        }
        mame = $before.mame
        frontend = [ordered]@{ debugger='imgui'; video='bgfx'; bgfx_path=$bgfxPath; focus_stealing=$false }
        arguments_template = [ordered]@{ path=[IO.Path]::GetFullPath($templatePath); sha256=$runLocalAssets.arguments_template; validation=$templateValidation }
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
        starting_nvram = 'absent'
        starting_configuration = 'absent; -noreadconfig'
        save_state_loaded = $false
        state_injection = $false
        input_injection = $false
        debugger_writes = $false
        input_replay_used = $true
        input_policy = 'tracked_physical_replay'
        mame_launched = $false
        launch_count = 0
        retry_allowed = $false
        natural_execution_claimed = $false
        fresh_directories = $emptyCounts
        classification = 'Prepared isolated future lamp-clear-natural capture. No MAME process was launched in this task.'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-JsonFile (Join-Path $run 'session-metadata.json') $metadata 40
    $preflight = [ordered]@{
        taskId = $script:TaskId
        status = 'prepared_no_launch'
        mode = 'PrepareOnly'
        runDirectory = $run
        sessionId = $sessionId
        protocol = $script:Protocol
        builtImage = $before.builtRom
        originalRom = $before.originalRom
        sourceMap = $before.sourceMap
        buildReport = $before.buildReport
        checkerReport = $before.checkerReport
        replay = $before.replay
        inputLua = $before.inputLua
        mame = $before.mame
        contract = $contract
        orderedPlan = [ordered]@{ path=[IO.Path]::GetFullPath($planPath); sha256=$runLocalAssets.plan_json; stageCount=$stages.Count; phaseCount=43; boundaryCount=14; ordering='target-dispatch-first-then-next-reachable-stage-only' }
        runLocalAssets = $runLocalAssets
        argumentsTemplate = [ordered]@{ path=[IO.Path]::GetFullPath($templatePath); sha256=$runLocalAssets.arguments_template; validation=$templateValidation }
        freshDirectories = $emptyCounts
        frozenInputsBefore = $before
        frozenInputsAfter = $after
        mameLaunched = $false
        launchCount = 0
        retryAllowed = $false
        naturalExecutionClaimed = $false
        evidenceClass = 'prepared_only_not_executed'
        checks = @(
            'frozen original/built/map/report/checker/replay/input-Lua/MAME hashes match the reviewed values',
            'source map BuildId and OutputImageSha256 bind the exact built image',
            '43 clear VM phases and the 14 reviewed runtime boundary records were derived from the frozen clear map and the accepted 61/67 contracts',
            'ordered stage plan covers every phase once and every boundary once',
            'native stack frame is derived from the 49C5/49CE/49D0/49E0/4A21/4A23 ROM instruction bytes',
            'generated map/plan/config/observer assets are canonical and hash-recorded',
            'MAME 0.281 product version, pinned executable hash, BGFX shader assets and plugins directory are present',
            'fresh isolated cfg/nvram/inp/snap/comments/state/diff directories are empty',
            'arguments template is isolated and contains no playback/state/autosave/debugscript/seed switch',
            'no MAME process was launched and no natural execution is claimed'
        )
        generatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-JsonFile (Join-Path $run 'preflight.json') $preflight 40
    [IO.File]::WriteAllText((Join-Path $run 'prepare-only.txt'),"status=prepared_no_launch`nmameLaunched=false`nlaunchCount=0`nchecks=10`nstages=$($stages.Count)`n",$script:Utf8)
    return [ordered]@{
        status = 'prepared_no_launch'
        mode = 'PrepareOnly'
        runDirectory = $run
        sessionId = $sessionId
        builtSha256 = $script:BuiltSha256
        mapSha256 = $script:MapSha256
        reportSha256 = $script:ReportSha256
        checkerReportSha256 = $script:CheckerReportSha256
        phaseCount = 43
        boundaryCount = 14
        stageCount = $stages.Count
        mameLaunched = $false
        launchCount = 0
        retryAllowed = $false
        naturalExecutionClaimed = $false
        preflightSha256 = Get-HashValue (Join-Path $run 'preflight.json') 'SHA256'
        metadataSha256 = Get-HashValue (Join-Path $run 'session-metadata.json') 'SHA256'
        planSha256 = $runLocalAssets.plan_json
        argumentsTemplateSha256 = $runLocalAssets.arguments_template
        mapLuaSha256 = $runLocalAssets.map_lua
        configLuaSha256 = $runLocalAssets.config_lua
        observerCompositionSha256 = $runLocalAssets.observer
        luaSha256 = $runLocalAssets.lua
    }
}

function Invoke-LampChecker {
    param([string]$RunPath)
    $checkerScript = Join-Path $script:Root 'tests/worker/Test-IlLampClearNatural.ps1'
    if (!(Test-Path -LiteralPath $checkerScript -PathType Leaf)) { throw "Offline checker is missing: $checkerScript" }
    $outputPath = Join-Path $RunPath 'checker-result.json'
    $stdoutPath = Join-Path $RunPath 'checker.stdout.log'
    $stderrPath = Join-Path $RunPath 'checker.stderr.log'
    $pwsh = Get-Command powershell -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $pwsh) { throw 'powershell is required to run the offline checker' }
    $record = Invoke-ProcessRecord -FilePath $pwsh.Source -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$checkerScript,'-Mode','Check','-RunDirectory',$RunPath,'-OutputPath',$outputPath) -WorkingDirectory $script:Root -StdOutPath $stdoutPath -StdErrPath $stderrPath -TimeoutSeconds 300
    if ($record.timedOut -or $record.exitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
        throw "Offline checker failed (exit=$($record.exitCode) timedOut=$($record.timedOut)): $stderr"
    }
    if (!(Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'Offline checker did not write checker-result.json' }
    return Read-JsonFile $outputPath
}

function Invoke-Run {
    param([string]$RunPath)
    if ([string]::IsNullOrWhiteSpace($RunPath)) { throw 'RunDirectory is required for Run' }
    $run = [IO.Path]::GetFullPath($RunPath)
    $preflightPath = Join-Path $run 'preflight.json'
    if (!(Test-Path -LiteralPath $preflightPath -PathType Leaf)) { throw "Run requires a PrepareOnly session: $preflightPath" }
    $preflight = Read-JsonFile $preflightPath
    if ([string]$preflight.status -ne 'prepared_no_launch') { throw 'Run requires a prepared_no_launch preflight record' }
    if ([bool]$preflight.mameLaunched) { throw 'Prepared session already records a MAME launch' }
    if (Test-Path -LiteralPath (Join-Path $run 'launch-lock.json')) { throw 'Launch lock already exists; no retry or second launch is permitted' }
    if (Test-Path -LiteralPath (Join-Path $run 'events.jsonl')) { throw 'Run directory already contains events; no rerun is permitted' }
    if (Test-Path -LiteralPath (Join-Path $run 'run-record.json')) { throw 'Run directory already contains a run record; no rerun is permitted' }

    $before = Get-FrozenInputIdentities
    $metadataPath = Join-Path $run 'session-metadata.json'
    $metadata = Read-JsonFile $metadataPath
    $expectedLua = [string]$metadata.lua.capturedSha256
    $luaPath = Join-Path $run 'IlLampClearNatural.lua'
    $mapLuaPath = Join-Path $run 'lamp-clear-natural-map.lua'
    $planPath = Join-Path $run 'lamp-clear-natural-plan.json'
    $configLuaPath = Join-Path $run 'session-config.lua'
    $configJsonPath = Join-Path $run 'session-config.json'
    $observerPath = Join-Path $run 'observer.lua'
    foreach ($path in @($luaPath,$mapLuaPath,$planPath,$configLuaPath,$configJsonPath,$observerPath,(Join-Path $run 'roms/m4addr/a6ls.p1'),(Join-Path $run 'replay-actions.csv'),(Join-Path $run 'input.lua'))) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Prepared run asset is missing: $path" }
    }
    if ((Get-HashValue $luaPath 'SHA256') -ine $expectedLua) { throw 'Prepared observer Lua hash differs from metadata' }
    if ((Get-HashValue $planPath 'SHA256') -ine [string]$metadata.ordered_plan.sha256) { throw 'Prepared ordered plan hash differs from metadata' }
    Assert-FileIdentity (Join-Path $run 'roms/m4addr/a6ls.p1') $script:BuiltSha1 $script:BuiltSha256 'run-local ROM' | Out-Null
    Assert-FileHashIdentity (Join-Path $run 'replay-actions.csv') $script:ReplaySha256 'run-local replay' | Out-Null
    Assert-FileHashIdentity (Join-Path $run 'input.lua') $script:InputLuaSha256 'run-local input Lua' | Out-Null

    # A prepared session must still be empty immediately before its only launch.
    $launchFreshness = [ordered]@{}
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        $count = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction Stop).Count
        if ($count -ne 0) { throw "Run refuses nonempty prelaunch directory $name" }
        $launchFreshness[$name] = $count
    }
    Write-JsonFile (Join-Path $run 'prelaunch-freshness.json') $launchFreshness 4

    $templatePath = Join-Path $run 'arguments.template.json'
    $arguments = @((Read-JsonFile $templatePath) | ForEach-Object { [string]$_ })
    $bgfxPath = [string]$before.mame.bgfxPath
    $templateValidation = Assert-MameArgumentsTemplate $run $arguments $bgfxPath
    $argumentsPath = Join-Path $run 'arguments.json'
    Write-JsonFile $argumentsPath @($arguments) 6

    $metadata | Add-Member -NotePropertyName mode -NotePropertyValue 'run' -Force
    $metadata.evidence_class = 'natural'
    $metadata.mame_launched = $true
    $metadata.launch_count = 1
    $metadata.retry_allowed = $false
    $metadata.natural_execution_claimed = $false
    Write-JsonFile $metadataPath $metadata 40

    $lockPath = Join-Path $run 'launch-lock.json'
    $lockStream = $null
    try {
        $lockStream = [IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $lockObject = [ordered]@{
            taskId = $script:TaskId
            sessionId = [string]$metadata.sessionId
            createdUtc = [DateTime]::UtcNow.ToString('o')
            launchCount = 1
            retryAllowed = $false
        }
        $lockBytes = $script:Utf8.GetBytes((ConvertTo-Json -InputObject $lockObject -Depth 5))
        $lockStream.Write($lockBytes,0,$lockBytes.Length)
        $lockStream.Flush()
    }
    finally {
        if ($null -ne $lockStream) { $lockStream.Dispose() }
    }

    $previousMap = $env:FML_IL_LAMP_CLEAR_MAP
    $previousConfig = $env:FML_IL_LAMP_CLEAR_CONFIG
    $previousReplay = $env:MPU4_REPLAY
    $previousPolicy = $env:MPU4_POLICY
    try {
        $env:FML_IL_LAMP_CLEAR_MAP = 'lamp-clear-natural-map.lua'
        $env:FML_IL_LAMP_CLEAR_CONFIG = 'session-config.lua'
        $env:MPU4_REPLAY = (Join-Path $run 'replay-actions.csv')
        $env:MPU4_POLICY = '7'
        $script:MameLaunched = $true
        $runRecord = Invoke-ProcessRecord -FilePath $MameExecutable -Arguments $arguments -WorkingDirectory $run -StdOutPath (Join-Path $run 'console.txt') -StdErrPath (Join-Path $run 'console.err.txt') -TimeoutSeconds $WallTimeoutSeconds
    }
    finally {
        $env:FML_IL_LAMP_CLEAR_MAP = $previousMap
        $env:FML_IL_LAMP_CLEAR_CONFIG = $previousConfig
        $env:MPU4_REPLAY = $previousReplay
        $env:MPU4_POLICY = $previousPolicy
    }
    $runRecord.commandId = 'il-lamp-clear-natural-' + $metadata.sessionId
    $runRecord.description = 'One fresh-boot lamp-clear-natural MAME observation at native debugger boundaries with the tracked physical replay'
    $runRecord.launchCount = 1
    $runRecord.retryAllowed = $false
    Write-JsonFile (Join-Path $run 'run-record.json') $runRecord 8
    [IO.File]::WriteAllText((Join-Path $run 'exit-code.txt'),[string]$runRecord.exitCode,$script:Utf8)
    $afterRunRom = Assert-FileIdentity (Join-Path $run 'roms/m4addr/a6ls.p1') $script:BuiltSha1 $script:BuiltSha256 'run-local ROM after execution'
    $afterOriginal = Assert-FileIdentity $OriginalRom $script:OriginalSha1 $script:OriginalSha256 'original ROM after execution'
    $afterFrozen = Test-FrozenInputRecheck $before
    $postRunHashes = [ordered]@{
        runLocalRom = $afterRunRom
        originalRom = $afterOriginal
        frozenInputs = $afterFrozen
        runLocalAssets = [ordered]@{
            lua = Get-HashValue (Join-Path $run 'IlLampClearNatural.lua') 'SHA256'
            mapLua = Get-HashValue (Join-Path $run 'lamp-clear-natural-map.lua') 'SHA256'
            planJson = Get-HashValue (Join-Path $run 'lamp-clear-natural-plan.json') 'SHA256'
            configLua = Get-HashValue (Join-Path $run 'session-config.lua') 'SHA256'
            configJson = Get-HashValue (Join-Path $run 'session-config.json') 'SHA256'
            observer = Get-HashValue (Join-Path $run 'observer.lua') 'SHA256'
            replay = Get-HashValue (Join-Path $run 'replay-actions.csv') 'SHA256'
            inputLua = Get-HashValue (Join-Path $run 'input.lua') 'SHA256'
        }
        mameLaunched = $true
        launchCount = 1
        retryAllowed = $false
        generatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    Write-JsonFile (Join-Path $run 'post-run-hashes.json') $postRunHashes 30

    if ($runRecord.timedOut -or $runRecord.exitCode -ne 0) {
        $failure = [ordered]@{
            taskId = $script:TaskId
            status = 'capture_failed'
            reason = if ($runRecord.timedOut) { 'wall timeout' } else { "MAME exit $($runRecord.exitCode)" }
            runDirectory = $run
            mameRecord = $runRecord
            runRomAfter = $afterRunRom
            originalRomAfter = $afterOriginal
            launchCount = 1
            retryAllowed = $false
            naturalExecutionClaimed = $false
            note = 'One launch was attempted. Raw files are preserved and no rerun is allowed.'
        }
        Write-JsonFile (Join-Path $run 'capture-failure.json') $failure 20
        throw "Single MAME launch failed: $($failure.reason)"
    }
    if (!(Test-Path -LiteralPath (Join-Path $run 'events.jsonl') -PathType Leaf)) {
        Write-JsonFile (Join-Path $run 'capture-failure.json') ([ordered]@{
            taskId = $script:TaskId; status='capture_failed'; reason='Lua observer did not produce events.jsonl'; runDirectory=$run; mameRecord=$runRecord; launchCount=1; retryAllowed=$false; naturalExecutionClaimed=$false
        }) 20
        throw 'Lua observer did not produce events.jsonl'
    }
    $checkResult = Invoke-LampChecker $run
    if (-not [bool]$checkResult.pass) {
        Write-JsonFile (Join-Path $run 'capture-failure.json') ([ordered]@{
            taskId = $script:TaskId; status='capture_failed'; reason='offline checker rejected the single capture'; runDirectory=$run; mameRecord=$runRecord; checkerResult=$checkResult; launchCount=1; retryAllowed=$false; naturalExecutionClaimed=$false
        }) 20
        throw 'Offline checker rejected the single capture; raw files are preserved'
    }
    return [ordered]@{
        status = [string]$checkResult.status
        runDirectory = $run
        mameLaunched = $true
        launchCount = 1
        retryAllowed = $false
        naturalExecutionClaimed = $true
        mameExitCode = $runRecord.exitCode
        mameTimedOut = $runRecord.timedOut
        postRunHashesSha256 = Get-HashValue (Join-Path $run 'post-run-hashes.json') 'SHA256'
        checkerResult = $checkResult
    }
}

function Invoke-Analyze {
    param([string]$RunPath,[switch]$VerifyOnly)
    if ([string]::IsNullOrWhiteSpace($RunPath)) { throw 'RunDirectory is required for Analyze and Verify' }
    $run = [IO.Path]::GetFullPath($RunPath)
    $checkResult = Invoke-LampChecker $run
    if (-not $VerifyOnly) {
        Write-JsonFile (Join-Path $run 'analysis-result.json') $checkResult 40
    }
    return $checkResult
}

if (-not $LibraryOnly) {
    try {
        if ($Mode -eq 'PrepareOnly') {
            $result = Invoke-PrepareOnly $RunDirectory
        }
        elseif ($Mode -eq 'Run') {
            $result = Invoke-Run $RunDirectory
        }
        elseif ($Mode -eq 'Verify') {
            $result = Invoke-Analyze $RunDirectory -VerifyOnly
        }
        else {
            $result = Invoke-Analyze $RunDirectory
        }
        Write-Output (ConvertTo-Json -InputObject $result -Depth 10)
        exit 0
    }
    catch {
        $message = $_.Exception.Message
        if ($Mode -eq 'PrepareOnly') { Write-PrepareFailure $RunDirectory $message }
        Write-Output (ConvertTo-Json -InputObject ([ordered]@{
            status = 'failed'
            error = $message
            mode = $Mode
            run = $RunDirectory
            mameLaunched = [bool]$script:MameLaunched
        }) -Depth 6)
        [Console]::Error.WriteLine($message)
        exit 1
    }
}
