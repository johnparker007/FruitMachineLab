param(
    [string]$RawRun='artifacts/deepseek/capture-36/natural-service',
    [string]$SourceRun='artifacts/deepseek/gate-28/natural-service',
    [string]$RomPath='E:\Arcade\MAME0266\roms\m4addr.zip',
    [string]$MamePath='E:\Arcade\MAME0266\mame281.exe',
    [string]$Capture33Fixture='evidence/mpu4/collection/fresh-tone-occurrence-capture33.json',
    [string]$Oracle31Fixture='evidence/mpu4/collection/fresh-tone-occurrence.json'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashFile([string]$p){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create('SHA256').ComputeHash([IO.File]::ReadAllBytes($p)))-replace '-','')}
function Write-Utf8([string]$path,[string]$text){[IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))}
function Copy-Run([string]$destination){
    New-Item -ItemType Directory -Path $destination|Out-Null
    Get-ChildItem -LiteralPath $raw -Force|Copy-Item -Destination $destination -Recurse -Force
}
function Set-Byte([string]$path,[int]$offset,[byte]$value){
    $bytes=[IO.File]::ReadAllBytes($path)
    $bytes[$offset]=$value
    [IO.File]::WriteAllBytes($path,$bytes)
}
function Retarget-Arguments([string]$case){
    $p=Join-Path $case 'arguments.json'
    $items=[object[]](Get-Content $p -Raw|ConvertFrom-Json)
    for($i=0;$i -lt $items.Count;$i++){
        if($items[$i] -is [string] -and $items[$i].StartsWith($raw,[StringComparison]::OrdinalIgnoreCase)){
            $items[$i]=$case+$items[$i].Substring($raw.Length)
        }
    }
    Write-Utf8 $p (ConvertTo-Json -InputObject $items)
}
function New-WrongZip([string]$path){
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::Open($path,[IO.Compression.ZipArchiveMode]::Create)
    try{
        $entry=$zip.CreateEntry('a6ls.p1')
        $stream=$entry.Open()
        try{$bytes=[Text.Encoding]::ASCII.GetBytes('not the pinned ROM');$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
    }finally{$zip.Dispose()}
}
$raw=Abs $RawRun
$source=Abs $SourceRun
$rom=Abs $RomPath
$mame=Abs $MamePath
$cap33=Abs $Capture33Fixture
$oracle31=Abs $Oracle31Fixture
$curator=Join-Path $PSScriptRoot 'Curate-MatchedServiceWindowCapture36.ps1'
$powershell=Join-Path $PSHOME 'powershell.exe'
if(!(Test-Path -LiteralPath $powershell)){$powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'}
foreach($p in @($raw,$source,$rom,$mame,$cap33,$oracle31,$curator)){if(!(Test-Path -LiteralPath $p)){throw "Missing $p"}}
$tempRoot=Join-Path ([IO.Path]::GetTempPath()) ("FruitMachineLab-capture36-"+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot|Out-Null
$originalHashes=[ordered]@{}
foreach($name in @('debug.log','debugger.cmd','arguments.json','provenance.json','input.lua','replay-actions.csv','queue.bin','sv-00.bin','sv-10.bin','fecc-00.bin','fecc-10.bin','cancel.bin','exit-code.txt')){
    $originalHashes[$name]=HashFile (Join-Path $raw $name)
}
$sourceHashes=[ordered]@{}
foreach($name in @('input.lua','replay-actions.csv')){$sourceHashes[$name]=HashFile (Join-Path $source $name)}
$fixtureHashes=[ordered]@{capture33=(HashFile $cap33);oracle31=(HashFile $oracle31)}
$failed=$false
function Invoke-Curator([string[]]$arguments){
    $all=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$curator)+$arguments
    $oldPreference=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    try{$output=@(& $powershell @all 2>&1);$code=$LASTEXITCODE}finally{$ErrorActionPreference=$oldPreference}
    return [pscustomobject]@{Exit=$code;Output=(($output|ForEach-Object{"$_"}) -join "`n")}
}
function Run-Negative([string]$name,[scriptblock]$mutate,[hashtable]$overrides=@{}){
    $case=Join-Path $tempRoot $name
    Copy-Run $case
    Retarget-Arguments $case
    if($mutate){& $mutate $case}
    $caseMame=$mame
    $caseRom=$rom
    $caseSource=$source
    $caseCap33=$cap33
    $caseOracle31=$oracle31
    if($overrides.ContainsKey('MamePath')){$caseMame=$overrides['MamePath']}
    if($overrides.ContainsKey('RomPath')){$caseRom=$overrides['RomPath']}
    if($overrides.ContainsKey('SourceRun')){$caseSource=$overrides['SourceRun']}
    if($overrides.ContainsKey('Capture33Fixture')){$caseCap33=$overrides['Capture33Fixture']}
    if($overrides.ContainsKey('Oracle31Fixture')){$caseOracle31=$overrides['Oracle31Fixture']}
    $result=Invoke-Curator @('-RunDirectory',$case,'-RomPath',$caseRom,'-MamePath',$caseMame,'-SourceRun',$caseSource,'-FixturePath',(Join-Path $case 'fixture.json'),'-Capture33Fixture',$caseCap33,'-Oracle31Fixture',$caseOracle31)
    if($result.Exit -eq 0){
        $script:failed=$true
        Write-Output "NEGATIVE FAIL $name exit=0"
        Write-Output $result.Output
    }else{
        $reason=@($result.Output -split "`n"|Where-Object{$_ -match '\S'})[0]
        Write-Output "NEGATIVE PASS $name exit=$($result.Exit) reason=$reason"
    }
}
try{
    $positiveFixture=Join-Path $tempRoot 'positive-fixture.json'
    $positive=Invoke-Curator @('-RunDirectory',$raw,'-RomPath',$rom,'-MamePath',$mame,'-SourceRun',$source,'-FixturePath',$positiveFixture,'-Capture33Fixture',$cap33,'-Oracle31Fixture',$oracle31)
    if($positive.Exit -ne 0){
        $failed=$true
        Write-Output "POSITIVE FAIL exit=$($positive.Exit)"
        Write-Output $positive.Output
    }elseif(!(Test-Path -LiteralPath $positiveFixture)){
        $failed=$true
        Write-Output 'POSITIVE FAIL fixture not written'
    }else{
        Write-Output "POSITIVE PASS exit=0 fixture=$positiveFixture"
    }

    Run-Negative 'wrong-matched-s' {
        param($case)
        $p=Join-Path $case 'debug.log'
        $t=[IO.File]::ReadAllText($p)
        $t=$t.Replace('fecc10 pc=FECC cyc=000000000390C1E1 s=078D','fecc10 pc=FECC cyc=000000000390C1E1 s=078F')
        Write-Utf8 $p $t
    }
    Run-Negative 'missing-service-return' {
        param($case)
        $p=Join-Path $case 'debug.log'
        $t=[IO.File]::ReadAllText($p)
        $t=[regex]::Replace($t,'(?m)^fecc10 .*\r?\n','')
        Write-Utf8 $p $t
    }
    Run-Negative 'anchor-tampering' {
        param($case)
        $p=Join-Path $case 'debug.log'
        $t=[IO.File]::ReadAllText($p)
        $t=$t.Replace('5c18 pc=5C18 cyc=0000000003902E0C s=0798 u=0672 x=59EB y=FC4F a=91 b=31 dp=00 cc=C0 44=00 45=3497 46=9700 47=0000 49=01A0 4b=00 4c=05 4d=31 4e=10 4f=00 50=10 27e=0102 27f=02 280=0304 281=04 282=05FF 283=FF 719B=00 st0=59E9','5c18 pc=5C18 cyc=0000000003902E0C s=0798 u=0672 x=59EB y=FC4F a=91 b=31 dp=00 cc=C0 44=00 45=3497 46=9700 47=0000 49=01A0 4b=00 4c=05 4d=31 4e=10 4f=00 50=10 27e=0102 27f=02 280=0304 281=04 282=05FF 283=FF 719B=00 st0=59E8')
        Write-Utf8 $p $t
    }
    Run-Negative 'tampered-ram' {param($case) Set-Byte (Join-Path $case 'queue.bin') 0x798 0x58}
    Run-Negative 'missing-saved-return' {param($case) Remove-Item -LiteralPath (Join-Path $case 'fecc-10.bin') -Force}
    Run-Negative 'injected-debugger' {
        param($case)
        $p=Join-Path $case 'debugger.cmd'
        Add-Content -LiteralPath $p -Value 'bpset 0x9000,1,{load injected.asm;go}' -Encoding ASCII
        $provPath=Join-Path $case 'provenance.json'
        $prov=Get-Content $provPath -Raw|ConvertFrom-Json
        $prov.debugger_sha256=HashFile $p
        Write-Utf8 $provPath (ConvertTo-Json -InputObject $prov)
    }
    Run-Negative 'altered-input' {param($case) Add-Content -LiteralPath (Join-Path $case 'input.lua') -Value '-- tampered derivative' -Encoding ASCII}
    Run-Negative 'altered-arguments' {param($case) $p=Join-Path $case 'arguments.json';$t=[IO.File]::ReadAllText($p);Write-Utf8 $p $t.Replace('"-noreadconfig"','"-readconfig"')}
    Run-Negative 'wrong-exit' {param($case) Set-Content -LiteralPath (Join-Path $case 'exit-code.txt') -Value '1' -Encoding ASCII}

    $wrongMame=Join-Path $tempRoot 'wrong-mame.exe'
    [IO.File]::WriteAllText($wrongMame,'not the pinned MAME binary')
    Run-Negative 'wrong-mame-hash' $null @{MamePath=$wrongMame}

    $wrongRom=Join-Path $tempRoot 'wrong-rom.zip'
    New-WrongZip $wrongRom
    Run-Negative 'wrong-rom-hash' $null @{RomPath=$wrongRom}

    $wrongSource=Join-Path $tempRoot 'wrong-source-pin'
    New-Item -ItemType Directory -Path $wrongSource|Out-Null
    $sourceText=[IO.File]::ReadAllText((Join-Path $source 'input.lua'))
    Write-Utf8 (Join-Path $wrongSource 'input.lua') ($sourceText+"`n-- tampered source")
    Copy-Item -LiteralPath (Join-Path $source 'replay-actions.csv') -Destination (Join-Path $wrongSource 'replay-actions.csv')
    Run-Negative 'wrong-source' $null @{SourceRun=$wrongSource}

    $wrongCap33=Join-Path $tempRoot 'wrong-capture33.json'
    [IO.File]::WriteAllText($wrongCap33,'{}')
    Run-Negative 'wrong-capture33-fixture' $null @{Capture33Fixture=$wrongCap33}

    foreach($name in $originalHashes.Keys){if((HashFile (Join-Path $raw $name)) -ne $originalHashes[$name]){throw "Original raw changed: $name"}}
    foreach($name in $sourceHashes.Keys){if((HashFile (Join-Path $source $name)) -ne $sourceHashes[$name]){throw "Original source changed: $name"}}
    if((HashFile $cap33) -ne $fixtureHashes.capture33){throw 'Original capture33 fixture changed'}
    if((HashFile $oracle31) -ne $fixtureHashes.oracle31){throw 'Original oracle31 fixture changed'}
    Write-Output 'ORIGINAL RAW/SOURCE/FIXTURES UNCHANGED'
}finally{
    if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}
}
if($failed){exit 1}
Write-Output 'All capture36 negative validator checks rejected their isolated tampered copies'
exit 0
