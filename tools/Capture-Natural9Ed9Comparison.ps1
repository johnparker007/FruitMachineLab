[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$VariantRom,
    [Parameter(Mandatory=$true)][ValidateSet('Original','Changed')][string]$Variant,
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [ValidateRange(60,1200)][int]$SecondsToRun = 1200,
    [ValidateRange(60,1800)][int]$WallTimeoutSeconds = 1800,
    [ValidateRange(0,64)][int]$Early9Ed9Limit = 0
)
$ErrorActionPreference = 'Stop'

$script:OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:ChangedSha1 = 'e1a42dccd304b7b175aabac99e8400cdad04cf69'
$script:ChangedSha256 = '577f76bd36dfca04dfb01b5f5d0be93e16572f8617c7ca906397c98df36e5107'
$script:ReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:Root = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:Root 'evidence/mpu4/skill-cash/actions.csv' }
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) { $InputLuaPath = Join-Path $script:Root 'evidence/mpu4/skill-cash/input.lua' }

function Get-FmlHash {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Write-FmlJson {
    param([string]$Path,$Object,[int]$Depth = 12)
    $json = ConvertTo-Json -InputObject $Object -Depth $Depth
    [IO.File]::WriteAllText($Path,$json,(New-Object System.Text.UTF8Encoding($false)))
}

function Assert-FmlRom {
    param([string]$Path,[int]$Length,[string]$Sha1,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $actualLength = (Get-Item -LiteralPath $Path).Length
    if ($actualLength -ne $Length) { throw "$Label length is $actualLength, expected $Length" }
    $actualSha1 = Get-FmlHash $Path 'SHA1'
    $actualSha256 = Get-FmlHash $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{ length=$actualLength; sha1=$actualSha1; sha256=$actualSha256 }
}

function Get-FmlChangedOffsets {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length images' }
    $result = New-Object 'System.Collections.Generic.List[int]'
    for ($i=0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { [void]$result.Add($i) } }
    return $result.ToArray()
}

function Format-FmlOffsets {
    param([int[]]$Offsets)
    return (($Offsets | ForEach-Object { '{0:X4}' -f $_ }) -join ',')
}

function Get-FmlDirectoryFileCount {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Container)) { return 0 }
    return @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue).Count
}

function ConvertTo-FmlArgumentString {
    param([string[]]$Arguments)
    $quoted = foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') { '"' + ($text.Replace('\','\\').Replace('"','\"')) + '"' } else { $text }
    }
    return ($quoted -join ' ')
}

function Invoke-FmlProcess {
    param(
        [string]$FilePath,[string[]]$Arguments,[string]$WorkingDirectory,
        [string]$StandardOutputPath,[string]$StandardErrorPath,[int]$TimeoutSeconds,
        [string]$CommandLeasePath
    )
    $argumentString = ConvertTo-FmlArgumentString $Arguments
    $startUtc = [DateTime]::UtcNow
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
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
    if (-not $process.Start()) { throw "Failed to start process: $FilePath" }
    $processId = $process.Id
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $exitCode = $null
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
            & $taskkill /PID $processId /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
        }
        if (-not $process.HasExited) {
            try { $process.Kill() } catch { }
            $process.WaitForExit(30000) | Out-Null
        }
        if ($process.HasExited) { $exitCode = $process.ExitCode }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [IO.File]::WriteAllText($StandardOutputPath,$stdout,(New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($StandardErrorPath,$stderr,(New-Object System.Text.UTF8Encoding($false)))
    }
    finally {
        $stopwatch.Stop()
        if (-not $process.HasExited) {
            $taskkill = Join-Path $env:SystemRoot 'System32/taskkill.exe'
            & $taskkill /PID $processId /T /F 2>&1 | Out-Null
            $process.WaitForExit(30000) | Out-Null
            if ($process.HasExited) { $exitCode = $process.ExitCode }
        }
        $process.Dispose()
    }
    $record = [ordered]@{
        command_id = 'mame-natural-9ed9'
        description = 'Fresh isolated natural MAME run to the first EE22 after EE16'
        command_line = $argumentString
        start_utc = $startUtc.ToString('o')
        end_utc = [DateTime]::UtcNow.ToString('o')
        wall_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds,3)
        timeout_seconds = $TimeoutSeconds
        timed_out = $timedOut
        exit_code = $exitCode
        process_id = $processId
    }
    if ($CommandLeasePath) { Write-FmlJson $CommandLeasePath $record 8 }
    return $record
}

