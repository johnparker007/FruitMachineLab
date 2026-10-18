param(
    [string]$RawRun='artifacts/deepseek/capture-43/natural-caller-stack',
    [string]$SourceRun='artifacts/deepseek/gate-28/natural-service',
    [string]$RomPath='E:\Arcade\MAME0266\roms\m4addr.zip',
    [string]$MamePath='E:\Arcade\MAME0266\mame281.exe',
    [string]$PriorCapture41Fixture='evidence/mpu4/collection/stack-writer-0785-capture41.json',
    [string]$PriorCapture41Run='artifacts/deepseek/capture-41/natural-stack-writer'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath("$PSScriptRoot/..")
function Abs([string]$p){if([IO.Path]::IsPathRooted($p)){[IO.Path]::GetFullPath($p)}else{[IO.Path]::GetFullPath((Join-Path $root $p))}}
function HashFile([string]$p){([BitConverter]::ToString([Security.Cryptography.HashAlgorithm]::Create('SHA256').ComputeHash([IO.File]::ReadAllBytes($p)))-replace '-','')}
function Write-Utf8([string]$path,[string]$text){[IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($false))}
function Copy-Run([string]$destination){New-Item -ItemType Directory -Path $destination|Out-Null;Get-ChildItem -LiteralPath $raw -Force|Copy-Item -Destination $destination -Recurse -Force}
function Set-Byte([string]$path,[int]$offset,[byte]$value){$bytes=[IO.File]::ReadAllBytes($path);$bytes[$offset]=$value;[IO.File]::WriteAllBytes($path,$bytes)}
function Retarget-Arguments([string]$case){
    $p=Join-Path $case 'arguments.json'
    $items=[object[]](Get-Content $p -Raw|ConvertFrom-Json)
    for($i=0;$i -lt $items.Count;$i++){if($items[$i] -is [string] -and $items[$i].StartsWith($raw,[StringComparison]::OrdinalIgnoreCase)){$items[$i]=$case+$items[$i].Substring($raw.Length)}}
    Write-Utf8 $p (ConvertTo-Json -InputObject $items)
}
function Update-Provenance([string]$case,[scriptblock]$mutate){$p=Join-Path $case 'provenance.json';$prov=Get-Content $p -Raw|ConvertFrom-Json;& $mutate $prov $case;Write-Utf8 $p (ConvertTo-Json -InputObject $prov)}
function New-WrongZip([string]$path){
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::Open($path,[IO.Compression.ZipArchiveMode]::Create)
    try{$entry=$zip.CreateEntry('a6ls.p1');$stream=$entry.Open();try{$bytes=[Text.Encoding]::ASCII.GetBytes('not the pinned ROM');$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}finally{$zip.Dispose()}
}
$raw=Abs $RawRun;$source=Abs $SourceRun;$rom=Abs $RomPath;$mame=Abs $MamePath;$priorFixture=Abs $PriorCapture41Fixture;$priorRun=Abs $PriorCapture41Run
$curator=Join-Path $PSScriptRoot 'Curate-StackWriterCapture43.ps1'
$powershell=Join-Path $PSHOME 'powershell.exe'
if(!(Test-Path -LiteralPath $powershell)){$powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'}
foreach($p in @($raw,$source,$rom,$mame,$priorFixture,$priorRun,$curator)){if(!(Test-Path -LiteralPath $p)){throw "Missing $p"}}
$tempRoot=Join-Path ([IO.Path]::GetTempPath()) ("FruitMachineLab-capture43-"+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot|Out-Null
$originalHashes=[ordered]@{}
foreach($name in @('debug.log','debugger.cmd','arguments.json','provenance.json','input.lua','replay-actions.csv','fc4d.bin','queue.bin','stop5cd0.bin','exit-code.txt')){$originalHashes[$name]=HashFile (Join-Path $raw $name)}
$sourceHashes=[ordered]@{};foreach($name in @('input.lua','replay-actions.csv')){$sourceHashes[$name]=HashFile (Join-Path $source $name)}
$priorHashes=[ordered]@{fixture=(HashFile $priorFixture);debug=(HashFile (Join-Path $priorRun 'debug.log'));stop=(HashFile (Join-Path $priorRun 'stop5cd0.bin'))}
$failed=$false
function Invoke-Curator([string[]]$arguments){
    $all=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$curator)+$arguments
    $oldPreference=$ErrorActionPreference;$ErrorActionPreference='Continue'
    try{$output=@(& $powershell @all 2>&1);$code=$LASTEXITCODE}finally{$ErrorActionPreference=$oldPreference}
    return [pscustomobject]@{Exit=$code;Output=(($output|ForEach-Object{"$_"}) -join "`n")}
}
function Run-Negative([string]$name,[scriptblock]$mutate,[hashtable]$overrides=@{}){
    $case=Join-Path $tempRoot $name
    Copy-Run $case;Retarget-Arguments $case
    if($mutate){& $mutate $case}
    $caseMame=$mame;$caseRom=$rom;$caseSource=$source;$casePriorFixture=$priorFixture;$casePriorRun=$priorRun
    if($overrides.ContainsKey('MamePath')){$caseMame=$overrides['MamePath']}
    if($overrides.ContainsKey('RomPath')){$caseRom=$overrides['RomPath']}
    if($overrides.ContainsKey('SourceRun')){$caseSource=$overrides['SourceRun']}
    if($overrides.ContainsKey('PriorCapture41Fixture')){$casePriorFixture=$overrides['PriorCapture41Fixture']}
    if($overrides.ContainsKey('PriorCapture41Run')){$casePriorRun=$overrides['PriorCapture41Run']}
    $result=Invoke-Curator @('-RunDirectory',$case,'-RomPath',$caseRom,'-MamePath',$caseMame,'-SourceRun',$caseSource,'-FixturePath',(Join-Path $case 'fixture.json'),'-PriorCapture41Fixture',$casePriorFixture,'-PriorCapture41Run',$casePriorRun)
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
    $positive=Invoke-Curator @('-RunDirectory',$raw,'-RomPath',$rom,'-MamePath',$mame,'-SourceRun',$source,'-FixturePath',$positiveFixture,'-PriorCapture41Fixture',$priorFixture,'-PriorCapture41Run',$priorRun)
    if($positive.Exit -ne 0){$failed=$true;Write-Output "POSITIVE FAIL exit=$($positive.Exit)";Write-Output $positive.Output}
    elseif(!(Test-Path -LiteralPath $positiveFixture)){$failed=$true;Write-Output 'POSITIVE FAIL fixture not written'}
    else{Write-Output "POSITIVE PASS exit=0 fixture=$positiveFixture"}

    Run-Negative 'wrong-stop-s' {param($case)$p=Join-Path $case 'debug.log';$t=[IO.File]::ReadAllText($p);$t=$t.Replace('SVC pc=5CD0 cyc=0000000003C59CF6 s=078B','SVC pc=5CD0 cyc=0000000003C59CF6 s=078D');Write-Utf8 $p $t}
    Run-Negative 'missing-final-0799-writer' {param($case)$p=Join-Path $case 'debug.log';$t=[IO.File]::ReadAllText($p);$t=[regex]::Replace($t,'(?m)^SW pc=7166 .*\r?\n','');Write-Utf8 $p $t}
    Run-Negative 'missing-final-079f-writer' {param($case)$p=Join-Path $case 'debug.log';$t=[IO.File]::ReadAllText($p);$t=[regex]::Replace($t,'(?m)^SW pc=5A0A .*\r?\n','');Write-Utf8 $p $t}
    Run-Negative 'tampered-0799-writer-value' {param($case)$p=Join-Path $case 'debug.log';$t=[IO.File]::ReadAllText($p);$t=$t.Replace('SW pc=7166 cyc=0000000003C5946A s=0799 u=0672 x=80A6 y=FC4F a=91 b=02 dp=00 cc=C4 719b=00 wpaddr=0799 old=E9 new=02','SW pc=7166 cyc=0000000003C5946A s=0799 u=0672 x=80A6 y=FC4F a=91 b=02 dp=00 cc=C4 719b=00 wpaddr=0799 old=E9 new=03');Write-Utf8 $p $t}
    Run-Negative 'tampered-079f-writer-value' {param($case)$p=Join-Path $case 'debug.log';$t=[IO.File]::ReadAllText($p);$t=$t.Replace('SW pc=5A0A cyc=0000000003C59435 s=079F u=0672 x=80A6 y=FC4F a=91 b=02 dp=00 cc=C0 719b=00 wpaddr=079F old=05 new=0A','SW pc=5A0A cyc=0000000003C59435 s=079F u=0672 x=80A6 y=FC4F a=91 b=02 dp=00 cc=C0 719b=00 wpaddr=079F old=05 new=0B');Write-Utf8 $p $t}
    Run-Negative 'tampered-719b' {param($case)$p=Join-Path $case 'debug.log';$t=[IO.File]::ReadAllText($p);$t=$t.Replace('719b=00','719b=01');Write-Utf8 $p $t}
    Run-Negative 'tampered-irq-frame' {param($case)$p=Join-Path $case 'debug.log';$t=[IO.File]::ReadAllText($p);$t=$t.Replace('wpaddr=0797 old=4F new=71','wpaddr=0797 old=4F new=70');Write-Utf8 $p $t}
    Run-Negative 'tampered-final-ram' {param($case)Set-Byte (Join-Path $case 'stop5cd0.bin') 0x799 0x03}
    Run-Negative 'injected-debugger' {param($case)$p=Join-Path $case 'debugger.cmd';$lines=[Collections.Generic.List[string]](@(Get-Content -LiteralPath $p));$lines.Insert($lines.Count-2,'load injected.asm');Set-Content -LiteralPath $p -Value $lines -Encoding ASCII;Update-Provenance $case {param($prov,$c)$prov.debugger_sha256=HashFile (Join-Path $c 'debugger.cmd')}}
    Run-Negative 'altered-input' {param($case)Add-Content -LiteralPath (Join-Path $case 'input.lua') -Value '-- tampered derivative' -Encoding ASCII;Update-Provenance $case {param($prov,$c)$prov.derived_input_lua_sha256=HashFile (Join-Path $c 'input.lua')}}
    Run-Negative 'altered-arguments' {param($case)$p=Join-Path $case 'arguments.json';$t=[IO.File]::ReadAllText($p);Write-Utf8 $p $t.Replace('"-noreadconfig"','"-readconfig"')}
    Run-Negative 'wrong-exit' {param($case)Set-Content -LiteralPath (Join-Path $case 'exit-code.txt') -Value '1' -Encoding ASCII}

    $wrongMame=Join-Path $tempRoot 'wrong-mame.exe';[IO.File]::WriteAllText($wrongMame,'not the pinned MAME binary')
    Run-Negative 'wrong-mame-hash' $null @{MamePath=$wrongMame}
    $wrongRom=Join-Path $tempRoot 'wrong-rom.zip';New-WrongZip $wrongRom
    Run-Negative 'wrong-rom-hash' $null @{RomPath=$wrongRom}
    $wrongSource=Join-Path $tempRoot 'wrong-source-pin';New-Item -ItemType Directory -Path $wrongSource|Out-Null
    $sourceText=[IO.File]::ReadAllText((Join-Path $source 'input.lua'));Write-Utf8 (Join-Path $wrongSource 'input.lua') ($sourceText+"`n-- tampered source")
    Copy-Item -LiteralPath (Join-Path $source 'replay-actions.csv') -Destination (Join-Path $wrongSource 'replay-actions.csv')
    Run-Negative 'wrong-source' $null @{SourceRun=$wrongSource}
    $wrongPriorFixture=Join-Path $tempRoot 'wrong-capture41.json';[IO.File]::WriteAllText($wrongPriorFixture,'{}')
    Run-Negative 'wrong-prior-fixture' $null @{PriorCapture41Fixture=$wrongPriorFixture}

    foreach($name in $originalHashes.Keys){if((HashFile (Join-Path $raw $name)) -ne $originalHashes[$name]){throw "Original raw changed: $name"}}
    foreach($name in $sourceHashes.Keys){if((HashFile (Join-Path $source $name)) -ne $sourceHashes[$name]){throw "Original source changed: $name"}}
    if((HashFile $priorFixture) -ne $priorHashes.fixture){throw 'Original capture41 fixture changed'}
    if((HashFile (Join-Path $priorRun 'debug.log')) -ne $priorHashes.debug){throw 'Original capture41 debug.log changed'}
    if((HashFile (Join-Path $priorRun 'stop5cd0.bin')) -ne $priorHashes.stop){throw 'Original capture41 stop5cd0 changed'}
    Write-Output 'ORIGINAL RAW/SOURCE/PRIOR FIXTURES UNCHANGED'
}finally{
    if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}
}
if($failed){exit 1}
Write-Output 'All capture43 negative validator checks rejected their isolated tampered copies'
exit 0
