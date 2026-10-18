param(
    [Parameter(Mandatory=$true)][string]$MameExecutable,
    [Parameter(Mandatory=$true)][string]$RomDirectory,
    [Parameter(Mandatory=$true)][string]$OriginalRom,
    [Parameter(Mandatory=$true)][string]$ChangedRom,
    [Parameter(Mandatory=$true)][string]$RunDirectory
)
$ErrorActionPreference = 'Stop'

function Get-HashHex([string]$Path, [string]$Algorithm) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Assert-FreshDirectory([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "Use a fresh isolated directory: $full" }
    return $full
}

$ExpectedOriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$ExpectedOriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$ExpectedChangedOffset = 0x9EDC
$ExpectedOriginalSpan = '795BFF80787E795BFF807AAF792F'
$ExpectedChangedSpan = '795BFF00787E795BFF807AAF792F'
$ExpectedHeaders = @{ body='00F8'; litword='795D'; add='7880'; xor='7AB1'; ret='7931' }
$ExpectedTemplate = @{ f8='3420'; fa='3184'; fc='AEA1'; fe='6E91' }
$Inputs = @(0x0000, 0x0080, 0x0100, 0xFFFF, 0x8000)

$originalSha1 = Get-HashHex $OriginalRom 'SHA1'
$originalSha256 = Get-HashHex $OriginalRom 'SHA256'
if ($originalSha1 -ne $ExpectedOriginalSha1) { throw "Unexpected original ROM SHA1: $originalSha1" }
if ($originalSha256 -ne $ExpectedOriginalSha256) { throw "Unexpected original ROM SHA256: $originalSha256" }
if ((Get-Item -LiteralPath $OriginalRom).Length -ne 65536) { throw 'Unexpected original ROM length' }

$originalBytes = [IO.File]::ReadAllBytes($OriginalRom)
$changedBytes = [IO.File]::ReadAllBytes($ChangedRom)
if ($changedBytes.Length -ne 65536) { throw 'Unexpected changed ROM length' }
$offsets = New-Object System.Collections.Generic.List[int]
for ($i = 0; $i -lt $originalBytes.Length; $i++) {
    if ($originalBytes[$i] -ne $changedBytes[$i]) { $offsets.Add($i) }
}
if ($offsets.Count -ne 1 -or $offsets[0] -ne $ExpectedChangedOffset) {
    throw ('Changed image offsets are not exactly 9EDC: ' + ($offsets -join ','))
}
if ($originalBytes[$ExpectedChangedOffset] -ne 0x80 -or $changedBytes[$ExpectedChangedOffset] -ne 0x00) {
    throw 'Changed image does not replace operand byte 80 with 00'
}
$originalSpan = (($originalBytes[0x9ED9..0x9EE6] | ForEach-Object { $_.ToString('X2') }) -join '')
$changedSpan = (($changedBytes[0x9ED9..0x9EE6] | ForEach-Object { $_.ToString('X2') }) -join '')
if ($originalSpan -ne $ExpectedOriginalSpan) { throw "Unexpected original span: $originalSpan" }
if ($changedSpan -ne $ExpectedChangedSpan) { throw "Unexpected changed span: $changedSpan" }
$changedSha1 = Get-HashHex $ChangedRom 'SHA1'
$changedSha256 = Get-HashHex $ChangedRom 'SHA256'
$mameSha256 = Get-HashHex $MameExecutable 'SHA256'

$runRoot = Assert-FreshDirectory $RunDirectory
New-Item -ItemType Directory -Path $runRoot | Out-Null
$cases = New-Object System.Collections.Generic.List[object]