function Set-FmlInputScript {
    param([string]$SourcePath,[string]$DestinationPath,[int]$SkipCallbacks)
    $lua = [IO.File]::ReadAllText($SourcePath)
    $lua = $lua.Replace('local frame=0', "local nudge_take_sent=false`nlocal frame=0")
    $lua = $lua.Replace('local text=display()', "local text=display()`n if not nudge_take_sent and mem:read_u8(0xc9)==22 and text:find('TAKE NUDGE',1,true) then`n  pulse(frame,':BLACK2',1,12,'take_nudge_entry',text)`n  nudge_take_sent=true`n end")
    $lua = $lua.Replace('local frame=0', "local nudge_step_sent=false`nlocal frame=0")
    $lua = $lua.Replace('local text=display()', "local text=display()`n if not nudge_step_sent and mem:read_u8(0xbd)==0x15 and mem:read_u8(0xbe)==3 and text:find('NUDGES',1,true) then`n  pulse(frame,':BLACK2',2,6,'nudge1_request',text)`n  nudge_step_sent=true`n end")
    $lua = $lua.Replace('local frame=0', "local nudge_remaining_sent={}`nlocal nudge_pattern='121'`nlocal frame=0")
    $lua = $lua.Replace('local text=display()', "local text=display()`n local remaining=mem:read_u8(0xbe)`n if mem:read_u8(0xbd)==0x15 and remaining>0 and remaining<3 and not nudge_remaining_sent[remaining] and text:find('NUDGE',1,true) then`n  pulse(frame,':BLACK2',2^tonumber(nudge_pattern:sub(4-remaining,4-remaining)),6,'nudge1_repeat',text)`n  nudge_remaining_sent[remaining]=true`n end")
    $lua = $lua.Replace('local frame=0', "local paid_nudge_step_sent=false`nlocal frame=0")
    $lua = $lua.Replace('local text=display()', "local text=display()`n if not paid_nudge_step_sent and m.time:as_double()>406.6 and mem:read_u8(0xbd)~=0x15 and mem:read_u8(0xbe)>0 and text:find('NUDGE',1,true) then`n  pulse(frame,':BLACK2',2,6,'ordinary_paid_nudge1',text)`n  paid_nudge_step_sent=true`n end")
    $lua = $lua.Replace('local frame=0', "local paid_start_sent=false`nlocal frame=0")
    $lua = $lua.Replace('local text=display()', "local text=display()`n if not paid_start_sent and t>=406.6 then`n  pulse(frame,':BLACK2',128,12,'paid_start',text)`n  paid_start_sent=true`n end")
    $lua = $lua.Replace('local frame=0', "local frame=0`nlocal setup_callbacks_to_skip=$SkipCallbacks")
    $lua = $lua.Replace('emu.register_frame_done(function()', "emu.register_frame_done(function()`n if setup_callbacks_to_skip>0 then`n  assert(m.time:as_double()<0.001,'Unexpected running frame during debugger setup')`n  setup_callbacks_to_skip=setup_callbacks_to_skip-1`n  return`n end")
    [IO.File]::WriteAllText($DestinationPath,$lua,(New-Object System.Text.UTF8Encoding($false)))
}

$run = [IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only run directory: $run" }
if (!(Test-Path -LiteralPath $MameExecutable -PathType Leaf)) { throw "MAME executable is missing: $MameExecutable" }
if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }
if (!(Test-Path -LiteralPath $ReplayPath -PathType Leaf)) { throw "Replay is missing: $ReplayPath" }
if (!(Test-Path -LiteralPath $InputLuaPath -PathType Leaf)) { throw "Input Lua is missing: $InputLuaPath" }

