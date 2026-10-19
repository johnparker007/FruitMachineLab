[CmdletBinding()]
param(
    [ValidateSet('Check','Test')][string]$Mode = 'Test',
    [string]$RunDirectory,
    [string]$OutputPath,
    [switch]$AllowSynthetic,
    [string]$ArtifactDirectory
)
$ErrorActionPreference = 'Stop'

$script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:Protocol = 'il-lamp-natural-v1'
$script:OriginalSha1 = '402D1518BB78FDC489B06C2AABC771E5CE151847'
$script:OriginalSha256 = 'EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C'
$script:BuiltSha1 = '9F060102692BB31E03F992E95E38F4F59BEE1129'
$script:BuiltSha256 = '631F6C252A5DF359525553F7D14A4FC8CEF965C76BBECA759EAAA862A3FAD4DE'
$script:MapSha256 = '42F0C4BB886313F5B1A7F78991A2EFD09351CC1912DF7A58EA6E3BE7E8E84163'
$script:ReportSha256 = 'F085192074032C35F212B96F8F480720AAC49BDEBC56C0B2C8D54FA11C9CF97F'
$script:CheckerReportSha256 = 'D988804F9E4157584D1BE1CCA2DAD41578B30C23BB25FBA16C0522F7BC679E99'
$script:MameSha256 = '0FCE5A88DF4F9D9B1FBF1405812C00848036E615993780978D967DA34204CB7A'
$script:ReplaySha256 = '4A051DA15264842697879EFF396B34A789F5D80623F9A2E749C244E6A80E721D'
$script:InputLuaSha256 = '23099F8888AF8DB353253E0DF97638320DC59CA9A47371723A380E0C4EE85C94'
$script:RequiredStartFrames = @(2221,2222,2223,2224)
$script:ExpectedCoinFrames = @(2100,2101,2102,2103)
$script:BoundaryIds = @(
    'port-orcc50','port-sta-0801','port-stb-0802','port-ldb-0803-preread','port-pulscc-pre',
    'frame-write-010f','frame-write-011f','frame-write-012f','frame-write-013f',
    'port-f1-set-read','port-f1-set-write','port-080c-set-write','port-f1-clear-write','port-080c-clear-write'
)
$script:Checks = 0
$script:Failures = 0

if ([string]::IsNullOrWhiteSpace($ArtifactDirectory)) {
    $ArtifactDirectory = Join-Path $script:Root 'artifacts/deepseek/il-lamp-natural-tools-finish-65'
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Get-Sha1([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA1]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Write-JsonFile([string]$Path,$Object,[int]$Depth = 40) {
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),$script:Utf8)
}
function Read-JsonFile([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON file is missing: $Path" }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}
function Format-Hex16([int]$Value) { return ('{0:X4}' -f ($Value -band 0xFFFF)) }
function Format-Hex8([int]$Value) { return ('{0:X2}' -f ($Value -band 0xFF)) }
function ConvertTo-HexInt([string]$Text) { return [Convert]::ToInt32($Text,16) }
function ConvertTo-LuaInt($Value) { if ($null -eq $Value) { return 'nil' }; return ('0x{0:X}' -f [int]$Value) }
function ConvertTo-LuaString([string]$Text) { return '"' + $Text.Replace('\','\\').Replace('"','\"') + '"' }
function Write-Pass([string]$Message) { $script:Checks++; Write-Output "PASS: $Message" }
function Write-Fail([string]$Message) { $script:Checks++; $script:Failures++; Write-Output "FAIL: $Message" }
function Assert-True([bool]$Condition,[string]$Message) { if ($Condition) { Write-Pass $Message } else { Write-Fail $Message } }
function Assert-Equal($Actual,$Expected,[string]$Message) {
    $numericTypes = @([int],[long],[byte],[int16],[int64],[double],[single],[decimal],[bool])
    $bothNumeric = ($null -ne $Actual) -and ($null -ne $Expected) -and ($numericTypes -contains $Actual.GetType()) -and ($numericTypes -contains $Expected.GetType())
    $equal = if ($bothNumeric) { [double]$Actual -eq [double]$Expected } else { [string]$Actual -eq [string]$Expected }
    if ($equal) { Write-Pass $Message }
    else { Write-Fail "$Message (actual '$Actual', expected '$Expected')" }
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
    return [ordered]@{ commandLine=$argumentString; startUtc=$startUtc.ToString('o'); endUtc=[DateTime]::UtcNow.ToString('o'); wallSeconds=[Math]::Round($stopwatch.Elapsed.TotalSeconds,3); timeoutSeconds=$TimeoutSeconds; timedOut=$timedOut; exitCode=$exitCode }
}

function Get-PhaseStackContract {
    return @{
        'caller-dispatch'=@{ controlTop=0x9F3F; savedCursorOffset=0; role='caller-control-top' }
        'header-trampoline-entry'=@{ controlTop=0x9F3F; savedCursorOffset=0; role='pending-y-before-pshs' }
        'body-prefetch-0'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-0'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-1'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-1'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-2'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-2'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-3'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-3'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-4'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-4'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-5'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'handler-5'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'body-prefetch-6'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'shared-handler-entry'=@{ controlTop=0x9F16; savedCursorOffset=0; role='shared-top' }
        'service-trampoline-jrs-entry'=@{ controlTop=0x9B18; savedCursorOffset=0; role='trampoline-control-top' }
        'service-trampoline-pshu'=@{ controlTop=0x9B18; savedCursorOffset=0; role='trampoline-control-top' }
        'shared-body-entry'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-fetch-word'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-rotate'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-add'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-fetch-byte'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-after-swap'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-entry'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-pulu-pattern'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-load-index'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-discard-index'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-branch-continuation'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'bridge-saves-y'=@{ controlTop=0x9B24; savedCursorOffset=2; role='native-y-below-shared' }
        'bridge-jsr-entry'=@{ controlTop=0x777E; savedCursorOffset=4; role='native-return-below-shared' }
        'native-prologue-save-regs'=@{ controlTop=$null; savedCursorOffset=8; role='native-saved-registers'; nativeStage='afterRegs' }
        'native-prologue-save-mask'=@{ controlTop=$null; savedCursorOffset=9; role='native-saved-mask'; nativeStage='afterMask' }
        'native-prologue-deepest'=@{ controlTop=$null; savedCursorOffset=10; role='native-saved-cc'; nativeStage='afterCc' }
        'native-epilogue-puls-cc'=@{ controlTop=$null; savedCursorOffset=9; role='native-after-puls-cc'; nativeStage='afterPulsCc' }
        'native-epilogue-puls-a'=@{ controlTop=$null; savedCursorOffset=8; role='native-after-puls-a'; nativeStage='afterPulsA' }
        'native-return'=@{ controlTop=0x9B24; savedCursorOffset=2; role='native-return-y-below-shared' }
        'bridge-restores-y'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-prefetch-return'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-return-handler'=@{ controlTop=0x1026; savedCursorOffset=0; role='shared-cursor-top' }
        'shared-returned-to-1026'=@{ controlTop=0x9F16; savedCursorOffset=0; role='outer-cursor-top' }
        'outer-return-handler'=@{ controlTop=0x9F16; savedCursorOffset=0; role='outer-cursor-top' }
        'outer-returned-to-9F16'=@{ controlTop=0x9F3F; savedCursorOffset=0; role='outer-control-top' }
    }
}

function Get-NativeFrameContract {
    return [ordered]@{
        entryPc=0x49C5; entryS=0x0790; maskTableAddress=0x49BD; maskTableHex='0102040810204080'
        steps=[ordered]@{
            afterRegs=@{ pc=0x49C7; sOffset=-4; topWord='entryAB'; returnOffset=4; yOffset=6; sharedCursorOffset=8 }
            afterMask=@{ pc=0x49D0; sOffset=-5; topWord='maskEntryA'; returnOffset=5; yOffset=7; sharedCursorOffset=9 }
            afterCc=@{ pc=0x49D2; sOffset=-6; topWord='ccMask'; returnOffset=6; yOffset=8; sharedCursorOffset=10 }
            afterPulsCc=@{ pc=0x49E2; sOffset=-5; topWord='maskEntryA'; returnOffset=5; yOffset=7; sharedCursorOffset=9 }
            afterPulsA=@{ pc=0x4A23; sOffset=-4; topWord='entryAB'; returnOffset=4; yOffset=6; sharedCursorOffset=8 }
            nativeReturn=@{ pc=0x777E; sOffset=2; topWord='y'; returnOffset=$null; yOffset=0; sharedCursorOffset=2 }
        }
    }
}

function Get-ExpectedPhases {
    param($Map)
    if ([int]$Map.Phases.Count -ne 43) { throw "Source map has $($Map.Phases.Count) phases, expected 43" }
    $stackContracts = Get-PhaseStackContract
    $list = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt $Map.Phases.Count; $i++) {
        $p = $Map.Phases[$i]
        $name = [string]$p.Phase
        if (-not $stackContracts.ContainsKey($name)) { throw "No stack contract for phase $name" }
        $stack = $stackContracts[$name]
        $liveToken = if ($null -ne $p.ReplacementToken) { [int]$p.ReplacementToken } else { [int]$p.Token }
        $kind = [int]$p.OperandKind
        $width = if ($kind -eq 1) { 2 } elseif ($kind -eq 2) { 1 } else { 0 }
        $list.Add([ordered]@{
            name=$name; pc=[int]$p.Pc; x=if ($null -ne $p.X) { [int]$p.X } else { $null }; y=[int]$p.Y
            u=[int]$p.U; s=[int]$p.S; token=[int]$p.Token; liveToken=$liveToken
            tokenAddress=(Get-TokenAddressForPhase $p); handlerAddress=if ($null -ne $p.HandlerAddress) { [int]$p.HandlerAddress } else { $null }
            operandAddress=if ($width -gt 0) { [int]$p.OperandAddress } else { $null }; operandWidth=$width
            operandValue=if ($width -gt 0) { [int]$p.OperandValue } else { $null }
            operandText=if ($width -eq 2) { Format-Hex16 ([int]$p.OperandValue) } elseif ($width -eq 1) { Format-Hex8 ([int]$p.OperandValue) } else { '' }
            savedCursor=if ($null -ne $p.SavedCursor) { [int]$p.SavedCursor } else { $null }
            savedCursorOffset=[int]$stack.savedCursorOffset
            savedCursorRole=[string]$stack.role
            controlTop=if ($null -ne $stack.controlTop) { [int]$stack.controlTop } else { $null }
            nativeStage=if ($stack.ContainsKey('nativeStage')) { [string]$stack.nativeStage } else { $null }
            controlTopSource=if ($null -ne $stack.controlTop) { 'static_prediction' } else { 'live_native_entry_frame' }
            requireX=($null -ne $p.X)
        })
    }
    return $list.ToArray()
}

function Get-OrderedStagePlan {
    param($Phases,$Boundaries)
    $boundaryById=@{}; foreach ($b in $Boundaries) { $boundaryById[[string]$b.id]=$b }
    $phaseByName=@{}; foreach ($p in $Phases) { $phaseByName[[string]$p.name]=$p }
    $used=@{}; $stages=New-Object 'System.Collections.Generic.List[object]'
    function Add-Stage {
        param([int]$Pc,[string[]]$PhaseNames,[string[]]$BoundaryIds,[string]$OnlyIf=$null,[string]$Branch=$null,[string]$Note='')
        $y=$null; foreach ($pn in $PhaseNames) { $y=[int]$phaseByName[$pn].y; break }
        if ($Pc -eq 0x00FC -and $null -eq $y) { throw 'Dispatcher stage has no phase Y' }
        $condition = if ($Pc -eq 0x00FC) { ('y==0x{0:x}' -f $y) } else { '1' }
        $id = ('stage-{0:D2}-{1}' -f ($stages.Count+1), $(if ($PhaseNames.Count -gt 0) { $PhaseNames[0] } elseif ($BoundaryIds.Count -gt 0) { $BoundaryIds[0] } else { 'unnamed' }))
        $stages.Add([ordered]@{ id=$id; ordinal=$stages.Count; pc=$Pc; condition=$condition; phaseNames=@($PhaseNames); boundaryIds=@($BoundaryIds); onlyIf=$OnlyIf; branch=$Branch; note=$Note })
        foreach ($id in $BoundaryIds) { $used[$id]=$true }
    }
    function Add-BoundaryStage { param([string]$Id,[string]$OnlyIf=$null)
        if (-not $boundaryById.ContainsKey($Id)) { throw "Boundary $Id is not defined" }
        if ($used.ContainsKey($Id)) { throw "Boundary $Id is already placed" }
        Add-Stage -Pc ([int]$boundaryById[$Id].pc) -PhaseNames @() -BoundaryIds @($Id) -OnlyIf $OnlyIf
    }
    foreach ($p in $Phases) {
        switch ([string]$p.name) {
            'bridge-pulu-pattern' {
                Add-Stage -Pc ([int]$p.pc) -PhaseNames @($p.name) -BoundaryIds @('port-f1-set-read') -Branch 'f1-entry'
                Add-BoundaryStage 'port-f1-set-write' 'f1EntryNonZero'
                Add-BoundaryStage 'port-080c-set-write' 'f1EntryNonZero'
            }
            'native-prologue-deepest' {
                Add-Stage -Pc ([int]$p.pc) -PhaseNames @($p.name) -BoundaryIds @()
                Add-BoundaryStage 'port-orcc50'; Add-BoundaryStage 'port-sta-0801'; Add-BoundaryStage 'port-stb-0802'; Add-BoundaryStage 'port-ldb-0803-preread'; Add-BoundaryStage 'port-pulscc-pre'
            }
            'native-epilogue-puls-cc' {
                Add-Stage -Pc ([int]$p.pc) -PhaseNames @($p.name) -BoundaryIds @()
                Add-BoundaryStage 'frame-write-010f'; Add-BoundaryStage 'frame-write-011f'; Add-BoundaryStage 'frame-write-012f'; Add-BoundaryStage 'frame-write-013f'
            }
            'bridge-restores-y' {
                Add-Stage -Pc ([int]$p.pc) -PhaseNames @($p.name) -BoundaryIds @() -Branch 'f1-exit'
                Add-BoundaryStage 'port-f1-clear-write' 'f1ExitNonZero'
                Add-BoundaryStage 'port-080c-clear-write' 'f1ExitNonZero'
            }
            default { Add-Stage -Pc ([int]$p.pc) -PhaseNames @($p.name) -BoundaryIds @() }
        }
    }
    $missing=@($Boundaries | Where-Object { -not $used.ContainsKey([string]$_.id) } | ForEach-Object { $_.id })
    if ($missing.Count -ne 0) { throw "Unplaced boundaries: $($missing -join ',')" }
    return $stages.ToArray()
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
    if ($name -like 'native-*' -or $name -eq 'native-return') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'bridge-restores-y') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'shared-prefetch-return') { return $y }
    if ($name -eq 'shared-return-handler') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'shared-returned-to-1026') { return $y }
    if ($name -eq 'outer-return-handler') { return ($y - 2) -band 0xFFFF }
    if ($name -eq 'outer-returned-to-9F16') { return $y }
    throw "No token-address rule for phase $name"
}

function Get-ExpectedBoundaries {
    $rows = @(
        @{ id='port-orcc50'; pc=0x49D5; bytes='1A50'; instruction='ORCC #$50'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-sta-0801'; pc=0x49D7; bytes='B70801'; instruction='STA $0801'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-stb-0802'; pc=0x49DA; bytes='F70802'; instruction='STB $0802'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-ldb-0803-preread'; pc=0x49DD; bytes='F60803'; instruction='LDB $0803'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='port-pulscc-pre'; pc=0x49E0; bytes='3501'; instruction='PULS CC'; kind='port_safe'; u=0x066E; s=0x078A; offset=$null; skipWhen=$null },
        @{ id='frame-write-010f'; pc=0x49F8; bytes='E784'; instruction='STB ,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x00; skipWhen=$null },
        @{ id='frame-write-011f'; pc=0x4A04; bytes='E78810'; instruction='STB $10,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x10; skipWhen=$null },
        @{ id='frame-write-012f'; pc=0x4A11; bytes='E78820'; instruction='STB $20,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x20; skipWhen=$null },
        @{ id='frame-write-013f'; pc=0x4A1E; bytes='E78830'; instruction='STB $30,X'; kind='frame_write'; u=0x066E; s=0x078B; offset=0x30; skipWhen=$null },
        @{ id='port-f1-set-read'; pc=0x7793; bytes='96F1'; instruction='LDA <$F1'; kind='port_safe'; u=0x066C; s=0x0794; offset=$null; skipWhen=$null },
        @{ id='port-f1-set-write'; pc=0x7799; bytes='97F1'; instruction='STA <$F1'; kind='port_safe'; u=0x066C; s=0x0794; offset=$null; skipWhen='f1_set_zero' },
        @{ id='port-080c-set-write'; pc=0x779B; bytes='B7080C'; instruction='STA $080C'; kind='port_safe'; u=0x066C; s=0x0794; offset=$null; skipWhen='f1_set_zero' },
        @{ id='port-f1-clear-write'; pc=0x7786; bytes='97F1'; instruction='STA <$F1'; kind='port_safe'; u=0x066E; s=0x0794; offset=$null; skipWhen='f1_clear_zero' },
        @{ id='port-080c-clear-write'; pc=0x7788; bytes='B7080C'; instruction='STA $080C'; kind='port_safe'; u=0x066E; s=0x0794; offset=$null; skipWhen='f1_clear_zero' }
    )
    $list = New-Object 'System.Collections.Generic.List[object]'
    foreach ($r in $rows) {
        $list.Add([ordered]@{ id=[string]$r.id; pc=[int]$r.pc; bytes=[string]$r.bytes; instruction=[string]$r.instruction; kind=[string]$r.kind; u=[int]$r.u; s=[int]$r.s; offset=$r.offset; skipWhen=$r.skipWhen })
    }
    return $list.ToArray()
}

function Get-EventRecords {
    param([string]$Run)
    $events = Join-Path $Run 'events.jsonl'
    if (!(Test-Path -LiteralPath $events -PathType Leaf)) { throw "events.jsonl is missing: $events" }
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $pwsh) { throw 'pwsh is required for strict JSONL validation' }
    $strictOut = Join-Path $Run 'events-strict.json'
    $record = Invoke-ProcessRecord -FilePath $pwsh.Source -Arguments @('-NoProfile','-File',(Join-Path $script:Root 'tests/worker/Test-IlEventJson.ps1'),'-Mode','Parse','-EventsPath',$events,'-OutputPath',$strictOut) -WorkingDirectory $script:Root -StdOutPath (Join-Path $Run 'events-strict.stdout.log') -StdErrPath (Join-Path $Run 'events-strict.stderr.log') -TimeoutSeconds 120
    if ($record.timedOut -or $record.exitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath (Join-Path $Run 'events-strict.stderr.log')) { Get-Content -LiteralPath (Join-Path $Run 'events-strict.stderr.log') -Raw } else { '' }
        throw "Strict JSONL parse failed: $stderr"
    }
    $summary = Read-JsonFile $strictOut
    if (-not [bool]$summary.pass) { throw 'Strict JSONL parser reported a failure' }
    return [ordered]@{ records=@($summary.records); strictPath=$strictOut; sha256=(Get-Sha256 $events); count=[int]$summary.recordCount }
}

function Get-InputRows {
    param([string]$Run)
    $path = Join-Path $Run 'input-levels.csv'
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw 'input-levels.csv is missing' }
    $lines = @(Get-Content -LiteralPath $path)
    if ($lines.Count -lt 2) { throw 'input-levels.csv has no samples' }
    if ($lines[0] -ne 'frame,t,aux2,black2,coin_override') { throw "input-levels.csv header is not canonical: $($lines[0])" }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in $lines[1..($lines.Count - 1)]) {
        if ($line -notmatch '^(\d+),([0-9.]+),([0-9A-Fa-f]{2}),([0-9A-Fa-f]{2}),(\d+)$') { throw "input-levels.csv row is malformed: $line" }
        $time = [double]::Parse($Matches[2],[Globalization.CultureInfo]::InvariantCulture)
        if ([double]::IsNaN($time) -or [double]::IsInfinity($time) -or $time -lt 0) { throw "input-levels.csv row has a non-finite time: $line" }
        $rows.Add([ordered]@{
            frame=[int]$Matches[1]; time=$time; aux2=[Convert]::ToInt32($Matches[3],16); black2=[Convert]::ToInt32($Matches[4],16); coinOverride=[int]$Matches[5]
        })
    }
    return $rows.ToArray()
}