foreach ($variant in @('Original','Changed')) {
    $rom = if ($variant -eq 'Original') { $OriginalRom } else { $ChangedRom }
    $romSha1 = if ($variant -eq 'Original') { $originalSha1 } else { $changedSha1 }
    foreach ($input in $Inputs) {
        $name = ('{0}-{1:X4}' -f $variant.ToLowerInvariant(), $input)
        $caseRun = Join-Path $runRoot $name
        New-Item -ItemType Directory -Path $caseRun | Out-Null
        foreach ($sub in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
            New-Item -ItemType Directory (Join-Path $caseRun $sub) | Out-Null
        }
        $runRom = Join-Path $caseRun 'roms/m4addr/a6ls.p1'
        Copy-Item -LiteralPath $rom -Destination $runRom
        if ((Get-HashHex $runRom 'SHA1') -ne $romSha1) { throw "Copied ROM identity changed: $name" }

        $commands = @(
            'w@f8=w@7927;w@fa=w@7929;w@fc=w@792b;w@fe=w@792d',
            ('w@600=0x{0:X4}' -f $input),
            's=0x700;u=0x600;dp=0;cc=0x50',
            'w@780=0x9ed7;w@782=0x792f',
            'bpset 795d,y==0x9edb,{printf "VM9_FIRST y=%04X x=%04X u=%04X s=%04X\n",y,x,u,s;go}',
            'bpset 7933,y==0x0782',
            'pc=0xfc;y=0x780',
            'go',
            'printf "VM9_RESULT pc=%04X y=%04X u=%04X s=%04X result=%04X frame=%04X\n",pc,y,u,s,w@600,w@6fe',
            'printf "VM9_SPAN bytes=%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X\n",b@9ed9,b@9eda,b@9edb,b@9edc,b@9edd,b@9ede,b@9edf,b@9ee0,b@9ee1,b@9ee2,b@9ee3,b@9ee4,b@9ee5,b@9ee6',
            'printf "VM9_HEADERS body=%04X litword=%04X add=%04X xor=%04X ret=%04X\n",w@9ed7,w@795b,w@787e,w@7aaf,w@792f',
            'printf "VM9_TEMPLATE f8=%04X fa=%04X fc=%04X fe=%04X\n",w@f8,w@fa,w@fc,w@fe',
            'quit'
        )
        $commands | Set-Content (Join-Path $caseRun 'debugger.cmd')

        $mameArgs = @(
            'm4addr','-noreadconfig',
            '-rompath',((Join-Path $caseRun 'roms')+';'+$RomDirectory),
            '-cfg_directory',"$caseRun/cfg",
            '-nvram_directory',"$caseRun/nvram",
            '-input_directory',"$caseRun/inp",
            '-snapshot_directory',"$caseRun/snap",
            '-comment_directory',"$caseRun/comments",
            '-state_directory',"$caseRun/state",
            '-diff_directory',"$caseRun/diff",
            '-debug','-debugger','windows',
            '-debugscript',(Join-Path $caseRun 'debugger.cmd'),
            '-debuglog','-video','none','-sound','none','-window',
            '-skip_gameinfo','-nothrottle','-seconds_to_run','5'
        )
        $mameArgs | ConvertTo-Json | Set-Content (Join-Path $caseRun 'arguments.json')
        @{
            classification = 'Synthetic isolated original-VM invocation; explicit PC/register/RAM stack and caller-stream seeding; no natural boot or gameplay claim'
            variant = $variant
            input = ('0x{0:X4}' -f $input)
            mame_sha256 = $mameSha256
            rom_sha1 = $romSha1
            run_rom_sha1 = (Get-HashHex $runRom 'SHA1')
            starting_nvram = 'absent'
            starting_configuration = 'absent; -noreadconfig'
            user_inputs = 'none'
        } | ConvertTo-Json | Set-Content (Join-Path $caseRun 'provenance.json')

        Push-Location $caseRun
        try {
            $ErrorActionPreference = 'Continue'
            & $MameExecutable @mameArgs *> console.txt
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            $exitCode | Set-Content exit-code.txt
        }
        finally { Pop-Location }
        if ($exitCode -ne 0) { throw "MAME exited $exitCode for $name" }

        $logPath = Join-Path $caseRun 'debug.log'
        $log = Get-Content -LiteralPath $logPath -Raw
        $logSha256 = Get-HashHex $logPath 'SHA256'
        $resultMatch = [regex]::Match($log, 'VM9_RESULT pc=([0-9A-F]{4}) y=([0-9A-F]{4}) u=([0-9A-F]{4}) s=([0-9A-F]{4}) result=([0-9A-F]{4}) frame=([0-9A-F]{4})')
        $firstMatch = [regex]::Match($log, 'VM9_FIRST y=([0-9A-F]{4}) x=([0-9A-F]{4}) u=([0-9A-F]{4}) s=([0-9A-F]{4})')
        $spanMatch = [regex]::Match($log, 'VM9_SPAN bytes=([0-9A-F]{28})')
        $headersMatch = [regex]::Match($log, 'VM9_HEADERS body=([0-9A-F]{4}) litword=([0-9A-F]{4}) add=([0-9A-F]{4}) xor=([0-9A-F]{4}) ret=([0-9A-F]{4})')
        $templateMatch = [regex]::Match($log, 'VM9_TEMPLATE f8=([0-9A-F]{4}) fa=([0-9A-F]{4}) fc=([0-9A-F]{4}) fe=([0-9A-F]{4})')
        if (!$resultMatch.Success -or !$firstMatch.Success -or !$spanMatch.Success -or !$headersMatch.Success -or !$templateMatch.Success) {
            throw "Missing VM9 observation marker for $name"
        }
        if ($resultMatch.Groups[3].Value -ne '0600') { throw "Unexpected U pointer for $name" }
        if ($resultMatch.Groups[4].Value -ne '0700') { throw "Unexpected S pointer for $name" }
        if ($resultMatch.Groups[6].Value -ne '0782') { throw "Unexpected return frame word for $name" }
        if ($firstMatch.Groups[1].Value -ne '9EDB' -or $firstMatch.Groups[2].Value -ne '795D') {
            throw "Word header did not enter the original body for $name"
        }
        $span = $spanMatch.Groups[1].Value
        $expectedSpan = if ($variant -eq 'Original') { $ExpectedOriginalSpan } else { $ExpectedChangedSpan }
        if ($span -ne $expectedSpan) { throw "Unexpected runtime span for $name" }
        if ($headersMatch.Groups[1].Value -ne $ExpectedHeaders.body -or
            $headersMatch.Groups[2].Value -ne $ExpectedHeaders.litword -or
            $headersMatch.Groups[3].Value -ne $ExpectedHeaders.add -or
            $headersMatch.Groups[4].Value -ne $ExpectedHeaders.xor -or
            $headersMatch.Groups[5].Value -ne $ExpectedHeaders.ret) {
            throw "Unexpected original word headers for $name"
        }
        if ($templateMatch.Groups[1].Value -ne $ExpectedTemplate.f8 -or
            $templateMatch.Groups[2].Value -ne $ExpectedTemplate.fa -or
            $templateMatch.Groups[3].Value -ne $ExpectedTemplate.fc -or
            $templateMatch.Groups[4].Value -ne $ExpectedTemplate.fe) {
            throw "Unexpected dispatch template for $name"
        }

        $case = [ordered]@{
            name = $name
            variant = $variant
            input = ('{0:X4}' -f $input)
            pc = $resultMatch.Groups[1].Value
            y = $resultMatch.Groups[2].Value
            u = $resultMatch.Groups[3].Value
            s = $resultMatch.Groups[4].Value
            result = $resultMatch.Groups[5].Value
            return_frame = $resultMatch.Groups[6].Value
            first_dispatch_y = $firstMatch.Groups[1].Value
            first_dispatch_x = $firstMatch.Groups[2].Value
            first_dispatch_u = $firstMatch.Groups[3].Value
            first_dispatch_s = $firstMatch.Groups[4].Value
            runtime_span = $span
            headers = @{ body=$headersMatch.Groups[1].Value; litword=$headersMatch.Groups[2].Value; add=$headersMatch.Groups[3].Value; xor=$headersMatch.Groups[4].Value; ret=$headersMatch.Groups[5].Value }
            dispatch_template = @{ f8=$templateMatch.Groups[1].Value; fa=$templateMatch.Groups[2].Value; fc=$templateMatch.Groups[3].Value; fe=$templateMatch.Groups[4].Value }
            debug_log_sha256 = $logSha256
            run_directory = $caseRun
            exit_code = $exitCode
        }
        $cases.Add([pscustomobject]$case)
    }
}