$replayHash = Get-FmlHash $ReplayPath 'SHA256'
if ($replayHash -ine $script:ReplaySha256) { throw "Replay SHA256 is $replayHash, expected $($script:ReplaySha256)" }
$originalIdentity = Assert-FmlRom $OriginalRom 65536 $script:OriginalSha1 $script:OriginalSha256 'original ROM'
$expectedVariant = if ($Variant -eq 'Original') { @{ Sha1=$script:OriginalSha1; Sha256=$script:OriginalSha256 } } else { @{ Sha1=$script:ChangedSha1; Sha256=$script:ChangedSha256 } }
$variantIdentity = Assert-FmlRom $VariantRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 "$Variant ROM"
$originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
$variantBytes = [IO.File]::ReadAllBytes($VariantRom)
$actualChanged = Get-FmlChangedOffsets $originalBytes $variantBytes
$expectedChanged = if ($Variant -eq 'Original') { @() } else { @(0x9EDC,0xFFD1,0xFFD2,0xFFD3,0xFFD4,0xFFD5) }
$actualSorted = @($actualChanged | Sort-Object)
$expectedSorted = @($expectedChanged | Sort-Object)
if (($actualSorted -join ',') -ne ($expectedSorted -join ',')) { throw "Changed offsets differ: actual $(Format-FmlOffsets $actualSorted); expected $(Format-FmlOffsets $expectedSorted)" }

New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) { New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null }
$runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
Copy-Item -LiteralPath $VariantRom -Destination $runRom -ErrorAction Stop
$runRomIdentity = Assert-FmlRom $runRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 'isolated run ROM copy'
Copy-Item -LiteralPath $ReplayPath -Destination (Join-Path $run 'replay-actions.csv') -ErrorAction Stop
Copy-Item -LiteralPath $InputLuaPath -Destination (Join-Path $run 'input.lua') -ErrorAction Stop

$preRunEmpty = [ordered]@{}
foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) { $preRunEmpty[$name] = Get-FmlDirectoryFileCount (Join-Path $run $name) }
$preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
foreach ($key in $preRunEmpty.Keys) { if ($preRunEmpty[$key] -ne 0) { throw "Pre-run directory $key is not empty" } }
Write-FmlJson (Join-Path $run 'pre-run-empty.json') $preRunEmpty 6

$versionOut = Join-Path $run 'mame-version.txt'
$versionErr = Join-Path $run 'mame-version.err.txt'
$versionRecord = Invoke-FmlProcess $MameExecutable @('-version') $run $versionOut $versionErr 60 $null
if ($versionRecord.timed_out -or $versionRecord.exit_code -ne 0) { throw "MAME -version failed: exit=$($versionRecord.exit_code)" }
$mameVersion = ((Get-Content -LiteralPath $versionOut -Raw).Trim() -split "\r?\n")[0]
if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }
$mameHash = Get-FmlHash $MameExecutable 'SHA256'

$replayText = Get-Content -LiteralPath (Join-Path $run 'replay-actions.csv') -Raw
$replayRows = @($replayText -split "\r?\n" | Where-Object { $_ -match '^\d+' })
if ($replayRows.Count -lt 2) { throw 'Replay has too few events' }