function Get-ReplaySchedule {
    param([string]$Run)
    $path = Join-Path $Run 'replay-actions.csv'
    $coin = $null
    $start = $null
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^(\d+),(\d+),([^,]+),(\d+),([^,]+),') {
            $entry = [ordered]@{ firstFrame=[int]$Matches[1]; lastFrame=[int]$Matches[2]; port=[string]$Matches[3]; mask=[int]$Matches[4]; reason=[string]$Matches[5] }
            if ($null -eq $coin -and $entry.reason -eq 'short_coin') { $coin = $entry }
            if ($null -eq $start -and $entry.reason -eq 'start_probe') { $start = $entry }
        }
    }
    if ($null -eq $coin -or $null -eq $start) { throw 'Tracked replay is missing its coin or start event' }
    if ($coin.firstFrame -ne 2100 -or $coin.lastFrame -ne 2103 -or $coin.port -ne ':AUX2' -or $coin.mask -ne 128) { throw 'Tracked replay coin event is wrong' }
    if ($start.firstFrame -ne 2220 -or $start.lastFrame -ne 2232 -or $start.port -ne ':BLACK2' -or $start.mask -ne 128) { throw 'Tracked replay start event is wrong' }
    return [ordered]@{ coin=$coin; start=$start }
}

function Add-Failure {
    param($List,[string]$Code,[string]$Message,[string]$Expected = '',[string]$Observed = '')
    $List.Add([ordered]@{ code=$Code; message=$Message; expected=$Expected; observed=$Observed })
}

function Get-NativeMaskValue {
    param([int]$EntryA)
    return @(0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80)[$EntryA -band 0x07]
}

function Test-NativeFrameRecord {
    param($Event,$Expected,$PhaseByName,$Failures)
    $stage = [string]$Expected.nativeStage
    if ([string]::IsNullOrWhiteSpace($stage) -and [string]$Expected.name -eq 'native-return') { $stage = 'nativeReturn' }
    if ([string]::IsNullOrWhiteSpace($stage)) { return }
    $steps = (Get-NativeFrameContract).steps
    if (-not $steps.Contains($stage)) { Add-Failure $Failures 'phase_native_frame' "Unknown native stage $stage" '' ''; return }
    $step = $steps[$stage]
    foreach ($field in @('nativeEntryA','nativeEntryB','nativeEntryX','nativeMask','nativeFrameTop','nativeYSlot')) {
        if ([string]::IsNullOrWhiteSpace([string]$Event.$field)) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) is missing $field" '' ''; return }
    }
    try {
        $entryA = ConvertTo-HexInt ([string]$Event.nativeEntryA)
        $entryB = ConvertTo-HexInt ([string]$Event.nativeEntryB)
        $entryX = ConvertTo-HexInt ([string]$Event.nativeEntryX)
    }
    catch { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) native entry fields are not hex" '' ''; return }
    $mask = Get-NativeMaskValue $entryA
    if ((ConvertTo-HexInt ([string]$Event.nativeMask)) -ne $mask) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) nativeMask is $($Event.nativeMask), ROM mask table says $(Format-Hex8 $mask)" (Format-Hex8 $mask) ([string]$Event.nativeMask) }
    $expectedTop = switch ([string]$step.topWord) {
        'entryAB'   { (($entryA -shl 8) -bor $entryB) -band 0xFFFF }
        'maskEntryA'{ (($mask -shl 8) -bor $entryA) -band 0xFFFF }
        'ccMask'    {
            $ccEvent = $PhaseByName['native-prologue-save-mask']
            if ($null -eq $ccEvent -or [string]::IsNullOrWhiteSpace([string]$ccEvent.ccSaved49D0)) { 0 }
            else { (([Convert]::ToInt32([string]$ccEvent.ccSaved49D0,16) -shl 8) -bor $mask) -band 0xFFFF }
        }
        'y'         { 0x9B24 }
        default     { -1 }
    }
    if ($expectedTop -lt 0) { Add-Failure $Failures 'phase_native_frame' "Unknown native top kind $($step.topWord)" '' ''; return }
    $observedTop = ConvertTo-HexInt ([string]$Event.nativeFrameTop)
    $rawTop = ConvertTo-HexInt ([string]$Event.controlStack0)
    if ($rawTop -ne $observedTop) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) controlStack0 $($Event.controlStack0) is not its nativeFrameTop $($Event.nativeFrameTop)" ([string]$Event.nativeFrameTop) ([string]$Event.controlStack0) }
    if ($observedTop -ne $expectedTop) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) native frame top is $(Format-Hex16 $observedTop), expected $(Format-Hex16 $expectedTop) from live entry A/B/X and the ROM mask table" (Format-Hex16 $expectedTop) (Format-Hex16 $observedTop) }
    if ($observedTop -eq 0x777E) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) wrongly uses 777E as the native w@S top" 'not 777E' '777E' }
    if ($null -ne $step.returnOffset) {
        if ([string]::IsNullOrWhiteSpace([string]$Event.nativeReturnSlot)) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) is missing nativeReturnSlot" '' '' }
        elseif ((ConvertTo-HexInt ([string]$Event.nativeReturnSlot)) -ne 0x777E) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) native return slot is $($Event.nativeReturnSlot), expected 777E" '777E' ([string]$Event.nativeReturnSlot) }
    }
    if ((ConvertTo-HexInt ([string]$Event.nativeYSlot)) -ne 0x9B24) { Add-Failure $Failures 'phase_native_frame' "Phase $($Expected.name) native Y slot is $($Event.nativeYSlot), expected 9B24" '9B24' ([string]$Event.nativeYSlot) }
    if ($stage -eq 'afterCc') {
        $ccEvent = $PhaseByName['native-prologue-save-mask']
        if ($null -eq $ccEvent -or [string]::IsNullOrWhiteSpace([string]$ccEvent.ccSaved49D0)) { Add-Failure $Failures 'phase_native_frame' 'native-prologue-save-mask did not record ccSaved49D0' '' '' }
        elseif ([string]::IsNullOrWhiteSpace([string]$Event.nativeSavedCc)) { Add-Failure $Failures 'phase_native_frame' 'native-prologue-deepest did not record nativeSavedCc' '' '' }
        elseif ([string]$Event.nativeSavedCc -ine [string]$ccEvent.ccSaved49D0) { Add-Failure $Failures 'phase_native_frame' "Native CC byte $($Event.nativeSavedCc) differs from the 49D0 saved CC $($ccEvent.ccSaved49D0)" ([string]$ccEvent.ccSaved49D0) ([string]$Event.nativeSavedCc) }
    }
}

function Test-PhaseRecords {
    param($Run,$Records,$ExpectedPhases,$Failures)
    $phaseEvents = @($Records | Where-Object { [string]$_.event -eq 'phase' })
    if ($phaseEvents.Count -ne 43) { Add-Failure $Failures 'phase_count' "Observed $($phaseEvents.Count) phase records, expected 43" '43' ([string]$phaseEvents.Count); return }
    $phaseByName = @{}
    foreach ($pe in $phaseEvents) { $phaseByName[[string]$pe.phase] = $pe }
    $stopById = @{}
    foreach ($stop in @($Records | Where-Object { [string]$_.event -eq 'physical_stop' })) { $stopById[[string]$stop.stopId] = $stop }
    for ($i = 0; $i -lt 43; $i++) {
        $e = $phaseEvents[$i]
        $x = $ExpectedPhases[$i]
        if ([string]$e.phase -ne $x.name) { Add-Failure $Failures 'phase_order' "Phase $i is $($e.phase), expected $($x.name)" $x.name ([string]$e.phase); return }
        if ([int]$e.phaseIndex -ne $i) { Add-Failure $Failures 'phase_order' "Phase $($x.name) index is $($e.phaseIndex)" ([string]$i) ([string]$e.phaseIndex) }
        if (-not $stopById.ContainsKey([string]$e.stopId)) { Add-Failure $Failures 'physical_binding' "Phase $($x.name) stopId $($e.stopId) has no physical_stop record" '' '' }
        else {
            $stop = $stopById[[string]$e.stopId]
            if ([string]$stop.pc -ine ([string]$e.pc)) { Add-Failure $Failures 'physical_binding' "Phase $($x.name) stop PC differs from its physical stop" ([string]$e.pc) ([string]$stop.pc) }
            if ([string]$stop.emulatedTime -ne [string]$e.emulatedTime) { Add-Failure $Failures 'physical_binding' "Phase $($x.name) stop time differs from its physical stop" ([string]$stop.emulatedTime) ([string]$e.emulatedTime) }
        }
        if ((ConvertTo-HexInt ([string]$e.pc)) -ne $x.pc) { Add-Failure $Failures 'phase_pc' "Phase $($x.name) PC is $($e.pc), expected $(Format-Hex16 $x.pc)" (Format-Hex16 $x.pc) ([string]$e.pc) }
        if ($x.name -eq 'native-prologue-save-regs' -and (ConvertTo-HexInt ([string]$e.pc)) -ne 0x49C7) { Add-Failure $Failures 'phase_mid_instruction' 'native-prologue-save-regs is not 49C7' '49C7' ([string]$e.pc) }
        if ($x.name -eq 'native-prologue-save-mask' -and (ConvertTo-HexInt ([string]$e.pc)) -ne 0x49D0) { Add-Failure $Failures 'phase_mid_instruction' 'native-prologue-save-mask is not 49D0' '49D0' ([string]$e.pc) }
        if ($x.name -eq 'native-prologue-deepest' -and (ConvertTo-HexInt ([string]$e.pc)) -ne 0x49D2) { Add-Failure $Failures 'phase_mid_instruction' 'native-prologue-deepest is not 49D2' '49D2' ([string]$e.pc) }
        if ($x.name -in @('native-prologue-save-mask') -and (ConvertTo-HexInt ([string]$e.pc)) -in @(0x49CF,0x49D1)) { Add-Failure $Failures 'phase_mid_instruction' "Phase $($x.name) stopped mid-instruction" '49D0' ([string]$e.pc) }
        if ((ConvertTo-HexInt ([string]$e.y)) -ne $x.y) { Add-Failure $Failures 'phase_field' "Phase $($x.name) Y is $($e.y), expected $(Format-Hex16 $x.y)" (Format-Hex16 $x.y) ([string]$e.y) }
        if ($x.requireX) {
            if ((ConvertTo-HexInt ([string]$e.x)) -ne $x.x) { Add-Failure $Failures 'phase_x' "Phase $($x.name) X is $($e.x), expected $(Format-Hex16 $x.x)" (Format-Hex16 $x.x) ([string]$e.x) }
        }
        if ((ConvertTo-HexInt ([string]$e.u)) -ne $x.u) { Add-Failure $Failures 'phase_u' "Phase $($x.name) U is $($e.u), expected $(Format-Hex16 $x.u)" (Format-Hex16 $x.u) ([string]$e.u) }
        if ((ConvertTo-HexInt ([string]$e.s)) -ne $x.s) { Add-Failure $Failures 'phase_s' "Phase $($x.name) S is $($e.s), expected $(Format-Hex16 $x.s)" (Format-Hex16 $x.s) ([string]$e.s) }
        if ((ConvertTo-HexInt ([string]$e.token)) -ne $x.liveToken) { Add-Failure $Failures 'phase_token' "Phase $($x.name) token is $($e.token), expected $(Format-Hex16 $x.liveToken)" (Format-Hex16 $x.liveToken) ([string]$e.token) }
        if ((ConvertTo-HexInt ([string]$e.tokenAddress)) -ne $x.tokenAddress) { Add-Failure $Failures 'phase_token' "Phase $($x.name) token address is wrong" (Format-Hex16 $x.tokenAddress) ([string]$e.tokenAddress) }
        if ($x.operandWidth -gt 0) {
            if ((ConvertTo-HexInt ([string]$e.operand)) -ne $x.operandValue) { Add-Failure $Failures 'phase_operand' "Phase $($x.name) operand is $($e.operand), expected $($x.operandText)" $x.operandText ([string]$e.operand) }
            if ((ConvertTo-HexInt ([string]$e.operandAddress)) -ne $x.operandAddress) { Add-Failure $Failures 'phase_operand' "Phase $($x.name) operand address is wrong" (Format-Hex16 $x.operandAddress) ([string]$e.operandAddress) }
        }
        if ($null -ne $x.controlTop) {
            if ((ConvertTo-HexInt ([string]$e.controlStack0)) -ne $x.controlTop) { Add-Failure $Failures 'phase_cursor' "Phase $($x.name) control top is $($e.controlStack0), expected $(Format-Hex16 $x.controlTop)" (Format-Hex16 $x.controlTop) ([string]$e.controlStack0) }
        }
        Test-NativeFrameRecord -Event $e -Expected $x -PhaseByName $phaseByName -Failures $Failures
        if ($x.name -eq 'header-trampoline-entry' -and
            ((ConvertTo-HexInt ([string]$e.savedCursor)) -ne (ConvertTo-HexInt ([string]$e.y)))) {
            Add-Failure $Failures 'phase_saved_cursor' 'Before PSHS Y the pending cursor must be in Y, not on S' '' ''
        }
        if ($null -ne $x.savedCursor) {
            if ([string]$e.savedCursorOffset -ne [string]$x.savedCursorOffset) { Add-Failure $Failures 'phase_saved_cursor' "Phase $($x.name) saved-cursor offset is $($e.savedCursorOffset), expected $($x.savedCursorOffset)" ([string]$x.savedCursorOffset) ([string]$e.savedCursorOffset) }
            if ([string]$e.savedCursorRole -ine [string]$x.savedCursorRole) { Add-Failure $Failures 'phase_saved_cursor' "Phase $($x.name) saved-cursor role is $($e.savedCursorRole), expected $($x.savedCursorRole)" ([string]$x.savedCursorRole) ([string]$e.savedCursorRole) }
            if ((ConvertTo-HexInt ([string]$e.savedCursor)) -ne $x.savedCursor) { Add-Failure $Failures 'phase_saved_cursor' "Phase $($x.name) saved cursor is $($e.savedCursor), expected $(Format-Hex16 $x.savedCursor)" (Format-Hex16 $x.savedCursor) ([string]$e.savedCursor) }
        }
        if ([string]$e.dpAvailable -ne 'true' -or [string]$e.dp -ne '00') { Add-Failure $Failures 'phase_dp' "Phase $($x.name) DP is not the live normalized 00" '00' ([string]$e.dp) }
        if ([string]$e.dpRaw -notmatch '^\d+$') { Add-Failure $Failures 'phase_dp' "Phase $($x.name) DP raw value is missing" '' ([string]$e.dpRaw) }
        $a = ConvertTo-HexInt ([string]$e.a); $b = ConvertTo-HexInt ([string]$e.b); $d = ConvertTo-HexInt ([string]$e.d)
        if ($d -ne ((($a -band 0xFF) -shl 8) -bor ($b -band 0xFF))) { Add-Failure $Failures 'phase_field' "Phase $($x.name) D is not the live A/B pair" '' '' }
        if ($x.name -in @('shared-after-rotate','shared-after-swap') -and (ConvertTo-HexInt ([string]$e.x)) -ne 0x008F) { Add-Failure $Failures 'phase_x' "Phase $($x.name) X is not 008F after ROT/SWAP" '008F' ([string]$e.x) }
        if ($x.name -in @('shared-return-handler','outer-return-handler') -and (ConvertTo-HexInt ([string]$e.x)) -ne 0x7931) { Add-Failure $Failures 'phase_x' "Phase $($x.name) return X is not 7931" '7931' ([string]$e.x) }
        if ($x.name -eq 'caller-dispatch' -and (ConvertTo-HexInt ([string]$e.dataStack0)) -ne 0x0000) { Add-Failure $Failures 'result_successor' 'Caller result top is not 0000' '0000' ([string]$e.dataStack0) }
        if ($x.name -eq 'outer-returned-to-9F16') {
            if ((ConvertTo-HexInt ([string]$e.dataStack0)) -ne 0x0000) { Add-Failure $Failures 'result_successor' 'Final data top is not 0000' '0000' ([string]$e.dataStack0) }
            if ([string]$e.successorWord -ine '75A9') { Add-Failure $Failures 'result_successor' 'Final successor word is not 75A9' '75A9' ([string]$e.successorWord) }
        }
        if ($x.name -eq 'native-prologue-save-mask') {
            if ([string]::IsNullOrWhiteSpace([string]$e.ccSaved49D0)) { Add-Failure $Failures 'phase_cc' '49D0 did not record its saved CC' '' '' }
        }
        if ($x.name -eq 'native-epilogue-puls-cc') {
            if ([string]$e.ccRestored -ine [string]$e.ccSaved49D0) { Add-Failure $Failures 'phase_cc' "49E2 CC $($e.ccRestored) does not equal the 49D0 saved CC $($e.ccSaved49D0)" ([string]$e.ccSaved49D0) ([string]$e.ccRestored) }
            if ([string]::IsNullOrWhiteSpace([string]$e.nativeMask)) { Add-Failure $Failures 'phase_column' '49E2 did not record the ROM-derived native mask' '' '' }
            elseif ([string]$e.savedMask -ne [string]$e.nativeMask) { Add-Failure $Failures 'phase_column' "Saved mask is $($e.savedMask), expected the ROM-derived native mask $($e.nativeMask)" ([string]$e.nativeMask) ([string]$e.savedMask) }
            if ([string]$e.nativeMask -ne '01') { Add-Failure $Failures 'phase_column' "ROM-derived native mask is $($e.nativeMask), expected 01 for this pattern" '01' ([string]$e.nativeMask) }
            if ([int]$e.column -ne 15) { Add-Failure $Failures 'phase_column' "Response-derived column is $($e.column), expected 15" '15' ([string]$e.column) }
            if ([string]::IsNullOrWhiteSpace([string]$e.response0803)) { Add-Failure $Failures 'phase_column' 'Response byte is missing' '' '' }
            if ([string]::IsNullOrWhiteSpace([string]$e.savedLogicalIndex)) { Add-Failure $Failures 'phase_column' 'Saved logical index is missing' '' '' }
            if (-not [string]::IsNullOrWhiteSpace([string]$e.response0803) -and -not [string]::IsNullOrWhiteSpace([string]$e.savedLogicalIndex)) {
                $recomputed = (((ConvertTo-HexInt ([string]$e.response0803)) -bxor (ConvertTo-HexInt ([string]$e.savedLogicalIndex))) -band 0x78) -shr 3
                if ($recomputed -ne [int]$e.column) { Add-Failure $Failures 'phase_column' "Reported column $($e.column) is not the live response XOR saved index derivation $recomputed" ([string]$recomputed) ([string]$e.column) }
            }
        }
    }
}