$capture = [ordered]@{
    schema_version = 1
    classification = 'Synthetic isolated original-VM invocation of 9ED9 through its original word header, with explicit PC/register/RAM stack and caller-stream seeding. Not natural reset, gameplay or hardware evidence.'
    original_rom = @{ path=$OriginalRom; length=65536; sha1=$originalSha1; sha256=$originalSha256; span=$originalSpan }
    changed_rom = @{ path=$ChangedRom; length=65536; sha1=$changedSha1; sha256=$changedSha256; span=$changedSpan; changed_offsets=@($offsets.ToArray()); changed_offsets_hex=@('9EDC') }
    mame = @{ executable=$MameExecutable; version='0.281'; sha256=$mameSha256 }
    seeding = @{
        pc = '0x00FC (original RAM dispatch template entry)'
        dispatch_template = 'RAM F8..FF copied from original ROM 7927..792E'
        caller_stream = 'RAM 0780=word header 9ED7, 0782=sentinel 792F'
        data_stack = 'U=0600 with input word at 0600..0601'
        return_stack = 'S=0700'
        local_frame = 'F4 not used by this body; no local frame seeded'
        interrupts = 'CC=50 (IRQ and FIRQ masked)'
    }
    contract = @{
        stop = 'PC=7933 after PULS Y, conditioned on Y=0782'
        expected_u = '0600'
        expected_s = '0700'
        expected_return_frame = '0782'
        expected_first_dispatch = 'Y=9EDB X=795D'
    }
    case_count = $cases.Count
    cases = $cases
}
$capture | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $runRoot 'capture.json')
$summary = foreach ($case in $cases) {
    '{0} input={1} result={2} u={3} s={4} frame={5} pc={6} y={7} first={8}/{9} span={10}' -f $case.variant,$case.input,$case.result,$case.u,$case.s,$case.return_frame,$case.pc,$case.y,$case.first_dispatch_y,$case.first_dispatch_x,$case.runtime_span
}
$summary | Set-Content (Join-Path $runRoot 'summary.txt')
Write-Output $runRoot