# Read-only debugger observation. Every handler hook is gated on the selected
# EE16 window (temp3==1) and exact token/cursor relation; no state is written.
$scFormat = 'SC y=%04X token=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X f4=%04X f6=%04X frame=%04X tick=%04X irq=%02X seed=%04X choice=%02X rate=%02X latch=%04X opt=%04X abort=%04X pending=%04X win=%04X board=%02X pot=%02X cycle=%016X guard=%02X checksum=%02X mode=%02X display=%04X suppress=%04X clock=%04X\n'
$scValues = 'y,w@y,u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@0xf4,w@0xf6,w@(w@0xf4),w@0x2d,b@0x33,w@0x324,b@0x4f,b@0x4e,w@0x90,w@0x719f,w@0x719b,w@0xba,w@0x2fa,b@0xc9,b@0xbf,totalcycles,b@0x2c,b@0x322,b@0x323,w@0x327,b@0xa0,w@0x45'
$fullFormat = ' y=%04X token=%04X x=%04X op0=%04X op1=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X sw0=%04X sw1=%04X sw2=%04X f4=%04X f6=%04X tick=%04X b0305=%02X c=%02X%02X%02X credit=%02X bank=%04X rom9edb=%02X%02X irq=%02X seed=%04X board=%02X win=%04X cycle=%016X\n'
$fullValues = 'y,w@y,x,w@(y+2),w@(y+4),u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@s,w@(s+2),w@(s+4),w@0xf4,w@0xf6,w@(w@0xf4),b@0x305,b@0x7d5,b@0x7d6,b@0x7d7,b@0x2f0,w@0x2fc,b@0x9edb,b@0x9edc,b@0x33,w@0x324,b@0xc9,w@0x2fa,totalcycles'
$handlerFormat = ' pc=%04X token=%04X x=%04X y=%04X u=%04X top=%04X second=%04X third=%04X fourth=%04X s=%04X sw0=%04X sw1=%04X sw2=%04X b0305=%02X c=%02X%02X%02X credit=%02X bank=%04X\n'
$handlerValues = 'pc,w@(y-2),x,y,u,w@u,w@(u+2),w@(u+4),w@(u+6),s,w@s,w@(s+2),w@(s+4),b@0x305,b@0x7d5,b@0x7d6,b@0x7d7,b@0x2f0,w@0x2fc'
$compositeFormat = ' pc=%04X x=%04X y=%04X s=%04X sw0=%04X sw1=%04X\n'
$compositeValues = 'pc,x,y,s,w@s,w@(s+2)'