function Test-BoundaryRecords {
    param($Records,$ExpectedPhases,$Failures)
    $boundaryEvents = @($Records | Where-Object { [string]$_.event -eq 'boundary' })
    $skipped = @($Records | Where-Object { [string]$_.event -eq 'boundary_skipped' })
    $byId = @{}
    foreach ($e in $boundaryEvents) { $byId[[string]$e.boundary] = $e }
    $phaseByName = @{}
    foreach ($p in $ExpectedPhases) { $phaseByName[$p.name] = $p }
    $phaseEventByName = @{}
    foreach ($p in @($Records | Where-Object { [string]$_.event -eq 'phase' })) { $phaseEventByName[[string]$p.phase] = $p }
    $stopById = @{}
    foreach ($stop in @($Records | Where-Object { [string]$_.event -eq 'physical_stop' })) { $stopById[[string]$stop.stopId] = $stop }
    $boundaryContract = @{}
    foreach ($bc in @(Get-ExpectedBoundaries)) { $boundaryContract[[string]$bc.id] = $bc }
    $setRead = $byId['port-f1-set-read']
    $clearPhase = @($Records | Where-Object { [string]$_.event -eq 'phase' -and [string]$_.phase -eq 'bridge-restores-y' })[0]
    if ($null -eq $setRead) { Add-Failure $Failures 'boundary_missing' 'port-f1-set-read (7793) is missing' '' '' }
    if ($null -eq $clearPhase) { Add-Failure $Failures 'boundary_missing' 'bridge-restores-y (7780) phase is missing for the clear branch' '' '' }
    $f1Set = if ($null -ne $setRead) { ConvertTo-HexInt ([string]$setRead.f1AtSetRead) } else { $null }
    $f1Clear = if ($null -ne $clearPhase) { ConvertTo-HexInt ([string]$clearPhase.f1AtClearRead) } else { $null }
    $skippedIds = @{}
    foreach ($s in $skipped) { $skippedIds[[string]$s.boundary] = $s }
    foreach ($id in @('port-f1-set-write','port-080c-set-write','port-f1-clear-write','port-080c-clear-write')) {
        $present = $byId.ContainsKey($id)
        $skippedHere = $skippedIds.ContainsKey($id)
        if ($present -and $skippedHere) { Add-Failure $Failures 'branch_coverage' "$id is both recorded and skipped" '' '' }
        if (-not $present -and -not $skippedHere) { Add-Failure $Failures 'branch_coverage' "$id is neither recorded nor explicitly skipped" '' '' }
        if ($skippedHere) {
            $expectSkip = if ($id -like '*-set-write') { ($null -ne $f1Set -and $f1Set -eq 0) } else { ($null -ne $f1Clear -and $f1Clear -eq 0) }
            if (-not $expectSkip) { Add-Failure $Failures 'branch_coverage' "$id was skipped although the measured whole 00F1 byte was non-zero" 'recorded' 'skipped' }
        }
    }
    if ($null -ne $setRead) {
        $expectedZero = ($f1Set -eq 0)
        if ([string]$setRead.setBranchByteZero -ne [string]$expectedZero.ToString().ToLowerInvariant()) { Add-Failure $Failures 'branch_bit0' "7793 branch classification $($setRead.setBranchByteZero) does not use the entire byte F1=$($setRead.f1AtSetRead)" ([string]$expectedZero) ([string]$setRead.setBranchByteZero) }
        if ([string]$setRead.branchTaken -ne [string]$expectedZero.ToString().ToLowerInvariant()) { Add-Failure $Failures 'branch_bit0' '7793 branchTaken does not match the entire-byte BEQ' ([string]$expectedZero) ([string]$setRead.branchTaken) }
    }
    if ($null -ne $clearPhase) {
        $expectedZero = ($f1Clear -eq 0)
        if ([string]$clearPhase.clearBranchByteZero -ne [string]$expectedZero.ToString().ToLowerInvariant()) { Add-Failure $Failures 'branch_bit0' "7780 branch classification $($clearPhase.clearBranchByteZero) does not use the entire byte F1=$($clearPhase.f1AtClearRead)" ([string]$expectedZero) ([string]$clearPhase.clearBranchByteZero) }
    }
    $setPathExpected = ($null -ne $f1Set -and $f1Set -ne 0)
    $clearPathExpected = ($null -ne $f1Clear -and $f1Clear -ne 0)
    foreach ($id in @('port-f1-set-write','port-080c-set-write')) {
        if ($setPathExpected -and -not $byId.ContainsKey($id)) { Add-Failure $Failures 'branch_coverage' "$id is required when the measured 00F1 byte is non-zero at 7793" '' '' }
        if (-not $setPathExpected -and $byId.ContainsKey($id)) { Add-Failure $Failures 'branch_coverage' "$id is present although the measured 00F1 byte is zero at 7793" '' '' }
    }
    foreach ($id in @('port-f1-clear-write','port-080c-clear-write')) {
        if ($clearPathExpected -and -not $byId.ContainsKey($id)) { Add-Failure $Failures 'branch_coverage' "$id is required when the measured 00F1 byte is non-zero at 7780" '' '' }
        if (-not $clearPathExpected -and $byId.ContainsKey($id)) { Add-Failure $Failures 'branch_coverage' "$id is present although the measured 00F1 byte is zero at 7780" '' '' }
    }
    $always = @('port-orcc50','port-sta-0801','port-stb-0802','port-ldb-0803-preread','port-pulscc-pre','frame-write-010f','frame-write-011f','frame-write-012f','frame-write-013f','port-f1-set-read')
    foreach ($id in $always) {
        if (-not $byId.ContainsKey($id)) { Add-Failure $Failures 'boundary_missing' "$id is missing" '' '' }
    }
    foreach ($e in $boundaryEvents) {
        if ($script:BoundaryIds -notcontains [string]$e.boundary) { Add-Failure $Failures 'boundary_extra' "Unknown boundary $($e.boundary)" '' '' }
        if (-not $stopById.ContainsKey([string]$e.stopId)) { Add-Failure $Failures 'physical_binding' "Boundary $($e.boundary) stopId $($e.stopId) has no physical_stop record" '' '' }
        else {
            $stop = $stopById[[string]$e.stopId]
            if ([string]$stop.pc -ine ([string]$e.pc)) { Add-Failure $Failures 'physical_binding' "Boundary $($e.boundary) stop PC differs from its physical stop" ([string]$e.pc) ([string]$stop.pc) }
            if ([string]$stop.emulatedTime -ne [string]$e.emulatedTime) { Add-Failure $Failures 'physical_binding' "Boundary $($e.boundary) stop time differs from its physical stop" ([string]$stop.emulatedTime) ([string]$e.emulatedTime) }
        }
        if ([string]$e.dpAvailable -ne 'true' -or [string]$e.dp -ne '00') { Add-Failure $Failures 'phase_dp' "Boundary $($e.boundary) DP is not 00" '00' ([string]$e.dp) }
        $bc = $boundaryContract[[string]$e.boundary]
        if ($null -ne $bc) {
            if ([string]$e.y -ne '9B24') { Add-Failure $Failures 'phase_field' "Boundary $($e.boundary) Y is $($e.y), expected 9B24" '9B24' ([string]$e.y) }
            if ((ConvertTo-HexInt ([string]$e.u)) -ne [int]$bc.u) { Add-Failure $Failures 'phase_u' "Boundary $($e.boundary) U is $($e.u), expected $(Format-Hex16 $bc.u)" (Format-Hex16 $bc.u) ([string]$e.u) }
            if ((ConvertTo-HexInt ([string]$e.s)) -ne [int]$bc.s) { Add-Failure $Failures 'phase_s' "Boundary $($e.boundary) S is $($e.s), expected $(Format-Hex16 $bc.s)" (Format-Hex16 $bc.s) ([string]$e.s) }
        }
        $entryEvent = $phaseEventByName['native-prologue-save-regs']
        $ccEvent = $phaseEventByName['native-prologue-save-mask']
        if ($null -ne $entryEvent -and $null -ne $ccEvent) {
            $nativeMask = $entryEvent.nativeMask
            $entryA = $entryEvent.nativeEntryA
            $ccSaved = $ccEvent.ccSaved49D0
            if (-not [string]::IsNullOrWhiteSpace([string]$nativeMask) -and -not [string]::IsNullOrWhiteSpace([string]$entryA) -and -not [string]::IsNullOrWhiteSpace([string]$ccSaved)) {
                if ([string]$e.boundary -in @('port-orcc50','port-sta-0801','port-stb-0802','port-ldb-0803-preread','port-pulscc-pre')) {
                    $expectedNativeTop = (([Convert]::ToInt32([string]$ccSaved,16) -shl 8) -bor [Convert]::ToInt32([string]$nativeMask,16)) -band 0xFFFF
                    if ((ConvertTo-HexInt ([string]$e.controlStack0)) -ne $expectedNativeTop) { Add-Failure $Failures 'phase_native_frame' "Boundary $($e.boundary) w@S is $($e.controlStack0), expected $(Format-Hex16 $expectedNativeTop) from the native CC/mask frame" (Format-Hex16 $expectedNativeTop) ([string]$e.controlStack0) }
                }
                elseif ([string]$e.kind -eq 'frame_write') {
                    $expectedNativeTop = (([Convert]::ToInt32([string]$nativeMask,16) -shl 8) -bor [Convert]::ToInt32([string]$entryA,16)) -band 0xFFFF
                    if ((ConvertTo-HexInt ([string]$e.controlStack0)) -ne $expectedNativeTop) { Add-Failure $Failures 'phase_native_frame' "Boundary $($e.boundary) w@S is $($e.controlStack0), expected $(Format-Hex16 $expectedNativeTop) from the native mask/entry-A frame" (Format-Hex16 $expectedNativeTop) ([string]$e.controlStack0) }
                }
            }
        }
    }
    if ($byId.ContainsKey('port-sta-0801') -and (([Convert]::ToInt32([string]$byId['port-sta-0801'].cc,16) -band 0x50) -ne 0x50)) { Add-Failure $Failures 'phase_cc' '49D7 CC does not carry I/F mask bits' '' ([string]$byId['port-sta-0801'].cc) }
    if ($byId.ContainsKey('port-stb-0802') -and (([Convert]::ToInt32([string]$byId['port-stb-0802'].cc,16) -band 0x50) -ne 0x50)) { Add-Failure $Failures 'phase_cc' '49DA CC does not have I=1,F=1' 'I=1,F=1' ([string]$byId['port-stb-0802'].cc) }
    if ($byId.ContainsKey('port-ldb-0803-preread') -and (([Convert]::ToInt32([string]$byId['port-ldb-0803-preread'].cc,16) -band 0x50) -ne 0x50)) { Add-Failure $Failures 'phase_cc' '49DD CC does not have I=1,F=1' 'I=1,F=1' ([string]$byId['port-ldb-0803-preread'].cc) }
    if ($byId.ContainsKey('port-pulscc-pre')) {
        if (([Convert]::ToInt32([string]$byId['port-pulscc-pre'].cc,16) -band 0x50) -ne 0x50) { Add-Failure $Failures 'phase_cc' '49E0 CC does not have I=1,F=1 before PULS CC' 'I=1,F=1' ([string]$byId['port-pulscc-pre'].cc) }
        if ([string]::IsNullOrWhiteSpace([string]$byId['port-pulscc-pre'].response0803)) { Add-Failure $Failures 'phase_column' '49E0 did not record the actual post-LDB B response' '' '' }
    }
    if ($byId.ContainsKey('port-f1-set-write')) {
        $expectedA = ($f1Set -bor 0x01) -band 0xFF
        if ((ConvertTo-HexInt ([string]$byId['port-f1-set-write'].preWriteA)) -ne $expectedA) { Add-Failure $Failures 'boundary_value' '7799 A is not measured F1 OR 01' (Format-Hex8 $expectedA) ([string]$byId['port-f1-set-write'].preWriteA) }
    }
    if ($byId.ContainsKey('port-080c-set-write')) {
        $expectedA = ($f1Set -bor 0x01) -band 0xFF
        if ((ConvertTo-HexInt ([string]$byId['port-080c-set-write'].preWriteA)) -ne $expectedA) { Add-Failure $Failures 'boundary_value' '779B A is not measured F1 OR 01' (Format-Hex8 $expectedA) ([string]$byId['port-080c-set-write'].preWriteA) }
        if ((ConvertTo-HexInt ([string]$byId['port-080c-set-write'].f1AfterSetWrite)) -ne $expectedA) { Add-Failure $Failures 'boundary_value' '00F1 after the set write is not the written value' (Format-Hex8 $expectedA) ([string]$byId['port-080c-set-write'].f1AfterSetWrite) }
    }
    if ($byId.ContainsKey('port-f1-clear-write')) {
        $expectedA = $f1Clear -band 0xFE
        if ((ConvertTo-HexInt ([string]$byId['port-f1-clear-write'].preWriteA)) -ne $expectedA) { Add-Failure $Failures 'boundary_value' '7786 A is not measured F1 AND FE' (Format-Hex8 $expectedA) ([string]$byId['port-f1-clear-write'].preWriteA) }
    }
    if ($byId.ContainsKey('port-080c-clear-write')) {
        $expectedA = $f1Clear -band 0xFE
        if ((ConvertTo-HexInt ([string]$byId['port-080c-clear-write'].preWriteA)) -ne $expectedA) { Add-Failure $Failures 'boundary_value' '7788 A is not measured F1 AND FE' (Format-Hex8 $expectedA) ([string]$byId['port-080c-clear-write'].preWriteA) }
        if ((ConvertTo-HexInt ([string]$byId['port-080c-clear-write'].f1AfterClearWrite)) -ne $expectedA) { Add-Failure $Failures 'boundary_value' '00F1 after the clear write is not the written value' (Format-Hex8 $expectedA) ([string]$byId['port-080c-clear-write'].f1AfterClearWrite) }
    }
    foreach ($id in @('frame-write-010f','frame-write-011f','frame-write-012f','frame-write-013f')) {
        if (-not $byId.ContainsKey($id)) { continue }
        $e = $byId[$id]
        $offset = @{'frame-write-010f'=0x00;'frame-write-011f'=0x10;'frame-write-012f'=0x20;'frame-write-013f'=0x30}[$id]
        $expectedTarget = (0x010F + $offset) -band 0xFFFF
        if ((ConvertTo-HexInt ([string]$e.target)) -ne $expectedTarget) { Add-Failure $Failures 'frame_target' "$id target is $($e.target), expected $(Format-Hex16 $expectedTarget)" (Format-Hex16 $expectedTarget) ([string]$e.target) }
        if ([string]$e.mask -ne '01') { Add-Failure $Failures 'frame_write' "$id mask is $($e.mask), expected 01" '01' ([string]$e.mask) }
        $pre = ConvertTo-HexInt ([string]$e.preValue); $mask = ConvertTo-HexInt ([string]$e.mask); $b = ConvertTo-HexInt ([string]$e.preWriteB)
        if ($b -ne (($pre -bor $mask) -band 0xFF)) { Add-Failure $Failures 'frame_write' "$id B is not measured pre-value OR mask" (Format-Hex8 (($pre -bor $mask) -band 0xFF)) ([string]$e.preWriteB) }
        if ((ConvertTo-HexInt ([string]$e.expectedB)) -ne $b) { Add-Failure $Failures 'frame_write' "$id expectedB field is inconsistent" ([string]$e.preWriteB) ([string]$e.expectedB) }
        if ([string]$e.alreadySet -eq 'true' -and [string]$e.visibleTransition -ne 'false') { Add-Failure $Failures 'frame_write' "$id already-on write wrongly claims a visible transition" 'visibleTransition=false' ([string]$e.visibleTransition) }
        if ([string]$e.alreadySet -eq 'false' -and [string]$e.visibleTransition -ne 'true') { Add-Failure $Failures 'frame_write' "$id clear-to-set write did not record a visible transition" 'visibleTransition=true' ([string]$e.visibleTransition) }
    }
}

function Test-FrameEffect {
    param($Records,$Failures)
    $phaseEvents = @($Records | Where-Object { [string]$_.event -eq 'phase' })
    $before = @($phaseEvents | Where-Object { [string]$_.phase -eq 'bridge-jsr-entry' })[0]
    $finalNative = @($phaseEvents | Where-Object { [string]$_.phase -eq 'native-epilogue-puls-a' })[0]
    $after = @($phaseEvents | Where-Object { [string]$_.phase -eq 'native-return' })[0]
    if ($null -eq $before -or $null -eq $finalNative -or $null -eq $after) { Add-Failure $Failures 'frame_missing' 'Frame-bank snapshots are missing' '' ''; return }
    function Parse-Bytes([string]$Text) {
        if ([string]::IsNullOrWhiteSpace($Text)) { throw 'Frame snapshot text is empty' }
        $parts = @($Text.Trim() -split '\s+')
        $out = New-Object 'System.Collections.Generic.List[int]'
        foreach ($p in $parts) { $out.Add([Convert]::ToInt32($p,16)) }
        return $out.ToArray()
    }
    try {
        $b = Parse-Bytes ([string]$before.frameBefore)
        $f = Parse-Bytes ([string]$finalNative.frameFinalNative)
        $a = Parse-Bytes ([string]$after.frameAfter)
    }
    catch { Add-Failure $Failures 'frame_missing' "Frame snapshot parse failed: $($_.Exception.Message)" '' ''; return }
    if ($b.Count -ne 64 -or $f.Count -ne 64 -or $a.Count -ne 64) { Add-Failure $Failures 'frame_missing' 'A frame snapshot is not 64 bytes' '64' "$($b.Count)/$($f.Count)/$($a.Count)"; return }
    for ($i = 0; $i -lt 64; $i++) {
        if ($f[$i] -ne $a[$i]) { Add-Failure $Failures 'frame_delta' "frameFinalNative and frameAfter differ at $(Format-Hex16 (0x0100 + $i))" '' ''; break }
    }
    $boundaryEvents = @($Records | Where-Object { [string]$_.event -eq 'boundary' -and [string]$_.kind -eq 'frame_write' })
    $targets = @{}
    foreach ($e in $boundaryEvents) {
        $target = ConvertTo-HexInt ([string]$e.target)
        $pre = ConvertTo-HexInt ([string]$e.preValue)
        $mask = ConvertTo-HexInt ([string]$e.mask)
        $targets[$target] = [ordered]@{ pre=$pre; mask=$mask; expected=(($pre -bor $mask) -band 0xFF); id=[string]$e.boundary }
    }
    foreach ($target in @(0x010F,0x011F,0x012F,0x013F)) {
        if (-not $targets.ContainsKey($target)) { Add-Failure $Failures 'frame_missing' "No per-write boundary for $(Format-Hex16 $target)" '' ''; continue }
        $index = $target - 0x0100
        $expected = ($b[$index] -bor $targets[$target].mask) -band 0xFF
        if ($a[$index] -ne $expected) { Add-Failure $Failures 'frame_delta' "After byte at $(Format-Hex16 $target) is $($a[$index]), expected $(Format-Hex8 $expected)" (Format-Hex8 $expected) (Format-Hex8 $a[$index]) }
    }
    for ($i = 0; $i -lt 64; $i++) {
        $address = 0x0100 + $i
        if ($targets.ContainsKey($address)) { continue }
        if ($a[$i] -ne $b[$i]) { Add-Failure $Failures 'frame_delta' "Unrelated frame byte $(Format-Hex16 $address) changed $($b[$i]) -> $($a[$i]); clean attribution fails" (Format-Hex8 $b[$i]) (Format-Hex8 $a[$i]) }
    }
}

function Test-InputAndStopInventory {
    param($Run,$Records,$Failures)
    $physical = @($Records | Where-Object { [string]$_.event -eq 'physical_stop' })
    if ($physical.Count -eq 0) { Add-Failure $Failures 'physical_stop' 'No physical_stop records were emitted' '' ''; return }
    $seen = @{}
    $lastTime = -1.0
    foreach ($stop in $physical) {
        $id = [string]$stop.stopId
        if ($seen.ContainsKey($id)) { Add-Failure $Failures 'physical_duplicate' "Duplicate physical stop id $id" '' '' }
        $seen[$id] = $true
        $time = [double]::Parse([string]$stop.emulatedTime,[Globalization.CultureInfo]::InvariantCulture)
        if ($time -le $lastTime) { Add-Failure $Failures 'physical_stop' "Physical stop times are not strictly increasing at $id" '' '' }
        $lastTime = $time
        if ([string]::IsNullOrWhiteSpace([string]$stop.matched)) { Add-Failure $Failures 'physical_stop' "Physical stop $id has no matched logical record" '' '' }
    }
    $logicalStopIds = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($e in @($Records | Where-Object { [string]$_.event -in @('phase','boundary') })) {
        [void]$logicalStopIds.Add([string]$e.stopId)
    }
    foreach ($id in $logicalStopIds) { if (-not $seen.ContainsKey($id)) { Add-Failure $Failures 'physical_binding' "Logical record binds missing stop $id" '' '' } }
    foreach ($id in $seen.Keys) { if (-not $logicalStopIds.Contains($id)) { Add-Failure $Failures 'physical_stop' "Physical stop $id has no phase or boundary binding" '' '' } }
    if ($logicalStopIds.Count -ne $physical.Count) { Add-Failure $Failures 'physical_stop' "Physical stop count $($physical.Count) differs from logical stop-id count $($logicalStopIds.Count)" '' '' }

    try { $rows = @(Get-InputRows $Run) } catch { Add-Failure $Failures 'input_malformed' $_.Exception.Message '' ''; return }
    if ($rows.Count -lt 2) { Add-Failure $Failures 'input_malformed' 'input-levels.csv has too few rows' '' ''; return }
    for ($i = 1; $i -lt $rows.Count; $i++) {
        if ($rows[$i].frame -le $rows[$i-1].frame) { Add-Failure $Failures 'input_malformed' "Input frame counter is not strictly increasing at $($rows[$i].frame)" '' ''; return }
        if ($rows[$i].time -le $rows[$i-1].time) { Add-Failure $Failures 'input_malformed' "Input time is not strictly increasing at frame $($rows[$i].frame)" '' ''; return }
    }
    $framePeriod = 1.0 / 60.0
    $tolerance = $framePeriod / 8.0
    $origin = $rows[0].time
    foreach ($row in $rows) {
        $index = [int][Math]::Floor((($row.time - $origin) / $framePeriod) + 0.5)
        $grid = $origin + ($index * $framePeriod)
        $row['derivedIndex'] = $index
        $row['gridError'] = $row.time - $grid
        $row['classification'] = if ([Math]::Abs($row.time - $grid) -le $tolerance) { 'real_60hz' } else { 'off_grid' }
    }
    $coinRows = @($rows | Where-Object { $_.aux2 -ne 0 -or $_.coinOverride -ne 0 })
    $coinFrames = @($coinRows | ForEach-Object { $_.frame })
    if (($coinFrames -join ',') -ne ($script:ExpectedCoinFrames -join ',')) { Add-Failure $Failures 'input_coin' "Coin frames are '$($coinFrames -join ',')', expected 2100,2101,2102,2103" '' '' }
    foreach ($row in $coinRows) { if ($row.classification -ne 'real_60hz') { Add-Failure $Failures 'input_coin' "Coin frame $($row.frame) is off the real 60 Hz grid" '' '' } }
    $startRows = @($rows | Where-Object { $_.black2 -ne 0 })
    $realStart = @($startRows | Where-Object { $_.classification -eq 'real_60hz' })
    $offGridStart = @($startRows | Where-Object { $_.classification -ne 'real_60hz' })
    if ($realStart.Count -lt 4) { Add-Failure $Failures 'input_start' "Only $($realStart.Count) real start rows were recorded" '4' ([string]$realStart.Count) }
    else {
        for ($i = 0; $i -lt 4; $i++) { if ($realStart[$i].frame -ne $script:RequiredStartFrames[$i]) { Add-Failure $Failures 'input_start' "Real start prefix is not 2221,2222,2223,2224" '' ''; break } }
    }
    if ($offGridStart.Count -gt 0) {
        $lastReal = if ($realStart.Count -gt 0) { $realStart[$realStart.Count - 1].frame } else { 0 }
        $stopTimes = @($physical | ForEach-Object { [double]::Parse([string]$_.emulatedTime,[Globalization.CultureInfo]::InvariantCulture) })
        if ($offGridStart.Count -ne $physical.Count) { Add-Failure $Failures 'logical_physical_count' "Off-grid start-active rows $($offGridStart.Count) do not equal deduplicated physical stops $($physical.Count)" ([string]$physical.Count) ([string]$offGridStart.Count) }
        $gaps = New-Object 'System.Collections.Generic.List[double]'
        for ($i = 1; $i -lt $stopTimes.Count; $i++) { $gaps.Add($stopTimes[$i] - $stopTimes[$i-1]) }
        $minGap = if ($gaps.Count -gt 0) { ($gaps | Measure-Object -Minimum).Minimum } else { 0.00001 }
        $matchTolerance = [Math]::Min(0.000001, ($minGap / 4.0))
        if ($matchTolerance -le 0) { $matchTolerance = 0.0000001 }
        for ($i = 0; $i -lt $offGridStart.Count; $i++) {
            if ($offGridStart[$i].frame -ne ($lastReal + 1 + $i)) { Add-Failure $Failures 'input_extra' "Off-grid start row $($offGridStart[$i].frame) is not contiguous with the real prefix" '' ''; break }
            if ($i -ge $stopTimes.Count) { Add-Failure $Failures 'logical_physical_count' 'More off-grid rows than physical stops' '' ''; break }
            if ([Math]::Abs($offGridStart[$i].time - $stopTimes[$i]) -gt $matchTolerance) { Add-Failure $Failures 'input_extra' "Off-grid row $($offGridStart[$i].frame) does not match ordered physical stop $i" '' ''; break }
        }
    }
    $last = $rows[$rows.Count - 1]
    if ($last.frame -ge 2400) { Add-Failure $Failures 'input_extra' "Input extended to frame $($last.frame), beyond the first complete call window" '' '' }
}

function Add-OrderedPlanFailures {
    param($Run,$ExpectedPhases,$ExpectedBoundaries,$Failures)
    $planPath = Join-Path $Run 'lamp-natural-plan.json'
    if (!(Test-Path -LiteralPath $planPath -PathType Leaf)) { Add-Failure $Failures 'plan_stage' 'Ordered plan JSON is missing' '' ''; return }
    try { $plan = Read-JsonFile $planPath } catch { Add-Failure $Failures 'plan_stage' "Ordered plan JSON is invalid: $($_.Exception.Message)" '' ''; return }
    $derived = @(Get-OrderedStagePlan $ExpectedPhases $ExpectedBoundaries)
    $stages = @($plan.stages)
    if ([int]$plan.stageCount -ne $derived.Count -or $stages.Count -ne $derived.Count) { Add-Failure $Failures 'plan_stage' "Plan stage count is $($stages.Count)/$($plan.stageCount), expected $($derived.Count)" ([string]$derived.Count) ([string]$stages.Count); return }
    if ($stages.Count -eq 0 -or [string]$stages[0].phaseNames[0] -ne 'caller-dispatch' -or [string]$stages[0].condition -ne 'y==0x9f14') { Add-Failure $Failures 'plan_stage' 'Plan does not begin with the caller-dispatch PC=00FC/Y=9F14 predicate' '' '' }
    for ($i=0; $i -lt $derived.Count; $i++) {
        $a = $stages[$i]; $e = $derived[$i]
        if ([int]$a.pc -ne [int]$e.pc) { Add-Failure $Failures 'plan_stage' "Plan stage $i PC is $($a.pc), expected $([int]$e.pc)" ([string]$e.pc) ([string]$a.pc) }
        if ((@($a.phaseNames) -join ',') -ne (@($e.phaseNames) -join ',')) { Add-Failure $Failures 'plan_stage' "Plan stage $i phase names differ" (@($e.phaseNames) -join ',') (@($a.phaseNames) -join ',') }
        if ((@($a.boundaryIds) -join ',') -ne (@($e.boundaryIds) -join ',')) { Add-Failure $Failures 'plan_stage' "Plan stage $i boundary ids differ" (@($e.boundaryIds) -join ',') (@($a.boundaryIds) -join ',') }
        if ([string]$a.onlyIf -ne [string]$e.onlyIf) { Add-Failure $Failures 'plan_stage' "Plan stage $i condition tag is $($a.onlyIf), expected $($e.onlyIf)" ([string]$e.onlyIf) ([string]$a.onlyIf) }
        if ([string]$a.condition -ne [string]$e.condition) { Add-Failure $Failures 'plan_stage' "Plan stage $i breakpoint condition is $($a.condition), expected $($e.condition)" ([string]$e.condition) ([string]$a.condition) }
    }
}