$extra = New-Object 'System.Collections.Generic.List[string]'
# Original firmware integrity markers from the accepted startup capture.
$extra.Add('bpset 7cd1,1,{printf "ILBOOT_RESET pc=%04X s=%04X cc=%02X\n",pc,s,cc;go}')
$extra.Add('bpset 6750,1,{printf "ILBOOT_INIT_ENTRY pc=%04X u=%04X\n",pc,u;go}')
$extra.Add('bpset 66a5,1,{printf "ILBOOT_ROM_CHECK_ENTRY pc=%04X u=%04X gate719b=%02X\n",pc,u,b@0x719b;go}')
$extra.Add('bpset 66db,1,{printf "ILBOOT_ROM_VERIFY_ENTRY pc=%04X u=%04X expected=%02X%02X%02X%02X%02X start=%04X end=%04X error=%02X\n",pc,u,b@(w@(u+1)),b@(w@(u+1)+1),b@(w@(u+1)+2),b@(w@(u+1)+3),b@(w@(u+1)+4),w@(u+3),w@(u+5),b@(u+7);go}')
$extra.Add('bpset 66f3,1,{printf "ILBOOT_SUM_XOR sum=%02X xor=%02X\n",a,b;go}')
$extra.Add('bpset 6715,1,{printf "ILBOOT_ROTATE_ADD value=%02X\n",a;go}')
$extra.Add('bpset 674c,1,{printf "ILBOOT_ROTATE_SUB_XOR a=%02X b=%02X\n",a,b;go}')
$extra.Add('bpset 674f,1,{printf "ILBOOT_ROM_VERIFY_FAILED error=%02X\n",b;quit}')
$extra.Add('bpset 677e,1,{printf "ILBOOT_ROM_CHECK_RETURN pc=%04X y=%04X u=%04X\n",pc,y,u;go}')
$extra.Add('bpset 67b3,1,{printf "ILBOOT_INIT_TAIL_JMP pc=%04X y=%04X u=%04X\n",pc,y,u;go}')
$extra.Add('bpset 3b1a,1,{printf "ILBOOT_INIT_TAIL_ENTRY pc=%04X y=%04X u=%04X\n",pc,y,u;go}')
$extra.Add('bpset 7cf6,1,{printf "ILBOOT_VM_CALL pc=%04X x=%04X y=%04X u=%04X\n",pc,x,y,u;go}')
$extra.Add('bpset 76c7,1,{printf "ILBOOT_VM_ENTRY pc=%04X x=%04X y=%04X u=%04X s=%04X first_word=%04X\n",pc,x,y,u,s,w@(x);go}')
# Pre-fetch probe at the copied dispatch. Y is the candidate node address.
foreach ($y in @('0xebca','0x9ed9','0x9edd','0x9edf','0x9ee3','0x9ee5','0xebcc')) {
    $extra.Add(('bpset 0xfc,temp0==1 && temp3==1 && y=={0},{{printf "PF{1}",{2};go}}' -f $y,$fullFormat,$fullValues))
}
# Composite 9ED7 body transfer: PC=00F8, X=9ED9, caller successor in Y.
$extra.Add(('bpset 0xf8,temp3==1 && pc==0xf8 && x==0x9ed9 && y==0xebcc,{{printf "CT{0}",{1};go}}' -f $compositeFormat,$compositeValues))
# Primitive handler entries, tied to the exact expected cursor and token pointer.
$extra.Add(('bpset 0x795d,temp3==1 && pc==0x795d && x==0x795d && (y==0x9edb || y==0x9ee1),{{printf "HE{0}",{1};go}}' -f $handlerFormat,$handlerValues))
$extra.Add(('bpset 0x7880,temp3==1 && pc==0x7880 && x==0x7880 && y==0x9edf,{{printf "HE{0}",{1};go}}' -f $handlerFormat,$handlerValues))
$extra.Add(('bpset 0x7ab1,temp3==1 && pc==0x7ab1 && x==0x7ab1 && y==0x9ee5,{{printf "HE{0}",{1};go}}' -f $handlerFormat,$handlerValues))
$extra.Add(('bpset 0x7931,temp3==1 && pc==0x7931 && x==0x7931 && y==0x9ee7,{{printf "HE{0}",{1};go}}' -f $handlerFormat,$handlerValues))
if ($Early9Ed9Limit -gt 0) {
    # Diagnostic only: first literal and return of earlier natural 9ED9 calls.
    $extra.Add(('bpset 0x795d,temp5<{0} && pc==0x795d && x==0x795d && y==0x9edb,{{temp5=temp5+1;printf "E9L{1}",{2};go}}' -f $Early9Ed9Limit,$fullFormat,$fullValues))
    $extra.Add(('bpset 0x7931,temp6<{0} && pc==0x7931 && x==0x7931 && y==0x9ee7,{{temp6=temp6+1;printf "E9R{1}",{2};go}}' -f $Early9Ed9Limit,$fullFormat,$fullValues))
}
# Selected tail and terminal. The terminal observer owns stopping.
$extra.Add(('bpset 0xfc,temp0==1 && temp3==0 && y==0xee16 && b@0x2f0<6,{{printf "TAIL{0}",{1};save tail-entry-ram.bin,0,800;save config-window.bin,7190,1a;temp3=1;go}}' -f $fullFormat,$fullValues))
$extra.Add(('bpset 0xfc,temp0==1 && temp3==1 && y==0xee22,{{printf "TERM{0}",{1};save result-ram.bin,0,800;temp0=0;quit}}' -f $fullFormat,$fullValues))
# Every bpset, including the main dispatch bpset, invokes one paused frame
# callback during debugger setup. The historical fixture skipped extras+main.
$skipCallbacks = $extra.Count + 1
Set-FmlInputScript $InputLuaPath (Join-Path $run 'input.lua') $skipCallbacks

$mainCondition = 'temp0==1 && temp3==1 && y!=0xee22 && y!=0xebca && y!=0x9ed9 && y!=0x9edd && y!=0x9edf && y!=0x9ee3 && y!=0x9ee5 && y!=0xebcc'
$mainAction = 'temp0=1;printf "' + $scFormat + '",' + $scValues + ';go'
$startupAction = 'printf "' + $scFormat + '",' + $scValues + ';save boundary-ram.bin,0,800;save config-entry.bin,7190,1a;temp0=1;temp2=1;go'
$commands = New-Object 'System.Collections.Generic.List[string]'
$commands.Add("bpset 0xfc,$mainCondition,{$mainAction}")
$commands.Add("bpset 0xfc,temp0==0 && temp2==0 && y==0xe247,{$startupAction}")
foreach ($line in $extra) { $commands.Add($line) }
$commands.Add(('gtime #{0}' -f ($SecondsToRun * 1000)))
$commands.Add('save ram-final.bin,0,800')
$commands.Add('quit')
[IO.File]::WriteAllLines((Join-Path $run 'debugger.cmd'),$commands,(New-Object System.Text.UTF8Encoding($false)))

$arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
    '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
    '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
    '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
    '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','windows',
    '-debugscript',(Join-Path $run 'debugger.cmd'),'-debuglog','-video','none','-sound','none',
    '-window','-skip_gameinfo','-nothrottle','-seconds_to_run',[string]$SecondsToRun,
    '-autoboot_delay','0','-autoboot_script',(Join-Path $run 'input.lua'))
Write-FmlJson (Join-Path $run 'arguments.json') @($arguments) 6
Write-FmlJson (Join-Path $run 'provenance.json') ([ordered]@{
    classification = 'Natural fresh-boot emulator execution from reset with the tracked physical-input replay and declared scripted pulses; read-only debugger/Lua observation only'
    variant = $Variant
    variant_description = if ($Variant -eq 'Original') { 'untouched original control image' } else { 'IL 9ED9 operand edit with ordered active integrity repair' }
    original_rom_sha1 = $originalIdentity.sha1
    original_rom_sha256 = $originalIdentity.sha256
    variant_rom_sha1 = $variantIdentity.sha1
    variant_rom_sha256 = $variantIdentity.sha256
    run_rom_sha1_before = $runRomIdentity.sha1
    run_rom_sha256_before = $runRomIdentity.sha256
    changed_offsets_hex = Format-FmlOffsets $actualSorted
    replay_path = 'evidence/mpu4/skill-cash/actions.csv'
    replay_sha256 = $replayHash
    replay_event_count = $replayRows.Count
    input_lua_path = 'evidence/mpu4/skill-cash/input.lua'
    input_lua_sha256_before_modification = Get-FmlHash $InputLuaPath 'SHA256'
    run_input_lua_sha256 = Get-FmlHash (Join-Path $run 'input.lua') 'SHA256'
    mame_executable = [IO.Path]::GetFullPath($MameExecutable)
    mame_sha256 = $mameHash
    mame_version = $mameVersion
    seconds_to_run = $SecondsToRun
    wall_timeout_seconds = $WallTimeoutSeconds
    setup_callbacks_skipped = $skipCallbacks
    observation_commands = $commands.Count
    starting_nvram = 'absent'
    starting_configuration = 'absent; -noreadconfig'
    save_state_loaded = $false
    debugger_writes = $false
    physical_inputs = 'tracked replay plus declared adaptive physical pulses; no PC/RAM/register/ROM injection'
    pre_run_empty_directory_file_counts = $preRunEmpty
    pre_run_rom_directory_files = $preRunRomFiles
}) 12

$leasePath = Join-Path $run 'command-lease.json'
$consolePath = Join-Path $run 'console.txt'
$consoleErrorPath = Join-Path $run 'console.err.txt'
$previousReplay = $env:MPU4_REPLAY
$previousPolicy = $env:MPU4_POLICY
try {
    $env:MPU4_REPLAY = Join-Path $run 'replay-actions.csv'
    $env:MPU4_POLICY = '7'
    $runRecord = Invoke-FmlProcess $MameExecutable $arguments $run $consolePath $consoleErrorPath $WallTimeoutSeconds $leasePath
}
finally {
    $env:MPU4_REPLAY = $previousReplay
    $env:MPU4_POLICY = $previousPolicy
}
Set-Content -LiteralPath (Join-Path $run 'exit-code.txt') -Value ([string]$runRecord.exit_code) -NoNewline
Write-FmlJson (Join-Path $run 'timing.json') $runRecord 8

$logPath = Join-Path $run 'debug.log'
if (!(Test-Path -LiteralPath $logPath -PathType Leaf)) { throw "MAME did not produce debug.log; exit=$($runRecord.exit_code) timed_out=$($runRecord.timed_out)" }
$log = Get-Content -LiteralPath $logPath -Raw
$postRunRom = Assert-FmlRom $runRom 65536 $expectedVariant.Sha1 $expectedVariant.Sha256 'isolated run ROM copy after execution'