function Invoke-LampCheck {
    param([string]$Run,[switch]$AllowSyntheticCheck)
    $failures = New-Object 'System.Collections.Generic.List[object]'
    $run = [IO.Path]::GetFullPath($Run)
    $result = [ordered]@{
        mode = 'check'
        runDirectory = $run
        protocol = $script:Protocol
        evidenceClass = ''
        pass = $false
        naturalClaim = $false
        status = 'blocked_offline_check'
        supervisorAcceptance = 'not_claimed'
        phaseCount = 0
        boundaryCount = 0
        skippedBoundaryCount = 0
        physicalStopCount = 0
        logicalRecordCount = 0
        failures = @()
    }
    try {
        if (!(Test-Path -LiteralPath $run -PathType Container)) { throw "Run directory is missing: $run" }
        $metadataPath = Join-Path $run 'session-metadata.json'
        if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf)) { throw "session-metadata.json is missing: $metadataPath" }
        $metadata = Read-JsonFile $metadataPath
        if ([string]$metadata.protocol -ne $script:Protocol) { Add-Failure $failures 'protocol' 'Session metadata protocol mismatch' $script:Protocol ([string]$metadata.protocol) }
        $evidenceClass = if ([string]::IsNullOrWhiteSpace([string]$metadata.evidence_class)) { 'unknown' } else { [string]$metadata.evidence_class }
        $result.evidenceClass = $evidenceClass
        if ($evidenceClass -eq 'prepared_only_not_executed') { Add-Failure $failures 'prepared_not_executed' 'The prepared session was never launched; no natural observation exists' '' '' }
        if ($evidenceClass -eq 'synthetic_checker_fixture' -and -not $AllowSyntheticCheck) { Add-Failure $failures 'synthetic_not_allowed' 'A synthetic fixture cannot pass as natural evidence' '' '' }
        if ($evidenceClass -notin @('natural','synthetic_checker_fixture')) { Add-Failure $failures 'evidence_class' "Unsupported evidence class '$evidenceClass'" 'natural/synthetic_checker_fixture' $evidenceClass }

        if ([string]$metadata.original_rom.sha256 -ine $script:OriginalSha256) { Add-Failure $failures 'identity_original' 'Original ROM identity is wrong' $script:OriginalSha256 ([string]$metadata.original_rom.sha256) }
        if ([string]$metadata.built_rom.sha256 -ine $script:BuiltSha256) { Add-Failure $failures 'identity_built' 'Built image identity is wrong' $script:BuiltSha256 ([string]$metadata.built_rom.sha256) }
        if ([string]$metadata.source_map.sha256 -ine $script:MapSha256) { Add-Failure $failures 'identity_map' 'Source map identity is wrong' $script:MapSha256 ([string]$metadata.source_map.sha256) }
        if ([string]$metadata.build_report.sha256 -ine $script:ReportSha256) { Add-Failure $failures 'identity_report' 'Build report identity is wrong' $script:ReportSha256 ([string]$metadata.build_report.sha256) }
        if ([string]$metadata.checker_report.sha256 -ine $script:CheckerReportSha256) { Add-Failure $failures 'identity_checker' 'Supervisor checker report identity is wrong' $script:CheckerReportSha256 ([string]$metadata.checker_report.sha256) }
        if ([string]$metadata.input_replay.sha256 -ine $script:ReplaySha256) { Add-Failure $failures 'identity_replay' 'Replay identity is wrong' $script:ReplaySha256 ([string]$metadata.input_replay.sha256) }
        if ([string]$metadata.input_replay.input_lua_sha256 -ine $script:InputLuaSha256) { Add-Failure $failures 'identity_inputlua' 'Input Lua identity is wrong' $script:InputLuaSha256 ([string]$metadata.input_replay.input_lua_sha256) }
        if ([string]$metadata.mame.sha256 -ine $script:MameSha256) { Add-Failure $failures 'identity_mame' 'MAME identity is wrong' $script:MameSha256 ([string]$metadata.mame.sha256) }

        if ([string]$metadata.starting_nvram -ne 'absent') { Add-Failure $failures 'fresh_nvram' 'The session did not start with absent NVRAM' 'absent' ([string]$metadata.starting_nvram) }
        if ([string]$metadata.starting_configuration -notmatch 'absent') { Add-Failure $failures 'fresh_config' 'The session did not start with absent configuration' 'absent' ([string]$metadata.starting_configuration) }
        if ([bool]$metadata.save_state_loaded) { Add-Failure $failures 'injection' 'A save state was loaded' '' '' }
        if ([bool]$metadata.state_injection) { Add-Failure $failures 'injection' 'State injection is claimed' '' '' }
        if ([bool]$metadata.input_injection) { Add-Failure $failures 'injection' 'Input injection is claimed' '' '' }
        if ([bool]$metadata.debugger_writes) { Add-Failure $failures 'injection' 'Debugger writes are claimed' '' '' }
        if ([string]$metadata.input_policy -ne 'tracked_physical_replay') { Add-Failure $failures 'input_policy' 'Input policy is not tracked physical replay' 'tracked_physical_replay' ([string]$metadata.input_policy) }
        if (-not [bool]$metadata.input_replay_used) { Add-Failure $failures 'input_policy' 'Session does not claim tracked physical input replay' '' '' }
        foreach ($dir in @('nvram','cfg','inp','snap','comments','diff')) {
            $files = @(Get-ChildItem -LiteralPath (Join-Path $run $dir) -Recurse -File -ErrorAction SilentlyContinue)
            if ($dir -in @('nvram','cfg')) {
                $code = if ($dir -eq 'nvram') { 'fresh_nvram' } else { 'fresh_config' }
                $preflight = Read-JsonFile (Join-Path $run 'preflight.json')
                if ($null -eq $preflight.freshDirectories.$dir -or [int]$preflight.freshDirectories.$dir -ne 0) {
                    Add-Failure $failures $code 'Preparation inventory was not empty' '0' ''
                }
                foreach ($file in $files) {
                    $relative = $file.FullName.Substring(([IO.Path]::GetFullPath($run)).TrimEnd('\').Length + 1).Replace('\','/')
                    $allowed = if ($dir -eq 'cfg') { @('cfg/default.cfg','cfg/m4addr.cfg') } else { @('nvram/m4addr/nvram') }
                    $recordPath = Join-Path $run 'run-record.json'
                    if ($relative -notin $allowed -or !(Test-Path -LiteralPath $recordPath)) {
                        Add-Failure $failures $code "Unexplained persistent file: $relative" '' ''; continue
                    }
                    $rr = Read-JsonFile $recordPath
                    $start = [DateTimeOffset]::Parse([string]$rr.startUtc).UtcDateTime
                    $end = [DateTimeOffset]::Parse([string]$rr.endUtc).UtcDateTime
                    if ($file.CreationTimeUtc -lt $start -or $file.CreationTimeUtc -gt $end.AddSeconds(2) -or
                        $file.LastWriteTimeUtc -lt $start -or $file.LastWriteTimeUtc -gt $end.AddSeconds(2)) {
                        Add-Failure $failures $code "Persistent file was not created during this MAME run: $relative" '' ''
                    }
                }
            }
            if ($dir -in @('inp','snap','comments','diff') -and $files.Count -ne 0) { Add-Failure $failures 'fresh_side_effect' "$dir directory contains $($files.Count) file(s)" '0' ([string]$files.Count) }
        }
        $stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'state') -Recurse -File -ErrorAction SilentlyContinue)
        if ($stateFiles.Count -ne 0) { Add-Failure $failures 'injection' "State directory contains $($stateFiles.Count) file(s)" '0' ([string]$stateFiles.Count) }

        $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
        if (!(Test-Path -LiteralPath $runRom -PathType Leaf)) { throw 'Run-local ROM is missing' }
        if ((Get-Sha256 $runRom) -ine $script:BuiltSha256) { Add-Failure $failures 'identity_built' 'Run-local ROM hash is not the built image' $script:BuiltSha256 (Get-Sha256 $runRom) }
        if ((Get-Sha1 $runRom) -ine $script:BuiltSha1) { Add-Failure $failures 'identity_built' 'Run-local ROM SHA1 is not the built image' $script:BuiltSha1 (Get-Sha1 $runRom) }
        $runReplay = Join-Path $run 'replay-actions.csv'
        $runInputLua = Join-Path $run 'input.lua'
        if ((Get-Sha256 $runReplay) -ine $script:ReplaySha256) { Add-Failure $failures 'identity_replay' 'Run-local replay hash is wrong' $script:ReplaySha256 (Get-Sha256 $runReplay) }
        if ((Get-Sha256 $runInputLua) -ine $script:InputLuaSha256) { Add-Failure $failures 'identity_inputlua' 'Run-local input Lua hash is wrong' $script:InputLuaSha256 (Get-Sha256 $runInputLua) }
        $runLua = Join-Path $run 'IlLampNatural.lua'
        if (!(Test-Path -LiteralPath $runLua -PathType Leaf)) { Add-Failure $failures 'identity_lua' 'Run-local observer Lua is missing' '' '' }
        elseif ([string]$metadata.lua.capturedSha256 -ne (Get-Sha256 $runLua)) { Add-Failure $failures 'identity_lua' 'Run-local observer Lua hash differs from metadata' ([string]$metadata.lua.capturedSha256) (Get-Sha256 $runLua) }
        $mapPath = Join-Path $run 'lamp-pattern-source-map.json'
        $reportPath = Join-Path $run 'build-report.json'
        if ((Get-Sha256 $mapPath) -ine $script:MapSha256) { Add-Failure $failures 'identity_map' 'Run-local source map hash is wrong' $script:MapSha256 (Get-Sha256 $mapPath) }
        if ((Get-Sha256 $reportPath) -ine $script:ReportSha256) { Add-Failure $failures 'identity_report' 'Run-local build report hash is wrong' $script:ReportSha256 (Get-Sha256 $reportPath) }
        $planPath = Join-Path $run 'lamp-natural-plan.json'
        if (!(Test-Path -LiteralPath $planPath -PathType Leaf)) { Add-Failure $failures 'plan_stage' 'Run-local ordered plan JSON is missing' '' '' }
        elseif ($null -ne $metadata.ordered_plan -and [string]$metadata.ordered_plan.sha256 -ne (Get-Sha256 $planPath)) { Add-Failure $failures 'plan_stage' 'Run-local ordered plan hash differs from metadata' ([string]$metadata.ordered_plan.sha256) (Get-Sha256 $planPath) }
        $map = Read-JsonFile $mapPath
        if ([string]$map.BuildId -ine $script:BuiltSha256) { Add-Failure $failures 'identity_map' 'Map BuildId is not the built image' $script:BuiltSha256 ([string]$map.BuildId) }
        if ([string]$map.OutputImageSha256 -ine $script:BuiltSha256) { Add-Failure $failures 'identity_map' 'Map OutputImageSha256 is not the built image' $script:BuiltSha256 ([string]$map.OutputImageSha256) }
        if ([int]$map.HeaderAddress -ne 0x1010 -or [string]$map.HeaderHex -ne '00F8') { Add-Failure $failures 'identity_map' 'Map header is not 1010/00F8' '' '' }
        if ([int]$map.AllocationEndInclusive -ne 0x1027) { Add-Failure $failures 'identity_map' 'Map allocation end is not 1027' '' '' }

        $argumentsPath = Join-Path $run 'arguments.json'
        if (Test-Path -LiteralPath $argumentsPath -PathType Leaf) {
            $arguments = @((Read-JsonFile $argumentsPath) | ForEach-Object { [string]$_ })
            foreach ($switch in @('-playback','-record','-state','-loadstate','-autosave','-debugscript','-snapshot','-aviwrite','-mngwrite','-wavwrite','-seed')) {
                if ($arguments -contains $switch) { Add-Failure $failures 'forbidden_argument' "MAME invocation contains forbidden $switch" '' '' }
            }
        }
        elseif ($evidenceClass -eq 'natural') {
            Add-Failure $failures 'mame_identity' 'Natural run has no arguments.json' '' ''
        }
        if ($evidenceClass -eq 'natural') {
            if ([bool]$metadata.mame_launched -ne $true) { Add-Failure $failures 'mame_launch_count' 'Natural run does not claim a MAME launch' 'true' ([string]$metadata.mame_launched) }
            if ([int]$metadata.launch_count -ne 1) { Add-Failure $failures 'mame_launch_count' 'Natural run launch count is not exactly 1' '1' ([string]$metadata.launch_count) }
            if ([bool]$metadata.retry_allowed) { Add-Failure $failures 'mame_launch_count' 'Natural run allows retries' 'false' 'true' }
        }

        $eventInfo = Get-EventRecords $run
        $records = @($eventInfo.records)
        $result.logicalRecordCount = $records.Count
        $ready = @($records | Where-Object { [string]$_.event -eq 'session_ready' })
        $complete = @($records | Where-Object { [string]$_.event -eq 'session_complete' })
        $failuresRecords = @($records | Where-Object { [string]$_.event -in @('startup_failure','protocol_failure','session_timeout') })
        if ($ready.Count -ne 1) { Add-Failure $failures 'event_sequence' "Observed $($ready.Count) session_ready records" '1' ([string]$ready.Count) }
        if ($complete.Count -ne 1) { Add-Failure $failures 'event_sequence' "Observed $($complete.Count) session_complete records" '1' ([string]$complete.Count) }
        if ($failuresRecords.Count -gt 0) { Add-Failure $failures 'failure_record' "Event log contains $($failuresRecords.Count) failure/timeout record(s)" '0' ([string]$failuresRecords.Count) }
        if ($records.Count -gt 0 -and [string]$records[0].event -ne 'session_ready') { Add-Failure $failures 'event_sequence' 'session_ready is not the first record' 'session_ready' ([string]$records[0].event) }
        if ($records.Count -gt 0 -and [string]$records[$records.Count - 1].event -ne 'session_complete') { Add-Failure $failures 'event_sequence' 'session_complete is not the last record' 'session_complete' ([string]$records[$records.Count - 1].event) }
        if ($ready.Count -eq 1) {
            $r = $ready[0]
            if ([string]$r.boundarySource -ne 'native_debugger_bpset') { Add-Failure $failures 'session_ready' 'Boundaries are not native debugger bpset stops' '' ([string]$r.boundarySource) }
            if ([string]$r.driver -ne 'emu.register_periodic_stopped_state_only') { Add-Failure $failures 'session_ready' 'Observer driver is not the stopped-state periodic driver' '' ([string]$r.driver) }
            if ([string]$r.ioReadPolicy -ne 'strict_allowlist_no_active_io_reads') { Add-Failure $failures 'session_ready' 'Observer did not declare the strict no-I/O read policy' '' ([string]$r.ioReadPolicy) }
            if ([string]$r.dpAvailable -ne 'true') { Add-Failure $failures 'session_ready' 'DP was unavailable' 'true' ([string]$r.dpAvailable) }
            if ([int]$r.phaseCount -ne 43 -or [int]$r.boundaryCount -ne 14) { Add-Failure $failures 'session_ready' 'Ready counts are not 43 phases / 14 boundaries' '43/14' "$($r.phaseCount)/$($r.boundaryCount)" }
        }
        $allowedEvents = @('session_ready','physical_stop','phase','boundary','boundary_skipped','session_timeout','startup_failure','protocol_failure','session_complete')
        foreach ($record in $records) {
            if ([string]$record.event -notin $allowedEvents) { Add-Failure $failures 'event_sequence' "Unexpected event type $($record.event)" '' '' }
            $props = @($record.PSObject.Properties.Name)
            foreach ($field in @('ioReadAddress','memReadAddress','memoryReadAddress')) {
                if ($props -contains $field) {
                    $addr = [string]$record.$field
                    if ($addr -match '^0*8[0-9A-Fa-f]{2}$') { Add-Failure $failures 'io_read_forbidden' "Observer recorded an active I/O read at $addr" 'no I/O read' $addr }
                }
            }
            if ($props -contains 'ioRead' -and [string]$record.ioRead -eq 'true') { Add-Failure $failures 'io_read_forbidden' 'Observer recorded an active I/O read' 'no I/O read' 'true' }
            if ([string]$record.event -in @('session_ready','phase','boundary','session_complete')) {
                $identityPairs = @(
                    @{ field='buildSha256'; expected=$script:BuiltSha256 },
                    @{ field='originalRomSha256'; expected=$script:OriginalSha256 },
                    @{ field='sourceMapSha256'; expected=$script:MapSha256 },
                    @{ field='buildReportSha256'; expected=$script:ReportSha256 },
                    @{ field='luaSha256'; expected=[string]$metadata.lua.capturedSha256 },
                    @{ field='mameSha256'; expected=$script:MameSha256 },
                    @{ field='replaySha256'; expected=$script:ReplaySha256 },
                    @{ field='inputLuaSha256'; expected=$script:InputLuaSha256 },
                    @{ field='sessionId'; expected=[string]$metadata.sessionId }
                )
                foreach ($pair in $identityPairs) {
                    if ($props -notcontains $pair.field) { Add-Failure $failures 'event_identity' "Event $($record.event) is missing $($pair.field)" $pair.field '' }
                    elseif ([string]$record.($pair.field) -ine [string]$pair.expected) { Add-Failure $failures 'event_identity' "Event $($record.event) has wrong $($pair.field)" ([string]$pair.expected) ([string]$record.($pair.field)) }
                }
                if ($props -contains 'imageSha256' -and [string]$record.imageSha256 -ine $script:BuiltSha256) { Add-Failure $failures 'event_identity' "Event $($record.event) has wrong imageSha256" $script:BuiltSha256 ([string]$record.imageSha256) }
            }
        }

        $expectedPhases = @(Get-ExpectedPhases $map)
        $expectedBoundaries = @(Get-ExpectedBoundaries)
        Add-OrderedPlanFailures $run $expectedPhases $expectedBoundaries $failures
        Test-PhaseRecords $run $records $expectedPhases $failures
        Test-BoundaryRecords $records $expectedPhases $failures
        Test-FrameEffect $records $failures
        Test-InputAndStopInventory $run $records $failures
        $result.phaseCount = @($records | Where-Object { [string]$_.event -eq 'phase' }).Count
        $result.boundaryCount = @($records | Where-Object { [string]$_.event -eq 'boundary' }).Count
        $result.skippedBoundaryCount = @($records | Where-Object { [string]$_.event -eq 'boundary_skipped' }).Count
        $result.physicalStopCount = @($records | Where-Object { [string]$_.event -eq 'physical_stop' }).Count
        if ($complete.Count -eq 1 -and [string]$complete[0].complete -ne 'true') { Add-Failure $failures 'event_sequence' 'session_complete does not claim completion' 'true' ([string]$complete[0].complete) }
        $result.failures = $failures.ToArray()
        $result.pass = ($failures.Count -eq 0)
        if ($result.pass) {
            if ($evidenceClass -eq 'natural') {
                $result.status = 'complete_natural_lamp_observation_pending_review'
                $result.naturalClaim = $true
            }
            else {
                $result.status = 'synthetic_fixture_value_check_passed_not_evidence'
                $result.naturalClaim = $false
            }
        }
        else { $result.status = 'blocked_offline_check'; $result.naturalClaim = $false }
    }
    catch {
        Add-Failure $failures 'exception' $_.Exception.Message '' ''
        $result.failures = $failures.ToArray()
        $result.pass = $false
        $result.status = 'blocked_offline_check'
        $result.naturalClaim = $false
    }
    if (![string]::IsNullOrWhiteSpace($OutputPath)) { Write-JsonFile $OutputPath $result 40 }
    return $result
}

function Copy-RunFixture {
    param([string]$Source,[string]$Destination)
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -ErrorAction Stop
}
function Edit-JsonFile {
    param([string]$Path,[scriptblock]$Mutation)
    $obj = Read-JsonFile $Path
    & $Mutation $obj
    Write-JsonFile $Path $obj 40
}
function Edit-JsonLines {
    param([string]$Path,[scriptblock]$Mutation)
    $records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $records.Add(($line | ConvertFrom-Json -ErrorAction Stop))
    }
    $result = & $Mutation $records
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($record in @($result)) { $lines.Add((ConvertTo-Json -InputObject $record -Depth 30 -Compress)) }
    [IO.File]::WriteAllText($Path,(($lines -join "`n") + "`n"),$script:Utf8)
}
function Set-MetadataField {
    param([string]$Run,[string]$Name,$Value)
    Edit-JsonFile (Join-Path $Run 'session-metadata.json') { param($o) $o | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force }
}

function New-SyntheticLampRun {
    param([string]$PreparedBase,[string]$Destination,[int]$F1Value,[switch]$OmitToggleStops,[switch]$AddUnexpectedSetStop)
    Copy-RunFixture $PreparedBase $Destination
    $metadataPath = Join-Path $Destination 'session-metadata.json'
    $metadata = Read-JsonFile $metadataPath
    $metadata | Add-Member -NotePropertyName evidence_class -NotePropertyValue 'synthetic_checker_fixture' -Force
    $metadata | Add-Member -NotePropertyName mame_launched -NotePropertyValue $true -Force
    $metadata | Add-Member -NotePropertyName launch_count -NotePropertyValue 1 -Force
    $metadata | Add-Member -NotePropertyName retry_allowed -NotePropertyValue $false -Force
    $metadata | Add-Member -NotePropertyName natural_execution_claimed -NotePropertyValue $false -Force
    Write-JsonFile $metadataPath $metadata 40
    Copy-Item -LiteralPath (Join-Path $Destination 'arguments.template.json') -Destination (Join-Path $Destination 'arguments.json') -Force

    $map = Read-JsonFile (Join-Path $Destination 'lamp-pattern-source-map.json')
    $phases = @(Get-ExpectedPhases $map)
    $boundaries = @(Get-ExpectedBoundaries)
    $frameBefore = New-Object 'System.Collections.Generic.List[int]'
    for ($i = 0; $i -lt 64; $i++) { $frameBefore.Add(0) }
    $frameBefore[0x011F - 0x0100] = 0x01
    $frameAfter = New-Object 'System.Collections.Generic.List[int]'
    foreach ($v in $frameBefore) { $frameAfter.Add($v) }
    foreach ($target in @(0x010F,0x011F,0x012F,0x013F)) { $frameAfter[$target - 0x0100] = ($frameAfter[$target - 0x0100] -bor 0x01) -band 0xFF }
    function Bytes-Text($list) { return (($list | ForEach-Object { Format-Hex8 $_ }) -join ' ') }

    $records = New-Object 'System.Collections.Generic.List[object]'
    $stopCounter = 0
    $timeCounter = 0
    function New-StopId { $script:__lampStop = $script:__lampStop + 1; return [string]$script:__lampStop }
    function New-StopTime { $script:__lampTime = $script:__lampTime + 1; return ('{0:F9}' -f (37.103 + ($script:__lampTime * 0.00005))) }
    $script:__lampStop = 0
    $script:__lampTime = 0
    $f1Set = $F1Value
    $f1Clear = if ($F1Value -eq 0) { 0 } elseif ($F1Value -eq 1) { 1 } elseif ($F1Value -eq 128) { 129 } elseif ($F1Value -eq 129) { 129 } else { $F1Value }
    $setPath = ($f1Set -ne 0)
    $clearPath = ($f1Clear -ne 0)
    if ($OmitToggleStops) { $setPath = $false; $clearPath = $false }

    $phaseRecords = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt 43; $i++) {
        $p = $phases[$i]
        $phaseRecords.Add([ordered]@{ index=$i; phase=$p; record=$null })
    }
    $entryA = 0x78; $entryB = 0x8F; $entryX = 0x8052; $entryS = 0x0790; $maskValue = 0x01; $ccSaved = 0x04
    $response0803 = (($entryA -bxor (15 -shl 3)) -band 0xFF)
    $nativeTop = @{
        'native-prologue-save-regs' = (($entryA -shl 8) -bor $entryB) -band 0xFFFF
        'native-prologue-save-mask' = (($maskValue -shl 8) -bor $entryA) -band 0xFFFF
        'native-prologue-deepest' = (($ccSaved -shl 8) -bor $maskValue) -band 0xFFFF
        'native-epilogue-puls-cc' = (($maskValue -shl 8) -bor $entryA) -band 0xFFFF
        'native-epilogue-puls-a' = (($entryA -shl 8) -bor $entryB) -band 0xFFFF
        'native-return' = 0x9B24
    }
    $nativeStage = @{
        'native-prologue-save-regs'='afterRegs'; 'native-prologue-save-mask'='afterMask'; 'native-prologue-deepest'='afterCc'
        'native-epilogue-puls-cc'='afterPulsCc'; 'native-epilogue-puls-a'='afterPulsA'; 'native-return'='nativeReturn'
    }
    $logical = New-Object 'System.Collections.Generic.List[object]'
    for ($i = 0; $i -lt 43; $i++) {
        $p = $phases[$i]
        $a = 0; $b = 0; $cc = 0x04
        if ($p.name -in @('bridge-jsr-entry','native-prologue-save-regs','native-prologue-save-mask','native-prologue-deepest','native-epilogue-puls-cc','native-epilogue-puls-a','native-return','bridge-saves-y')) { $a = $entryA; $b = $entryB }
        if ($p.name -eq 'native-prologue-save-mask') { $cc = $ccSaved }
        if ($p.name -eq 'native-epilogue-puls-cc') { $cc = $ccSaved }
        if ($p.name -eq 'native-return') { $cc = $ccSaved }
        if ($p.name -eq 'bridge-restores-y') { $cc = $ccSaved }
        $top = if ($p.name -in $nativeTop.Keys) { $nativeTop[$p.name] } elseif ($null -ne $p.controlTop) { $p.controlTop } else { 0 }
        $record = [ordered]@{
            event='phase'; recordType='phase'; phase=$p.name; phaseIndex=[string]$i; required='true'
            pc=(Format-Hex16 $p.pc); x=(Format-Hex16 $(if ($null -ne $p.x) { $p.x } else { 0 })); y=(Format-Hex16 $p.y)
            u=(Format-Hex16 $p.u); s=(Format-Hex16 $p.s); a=(Format-Hex8 $a); b=(Format-Hex8 $b)
            d=(Format-Hex16 (($a -shl 8) -bor $b)); cc=(Format-Hex8 $cc); dpAvailable='true'; dpRaw='0'; dp='00'
            dpWidthBits='8'; dpWidthSource='state_entry_size_bytes'; dpNormalizedMask='00FF'
            token=(Format-Hex16 $p.liveToken); tokenAddress=(Format-Hex16 $p.tokenAddress)
            handlerAddress=$(if ($null -ne $p.handlerAddress) { Format-Hex16 $p.handlerAddress } else { '' })
            operandAddress=$(if ($null -ne $p.operandAddress) { Format-Hex16 $p.operandAddress } else { '' })
            operandWidth=$(if ($p.operandWidth -gt 0) { [string]$p.operandWidth } else { '' })
            operand=$p.operandText
            savedCursor=$(if ($null -ne $p.savedCursor) { Format-Hex16 $p.savedCursor } else { '' })
            savedCursorOffset=[string]$p.savedCursorOffset
            savedCursorRole=[string]$p.savedCursorRole
            controlTopSource=[string]$p.controlTopSource
            controlStack0=(Format-Hex16 $top); controlStack1='0000'; controlStack2='0000'; controlStack3='0000'
            dataStack0='0000'; dataStack1='0000'; dataStack2='0000'; dataStack3='0000'
            buildSha256=$script:BuiltSha256; sourceMapSha256=$script:MapSha256; buildReportSha256=$script:ReportSha256
            luaSha256=[string]$metadata.lua.capturedSha256; mameSha256=$script:MameSha256; replaySha256=$script:ReplaySha256; inputLuaSha256=$script:InputLuaSha256
            sessionId=[string]$metadata.sessionId
        }
        if ($p.name -in $nativeStage.Keys) {
            $stage = $nativeStage[$p.name]
            $record.nativeStage = $stage
            $record.nativeFrameTop = Format-Hex16 $top
            $record.nativeYSlot = '9B24'
            $record.nativeReturnSlot = if ($stage -eq 'nativeReturn') { '' } else { '777E' }
            $record.nativeEntryA = Format-Hex8 $entryA
            $record.nativeEntryB = Format-Hex8 $entryB
            $record.nativeEntryX = Format-Hex16 $entryX
            $record.nativeMask = Format-Hex8 $maskValue
            if ($stage -eq 'afterCc') { $record.nativeSavedCc = Format-Hex8 $ccSaved }
        }
        if ($p.name -eq 'bridge-jsr-entry') {
            $record.nativeEntryA = Format-Hex8 $entryA
            $record.nativeEntryB = Format-Hex8 $entryB
            $record.nativeEntryX = Format-Hex16 $entryX
            $record.nativeMask = Format-Hex8 $maskValue
            $record.frameBefore = Bytes-Text $frameBefore
        }
        if ($p.name -eq 'native-epilogue-puls-a') { $record.frameFinalNative = Bytes-Text $frameAfter }
        if ($p.name -eq 'native-return') { $record.frameAfter = Bytes-Text $frameAfter }
        if ($p.name -eq 'native-prologue-save-mask') { $record.ccSaved49D0 = Format-Hex8 $ccSaved }
        if ($p.name -eq 'native-epilogue-puls-cc') {
            $record.ccSaved49D0=Format-Hex8 $ccSaved; $record.ccRestored=Format-Hex8 $ccSaved; $record.response0803=Format-Hex8 $response0803; $record.savedLogicalIndex=Format-Hex8 $entryA; $record.savedMask=Format-Hex8 $maskValue; $record.column='15'
        }
        if ($p.name -eq 'bridge-restores-y') {
            $record.f1AtClearRead = Format-Hex8 $f1Clear
            $record.clearBranchByteZero = ($(if ($f1Clear -eq 0) { 'true' } else { 'false' }))
        }
        if ($p.name -eq 'outer-returned-to-9F16') {
            $record.finalResultTop='0000'; $record.successorWord='75A9'; $record.dataStack0='0000'
        }
        $logical.Add([ordered]@{ kind='phase'; phaseIndex=$i; record=$record })
    }

    # Insert the boundary logical records at their semantic positions.
    $insertBefore = @{}
    $insertAfter = @{}
    $mergeWithPhase = @{}
    function Add-InsertBefore([int]$At,$Record) { $key=[string]$At;
        if (-not $insertBefore.Contains($key)) { $insertBefore[$key] = New-Object 'System.Collections.Generic.List[object]' }
        $insertBefore[$key].Add($Record)
    }
    function Add-InsertAfter([int]$At,$Record) { $key=[string]$At;
        if (-not $insertAfter.Contains($key)) { $insertAfter[$key] = New-Object 'System.Collections.Generic.List[object]' }
        $insertAfter[$key].Add($Record)
    }
    function Add-MergeWithPhase([int]$At,$Record) { $key=[string]$At;
        if (-not $mergeWithPhase.Contains($key)) { $mergeWithPhase[$key] = New-Object 'System.Collections.Generic.List[object]' }
        $mergeWithPhase[$key].Add($Record)
    }
    function Add-Identity([object]$Record) {
        $Record['buildSha256'] = $script:BuiltSha256
        $Record['originalRomSha256'] = $script:OriginalSha256
        $Record['sourceMapSha256'] = $script:MapSha256
        $Record['buildReportSha256'] = $script:ReportSha256
        $Record['luaSha256'] = [string]$metadata.lua.capturedSha256
        $Record['mameSha256'] = $script:MameSha256
        $Record['replaySha256'] = $script:ReplaySha256
        $Record['inputLuaSha256'] = $script:InputLuaSha256
        $Record['sessionId'] = [string]$metadata.sessionId
    }
    foreach ($b in $boundaries) {
        $a=0; $bval=0; $cc=0x04; $x=0; $y=0; $u=0; $s=0; $control0=0x0401
        if ($b.id -eq 'port-orcc50') { $cc=0x04 }
        elseif ($b.id -in @('port-sta-0801','port-stb-0802','port-ldb-0803-preread')) { $cc=0x54 }
        elseif ($b.id -eq 'port-pulscc-pre') { $cc=0x54; $bval=0x00 }
        elseif ($b.kind -eq 'frame_write') { $x=0x010F; $u=0x066E; $s=0x078B; $control0=(($maskValue -shl 8) -bor $entryA) -band 0xFFFF }
        elseif ($b.id -eq 'port-f1-set-read') { $x=0x8052; $u=0x066C; $s=0x0794; $control0=0x1026 }
        elseif ($b.id -in @('port-f1-set-write','port-080c-set-write','port-f1-clear-write','port-080c-clear-write')) { $u=0x066E; $s=0x0794; $control0=0x1026 }
        if ($b.kind -eq 'frame_write') {
            $target = 0x010F + [int]$b.offset
            $pre = $frameBefore[$target - 0x0100]; $mask = 0x01; $bval = (($pre -bor $mask) -band 0xFF)
            $rec = [ordered]@{
                event='boundary'; recordType='boundary'; boundary=$b.id; kind=$b.kind; instruction=$b.instruction; bytes=$b.bytes
                pc=(Format-Hex16 $b.pc); x=(Format-Hex16 $x); y='9B24'; u=(Format-Hex16 $u); s='078B'
                a='00'; b=(Format-Hex8 $bval); d=(Format-Hex16 $bval); cc=(Format-Hex8 $cc); dpAvailable='true'; dpRaw='0'; dp='00'
                dpWidthBits='8'; dpWidthSource='state_entry_size_bytes'; dpNormalizedMask='00FF'
                controlStack0=(Format-Hex16 $control0); target=(Format-Hex16 $target); preValue=(Format-Hex8 $pre); mask='01'
                preWriteB=(Format-Hex8 $bval); expectedB=(Format-Hex8 (($pre -bor $mask) -band 0xFF)); alreadySet=(($pre -band $mask) -ne 0).ToString().ToLowerInvariant()
                visibleTransition=((($pre -band $mask) -eq 0).ToString().ToLowerInvariant())
            }
            Add-InsertAfter 34 $rec
            continue
        }
        if ($b.id -eq 'port-f1-set-read') {
            $rec = [ordered]@{
                event='boundary'; recordType='boundary'; boundary=$b.id; kind=$b.kind; instruction=$b.instruction; bytes=$b.bytes
                pc=(Format-Hex16 $b.pc); x='8052'; y='9B24'; u='066C'; s='0794'; a='00'; b='00'; d='0000'; cc='04'
                dpAvailable='true'; dpRaw='0'; dp='00'; dpWidthBits='8'; dpWidthSource='state_entry_size_bytes'; dpNormalizedMask='00FF'
                controlStack0='1026'; f1AtSetRead=(Format-Hex8 $f1Set); setBranchByteZero=(($f1Set -eq 0).ToString().ToLowerInvariant()); branchTaken=(($f1Set -eq 0).ToString().ToLowerInvariant())
            }
            Add-MergeWithPhase 25 $rec
            continue
        }
        if ($b.id -in @('port-f1-set-write','port-080c-set-write')) {
            if (-not $setPath) { continue }
            $expectedA = (($f1Set -bor 0x01) -band 0xFF)
            $rec = [ordered]@{
                event='boundary'; recordType='boundary'; boundary=$b.id; kind=$b.kind; instruction=$b.instruction; bytes=$b.bytes
                pc=(Format-Hex16 $b.pc); x='8052'; y='9B24'; u='066C'; s='0794'; a=(Format-Hex8 $expectedA); b='00'; d=(Format-Hex16 ($expectedA -shl 8)); cc='04'
                dpAvailable='true'; dpRaw='0'; dp='00'; dpWidthBits='8'; dpWidthSource='state_entry_size_bytes'; dpNormalizedMask='00FF'
                controlStack0='1026'; preWriteA=(Format-Hex8 $expectedA)
            }
            if ($b.id -eq 'port-080c-set-write') { $rec.f1AfterSetWrite = Format-Hex8 $expectedA }
            Add-InsertBefore 26 $rec
            continue
        }
        if ($b.id -in @('port-f1-clear-write','port-080c-clear-write')) {
            if (-not $clearPath) { continue }
            $expectedA = ($f1Clear -band 0xFE)
            $rec = [ordered]@{
                event='boundary'; recordType='boundary'; boundary=$b.id; kind=$b.kind; instruction=$b.instruction; bytes=$b.bytes
                pc=(Format-Hex16 $b.pc); x='8052'; y='9B24'; u='066E'; s='0794'; a=(Format-Hex8 $expectedA); b='00'; d=(Format-Hex16 ($expectedA -shl 8)); cc='04'
                dpAvailable='true'; dpRaw='0'; dp='00'; dpWidthBits='8'; dpWidthSource='state_entry_size_bytes'; dpNormalizedMask='00FF'
                controlStack0='1026'; preWriteA=(Format-Hex8 $expectedA)
            }
            if ($b.id -eq 'port-080c-clear-write') { $rec.f1AfterClearWrite = Format-Hex8 $expectedA }
            Add-InsertBefore 38 $rec
            continue
        }
        # Native port-safe stops before 49E2.
        $rec = [ordered]@{
            event='boundary'; recordType='boundary'; boundary=$b.id; kind=$b.kind; instruction=$b.instruction; bytes=$b.bytes
            pc=(Format-Hex16 $b.pc); x='8052'; y='9B24'; u='066E'; s='078A'; a='00'; b='00'; d='0000'; cc=(Format-Hex8 $cc)
            dpAvailable='true'; dpRaw='0'; dp='00'; dpWidthBits='8'; dpWidthSource='state_entry_size_bytes'; dpNormalizedMask='00FF'
            controlStack0=(Format-Hex16 $control0)
        }
        if ($b.id -eq 'port-pulscc-pre') { $rec.response0803=Format-Hex8 $response0803; $rec.ccPrePuls='54' }
        if ($b.id -eq 'port-orcc50') { $rec.ccPreOrcc50='04' }
        if ($b.id -eq 'port-sta-0801') { $rec.preWriteA='00' }
        if ($b.id -eq 'port-stb-0802') { $rec.preWriteB='00' }
        if ($b.id -eq 'port-ldb-0803-preread') { $rec.preReadA='00'; $rec.preReadB='00' }
        Add-InsertBefore 34 $rec
    }

    # Build ordered logical records. The 7793 phase+boundary share one physical
    # stop; native port saves occur before the 49E2 phase, frame writes after it,
    # and the 7799/7786 branch stops occur before their following VM phases.
    for ($i = 0; $i -lt 43; $i++) {
        if ($insertBefore.Contains([string]$i)) {
            foreach ($rec in $insertBefore[[string]$i]) {
                Add-Identity $rec
                $stopId = [string]($stopCounter + 1)
                $stopTime = ('{0:F9}' -f (37.103 + ($timeCounter * 0.00005)))
                $stopCounter++
                $timeCounter++
                $rec.stopId = $stopId
                $rec.emulatedTime = $stopTime
                $records.Add([ordered]@{ event='physical_stop'; stopId=$stopId; pc=[string]$rec.pc; emulatedTime=$stopTime; matched=('boundary:' + [string]$rec.boundary); phaseCount=[string]$i; boundaryCount='0' })
                $records.Add($rec)
            }
        }
        $phaseLogical = @($logical | Where-Object { $_.kind -eq 'phase' -and [int]$_.phaseIndex -eq $i })[0]
        $group = New-Object 'System.Collections.Generic.List[object]'
        $group.Add($phaseLogical.record)
        if ($mergeWithPhase.Contains([string]$i)) { foreach ($rec in $mergeWithPhase[[string]$i]) { $group.Add($rec) } }
        $stopId = [string]($stopCounter + 1)
        $stopTime = ('{0:F9}' -f (37.103 + ($timeCounter * 0.00005)))
        $stopCounter++
        $timeCounter++
        $matched = New-Object 'System.Collections.Generic.List[string]'
        foreach ($rec in $group) {
            Add-Identity $rec
            $rec.stopId = $stopId
            $rec.emulatedTime = $stopTime
            if ([string]$rec.event -eq 'phase') { $matched.Add('phase:' + [string]$rec.phase) } else { $matched.Add('boundary:' + [string]$rec.boundary) }
        }
        $records.Add([ordered]@{ event='physical_stop'; stopId=$stopId; pc=[string]$group[0].pc; emulatedTime=$stopTime; matched=($matched -join ','); phaseCount=[string]$i; boundaryCount='0' })
        foreach ($rec in $group) { $records.Add($rec) }
        if ($insertAfter.Contains([string]$i)) {
            foreach ($rec in $insertAfter[[string]$i]) {
                Add-Identity $rec
                $stopId = [string]($stopCounter + 1)
                $stopTime = ('{0:F9}' -f (37.103 + ($timeCounter * 0.00005)))
                $stopCounter++
                $timeCounter++
                $rec.stopId = $stopId
                $rec.emulatedTime = $stopTime
                $records.Add([ordered]@{ event='physical_stop'; stopId=$stopId; pc=[string]$rec.pc; emulatedTime=$stopTime; matched=('boundary:' + [string]$rec.boundary); phaseCount=[string]$i; boundaryCount='0' })
                $records.Add($rec)
            }
        }
    }

    $skipTime = ('{0:F9}' -f (37.103 + ($timeCounter * 0.00005)))
    foreach ($id in @('port-f1-set-write','port-080c-set-write')) {
        if (-not $setPath) {
            $skip = [ordered]@{ event='boundary_skipped'; boundary=$id; reason='measured whole 00F1 byte is zero at 7793'; stopId=''; stageId=$id; onlyIf='f1EntryNonZero'; f1Entry=(Format-Hex8 $f1Set); f1Exit=''; emulatedTime=$skipTime; phaseCount='43'; boundaryCount='0'; skippedCount='4' }
            Add-Identity $skip
            $records.Add($skip)
        }
    }
    foreach ($id in @('port-f1-clear-write','port-080c-clear-write')) {
        if (-not $clearPath) {
            $skip = [ordered]@{ event='boundary_skipped'; boundary=$id; reason='measured whole 00F1 byte is zero at 7780'; stopId=''; stageId=$id; onlyIf='f1ExitNonZero'; f1Entry=(Format-Hex8 $f1Set); f1Exit=(Format-Hex8 $f1Clear); emulatedTime=$skipTime; phaseCount='43'; boundaryCount='0'; skippedCount='4' }
            Add-Identity $skip
            $records.Add($skip)
        }
    }

    $ready = [ordered]@{
        event='session_ready'; sessionId=[string]$metadata.sessionId; imageSha256=$script:BuiltSha256; originalRomSha256=$script:OriginalSha256
        sourceMapSha256=$script:MapSha256; buildReportSha256=$script:ReportSha256; luaSha256=[string]$metadata.lua.capturedSha256
        mameSha256=$script:MameSha256; replaySha256=$script:ReplaySha256; inputLuaSha256=$script:InputLuaSha256
        inputPolicy='tracked_physical_replay'; boundarySource='native_debugger_bpset'; driver='emu.register_periodic_stopped_state_only'
        ioReadPolicy='strict_allowlist_no_active_io_reads'; dpAvailable='true'; phaseCount='43'; boundaryCount='14'; physicalStopCount=[string]$stopCounter
        resetPc='7CCF'; secondsToRun='180'; wallTimeoutSeconds='900'
    }
    $completeRecord = [ordered]@{
        event='session_complete'; sessionId=[string]$metadata.sessionId; imageSha256=$script:BuiltSha256; originalRomSha256=$script:OriginalSha256
        sourceMapSha256=$script:MapSha256; buildReportSha256=$script:ReportSha256; luaSha256=[string]$metadata.lua.capturedSha256
        mameSha256=$script:MameSha256; replaySha256=$script:ReplaySha256; inputLuaSha256=$script:InputLuaSha256
        reason='lamp_natural_complete'; status='synthetic_fixture_complete_values'; complete='true'; phaseCount='43'; expectedPhaseCount='43'
        boundaryCount=[string]@($records | Where-Object { [string]$_.event -eq 'boundary' }).Count
        expectedBoundaryCount='14'; skippedBoundaryCount=[string]@($records | Where-Object { [string]$_.event -eq 'boundary_skipped' }).Count
        physicalStopCount=[string]$stopCounter; emulatedTime=('{0:F9}' -f (37.103 + ($timeCounter * 0.00005))); wallSeconds='0'
    }
    Add-Identity $ready
    $ready['imageSha256'] = $script:BuiltSha256
    Add-Identity $completeRecord
    $completeRecord['imageSha256'] = $script:BuiltSha256
    $finalRecords = New-Object 'System.Collections.Generic.List[object]'
    $finalRecords.Add($ready)
    foreach ($rec in $records) { $finalRecords.Add($rec) }
    $finalRecords.Add($completeRecord)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rec in $finalRecords) { $lines.Add((ConvertTo-Json -InputObject $rec -Depth 30 -Compress)) }
    [IO.File]::WriteAllText((Join-Path $Destination 'events.jsonl'),(($lines -join "`n") + "`n"),$script:Utf8)

    $inputLines = New-Object 'System.Collections.Generic.List[string]'
    $inputLines.Add('frame,t,aux2,black2,coin_override')
    for ($frame = 1; $frame -le 2224; $frame++) {
        $time = ($frame - 1) / 60.0
        $aux2 = if ($frame -ge 2100 -and $frame -le 2103) { '80' } else { '00' }
        $black2 = if ($frame -ge 2221 -and $frame -le 2224) { '80' } else { '00' }
        $coin = if ($aux2 -ne '00') { '1' } else { '0' }
        $inputLines.Add(('{0},{1:F9},{2},{3},{4}' -f $frame,$time,$aux2,$black2,$coin))
    }
    for ($i = 0; $i -lt $stopCounter; $i++) {
        $frame = 2225 + $i
        $time = 37.103 + ($i * 0.00005)
        $inputLines.Add(('{0},{1:F9},00,80,0' -f $frame,$time))
    }
    [IO.File]::WriteAllText((Join-Path $Destination 'input-levels.csv'),(($inputLines -join "`n") + "`n"),$script:Utf8)
    $debugLines = New-Object 'System.Collections.Generic.List[string]'
    $debugLines.Add('Stopped at breakpoint initial-reset')
    for ($i = 0; $i -lt $stopCounter; $i++) { $debugLines.Add('Stopped at breakpoint observation-' + $i) }
    [IO.File]::WriteAllText((Join-Path $Destination 'debug.log'),(($debugLines -join "`n") + "`n"),$script:Utf8)
    Write-JsonFile (Join-Path $Destination 'run-record.json') ([ordered]@{ commandId='synthetic-fixture'; exitCode=0; timedOut=$false; launchCount=1; retryAllowed=$false; description='SYNTHETIC offline checker fixture; not natural execution evidence' }) 6
    [IO.File]::WriteAllText((Join-Path $Destination 'exit-code.txt'),'0',$script:Utf8)
    return $Destination
}