# Separate replay and scripted pulses, then a merged run-local physical-input log.
$replayEvents = New-Object 'System.Collections.Generic.List[object]'
foreach ($row in $replayRows) {
    $parts = $row -split ','
    if ($parts.Count -lt 4) { throw "Malformed replay row: $row" }
    $replayEvents.Add([ordered]@{ first_frame=[int]$parts[0]; last_frame=[int]$parts[1]; press_frame=[int]$parts[0]; release_frame=[int]$parts[1]; port=$parts[2]; mask=[int]$parts[3]; reason=if($parts.Count -ge 5){$parts[4]}else{''}; source='replay' })
}
$scriptedPath = Join-Path $run 'actions.csv'
if (!(Test-Path -LiteralPath $scriptedPath -PathType Leaf)) { throw 'Run-local scripted-pulse log is missing' }
$scriptedRows = @(Get-Content -LiteralPath $scriptedPath | Where-Object { $_ -match '^\d+' })
$scriptedEvents = New-Object 'System.Collections.Generic.List[object]'
foreach ($row in $scriptedRows) {
    $parts = $row -split ','
    if ($parts.Count -lt 5) { throw "Malformed scripted-pulse row: $row" }
    $scriptedEvents.Add([ordered]@{ first_frame=[int]$parts[0]; last_frame=[int]$parts[1]; press_frame=[int]$parts[0]; release_frame=[int]$parts[1]; port=$parts[2]; mask=[int]$parts[3]; reason=$parts[4]; source='scripted' })
}
$merged = @($replayEvents + $scriptedEvents | Sort-Object @{Expression={$_.first_frame}},@{Expression={$_.port}},@{Expression={$_.mask}})
$levelsPath = Join-Path $run 'input-levels.csv'
if (!(Test-Path -LiteralPath $levelsPath -PathType Leaf)) { throw 'Run-local input-levels.csv is missing' }
$levels = @{}
foreach ($line in Get-Content -LiteralPath $levelsPath) {
    if ($line -notmatch '^\d+,') { continue }
    $p = $line -split ','
    $levels[[int]$p[0]] = [ordered]@{ aux=[Convert]::ToInt32($p[2],16); black=[Convert]::ToInt32($p[3],16) }
}
$maxLevelFrame = ($levels.Keys | Measure-Object -Maximum).Maximum
$observedMerged = @($merged | Where-Object { $_.first_frame -le $maxLevelFrame })
foreach ($e in $observedMerged) {
    $lastCheck = [Math]::Min($e.last_frame+1,$maxLevelFrame)
    for ($f=$e.first_frame; $f -le $lastCheck; $f++) {
        if (!$levels.ContainsKey($f)) { throw "Input-level log has no frame $f for event $($e.source)/$($e.reason)" }
        $value = if ($e.port -eq ':AUX2') { $levels[$f].aux } else { $levels[$f].black }
        $expectPressed = ($f -ge ($e.first_frame+1) -and $f -le $e.last_frame)
        $pressed = (($value -band [int]$e.mask) -ne 0)
        if ($expectPressed -and !$pressed) { throw "Input event $($e.port)/$($e.mask) is not asserted at frame $f" }
        if (!$expectPressed -and $f -eq ($e.last_frame+1) -and $f -le $maxLevelFrame -and $pressed -and !(@($observedMerged | Where-Object { $_.port -eq $e.port -and ([int]$_.mask -band [int]$e.mask) -ne 0 -and $f -ge ([int]$_.first_frame+1) -and $f -le [int]$_.last_frame }).Count)) { throw "Input event $($e.port)/$($e.mask) is not released after frame $($e.last_frame)" } }
}
$inputHeader = 'first_frame,last_frame,press_frame,release_frame,observed_press_frame,observed_last_pressed_frame,observed_release_frame,port,mask,reason,source'
function Format-FmlInputRow($e) {
    if ($e.first_frame -le $maxLevelFrame) {
        return ('{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}' -f $e.first_frame,$e.last_frame,$e.press_frame,$e.release_frame,($e.first_frame+1),$e.last_frame,($e.last_frame+1),$e.port,$e.mask,$e.reason,$e.source)
    }
    return ('{0},{1},{2},{3},,,{4},{5},{6},{7}' -f $e.first_frame,$e.last_frame,$e.press_frame,$e.release_frame,$e.port,$e.mask,$e.reason,$e.source)
}
$replayCsv = New-Object 'System.Collections.Generic.List[string]'
$replayCsv.Add($inputHeader)
foreach ($e in $replayEvents) { $replayCsv.Add((Format-FmlInputRow $e)) }
[IO.File]::WriteAllLines((Join-Path $run 'replay-events.csv'),$replayCsv,(New-Object System.Text.UTF8Encoding($false)))
$scriptedCsv = New-Object 'System.Collections.Generic.List[string]'
$scriptedCsv.Add($inputHeader)
foreach ($e in $scriptedEvents) { $scriptedCsv.Add((Format-FmlInputRow $e)) }
[IO.File]::WriteAllLines((Join-Path $run 'scripted-pulses.csv'),$scriptedCsv,(New-Object System.Text.UTF8Encoding($false)))
$mergedCsv = New-Object 'System.Collections.Generic.List[string]'
$mergedCsv.Add($inputHeader)
foreach ($e in $observedMerged) { $mergedCsv.Add((Format-FmlInputRow $e)) }
[IO.File]::WriteAllLines((Join-Path $run 'physical-inputs.csv'),$mergedCsv,(New-Object System.Text.UTF8Encoding($false)))