function Get-FailureCodes {
    param($Result)
    return @($Result.failures | ForEach-Object { [string]$_.code })
}

function Invoke-PrepareTool {
    param([string]$RunDirectory,[string]$OriginalRom,[string]$SourceMapPath,[string]$BuildReportPath,[string]$MameExecutable,[string]$Mode='PrepareOnly')
    $tool = Join-Path $script:Root 'tools/Capture-IlLampNatural.ps1'
    $stdout = Join-Path $script:ArtifactDirectory ('prepare-' + [guid]::NewGuid().ToString('N') + '.stdout.log')
    $stderr = Join-Path $script:ArtifactDirectory ('prepare-' + [guid]::NewGuid().ToString('N') + '.stderr.log')
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$tool,'-Mode',$Mode,'-RunDirectory',$RunDirectory)
    if (![string]::IsNullOrWhiteSpace($OriginalRom)) { $args += @('-OriginalRom',$OriginalRom) }
    if (![string]::IsNullOrWhiteSpace($SourceMapPath)) { $args += @('-SourceMapPath',$SourceMapPath) }
    if (![string]::IsNullOrWhiteSpace($BuildReportPath)) { $args += @('-BuildReportPath',$BuildReportPath) }
    if (![string]::IsNullOrWhiteSpace($MameExecutable)) { $args += @('-MameExecutable',$MameExecutable) }
    $record = Invoke-ProcessRecord -FilePath (Get-Command powershell).Source -Arguments $args -WorkingDirectory $script:Root -StdOutPath $stdout -StdErrPath $stderr -TimeoutSeconds 300
    $text = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw } else { '' }
    return [ordered]@{ exitCode=$record.exitCode; timedOut=$record.timedOut; text=$text; stdout=$stdout; stderr=$stderr }
}

function Test-NativeFrameRomDerivation {
    param([string]$RunRomPath)
    $rom = [IO.File]::ReadAllBytes($RunRomPath)
    Assert-Equal (Get-Sha256 $RunRomPath) $script:BuiltSha256 'ROM-derived native frame test uses the exact built image'
    $maskHex = (($rom[0x49BD..0x49C4] | ForEach-Object { Format-Hex8 $_ }) -join '')
    Assert-Equal $maskHex '0102040810204080' '49BD..49C4 is the 8-entry bit-mask table'
    Assert-Equal (Format-Hex8 $rom[0x49C5]) '34' '49C5 is PSHS'
    Assert-Equal (Format-Hex8 $rom[0x49C6]) '16' '49C6 PSHS postbyte saves A,B,X'
    Assert-Equal (Format-Hex8 $rom[0x49CE]) '34' '49CE is PSHS'
    Assert-Equal (Format-Hex8 $rom[0x49CF]) '04' '49CF PSHS postbyte saves B'
    Assert-Equal (Format-Hex8 $rom[0x49D0]) '34' '49D0 is PSHS'
    Assert-Equal (Format-Hex8 $rom[0x49D1]) '01' '49D1 PSHS postbyte saves CC'
    Assert-Equal (Format-Hex8 $rom[0x49E0]) '35' '49E0 is PULS'
    Assert-Equal (Format-Hex8 $rom[0x49E1]) '01' '49E1 PULS postbyte restores CC'
    Assert-Equal (Format-Hex8 $rom[0x4A21]) '35' '4A21 is PULS'
    Assert-Equal (Format-Hex8 $rom[0x4A22]) '02' '4A22 PULS postbyte restores A'
    Assert-Equal (Format-Hex8 $rom[0x4A23]) '35' '4A23 is PULS'
    Assert-Equal (Format-Hex8 $rom[0x4A24]) '96' '4A24 PULS postbyte restores PC,X,B,A'
    Assert-Equal (Format-Hex8 $rom[0x777A]) '34' '777A is PSHS'
    Assert-Equal (Format-Hex8 $rom[0x777B]) '20' '777B PSHS postbyte saves Y'
    Assert-Equal (Format-Hex8 $rom[0x777C]) 'AD' '777C is JSR indexed'
    Assert-Equal (Format-Hex8 $rom[0x777D]) '94' '777D JSR postbyte is [,X]'
    Assert-Equal (Format-Hex8 $rom[0x777E]) '35' '777E is PULS'
    Assert-Equal (Format-Hex8 $rom[0x777F]) '20' '777F PULS postbyte restores Y'
    $pshs16 = 0
    foreach ($bit in @(0x10,0x04,0x02)) { if (([int]$rom[0x49C6] -band $bit) -ne 0) { $pshs16 += if ($bit -eq 0x10) { 2 } else { 1 } } }
    Assert-Equal $pshs16 4 '3416 drops four bytes (X,B,A)'
    Assert-Equal ([int]$rom[0x49CF]) 0x04 '3404 drops one byte (B)'
    Assert-Equal ([int]$rom[0x49D1]) 0x01 '3401 drops one byte (CC)'
    Assert-Equal ([int]$rom[0x49E1]) 0x01 '3501 restores one byte (CC)'
    Assert-Equal ([int]$rom[0x4A22]) 0x02 '3502 restores one byte (A)'
    Assert-Equal ([int]$rom[0x4A24]) 0x96 '3596 restores six bytes (PC,X,B,A)'
    Assert-Equal ([int]$rom[0x777B]) 0x20 '3420 drops two bytes (Y)'
    Assert-Equal ([int]$rom[0x777F]) 0x20 '3520 restores two bytes (Y)'
    $entryS = 0x0790
    Assert-Equal ('{0:X4}' -f (($entryS - $pshs16) -band 0xFFFF)) '078C' 'After 3416 the native S is 078C'
    Assert-Equal ('{0:X4}' -f (($entryS - $pshs16 - 1) -band 0xFFFF)) '078B' 'After 3404 the native S is 078B'
    Assert-Equal ('{0:X4}' -f (($entryS - $pshs16 - 2) -band 0xFFFF)) '078A' 'After 3401 the native S is 078A (deepest)'
    Assert-Equal ('{0:X4}' -f (($entryS - $pshs16 - 2 + [int]$rom[0x49E1]) -band 0xFFFF)) '078B' 'After 3501 the native S is 078B'
    Assert-Equal ('{0:X4}' -f (($entryS - $pshs16) -band 0xFFFF)) '078C' 'After 3501 and 3502 the native S is 078C (one CC and one A byte restored)'
    Assert-Equal ('{0:X4}' -f (($entryS + 2) -band 0xFFFF)) '0792' 'After 3596 the native return S is 0792 (Y top)'
    $steps = (Get-NativeFrameContract).steps
    Assert-Equal ([int]$steps['afterRegs'].sOffset) -4 'Native afterRegs step is entryS-4'
    Assert-Equal ([int]$steps['afterMask'].sOffset) -5 'Native afterMask step is entryS-5'
    Assert-Equal ([int]$steps['afterCc'].sOffset) -6 'Native afterCc step is entryS-6'
    Assert-Equal ([int]$steps['afterPulsCc'].sOffset) -5 'Native afterPulsCc step is entryS-5'
    Assert-Equal ([int]$steps['afterPulsA'].sOffset) -4 'Native afterPulsA step is entryS-4'
    Assert-Equal ([int]$steps['nativeReturn'].sOffset) 2 'Native return step is entryS+2'
    Assert-Equal ([int]$steps['afterRegs'].sharedCursorOffset) 8 'Shared 1026 is at S+8 after 3416'
    Assert-Equal ([int]$steps['afterMask'].sharedCursorOffset) 9 'Shared 1026 is at S+9 after 3404'
    Assert-Equal ([int]$steps['afterCc'].sharedCursorOffset) 10 'Shared 1026 is at S+10 after 3401'
    Assert-Equal ([int]$steps['afterPulsCc'].sharedCursorOffset) 9 'Shared 1026 is at S+9 after 3501'
    Assert-Equal ([int]$steps['afterPulsA'].sharedCursorOffset) 8 'Shared 1026 is at S+8 after 3502'
    Assert-Equal ([int]$steps['nativeReturn'].sharedCursorOffset) 2 'Shared 1026 is at S+2 at 777E'
}

function Get-StageExpectedY {
    param($Stage,$ExpectedPhases)
    if ([int]$Stage.pc -ne 0x00FC) { return $null }
    foreach ($name in @($Stage.phaseNames)) {
        $p = @($ExpectedPhases | Where-Object { $_.name -eq [string]$name })[0]
        if ($null -ne $p) { return [int]$p.y }
    }
    return $null
}

function Get-NextPlanIndex {
    param($Stages,[int]$Index,[int]$F1Entry,[int]$F1Exit)
    while ($Index -lt $Stages.Count) {
        $stage = $Stages[$Index]
        if ([string]$stage.onlyIf -eq 'f1EntryNonZero' -and $F1Entry -eq 0) { $Index++; continue }
        if ([string]$stage.onlyIf -eq 'f1ExitNonZero' -and $F1Exit -eq 0) { $Index++; continue }
        return $Index
    }
    return $Index
}

function Test-OrderedArmingPlan {
    param([string]$PlanPath,$ExpectedPhases,$ExpectedBoundaries)
    $plan = Read-JsonFile $PlanPath
    $derived = @(Get-OrderedStagePlan $ExpectedPhases $ExpectedBoundaries)
    Assert-Equal ([int]$plan.stageCount) $derived.Count 'Generated plan stage count matches the independent plan'
    Assert-Equal ([int]$plan.phaseCount) 43 'Generated plan declares 43 phases'
    Assert-Equal ([int]$plan.boundaryCount) 14 'Generated plan declares 14 boundaries'
    Assert-Equal (@((@($plan.stages) | ForEach-Object { @($_.phaseNames) }) -join ',') -join ',') (@((@($derived) | ForEach-Object { @($_.phaseNames) }) -join ',') -join ',') 'Generated plan preserves the 43 phase order'
    $planBoundaries = @((@($plan.stages) | ForEach-Object { @($_.boundaryIds) }) | ForEach-Object { $_ } | Sort-Object)
    $derivedBoundaries = @((@($derived) | ForEach-Object { @($_.boundaryIds) }) | ForEach-Object { $_ } | Sort-Object)
    Assert-Equal (@($planBoundaries) -join ',') (@($derivedBoundaries) -join ',') 'Generated plan places every boundary exactly once'
    $first = @($plan.stages)[0]
    Assert-Equal ([string]$first.phaseNames[0]) 'caller-dispatch' 'First armed stage is caller-dispatch'
    Assert-Equal ([int]$first.pc) 0x00FC 'First armed stage PC is 00FC'
    Assert-Equal ([string]$first.condition) 'y==0x9f14' 'First armed predicate is the target Y=9F14, not a reset-time all-breakpoint arm'
    $firstPhase = @($ExpectedPhases | Where-Object { $_.name -eq 'caller-dispatch' })[0]
    $pretarget = [ordered]@{ pc=0x49C5; y=0x9B24; u=0x066E; s=0x078A }
    $armed = ($pretarget.pc -eq [int]$first.pc) -and ($pretarget.y -eq (Get-StageExpectedY $first $ExpectedPhases))
    Assert-Equal $armed $false 'An unrelated pre-target 49C5 service call is not armed by the first stage'
    $wrongTarget = [ordered]@{ pc=0x00FC; y=0x9F14; u=0x066A; s=0x0798 }
    $matchesTargetContext = ($wrongTarget.pc -eq [int]$first.pc -and $wrongTarget.y -eq (Get-StageExpectedY $first $ExpectedPhases))
    Assert-True $matchesTargetContext 'Wrong-target-state test reaches the PC/Y target predicate'
    $wrongCode = if (-not $matchesTargetContext) { 'unexpected_stop' } elseif ($wrongTarget.u -ne $firstPhase.u) { 'phase_u' } elseif ($wrongTarget.s -ne $firstPhase.s) { 'phase_s' } else { '' }
    Assert-Equal $wrongCode 'phase_u' 'A genuine wrong U at the target fails immediately instead of timing out'
    $second = @($plan.stages)[1]
    $outOfOrder = [ordered]@{ pc=0x00FC; y=0x1012; u=0x066E; s=0x0796 }
    $outOfOrderMatches = ($outOfOrder.pc -eq [int]$second.pc -and $outOfOrder.y -eq (Get-StageExpectedY $second $ExpectedPhases))
    Assert-Equal $outOfOrderMatches $false 'A later dispatcher phase is rejected while the next stage is 00F8'
    $coincident = @($plan.stages | Where-Object { @($_.phaseNames) -contains 'bridge-pulu-pattern' })[0]
    Assert-True ($null -ne $coincident) 'Plan contains the 7793 bridge-pulu-pattern stage'
    Assert-True (@($coincident.phaseNames) -contains 'bridge-pulu-pattern' -and @($coincident.boundaryIds) -contains 'port-f1-set-read') 'The 7793 phase and port-safe read share one physical stage'
    $stages = @($plan.stages)
    $puluIndex = [array]::IndexOf(@($stages | ForEach-Object { @($_.phaseNames) -contains 'bridge-pulu-pattern' }), $true)
    $nextZero = Get-NextPlanIndex $stages ($puluIndex + 1) 0 0
    $nextNonZero = Get-NextPlanIndex $stages ($puluIndex + 1) 0x80 0
    Assert-Equal ([string]$stages[$nextZero].phaseNames[0]) 'bridge-load-index' 'F1=00 at 7793 skips the set-path boundaries and arms 779E'
    Assert-Equal ([string]$stages[$nextNonZero].boundaryIds[0]) 'port-f1-set-write' 'F1=80 at 7793 arms the 7799 set-path boundary'
    $restoresIndex = [array]::IndexOf(@($stages | ForEach-Object { @($_.phaseNames) -contains 'bridge-restores-y' }), $true)
    $exitZero = Get-NextPlanIndex $stages ($restoresIndex + 1) 0 0
    $exitNonZero = Get-NextPlanIndex $stages ($restoresIndex + 1) 0 0x80
    Assert-Equal ([string]$stages[$exitZero].phaseNames[0]) 'shared-prefetch-return' 'F1=00 at 7780 skips the clear-path boundaries and arms 00FC'
    Assert-Equal ([string]$stages[$exitNonZero].boundaryIds[0]) 'port-f1-clear-write' 'F1=80 at 7780 arms the 7786 clear-path boundary'
}

function Invoke-LampSelfTests {
    if (!(Test-Path -LiteralPath $script:ArtifactDirectory -PathType Container)) { New-Item -ItemType Directory -Path $script:ArtifactDirectory -Force | Out-Null }
    $base = Join-Path $script:ArtifactDirectory ('checker-base-' + [guid]::NewGuid().ToString('N'))
    $prepare = Invoke-PrepareTool -RunDirectory $base
    Assert-Equal $prepare.exitCode 0 'PrepareOnly positive exits 0'
    if ($prepare.exitCode -ne 0) { Write-Output $prepare.text; return }
    $preflight = Read-JsonFile (Join-Path $base 'preflight.json')
    Assert-Equal $preflight.status 'prepared_no_launch' 'PrepareOnly status is prepared_no_launch'
    Assert-Equal ([bool]$preflight.mameLaunched) $false 'PrepareOnly did not launch MAME'
    Assert-Equal ([int]$preflight.launchCount) 0 'PrepareOnly launch count is 0'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $base 'events.jsonl'))) 'PrepareOnly created no events.jsonl'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $base 'run-record.json'))) 'PrepareOnly created no run-record.json'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $base 'exit-code.txt'))) 'PrepareOnly created no exit-code.txt'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $base 'arguments.json'))) 'PrepareOnly created only an arguments template'
    Assert-True (Test-Path -LiteralPath (Join-Path $base 'arguments.template.json')) 'PrepareOnly created the arguments template'
    Assert-Equal (Get-Sha256 (Join-Path $base 'roms/m4addr/a6ls.p1')) $script:BuiltSha256 'Prepared run-local ROM is the exact built image'
    Assert-Equal (Get-Sha256 (Join-Path $base 'replay-actions.csv')) $script:ReplaySha256 'Prepared replay hash is pinned'
    Assert-Equal (Get-Sha256 (Join-Path $base 'input.lua')) $script:InputLuaSha256 'Prepared input Lua hash is pinned'
    Assert-Equal (Get-Sha256 (Join-Path $base 'IlLampNatural.lua')) (Get-Sha256 (Join-Path $script:Root 'tools/lua/IlLampNatural.lua')) 'Prepared observer matches the tracked Lua source'
    $second = Invoke-PrepareTool -RunDirectory $base
    Assert-True ($second.exitCode -ne 0) 'PrepareOnly refuses an existing run directory (create-only/not fresh)'
    Test-NativeFrameRomDerivation -RunRomPath (Join-Path $base 'roms/m4addr/a6ls.p1')
    $baseMap = Read-JsonFile (Join-Path $base 'lamp-pattern-source-map.json')
    $basePhases = @(Get-ExpectedPhases $baseMap)
    $baseBoundaries = @(Get-ExpectedBoundaries)
    Test-OrderedArmingPlan -PlanPath (Join-Path $base 'lamp-natural-plan.json') -ExpectedPhases $basePhases -ExpectedBoundaries $baseBoundaries
    $luaPath = Join-Path $script:Root 'tools/lua/IlLampNatural.lua'
    $luaText = Get-Content -LiteralPath $luaPath -Raw
    Assert-True ($luaText -match 'map\.stages') 'Observer Lua consumes the ordered stage plan'
    Assert-True ($luaText -match 'resolveNextStageIndex') 'Observer Lua advances only to the next reachable stage'
    Assert-True ($luaText -match 'checkNativeFrame') 'Observer Lua validates the ROM-derived native frame'
    Assert-True (-not ($luaText -match 'setObservationBreakpoints')) 'Observer Lua has no reset-time all-observation breakpoint arming function'
    Assert-True (-not ($luaText -match 'stopDefs')) 'Observer Lua has no flat all-stop definition table'
    Assert-Equal ([regex]::Matches($luaText,'mem:read_u8').Count) 2 'Observer Lua has exactly two mem:read_u8 call sites, both behind the central allowlist'
    Assert-True (-not ($luaText -match '0x080[123C]')) 'Observer Lua does not name active I/O 0801/0802/0803/080C as a readable address'
    Assert-True ($luaText.Contains('else operand = hex8(readRom8(phase.operandAddress)) end')) 'Inline ROM byte operands use the ROM allowlist'
    Assert-True (-not $luaText.Contains('readRam8(phase.operandAddress)')) 'ROM operands never enter the RAM-only reader'
    Assert-True (-not $luaText.Contains('session.ccSaved49D0')) 'CC restore uses the same session field as the 49D0 save'
    Assert-True ($luaText.Contains('session.ccAt49D0 = state.cc') -and $luaText.Contains('state.cc ~= session.ccAt49D0')) 'Saved and restored CC compare the actual 49D0 snapshot'
    Assert-True ($luaText -match 'local function snapshot\(') 'Observer Lua defines the live CPU snapshot helper'
    Assert-True ($luaText -match 'local function stateFields\(') 'Observer Lua defines the state-field emitter used by phase records'
    Assert-True ($luaText -match 'local function frameSnapshot\(') 'Observer Lua defines the frame-bank snapshot helper'
    Assert-True ($luaText -match 'local function probeDpState\(') 'Observer Lua probes the live DP state rather than fabricating it'
    Assert-True ($luaText -match 'fields\["controlStack" \.\. i\]') 'Observer Lua emits controlStack0..3 raw diagnostics'
    Assert-True ($luaText -match 'branchProofA') 'Observer Lua records the actual branch-path A value'
    $script:LuaParserStatus = 'absent_no_parser_available'
    $badOriginal = Join-Path $base 'wrong-original.p1'
    Copy-Item -LiteralPath (Join-Path $base 'roms/m4addr/a6ls.p1') -Destination $badOriginal -Force
    $wrongRomRun = Join-Path $script:ArtifactDirectory ('wrong-rom-' + [guid]::NewGuid().ToString('N'))
    $wrongRom = Invoke-PrepareTool -RunDirectory $wrongRomRun -OriginalRom $badOriginal
    Assert-True ($wrongRom.exitCode -ne 0) 'PrepareOnly rejects a wrong original ROM identity'
    $wrongMapRun = Join-Path $script:ArtifactDirectory ('wrong-map-' + [guid]::NewGuid().ToString('N'))
    $wrongMap = Invoke-PrepareTool -RunDirectory $wrongMapRun -SourceMapPath (Join-Path $base 'build-report.json')
    Assert-True ($wrongMap.exitCode -ne 0) 'PrepareOnly rejects a wrong source map hash'
    $wrongReportRun = Join-Path $script:ArtifactDirectory ('wrong-report-' + [guid]::NewGuid().ToString('N'))
    $wrongReport = Invoke-PrepareTool -RunDirectory $wrongReportRun -BuildReportPath (Join-Path $base 'lamp-pattern-source-map.json')
    Assert-True ($wrongReport.exitCode -ne 0) 'PrepareOnly rejects a wrong build report hash'
    $wrongMameRun = Join-Path $script:ArtifactDirectory ('wrong-mame-' + [guid]::NewGuid().ToString('N'))
    $wrongMame = Invoke-PrepareTool -RunDirectory $wrongMameRun -MameExecutable (Get-Command powershell).Source
    Assert-True ($wrongMame.exitCode -ne 0) 'PrepareOnly rejects a wrong MAME executable hash'

    $fixtures = Join-Path $script:ArtifactDirectory 'checker-fixtures'
    if (!(Test-Path -LiteralPath $fixtures -PathType Container)) { New-Item -ItemType Directory -Path $fixtures -Force | Out-Null }
    $positiveRuns = @{}
    foreach ($f1 in @(0,1,128,129)) {
        $dir = Join-Path $fixtures ('positive-f1-' + $f1)
        New-SyntheticLampRun -PreparedBase $base -Destination $dir -F1Value $f1 | Out-Null
        $result = Invoke-LampCheck -Run $dir -AllowSyntheticCheck
        Assert-True ([bool]$result.pass) "Synthetic F1=$f1 fixture passes value checks"
        Assert-Equal $result.status 'synthetic_fixture_value_check_passed_not_evidence' "Synthetic F1=$f1 is not evidence"
        Assert-Equal ([bool]$result.naturalClaim) $false "Synthetic F1=$f1 does not claim natural execution"
        $positiveRuns[$f1] = $dir
    }
    $withoutAllow = Invoke-LampCheck -Run $positiveRuns[128]
    Assert-Equal ([bool]$withoutAllow.pass) $false 'Synthetic fixture is rejected without -AllowSynthetic'
    Assert-True ((Get-FailureCodes $withoutAllow) -contains 'synthetic_not_allowed') 'Synthetic rejection names synthetic_not_allowed'

    $negativeCases = @(
        @{ name='missing-firq-mask'; code='phase_cc'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'boundary' -and [string]$x.boundary -eq 'port-sta-0801'){$x.cc='10'}}; $rs } } },
        @{ name='missing-irq-mask'; code='phase_cc'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'boundary' -and [string]$x.boundary -eq 'port-sta-0801'){$x.cc='40'}}; $rs } } },
        @{ name='wrong-built-hash'; code='identity_built'; mutate={ param($r) Set-MetadataField $r 'built_rom' ([ordered]@{ path='x'; length=65536; sha1=$script:BuiltSha1; sha256=('0'*64) }) } },
        @{ name='wrong-map-hash'; code='identity_map'; mutate={ param($r) Set-MetadataField $r 'source_map' ([ordered]@{ path='x'; sha256=('1'*64) }) } },
        @{ name='wrong-report-hash'; code='identity_report'; mutate={ param($r) Set-MetadataField $r 'build_report' ([ordered]@{ path='x'; sha256=('2'*64) }) } },
        @{ name='wrong-replay-hash'; code='identity_replay'; mutate={ param($r) Set-MetadataField $r 'input_replay' ([ordered]@{ path='x'; sha256=('3'*64); input_lua_sha256=$script:InputLuaSha256; classification='tracked_physical_input_replay_no_state_injection' }) } },
        @{ name='wrong-pc'; code='phase_pc'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'shared-body-entry'){$x.pc='00FD'}}; $rs } } },
        @{ name='not-fresh-nvram'; code='fresh_nvram'; mutate={ param($r) $p=Join-Path $r 'nvram'; [IO.File]::WriteAllText((Join-Path $p 'leftover.bin'),'x') } },
        @{ name='forbidden-playback'; code='forbidden_argument'; mutate={ param($r) $p=Join-Path $r 'arguments.json'; $a=@((Read-JsonFile $p)|ForEach-Object{[string]$_}); $a=@('-playback','x')+$a; Write-JsonFile $p @($a) 6 } },
        @{ name='injection'; code='injection'; mutate={ param($r) Edit-JsonFile (Join-Path $r 'session-metadata.json') { param($o) $o.debugger_writes=$true } } },
        @{ name='io-peek'; code='io_read_forbidden'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) $rs.Add([ordered]@{event='memory_read'; ioReadAddress='0803'; note='negative control'}); $rs } } },
        @{ name='missing-phase'; code='phase_count'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) $out=New-Object 'System.Collections.Generic.List[object]'; $removed=$false; foreach($x in $rs){ if(-not $removed -and [string]$x.event -eq 'phase'){$removed=$true; continue}; $out.Add($x)}; $out } } },
        @{ name='mid-instruction-pc'; code='phase_mid_instruction'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-prologue-save-mask'){$x.pc='49CF'}}; $rs } } },
        @{ name='f1-bit0-mistake'; code='branch_coverage'; mutate={ param($r) $tmp=Join-Path (Split-Path $r -Parent) ('f1bit0-' + [guid]::NewGuid().ToString('N')); New-SyntheticLampRun -PreparedBase $base -Destination $tmp -F1Value 128 -OmitToggleStops | Out-Null; Copy-RunFixture $tmp $r } },
        @{ name='frame-write-wrong'; code='frame_write'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'boundary' -and [string]$x.boundary -eq 'frame-write-010f'){$x.preWriteB='00'}}; $rs } } },
        @{ name='frame-other-delta'; code='frame_delta'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-return'){ $parts=@($x.frameAfter.Trim() -split '\s+'); $parts[0]='01'; $x.frameAfter=($parts -join ' ') }}; $rs } } },
        @{ name='input-coin-missing'; code='input_coin'; mutate={ param($r) $p=Join-Path $r 'input-levels.csv'; $lines=@(Get-Content $p); for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match '^2103,([0-9.]+),80,00,1$'){ $lines[$i]="2103,$($Matches[1]),00,00,0" } }; [IO.File]::WriteAllText($p,(($lines -join "`n")+"`n"),$script:Utf8) } },
        @{ name='logical-vs-physical-count'; code='logical_physical_count'; mutate={ param($r) $p=Join-Path $r 'input-levels.csv'; $lines=@(Get-Content $p); $lastOffGrid=-1; for($i=1;$i -lt $lines.Count;$i++){ if($lines[$i] -match '^(\d+),([0-9.]+),00,80,0$' -and [int]$Matches[1] -ge 2225){ $lastOffGrid=$i } }; if($lastOffGrid -ge 0){ $out=New-Object 'System.Collections.Generic.List[string]'; for($i=0;$i -lt $lines.Count;$i++){ if($i -ne $lastOffGrid){ $out.Add($lines[$i]) } }; [IO.File]::WriteAllText($p,(($out -join "`n")+"`n"),$script:Utf8) } } },
        @{ name='wrong-cursor'; code='phase_cursor'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'shared-returned-to-1026'){$x.controlStack0='1026'}}; $rs } } },
        @{ name='wrong-dp'; code='phase_dp'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'caller-dispatch'){$x.dp='01'}}; $rs } } },
        @{ name='wrong-u'; code='phase_u'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'shared-body-entry'){$x.u='066A'}}; $rs } } },
        @{ name='wrong-s'; code='phase_s'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'bridge-jsr-entry'){$x.s='0792'}}; $rs } } },
        @{ name='wrong-x-after-swap'; code='phase_x'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'shared-after-swap'){$x.x='9B22'}}; $rs } } },
        @{ name='wrong-cc-restore'; code='phase_cc'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-epilogue-puls-cc'){$x.ccRestored='54'}}; $rs } } },
        @{ name='wrong-result'; code='result_successor'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'outer-returned-to-9F16'){$x.dataStack0='0001'}}; $rs } } },
        @{ name='wrong-caller-token'; code='phase_token'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'caller-dispatch'){$x.token='9ED7'}}; $rs } } },
        @{ name='native-top-777e-in-prologue'; code='phase_native_frame'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-prologue-save-regs'){$x.controlStack0='777E'; $x.nativeFrameTop='777E'}}; $rs } } },
        @{ name='native-pattern-endian'; code='phase_native_frame'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-prologue-save-regs'){$x.controlStack0='8F78'; $x.nativeFrameTop='8F78'}}; $rs } } },
        @{ name='native-wrong-cc'; code='phase_native_frame'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-prologue-deepest'){$x.nativeSavedCc='54'; $x.controlStack0='5401'; $x.nativeFrameTop='5401'}}; $rs } } },
        @{ name='native-return-slot'; code='phase_native_frame'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-prologue-save-regs'){$x.nativeReturnSlot='0000'}}; $rs } } },
        @{ name='native-mask-wrong'; code='phase_native_frame'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-prologue-save-mask'){$x.nativeMask='02'}}; $rs } } },
        @{ name='native-entry-a-wrong'; code='phase_native_frame'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-prologue-save-regs'){$x.nativeEntryA='00'}}; $rs } } },
        @{ name='native-return-saved-cursor-offset'; code='phase_saved_cursor'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'phase' -and [string]$x.phase -eq 'native-return'){$x.savedCursorOffset='0'; $x.savedCursor='9B24'}}; $rs } } },
        @{ name='native-frame-write-top'; code='phase_native_frame'; mutate={ param($r) Edit-JsonLines (Join-Path $r 'events.jsonl') { param($rs) foreach($x in $rs){ if([string]$x.event -eq 'boundary' -and [string]$x.boundary -eq 'frame-write-010f'){$x.controlStack0='777E'}}; $rs } } },
        @{ name='ordered-plan-out-of-order'; code='plan_stage'; mutate={ param($r) $p=Join-Path $r 'lamp-natural-plan.json'; $plan=Read-JsonFile $p; $stages=@($plan.stages); $tmp=$stages[2]; $stages[2]=$stages[3]; $stages[3]=$tmp; $plan.stages=$stages; Write-JsonFile $p $plan 50 } },
        @{ name='nonphysical-input'; code='input_policy'; mutate={ param($r) Edit-JsonFile (Join-Path $r 'session-metadata.json') { param($o) $o.input_policy='synthetic_adaptive'; $o.input_replay_used=$false } } }
    )
    foreach ($case in $negativeCases) {
        $dir = Join-Path $fixtures ('negative-' + $case.name)
        Copy-RunFixture $positiveRuns[128] $dir
        & $case.mutate $dir
        $result = Invoke-LampCheck -Run $dir -AllowSyntheticCheck
        Assert-Equal ([bool]$result.pass) $false "Negative '$($case.name)' is rejected"
        $codes = Get-FailureCodes $result
        Assert-True ($codes -contains $case.code) "Negative '$($case.name)' reports $($case.code) (observed: $($codes -join ','))"
    }
    # Unexpected set-path records when F1 is zero.
    $unexpectedDir = Join-Path $fixtures 'negative-unexpected-set-branch'
    New-SyntheticLampRun -PreparedBase $base -Destination $unexpectedDir -F1Value 0 | Out-Null
    Edit-JsonLines (Join-Path $unexpectedDir 'events.jsonl') { param($rs) $out=New-Object 'System.Collections.Generic.List[object]'; foreach($x in $rs){ $out.Add($x); if([string]$x.event -eq 'boundary' -and [string]$x.boundary -eq 'port-f1-set-read'){ $out.Add([ordered]@{event='boundary'; boundary='port-f1-set-write'; stopId=$x.stopId; emulatedTime=$x.emulatedTime; pc='7799'; dpAvailable='true'; dp='00'; preWriteA='01'}) } }; $out }
    $unexpected = Invoke-LampCheck -Run $unexpectedDir -AllowSyntheticCheck
    Assert-Equal ([bool]$unexpected.pass) $false 'Unexpected set-branch stop is rejected'
    Assert-True ((Get-FailureCodes $unexpected) -contains 'branch_coverage') 'Unexpected set-branch stop reports branch_coverage'

    $summary = [ordered]@{
        mode = 'self-test'
        checks = $script:Checks
        failures = $script:Failures
        pass = ($script:Failures -eq 0)
        positiveFixtures = @('f1=00','f1=01','f1=80','f1=81','already-on frame target 011F')
        negativeControlCount = $negativeCases.Count + 2
        nativeFrameRomDerivation = 'included_in_checks'
        orderedArmingPlan = 'included_in_checks'
        luaParserStatus = $script:LuaParserStatus
        luaSyntaxProof = 'not_claimed_without_parser'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
    }
    $summaryPath = Join-Path $script:ArtifactDirectory 'checker-selftest.json'
    Write-JsonFile $summaryPath $summary 10
    Write-Output (ConvertTo-Json -InputObject $summary -Depth 6)
    if ($script:Failures -ne 0) { exit 1 }
    exit 0
}

if ($Mode -eq 'Check') {
    if ([string]::IsNullOrWhiteSpace($RunDirectory)) { throw 'RunDirectory is required for Check mode' }
    $result = Invoke-LampCheck -Run $RunDirectory -AllowSyntheticCheck:$AllowSynthetic
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path ([IO.Path]::GetFullPath($RunDirectory)) 'checker-result.json'
    }
    Write-JsonFile $OutputPath $result 40
    Write-Output (ConvertTo-Json -InputObject $result -Depth 8)
    if ([bool]$result.pass) { exit 0 } else { exit 1 }
}
else {
    if (!(Test-Path -LiteralPath $ArtifactDirectory -PathType Container)) { New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null }
    Invoke-LampSelfTests
}