$observation = [ordered]@{
    variant = $Variant
    exit_code = $runRecord.exit_code
    timed_out = $runRecord.timed_out
    wall_seconds = $runRecord.wall_seconds
    emulated_seconds_limit = $SecondsToRun
    run_rom_sha1_after = $postRunRom.sha1
    run_rom_sha256_after = $postRunRom.sha256
    rom_unchanged = ($postRunRom.sha1 -ieq $expectedVariant.Sha1 -and $postRunRom.sha256 -ieq $expectedVariant.Sha256)
    debug_log_sha256 = Get-FmlHash $logPath 'SHA256'
    console_sha256 = Get-FmlHash $consolePath 'SHA256'
    console_error_sha256 = Get-FmlHash $consoleErrorPath 'SHA256'
    replay_event_count = $replayEvents.Count
    observed_replay_event_count = @($replayEvents | Where-Object { $_.first_frame -le $maxLevelFrame }).Count
    scripted_event_count = $scriptedEvents.Count
    scripted_reasons = @($scriptedEvents | ForEach-Object { $_.reason })
    observed_input_max_frame = $maxLevelFrame
    integrity_failure = [regex]::IsMatch($log,'(?m)^ILBOOT_ROM_VERIFY_FAILED ')
    reset_markers = [regex]::Matches($log,'(?m)^ILBOOT_RESET pc=7CD1\b').Count
    checksum_returns = [regex]::Matches($log,'(?m)^ILBOOT_ROM_CHECK_RETURN pc=677E\b').Count
    vm_entry_count = [regex]::Matches($log,'(?m)^ILBOOT_VM_ENTRY pc=76C7\b').Count
    ee16_reached = [regex]::IsMatch($log,'(?m)^TAIL y=EE16\b')
    ee22_reached = [regex]::IsMatch($log,'(?m)^TERM y=EE22\b')
    target_prefetch_y = @([regex]::Matches($log,'(?m)^PF y=([0-9A-F]{4})\b') | ForEach-Object { $_.Groups[1].Value })
    handler_entries = @([regex]::Matches($log,'(?m)^HE pc=([0-9A-F]{4})\b') | ForEach-Object { $_.Groups[1].Value })
    composite_entry_reached = [regex]::IsMatch($log,'(?m)^CT pc=00F8\b')
}
Write-FmlJson (Join-Path $run 'observation.json') $observation 10
Get-ChildItem -LiteralPath $run -File | ForEach-Object { [ordered]@{ name=$_.Name; length=$_.Length; sha256=Get-FmlHash $_.FullName 'SHA256' } } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $run 'hashes.json')

if ($runRecord.timed_out) { throw "MAME exceeded the ${WallTimeoutSeconds}s wall cap; capture preserved at $run" }
if ($runRecord.exit_code -ne 0) { throw "MAME exited $($runRecord.exit_code); inspect $consolePath and $run" }
if (!$observation.rom_unchanged) { throw 'Run ROM copy changed during capture' }
if ($observation.integrity_failure) { throw "Firmware integrity failure marker: $run" }
Write-Output $run
