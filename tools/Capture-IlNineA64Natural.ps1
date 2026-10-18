[CmdletBinding()]
param(
    [ValidateSet('Capture','Analyze','Verify','MapOnly')][string]$Mode = 'Capture',
    [string]$MameExecutable,
    [string]$RomDirectory,
    [string]$OriginalRom,
    [string]$RunDirectory,
    [string]$ReplayPath,
    [string]$InputLuaPath,
    [string]$EvidencePath,
    [ValidateRange(1,120)][int]$SecondsToRun = 120,
    [ValidateRange(30,600)][int]$WallTimeoutSeconds = 600,
    [ValidateRange(1,8)][int]$MaxCalls = 8
)
$ErrorActionPreference = 'Stop'

$script:IlA64Protocol = 'il-9a64-natural-v1'
$script:IlA64OriginalSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$script:IlA64OriginalSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$script:IlA64MameSha256 = '0fce5a88df4f9d9b1fbf1405812c00848036e615993780978d967da34204cb7a'
$script:IlA64ReplaySha256 = '4a051da15264842697879eff396b34a789f5d80623f9a2e749c244e6a80e721d'
$script:IlA64Root = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($ReplayPath)) { $ReplayPath = Join-Path $script:IlA64Root 'evidence/mpu4/skill-cash/actions.csv' }
if ([string]::IsNullOrWhiteSpace($InputLuaPath)) { $InputLuaPath = Join-Path $script:IlA64Root 'evidence/mpu4/skill-cash/input.lua' }
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { $EvidencePath = Join-Path $script:IlA64Root 'evidence/mpu4/integrity/il-9a64-natural.json' }
if ([string]::IsNullOrWhiteSpace($OriginalRom)) { $OriginalRom = Join-Path $script:IlA64Root 'artifacts/deepseek/general-14/roms/original.p1' }

$script:IlA64Utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-IlA64Hash {
    param([string]$Path,[string]$Algorithm)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $hash = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $hash.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Write-IlA64Json {
    param([string]$Path,$Object,[int]$Depth = 24)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Object -Depth $Depth),$script:IlA64Utf8)
}

function ConvertTo-IlA64Int {
    param([string]$Text)
    return [Convert]::ToInt32($Text,16)
}

function Format-IlA64Hex16 {
    param([int]$Value)
    return ('{0:X4}' -f ($Value -band 0xFFFF))
}

function Assert-IlA64Rom {
    param([string]$Path,[string]$Sha1,[string]$Sha256,[string]$Label)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is missing: $Path" }
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -ne 65536) { throw "$Label length is $length, expected 65536" }
    $actualSha1 = Get-IlA64Hash $Path 'SHA1'
    $actualSha256 = Get-IlA64Hash $Path 'SHA256'
    if ($actualSha1 -ine $Sha1) { throw "$Label SHA1 is $actualSha1, expected $Sha1" }
    if ($actualSha256 -ine $Sha256) { throw "$Label SHA256 is $actualSha256, expected $Sha256" }
    return [ordered]@{ path=[IO.Path]::GetFullPath($Path); length=$length; sha1=$actualSha1; sha256=$actualSha256 }
}

function Get-IlA64OffsetList {
    param([byte[]]$A,[byte[]]$B)
    if ($A.Length -ne $B.Length) { throw 'Cannot compare different-length images' }
    $list = New-Object 'System.Collections.Generic.List[int]'
    for ($i=0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { [void]$list.Add($i) } }
    return $list.ToArray()
}

function Get-IlA64Field {
    param($Event,[string]$Name)
    $property = $Event.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return [string]$property.Value
}

function ConvertTo-IlA64LuaString {
    param([string]$Text)
    return '"' + $Text.Replace('\','\\').Replace('"','\"') + '"'
}

function Write-IlA64MapLua {
    param([string]$Path,$Map,[string]$SourceMapSha256)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    [void]$sb.AppendLine('  schemaVersion = 1,')
    [void]$sb.AppendLine(('  protocol = "{0}",' -f $script:IlA64Protocol))
    [void]$sb.AppendLine(('  imageSha256 = "{0}",' -f $Map.outputSha256))
    [void]$sb.AppendLine(('  originalRomSha256 = "{0}",' -f $Map.originalRomSha256))
    [void]$sb.AppendLine(('  bodyStart = 0x{0},' -f $Map.bodyStart))
    [void]$sb.AppendLine(('  bodyEndExclusive = 0x{0},' -f $Map.bodyEndExclusive))
    [void]$sb.AppendLine(('  sourceMapSha256 = "{0}",' -f $SourceMapSha256))
    [void]$sb.AppendLine('  nodes = {')
    foreach ($node in @($Map.nodes)) {
        $bytes = @()
        for ($i=0; $i -lt ([string]$node.bytesHex).Length; $i+=2) { $bytes += ('0x' + ([string]$node.bytesHex).Substring($i,2)) }
        $branchText = 'nil'
        if ($null -ne $node.branch) {
            $branchText = ('{{ nodeIndex = {0}, tokenAddress = 0x{1}, operandAddress = 0x{2}, operandByte = 0x{3}, targetAddress = 0x{4}, condition = "{5}", offsetBase = "{6}", offsetUnsigned = {7}, operandWidthBytes = {8} }}' -f `
                $node.branch.nodeIndex,$node.branch.tokenAddress,$node.branch.operandAddress,$node.branch.operandByte,$node.branch.targetAddress,$node.branch.condition,$node.branch.offsetBase,($(if ($node.branch.offsetUnsigned) { 'true' } else { 'false' })),$node.branch.operandWidthBytes)
        }
        [void]$sb.AppendLine(('    {{ index = {0}, address = 0x{1}, token = 0x{2}, operation = "{3}", handlerPc = 0x{4}, handlerAddress = 0x{5}, bytes = {{{6}}}, branch = {7} }},' -f $node.index,$node.address,$node.token,$node.operation,$node.handlerPc,$node.handlerAddress,($bytes -join ','),$branchText))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  entries = {')
    foreach ($entry in @($Map.entries)) {
        [void]$sb.AppendLine(('    {{ address = 0x{0}, nodeIndex = {1}, token = 0x{2}, operation = "{3}", imageByte = 0x{4} }},' -f $entry.address,$entry.nodeIndex,$entry.token,$entry.operation,$entry.imageByte))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('  branches = {')
    foreach ($branch in @($Map.branches)) {
        [void]$sb.AppendLine(('    {{ nodeIndex = {0}, tokenAddress = 0x{1}, operandAddress = 0x{2}, operandByte = 0x{3}, targetAddress = 0x{4}, condition = "{5}", offsetBase = "{6}", offsetUnsigned = {7}, operandWidthBytes = {8} }},' -f $branch.nodeIndex,$branch.tokenAddress,$branch.operandAddress,$branch.operandByte,$branch.targetAddress,$branch.condition,$branch.offsetBase,($(if ($branch.offsetUnsigned) { 'true' } else { 'false' })),$branch.operandWidthBytes))
    }
    [void]$sb.AppendLine('  },')
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),$script:IlA64Utf8)
}

function Write-IlA64ConfigLua {
    param([string]$Path,$Config)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('return {')
    foreach ($key in $Config.Keys) {
        $value = $Config[$key]
        if ($value -is [int] -or $value -is [long]) { [void]$sb.AppendLine(('  {0} = {1},' -f $key,$value)) }
        else { [void]$sb.AppendLine(('  {0} = "{1}",' -f $key,([string]$value).Replace('"','\"'))) }
    }
    [void]$sb.AppendLine('}')
    [IO.File]::WriteAllText($Path,$sb.ToString(),$script:IlA64Utf8)
}

function Invoke-IlA64Process {
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
        [IO.File]::WriteAllText($StdOutPath,$stdoutTask.GetAwaiter().GetResult(),$script:IlA64Utf8)
        [IO.File]::WriteAllText($StdErrPath,$stderrTask.GetAwaiter().GetResult(),$script:IlA64Utf8)
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

function Invoke-IlA64MapGeneration {
    param([string]$RomPath,[string]$Run)
    $generatorDir = Join-Path $Run 'source-map-gen'
    New-Item -ItemType Directory -Path $generatorDir -ErrorAction Stop | Out-Null
    $projectPath = Join-Path $generatorDir 'IlNineA64MapGen.csproj'
    $programPath = Join-Path $generatorDir 'Program.cs'
    $ilProject = (Join-Path $script:IlA64Root 'src/FruitMachineLab.Il/FruitMachineLab.Il.csproj').Replace('\','/')
    $projectText = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>IlNineA64MapGen</AssemblyName>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="Program.cs" />
    <ProjectReference Include="__IL_PROJECT__" />
  </ItemGroup>
</Project>
'@.Replace('__IL_PROJECT__',$ilProject)
    [IO.File]::WriteAllText($projectPath,$projectText,$script:IlA64Utf8)
    $programText = @'
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FruitMachineLab.Il;

if (args.Length != 3)
{
    Console.Error.WriteLine("usage: IlNineA64MapGen <original-rom> <source-map.json> <build-report.json>");
    return 2;
}

string romPath = Path.GetFullPath(args[0]);
string mapPath = Path.GetFullPath(args[1]);
string buildPath = Path.GetFullPath(args[2]);
byte[] rom = File.ReadAllBytes(romPath);
VmIlDefinition definition = NineASixFourDecoder.Decode(rom);
VmIlCompileResult compile = VmIlCompiler.CompileIdentity(definition, rom);
VmIlSourceMap map = VmIlSourceMap.CreateForBuild(definition, compile.Image, compile.EmittedBody);
IReadOnlyList<NineASixFourBranchHandler> handlers =
    NineASixFourDecoder.DecodeBranchHandlers(rom);

if (!compile.Image.AsSpan().SequenceEqual(rom))
    throw new InvalidDataException("identity compile changed the original image");
if (compile.ChangedOffsets.Length != 0)
    throw new InvalidDataException("identity compile reported changed offsets");

string Hex16(int value) => (value & 0xFFFF).ToString("X4");
string Hex8(int value) => (value & 0xFF).ToString("X2");
string HexBytes(byte[] bytes) => Convert.ToHexString(bytes);
string Sha1(byte[] bytes) => Convert.ToHexString(SHA1.HashData(bytes));
string Sha256(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes));

var handlerByToken = handlers.ToDictionary(item => item.TokenAddress);
var nodeObjects = new List<Dictionary<string, object?>>();
foreach (VmIlNode node in definition.Nodes)
{
    ushort handlerAddress = node.Branch is null
        ? (ushort)(node.Token + 2)
        : node.Branch.HandlerAddress;
    ushort tokenWord = (ushort)((rom[node.Token] << 8) | rom[node.Token + 1]);
    if (tokenWord != handlerAddress)
        throw new InvalidDataException(
            $"token {node.Token:X4} points at {tokenWord:X4}, expected handler {handlerAddress:X4}");

    Dictionary<string, object?>? branch = null;
    if (node.Branch is not null)
    {
        branch = new Dictionary<string, object?>
        {
            ["nodeIndex"] = node.Index,
            ["handlerAddress"] = Hex16(node.Branch.HandlerAddress),
            ["tokenAddress"] = Hex16(node.Address),
            ["operandAddress"] = Hex16(node.Branch.OperandAddress),
            ["operandByte"] = Hex8(node.Branch.OperandByte),
            ["targetAddress"] = Hex16(node.Branch.TargetAddress),
            ["condition"] = node.Branch.Condition.ToString(),
            ["offsetBase"] = node.Branch.OffsetBase,
            ["offsetUnsigned"] = node.Branch.OffsetUnsigned,
            ["operandWidthBytes"] = node.Branch.OperandWidthBytes,
            ["evidenceClass"] = node.Branch.EvidenceClass
        };
    }

    nodeObjects.Add(new Dictionary<string, object?>
    {
        ["index"] = node.Index,
        ["address"] = Hex16(node.Address),
        ["token"] = Hex16(node.Token),
        ["operation"] = node.Operation,
        ["bytesHex"] = HexBytes(node.Bytes),
        ["handlerAddress"] = Hex16(node.Token + 2),
        ["handlerPc"] = Hex16(handlerAddress),
        ["branch"] = branch
    });
}

var entries = map.Entries.Select(entry => new Dictionary<string, object?>
{
    ["address"] = Hex16(entry.Address),
    ["nodeIndex"] = entry.NodeIndex,
    ["token"] = Hex16(entry.Token),
    ["operation"] = entry.Operation,
    ["imageByte"] = Hex8(entry.ImageByte)
}).ToList();

var branches = map.Branches.Select(branch => new Dictionary<string, object?>
{
    ["nodeIndex"] = branch.NodeIndex,
    ["tokenAddress"] = Hex16(branch.TokenAddress),
    ["operandAddress"] = Hex16(branch.OperandAddress),
    ["operandByte"] = Hex8(branch.OperandByte),
    ["targetAddress"] = Hex16(branch.TargetAddress),
    ["condition"] = branch.Condition.ToString(),
    ["offsetBase"] = branch.OffsetBase,
    ["offsetUnsigned"] = branch.OffsetUnsigned,
    ["operandWidthBytes"] = branch.OperandWidthBytes,
    ["evidenceClass"] = branch.EvidenceClass
}).ToList();

var handlerObjects = handlers.Select(handler => new Dictionary<string, object?>
{
    ["tokenAddress"] = Hex16(handler.TokenAddress),
    ["handlerAddress"] = Hex16(handler.HandlerAddress),
    ["operation"] = handler.Operation,
    ["condition"] = handler.Condition.ToString(),
    ["semantics"] = handler.Semantics,
    ["instructions"] = handler.Instructions.Select(instruction => new Dictionary<string, object?>
    {
        ["address"] = Hex16(instruction.Address),
        ["bytesHex"] = HexBytes(instruction.Bytes),
        ["mnemonic"] = instruction.Mnemonic,
        ["operand"] = instruction.Operand
    }).ToList()
}).ToList();

string inputSha1 = Sha1(rom);
string inputSha256 = Sha256(rom);
string outputSha1 = Sha1(compile.Image);
string outputSha256 = Sha256(compile.Image);
string mapIdentity = outputSha256;

var mapDocument = new Dictionary<string, object?>
{
    ["schemaVersion"] = 1,
    ["taskId"] = "il-9a64-finish-15",
    ["classification"] =
        "Source map generated from NineASixFourDecoder.Decode + VmIlCompiler.CompileIdentity + " +
        "VmIlSourceMap.CreateForBuild over the exact identity-checked original ROM. Static map only; " +
        "natural execution is recorded separately.",
    ["originalRomSha1"] = inputSha1,
    ["originalRomSha256"] = inputSha256,
    ["outputSha1"] = outputSha1,
    ["outputSha256"] = outputSha256,
    ["identityBuild"] = true,
    ["changedOffsets"] = Array.Empty<string>(),
    ["headerAddress"] = Hex16(definition.HeaderAddress),
    ["headerValue"] = HexBytes(definition.HeaderBytes),
    ["bodyStart"] = Hex16(definition.BodyStart),
    ["bodyEndExclusive"] = Hex16(definition.BodyEndExclusive),
    ["spanHex"] = HexBytes(rom.AsSpan(definition.BodyStart, definition.BodyLength).ToArray()),
    ["emittedBodyHex"] = HexBytes(compile.EmittedBody),
    ["nodes"] = nodeObjects,
    ["entries"] = entries,
    ["branches"] = branches,
    ["handlers"] = handlerObjects,
    ["provenance"] = new Dictionary<string, object?>
    {
        ["evidenceClass"] = definition.Provenance.EvidenceClass,
        ["listingPath"] = definition.Provenance.ListingPath,
        ["listingSha256"] = definition.Provenance.ListingSha256,
        ["checkpointPath"] = definition.Provenance.CheckpointPath,
        ["checkpointSpanClassification"] = definition.Provenance.CheckpointSpanClassification,
        ["observedSites"] = definition.Provenance.ObservedSites,
        ["sourceMapImageSha256"] = map.IsIdentityBuild ? map.RomSha256 : map.ImageSha256,
        ["sourceMapEntryCount"] = map.Entries.Count,
        ["sourceMapBranchCount"] = map.Branches.Count
    }
};

File.WriteAllText(
    mapPath,
    JsonSerializer.Serialize(mapDocument, new JsonSerializerOptions { WriteIndented = true }) + "\n",
    new UTF8Encoding(false));

var buildDocument = new Dictionary<string, object?>
{
    ["schemaVersion"] = 1,
    ["taskId"] = "il-9a64-finish-15",
    ["classification"] =
        "Identity compilation report from VmIlCompiler.CompileIdentity. The emitted body was written " +
        "back byte-identically; no edit, repair, extension or runtime claim is included.",
    ["decoder"] = "FruitMachineLab.Il.NineASixFourDecoder",
    ["originalSha1"] = inputSha1,
    ["originalSha256"] = inputSha256,
    ["outputSha1"] = outputSha1,
    ["outputSha256"] = outputSha256,
    ["identityImageUnchanged"] = true,
    ["changedOffsets"] = Array.Empty<string>(),
    ["bodyStart"] = Hex16(definition.BodyStart),
    ["bodyEndExclusive"] = Hex16(definition.BodyEndExclusive),
    ["emittedBodyHex"] = HexBytes(compile.EmittedBody),
    ["sourceMapImageSha256"] = mapIdentity,
    ["sourceMapEntryCount"] = map.Entries.Count,
    ["sourceMapBranchCount"] = map.Branches.Count,
    ["checks"] = new Dictionary<string, bool>
    {
        ["strictOriginalIdentity"] = true,
        ["identityImageUnchanged"] = true,
        ["emittedBodyMatchesSpan"] = true,
        ["sourceMapBoundToOutputSha256"] = true,
        ["tokenHandlersVerified"] = true,
        ["branchModelPresent"] = map.Branches.Count == 2
    }
};

File.WriteAllText(
    buildPath,
    JsonSerializer.Serialize(buildDocument, new JsonSerializerOptions { WriteIndented = true }) + "\n",
    new UTF8Encoding(false));
return 0;
'@
    [IO.File]::WriteAllText($programPath,$programText,$script:IlA64Utf8)

    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $dotnet) { throw 'dotnet is required to generate the 9A64 source map from the IL API' }
    $mapOut = Join-Path $Run 'source-map.json'
    $buildOut = Join-Path $Run 'build-report.json'
    $record = Invoke-IlA64Process -FilePath $dotnet.Source -Arguments @('run','--project',$projectPath,'--configuration','Release','--',$RomPath,$mapOut,$buildOut) -WorkingDirectory $script:IlA64Root -StdOutPath (Join-Path $Run 'source-map-gen.out.log') -StdErrPath (Join-Path $Run 'source-map-gen.err.log') -TimeoutSeconds 300
    $record.commandId = 'il-9a64-source-map-generation'
    $record.description = 'Generate source map from NineASixFourDecoder, VmIlCompiler.CompileIdentity and VmIlSourceMap'
    if ($record.timedOut -or $record.exitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath (Join-Path $Run 'source-map-gen.err.log')) { Get-Content -LiteralPath (Join-Path $Run 'source-map-gen.err.log') -Raw } else { '' }
        throw "Source-map generation failed (exit=$($record.exitCode) timedOut=$($record.timedOut)): $stderr"
    }
    return [ordered]@{ record=$record; mapPath=$mapOut; buildPath=$buildOut }
}

function Test-IlA64MapDocument {
    param($Map,[byte[]]$Rom,[string]$ExpectedOutputSha256)
    if ([int]$Map.schemaVersion -ne 1) { throw 'Source map schemaVersion is not 1' }
    if ([string]$Map.originalRomSha256 -ine $script:IlA64OriginalSha256) { throw 'Source map original identity is wrong' }
    if ([string]$Map.outputSha256 -ine $ExpectedOutputSha256) { throw 'Source map output identity is wrong' }
    if ([string]$Map.bodyStart -ine '9A64' -or [string]$Map.bodyEndExclusive -ine '9A72') { throw 'Source map body span is not 9A64..9A72' }
    if ([string]$Map.spanHex -ine '7B6D79820676657979037671792F') { throw 'Source map span is not the checked 9A64 span' }
    if ([string]$Map.emittedBodyHex -ine [string]$Map.spanHex) { throw 'Identity emitted body differs from the original span' }
    if (-not [bool]$Map.identityBuild) { throw 'Source map is not an identity build' }
    if (@($Map.changedOffsets).Count -ne 0) { throw 'Identity source map has changed offsets' }
    $entries = @($Map.entries)
    $nodes = @($Map.nodes)
    $branches = @($Map.branches)
    if ($entries.Count -ne 14) { throw "Source map has $($entries.Count) entries, expected 14" }
    if ($nodes.Count -ne 6) { throw "Source map has $($nodes.Count) nodes, expected 6" }
    if ($branches.Count -ne 2) { throw "Source map has $($branches.Count) branches, expected 2" }
    $expectedAddress = 0x9A64
    $lastNode = -1
    foreach ($entry in $entries) {
        $address = ConvertTo-IlA64Int ([string]$entry.address)
        if ($address -ne $expectedAddress) { throw "Source map is not contiguous at $($entry.address)" }
        if ([int]$entry.nodeIndex -lt $lastNode) { throw "Source map node order is reordered at $($entry.address)" }
        if ([int]$entry.nodeIndex -gt $lastNode) {
            if ([int]$entry.nodeIndex -ne ($lastNode + 1)) { throw "Source map node index gap at $($entry.address)" }
            $lastNode = [int]$entry.nodeIndex
        }
        if ((ConvertTo-IlA64Int ([string]$entry.imageByte)) -ne $Rom[$address]) { throw "Source map byte at $($entry.address) differs from the original ROM" }
        $expectedAddress++
    }
    if ($expectedAddress -ne 0x9A72) { throw 'Source map does not cover the declared body end' }
    if ($lastNode -ne 5) { throw 'Source map does not contain node indices 0..5' }
    foreach ($node in $nodes) {
        $address = ConvertTo-IlA64Int ([string]$node.address)
        $token = ConvertTo-IlA64Int ([string]$node.token)
        $handler = ConvertTo-IlA64Int ([string]$node.handlerPc)
        $liveToken = (([int]$Rom[$address] -shl 8) -bor [int]$Rom[$address+1])
        if ($liveToken -ne $token) { throw "Source map token differs at $($node.address)" }
        $liveHandler = (([int]$Rom[$token] -shl 8) -bor [int]$Rom[$token+1])
        if ($liveHandler -ne $handler) { throw "Token $($node.token) does not point at handler $($node.handlerPc)" }
        $bytesHex = [string]$node.bytesHex
        for ($i=0; $i -lt $bytesHex.Length; $i+=2) {
            if ((ConvertTo-IlA64Int $bytesHex.Substring($i,2)) -ne $Rom[$address + ($i/2)]) { throw "Source map node bytes differ at $($node.address)" }
        }
    }
    $ifZero = @($branches | Where-Object { [string]$_.condition -eq 'IfZero' })
    $always = @($branches | Where-Object { [string]$_.condition -eq 'Always' })
    if ($ifZero.Count -ne 1 -or $always.Count -ne 1) { throw 'Source map branch conditions are not the checked one-zero and one-always pair' }
    foreach ($branch in $branches) {
        if ([string]$branch.offsetBase -ine 'operand-address' -or -not [bool]$branch.offsetUnsigned -or [int]$branch.operandWidthBytes -ne 1) { throw 'Source map branch offset semantics are not the checked unsigned byte form' }
        $operandAddress = ConvertTo-IlA64Int ([string]$branch.operandAddress)
        $operandByte = ConvertTo-IlA64Int ([string]$branch.operandByte)
        $target = ConvertTo-IlA64Int ([string]$branch.targetAddress)
        if ($Rom[$operandAddress] -ne $operandByte) { throw "Branch operand at $($branch.operandAddress) differs from the ROM" }
        if ((($operandAddress + $operandByte) -band 0xFFFF) -ne $target) { throw "Branch target at $($branch.tokenAddress) is not operand-address plus unsigned byte" }
    }
    $zeroBranch = $ifZero[0]
    $alwaysBranch = $always[0]
    if ([string]$zeroBranch.tokenAddress -ine '9A66' -or [string]$zeroBranch.operandAddress -ine '9A68' -or [string]$zeroBranch.operandByte -ine '06' -or [string]$zeroBranch.targetAddress -ine '9A6E') { throw '7982 branch model is not the checked 9A66/9A68/06/9A6E form' }
    if ([string]$alwaysBranch.tokenAddress -ine '9A6B' -or [string]$alwaysBranch.operandAddress -ine '9A6D' -or [string]$alwaysBranch.operandByte -ine '03' -or [string]$alwaysBranch.targetAddress -ine '9A70') { throw '7979 branch model is not the checked 9A6B/9A6D/03/9A70 form' }
    return [ordered]@{ entryCount=$entries.Count; nodeCount=$nodes.Count; branchCount=$branches.Count }
}

function Invoke-IlA64StrictParse {
    param([string]$EventsPath,[string]$OutputPath)
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $pwsh) { throw 'pwsh with System.Text.Json is required for strict event JSON checks' }
    $helper = Join-Path $script:IlA64Root 'tests/worker/Test-IlEventJson.ps1'
    if (!(Test-Path -LiteralPath $helper -PathType Leaf)) { throw "Strict JSON helper is missing: $helper" }
    $outLog = $OutputPath + '.stdout.log'
    $errLog = $OutputPath + '.stderr.log'
    $record = Invoke-IlA64Process -FilePath $pwsh.Source -Arguments @('-NoProfile','-File',$helper,'-Mode','Parse','-EventsPath',$EventsPath,'-OutputPath',$OutputPath) -WorkingDirectory $script:IlA64Root -StdOutPath $outLog -StdErrPath $errLog -TimeoutSeconds 120
    if ($record.timedOut -or $record.exitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath $errLog) { Get-Content -LiteralPath $errLog -Raw } else { '' }
        throw "Strict JSONL parse failed (exit=$($record.exitCode)): $stderr"
    }
    if (!(Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw 'Strict JSONL parser did not write a summary' }
    $summary = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json
    if (-not [bool]$summary.pass) { throw 'Strict JSONL parser reported a failure' }
    return [ordered]@{ summary=$summary; sha256=(Get-IlA64Hash $EventsPath 'SHA256'); recordCount=[int]$summary.nonblank }
}

function Get-IlA64Analysis {
    param([string]$Run,[string]$SourceMapPath,[string]$BuildReportPath,[string]$EventsPath,[string]$OriginalRomPath,[switch]$SkipStrictParse)

    $metadataPath = Join-Path $Run 'session-metadata.json'
    if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf)) { throw "Session metadata is missing: $metadataPath" }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ([string]$metadata.protocol -ne $script:IlA64Protocol) { throw 'Session metadata protocol mismatch' }
    if ([string]::IsNullOrWhiteSpace($SourceMapPath)) { $SourceMapPath = Join-Path $Run 'source-map.json' }
    if ([string]::IsNullOrWhiteSpace($BuildReportPath)) { $BuildReportPath = Join-Path $Run 'build-report.json' }
    if ([string]::IsNullOrWhiteSpace($EventsPath)) { $EventsPath = Join-Path $Run 'events.jsonl' }
    if ([string]::IsNullOrWhiteSpace($OriginalRomPath)) { $OriginalRomPath = [string]$metadata.original_rom.path }
    foreach ($path in @($SourceMapPath,$BuildReportPath,$EventsPath,$OriginalRomPath)) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required analysis input is missing: $path" }
    }

    $romIdentity = Assert-IlA64Rom $OriginalRomPath $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'analysis original ROM'
    $rom = [IO.File]::ReadAllBytes($OriginalRomPath)
    $mapSha256 = Get-IlA64Hash $SourceMapPath 'SHA256'
    $buildSha256 = Get-IlA64Hash $BuildReportPath 'SHA256'
    $expectedMapHash = [string]$metadata.source_map_sha256
    $expectedBuildHash = [string]$metadata.build_report_sha256
    if ($mapSha256 -ine $expectedMapHash) { throw "Source map SHA256 is $mapSha256, expected $expectedMapHash" }
    if ($buildSha256 -ine $expectedBuildHash) { throw "Build report SHA256 is $buildSha256, expected $expectedBuildHash" }
    $map = Get-Content -LiteralPath $SourceMapPath -Raw | ConvertFrom-Json
    $build = Get-Content -LiteralPath $BuildReportPath -Raw | ConvertFrom-Json
    if ([string]$build.originalSha256 -ine $script:IlA64OriginalSha256) { throw 'Build report original identity is wrong' }
    if ([string]$build.outputSha256 -ine $script:IlA64OriginalSha256) { throw 'Build report output is not the identity original image' }
    if (-not [bool]$build.identityImageUnchanged) { throw 'Build report does not assert an unchanged identity image' }
    if (@($build.changedOffsets).Count -ne 0) { throw 'Build report contains changed offsets' }
    if ([string]$build.emittedBodyHex -ine '7B6D79820676657979037671792F') { throw 'Build report emitted body is not the 9A64 span' }
    if ([string]$build.sourceMapImageSha256 -ine $script:IlA64OriginalSha256) { throw 'Build report source map is not bound to the identity image' }
    $mapCheck = Test-IlA64MapDocument $map $rom $script:IlA64OriginalSha256

    $parseInfo = $null
    if ($SkipStrictParse) {
        $records = New-Object 'System.Collections.Generic.List[object]'
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $EventsPath) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $records.Add(($line | ConvertFrom-Json -ErrorAction Stop))
        }
        $parseInfo = [ordered]@{ sha256=(Get-IlA64Hash $EventsPath 'SHA256'); recordCount=$records.Count; strict=$false }
    }
    else {
        $parseOut = Join-Path $Run ('events-strict-' + [guid]::NewGuid().ToString('N') + '.json')
        $strict = Invoke-IlA64StrictParse $EventsPath $parseOut
        $records = New-Object 'System.Collections.Generic.List[object]'
        foreach ($record in @($strict.summary.records)) { $records.Add($record) }
        $parseInfo = [ordered]@{ sha256=$strict.sha256; recordCount=$strict.recordCount; strict=$true; summary=$strict.summary }
    }
    if ($records.Count -eq 0) { throw 'Event log is empty' }

    $ready = @($records | Where-Object { (Get-IlA64Field $_ 'event') -eq 'session_ready' })
    if ($ready.Count -ne 1) { throw "Event log has $($ready.Count) session_ready records, expected 1" }
    if ((Get-IlA64Field $ready[0] 'imageSha256') -ine $script:IlA64OriginalSha256) { throw 'Session ready image identity is wrong' }
    if ((Get-IlA64Field $ready[0] 'originalRomSha256') -ine $script:IlA64OriginalSha256) { throw 'Session ready original identity is wrong' }
    if ((Get-IlA64Field $ready[0] 'sourceMapSha256') -ine $mapSha256) { throw 'Session ready source map identity differs from the analysed map' }
    $completeRecords = @($records | Where-Object { (Get-IlA64Field $_ 'event') -eq 'session_complete' })
    if ($completeRecords.Count -ne 1) { throw "Event log has $($completeRecords.Count) session_complete records, expected 1" }
    $failureRecords = @($records | Where-Object { (Get-IlA64Field $_ 'event') -in @('startup_failure','protocol_failure') })
    if ($failureRecords.Count -ne 0) { throw "Event log contains a failure record: $((Get-IlA64Field $failureRecords[0] 'event'))" }

    $nodeByIndex = @{}
    foreach ($node in @($map.nodes)) { $nodeByIndex[[int]$node.index] = $node }
    $branchByIndex = @{}
    foreach ($branch in @($map.branches)) { $branchByIndex[[int]$branch.nodeIndex] = $branch }

    foreach ($record in $records) {
        $eventName = Get-IlA64Field $record 'event'
        $nodeIndexText = Get-IlA64Field $record 'nodeIndex'
        if ($eventName -eq 'call_entry') {
            $siteYText = Get-IlA64Field $record 'siteY'
            if ($siteYText -notmatch '^[0-9A-Fa-f]{4}$') { throw "call_entry siteY is malformed: $siteYText" }
            $siteY = ConvertTo-IlA64Int $siteYText
            $liveCallToken = (([int]$rom[$siteY] -shl 8) -bor [int]$rom[($siteY + 1) -band 0xFFFF])
            if ($liveCallToken -ne 0x9A62) { throw "call_entry siteY $siteYText holds $('{0:X4}' -f $liveCallToken), not the 9A62 call token" }
            if ((Get-IlA64Field $record 'token') -ine '9A62') { throw 'call_entry token is not the 9A62 call token' }
        }
        elseif ($eventName -eq 'composite_entry') {
            if ((Get-IlA64Field $record 'pc') -ine '00F8') { throw 'composite_entry PC is not the 00F8 trampoline' }
            if ((Get-IlA64Field $record 'x') -ine '9A64') { throw 'composite_entry X is not the 9A64 body address' }
        }
        elseif ($eventName -eq 'node_prefetch') {
            if ($nodeIndexText -notmatch '^\d+$') { throw "node_prefetch nodeIndex is malformed: $nodeIndexText" }
            $nodeIndex = [int]$nodeIndexText
            if (-not $nodeByIndex.ContainsKey($nodeIndex)) { throw "node_prefetch nodeIndex $nodeIndex is not mapped" }
            $node = $nodeByIndex[$nodeIndex]
            if ((Get-IlA64Field $record 'nodeAddress') -ine [string]$node.address) { throw "node_prefetch nodeAddress differs from the source map at node $nodeIndex" }
            if ((Get-IlA64Field $record 'y') -ine [string]$node.address) { throw "node_prefetch Y differs from mapped node $nodeIndex address" }
            if ((Get-IlA64Field $record 'token') -ine [string]$node.token) { throw "node_prefetch token differs from mapped node $nodeIndex token" }
            if ((Get-IlA64Field $record 'operation') -ine [string]$node.operation) { throw "node_prefetch operation differs from mapped node $nodeIndex operation" }
        }
        elseif ($eventName -eq 'handler_entry') {
            if ($nodeIndexText -notmatch '^\d+$') { throw "handler_entry nodeIndex is malformed: $nodeIndexText" }
            $nodeIndex = [int]$nodeIndexText
            if (-not $nodeByIndex.ContainsKey($nodeIndex)) { throw "handler_entry nodeIndex $nodeIndex is not mapped" }
            $node = $nodeByIndex[$nodeIndex]
            $expectedHandlerY = Format-IlA64Hex16 ((ConvertTo-IlA64Int ([string]$node.address)) + 2)
            $expectedHandlerX = Format-IlA64Hex16 ((ConvertTo-IlA64Int ([string]$node.token)) + 2)
            if ((Get-IlA64Field $record 'nodeAddress') -ine [string]$node.address) { throw "handler_entry nodeAddress differs from the source map at node $nodeIndex" }
            if ((Get-IlA64Field $record 'pc') -ine [string]$node.handlerPc) { throw "handler_entry PC differs from mapped node $nodeIndex handler" }
            if ((Get-IlA64Field $record 'y') -ine $expectedHandlerY) { throw "handler_entry Y is not node $nodeIndex + 2" }
            if ((Get-IlA64Field $record 'x') -ine $expectedHandlerX) { throw "handler_entry X is not token pointer $nodeIndex + 2" }
            if ((Get-IlA64Field $record 'token') -ine [string]$node.token) { throw "handler_entry token differs from mapped node $nodeIndex token" }
            if ((Get-IlA64Field $record 'operation') -ine [string]$node.operation) { throw "handler_entry operation differs from mapped node $nodeIndex operation" }
            if ($null -ne $node.branch) {
                $operandAddressText = Get-IlA64Field $record 'operandAddress'
                $operandByteText = Get-IlA64Field $record 'operandByte'
                $targetAddressText = Get-IlA64Field $record 'targetAddress'
                if ($operandAddressText -ine [string]$node.branch.operandAddress) { throw "handler_entry branch operand address differs from the source map at node $nodeIndex" }
                if ($operandByteText -ine [string]$node.branch.operandByte) { throw "handler_entry branch operand byte differs from the source map at node $nodeIndex" }
                if ($targetAddressText -ine [string]$node.branch.targetAddress) { throw "handler_entry branch target differs from the source map at node $nodeIndex" }
            }
        }
        elseif ($eventName -eq 'post_return_prefetch') {
            $savedCursorText = Get-IlA64Field $record 'savedCursor'
            if ($savedCursorText -notmatch '^[0-9A-Fa-f]{4}$') { throw "post_return_prefetch savedCursor is malformed: $savedCursorText" }
            if ((Get-IlA64Field $record 'y') -ine $savedCursorText) { throw 'post_return_prefetch Y differs from the saved caller cursor' }
            $savedCursor = ConvertTo-IlA64Int $savedCursorText
            $livePostToken = (([int]$rom[$savedCursor] -shl 8) -bor [int]$rom[($savedCursor + 1) -band 0xFFFF])
            if ((Get-IlA64Field $record 'token') -ine ('{0:X4}' -f $livePostToken)) { throw 'post_return_prefetch token differs from the ROM word at the saved cursor' }
        }
    }

    $callIds = New-Object 'System.Collections.Generic.List[int]'
    foreach ($record in $records) {
        $callId = Get-IlA64Field $record 'callId'
        if ($null -ne $callId -and $callId -match '^\d+$') {
            if (-not $callIds.Contains([int]$callId)) { $callIds.Add([int]$callId) }
        }
    }
    $callIds.Sort()

    $calls = New-Object 'System.Collections.Generic.List[object]'
    $branchPaths = New-Object 'System.Collections.Generic.List[string]'
    $observedNodes = New-Object 'System.Collections.Generic.List[int]'
    $observedHandlers = New-Object 'System.Collections.Generic.List[string]'
    $returnTransitions = New-Object 'System.Collections.Generic.List[object]'
    $completed = 0

    foreach ($callId in $callIds) {
        $callEvents = @($records | Where-Object { (Get-IlA64Field $_ 'callId') -eq [string]$callId })
        $entry = @($callEvents | Where-Object { (Get-IlA64Field $_ 'event') -eq 'call_entry' })
        $composite = @($callEvents | Where-Object { (Get-IlA64Field $_ 'event') -eq 'composite_entry' })
        $nodeEvents = @($callEvents | Where-Object { (Get-IlA64Field $_ 'event') -eq 'node_prefetch' })
        $handlerEvents = @($callEvents | Where-Object { (Get-IlA64Field $_ 'event') -eq 'handler_entry' })
        $postReturn = @($callEvents | Where-Object { (Get-IlA64Field $_ 'event') -eq 'post_return_prefetch' })
        $complete = @($callEvents | Where-Object { (Get-IlA64Field $_ 'event') -eq 'call_complete' })
        if ($entry.Count -ne 1) { throw "Call $callId has $($entry.Count) call_entry records, expected 1" }
        if ((Get-IlA64Field $entry[0] 'token') -ine '9A62') { throw "Call $callId did not enter through token 9A62" }
        $nodeSequence = @($nodeEvents | ForEach-Object { [int](Get-IlA64Field $_ 'nodeIndex') })
        $handlerSequence = @($handlerEvents | ForEach-Object { (Get-IlA64Field $_ 'pc') })
        $nodeText = ($nodeSequence -join ',')
        $handlerText = ($handlerSequence -join ',')
        $call = [ordered]@{
            callId = $callId
            callSiteY = Get-IlA64Field $entry[0] 'siteY'
            callSiteToken = Get-IlA64Field $entry[0] 'token'
            callSiteU = Get-IlA64Field $entry[0] 'u'
            callSiteS = Get-IlA64Field $entry[0] 's'
            emulatedTime = Get-IlA64Field $entry[0] 'emulatedTime'
            callerSuccessor = if ($composite.Count -eq 1) { Get-IlA64Field $composite[0] 'callerSuccessor' } else { $null }
            compositePC = if ($composite.Count -eq 1) { Get-IlA64Field $composite[0] 'pc' } else { $null }
            compositeX = if ($composite.Count -eq 1) { Get-IlA64Field $composite[0] 'x' } else { $null }
            nodeSequence = $nodeText
            handlerSequence = $handlerText
            nodeCount = $nodeEvents.Count
            handlerCount = $handlerEvents.Count
            completeRecord = ($complete.Count -eq 1)
            completed = $false
            branchPath = $null
            branchConditionCell = $null
            branchOperandAddress = $null
            branchOperandByte = $null
            branchNextY = $null
            branchUAdvance = $null
            returnSavedCursor = $null
            returnS = $null
            postReturnY = $null
            postReturnS = $null
            postReturnToken = $null
            returnSAdvanced = $null
            errors = New-Object 'System.Collections.Generic.List[string]'
        }

        foreach ($nodeIndex in $nodeSequence) {
            if (-not $observedNodes.Contains($nodeIndex)) { $observedNodes.Add($nodeIndex) }
        }
        foreach ($handlerPc in $handlerSequence) {
            if (-not $observedHandlers.Contains($handlerPc)) { $observedHandlers.Add($handlerPc) }
        }

        $isComplete = $false
        if ($complete.Count -eq 1) {
            if ($postReturn.Count -ne 1) { [void]$call.errors.Add('call_complete record without one post_return_prefetch') }
            elseif ($composite.Count -ne 1) { [void]$call.errors.Add('call_complete record without one composite_entry') }
            elseif ($nodeText -eq '0,1,2,3,5' -and $handlerText -eq '7B6F,7984,7667,797B,7931') {
                $call.branchPath = 'nonzero'
                $isComplete = $true
            }
            elseif ($nodeText -eq '0,1,4,5' -and $handlerText -eq '7B6F,7984,7673,7931') {
                $call.branchPath = 'zero'
                $isComplete = $true
            }
            else {
                [void]$call.errors.Add("unsupported observed sequence nodes=$nodeText handlers=$handlerText")
            }
        }
        else {
            if ($postReturn.Count -gt 0) { [void]$call.errors.Add('post_return_prefetch without one call_complete record') }
        }

        if ($isComplete) {
            $branchHandler = @($handlerEvents | Where-Object { [int](Get-IlA64Field $_ 'nodeIndex') -eq 1 })
            if ($branchHandler.Count -ne 1) { [void]$call.errors.Add('complete call lacks one 7982 branch handler') }
            else {
                $bh = $branchHandler[0]
                $call.branchConditionCell = Get-IlA64Field $bh 'conditionCell'
                $call.branchOperandAddress = Get-IlA64Field $bh 'operandAddress'
                $call.branchOperandByte = Get-IlA64Field $bh 'operandByte'
                $branchModel = $branchByIndex[1]
                if ([string]$call.branchOperandAddress -ine [string]$branchModel.operandAddress) { [void]$call.errors.Add('observed 7982 operand address differs from the source map') }
                if ([string]$call.branchOperandByte -ine [string]$branchModel.operandByte) { [void]$call.errors.Add('observed 7982 operand byte differs from the source map') }
                $branchNodePosition = [Array]::IndexOf($nodeSequence,1)
                if ($branchNodePosition -lt 0 -or $branchNodePosition + 1 -ge $nodeSequence.Count) { [void]$call.errors.Add('branch node has no observed successor') }
                else {
                    $nextNodeEvent = $nodeEvents[$branchNodePosition + 1]
                    $call.branchNextY = Get-IlA64Field $nextNodeEvent 'y'
                    $expectedNext = if ($call.branchPath -eq 'zero') { [string]$branchModel.targetAddress } else { [string]$nodeByIndex[2].address }
                    if ([string]$call.branchNextY -ine $expectedNext) { [void]$call.errors.Add("observed next Y $($call.branchNextY) differs from expected $expectedNext") }
                    $handlerU = ConvertTo-IlA64Int ([string](Get-IlA64Field $bh 'u'))
                    $nextU = ConvertTo-IlA64Int ([string](Get-IlA64Field $nextNodeEvent 'u'))
                    $call.branchUAdvance = Format-IlA64Hex16 ($nextU - $handlerU)
                    if ((($handlerU + 2) -band 0xFFFF) -ne $nextU) { [void]$call.errors.Add('U did not advance by exactly 2 across the 7982 handler') }
                    if ([string]$call.branchConditionCell -ine [string](Get-IlA64Field $bh 'dataStack0')) { [void]$call.errors.Add('condition cell differs from the handler data-stack top') }
                    if ($call.branchPath -eq 'zero' -and [string]$call.branchConditionCell -ine '0000') { [void]$call.errors.Add('zero path condition cell is not 0000') }
                    if ($call.branchPath -eq 'nonzero' -and [string]$call.branchConditionCell -ieq '0000') { [void]$call.errors.Add('nonzero path condition cell is 0000') }
                }
            }
            if ($call.branchPath -eq 'nonzero') {
                $unconditionalHandler = @($handlerEvents | Where-Object { [int](Get-IlA64Field $_ 'nodeIndex') -eq 3 })
                if ($unconditionalHandler.Count -ne 1) { [void]$call.errors.Add('nonzero complete call lacks one 7979 handler') }
                else {
                    $uh = $unconditionalHandler[0]
                    $branchModel = $branchByIndex[3]
                    if ([string](Get-IlA64Field $uh 'operandAddress') -ine [string]$branchModel.operandAddress) { [void]$call.errors.Add('observed 7979 operand address differs from the source map') }
                    if ([string](Get-IlA64Field $uh 'operandByte') -ine [string]$branchModel.operandByte) { [void]$call.errors.Add('observed 7979 operand byte differs from the source map') }
                    $unconditionalPosition = [Array]::IndexOf($nodeSequence,3)
                    if ($unconditionalPosition -lt 0 -or $unconditionalPosition + 1 -ge $nodeSequence.Count) { [void]$call.errors.Add('unconditional branch node has no observed successor') }
                    else {
                        $nextY = Get-IlA64Field $nodeEvents[$unconditionalPosition + 1] 'y'
                        if ([string]$nextY -ine [string]$branchModel.targetAddress) { [void]$call.errors.Add("7979 next Y $nextY differs from target $($branchModel.targetAddress)") }
                    }
                }
            }
            $returnHandler = @($handlerEvents | Where-Object { [int](Get-IlA64Field $_ 'nodeIndex') -eq 5 })
            if ($returnHandler.Count -ne 1) { [void]$call.errors.Add('complete call lacks one 792F return handler') }
            else {
                $rh = $returnHandler[0]
                $call.returnSavedCursor = Get-IlA64Field $rh 'savedCursor'
                $call.returnS = Get-IlA64Field $rh 's'
                $pr = $postReturn[0]
                $call.postReturnY = Get-IlA64Field $pr 'y'
                $call.postReturnS = Get-IlA64Field $pr 's'
                $call.postReturnToken = Get-IlA64Field $pr 'token'
                if ([string]$call.postReturnY -ine [string]$call.returnSavedCursor) { [void]$call.errors.Add('post-return Y differs from the saved caller cursor') }
                if ([string]$call.postReturnY -ine [string]$call.callerSuccessor) { [void]$call.errors.Add('post-return Y differs from the composite caller successor') }
                $returnS = ConvertTo-IlA64Int ([string]$call.returnS)
                $postS = ConvertTo-IlA64Int ([string]$call.postReturnS)
                $call.returnSAdvanced = Format-IlA64Hex16 ($postS - $returnS)
                if ((($returnS + 2) -band 0xFFFF) -ne $postS) { [void]$call.errors.Add('post-return S is not the return handler S advanced by JMP/PULS') }
                $savedCursor = ConvertTo-IlA64Int ([string]$call.returnSavedCursor)
                $expectedToken = Format-IlA64Hex16 (([int]$rom[$savedCursor] -shl 8) -bor [int]$rom[($savedCursor + 1) -band 0xFFFF])
                if ([string]$call.postReturnToken -ine $expectedToken) { [void]$call.errors.Add('post-return token differs from the ROM word at the saved cursor') }
                $returnTransitions.Add([ordered]@{
                    callId = $callId
                    savedCursor = $call.returnSavedCursor
                    returnS = $call.returnS
                    postReturnY = $call.postReturnY
                    postReturnS = $call.postReturnS
                    postReturnToken = $call.postReturnToken
                    sAdvance = $call.returnSAdvanced
                })
            }
        }

        if ($call.errors.Count -eq 0 -and $isComplete) {
            $call.completed = $true
            $completed++
            if (-not $branchPaths.Contains([string]$call.branchPath)) { $branchPaths.Add([string]$call.branchPath) }
        }
        elseif ($call.errors.Count -gt 0) {
            throw "Call $callId failed 9A64 branch/return validation: $($call.errors -join '; ')"
        }
        $calls.Add($call)
    }

    $observedNodeText = @($observedNodes | Sort-Object | ForEach-Object { [string]$_ }) -join ','
    $observedHandlerText = @($observedHandlers | Sort-Object) -join ','
    $gaps = New-Object 'System.Collections.Generic.List[string]'
    if ($calls.Count -eq 0) {
        $gaps.Add('No natural 9A64 call entered within the emulated budget with the tracked physical replay.')
    }
    if ($calls.Count -gt 0 -and $completed -eq 0) {
        $gaps.Add('At least one 9A64 call started, but none reached a complete return/post-return boundary within the budget.')
    }
    if ($completed -gt 0) {
        if (-not $branchPaths.Contains('zero')) {
            $gaps.Add('Zero-condition 7982 path was not observed: 9A6E, the 7671 handler and the final return after the clear path remain unobserved in this capture.')
        }
        if (-not $branchPaths.Contains('nonzero')) {
            $gaps.Add('Nonzero 7982 fall-through path was not observed: 9A69, the 9A6B/7979 pair and the 7667 handler remain unobserved in this capture.')
        }
    }
    $unobserved = New-Object 'System.Collections.Generic.List[object]'
    foreach ($index in ($nodeByIndex.Keys | Sort-Object)) {
        if (-not $observedNodes.Contains([int]$index)) {
            $unobserved.Add([ordered]@{ index=[int]$index; address=[string]$nodeByIndex[$index].address; token=[string]$nodeByIndex[$index].token; operation=[string]$nodeByIndex[$index].operation })
        }
    }
    if ($unobserved.Count -gt 0) {
        $gaps.Add('Nodes not observed in this capture (not labelled executed): ' + (($unobserved | ForEach-Object { "$($_.address) $($_.operation)" }) -join '; '))
    }
    $gaps.Add('No memory OR/clear effect is claimed. The 7665/7671 handler contracts were not re-derived beyond the tracked native evidence and original ROM bytes in this task.')

    $status = 'no_natural_9a64_call_observed'
    if ($completed -gt 0) { $status = 'complete_natural_calls_observed' }
    elseif ($calls.Count -gt 0) { $status = 'partial_natural_call_observed' }

    return [ordered]@{
        status = $status
        map = [ordered]@{
            path = [IO.Path]::GetFullPath($SourceMapPath)
            sha256 = $mapSha256
            originalRomSha256 = [string]$map.originalRomSha256
            outputSha256 = [string]$map.outputSha256
            bodyStart = [string]$map.bodyStart
            bodyEndExclusive = [string]$map.bodyEndExclusive
            spanHex = [string]$map.spanHex
            entryCount = $mapCheck.entryCount
            nodeCount = $mapCheck.nodeCount
            branchCount = $mapCheck.branchCount
            provenance = $map.provenance
        }
        build = [ordered]@{
            path = [IO.Path]::GetFullPath($BuildReportPath)
            sha256 = $buildSha256
            originalSha256 = [string]$build.originalSha256
            outputSha256 = [string]$build.outputSha256
            identityImageUnchanged = [bool]$build.identityImageUnchanged
            emittedBodyHex = [string]$build.emittedBodyHex
            checks = $build.checks
        }
        events = [ordered]@{
            path = [IO.Path]::GetFullPath($EventsPath)
            sha256 = $parseInfo.sha256
            recordCount = $parseInfo.recordCount
            strictJsonPass = ($parseInfo.strict -eq $true)
        }
        calls = $calls.ToArray()
        callsStarted = $callIds.Count
        callsCompleted = $completed
        branchPathsObserved = $branchPaths.ToArray()
        observedNodeIndexes = $observedNodes.ToArray()
        observedNodeSequenceUnion = $observedNodeText
        observedHandlerSequenceUnion = $observedHandlerText
        observedNodes = @($observedNodes | Sort-Object | ForEach-Object { $nodeByIndex[[int]$_] })
        observedHandlers = @($observedHandlers | Sort-Object)
        unobservedNodes = $unobserved.ToArray()
        returnTransitions = $returnTransitions.ToArray()
        coverageGaps = $gaps.ToArray()
        sessionComplete = $completeRecords[0]
        metadata = $metadata
    }
}

function Test-IlA64NegativeControls {
    param([string]$Run,$Analysis)
    $root = Join-Path $Run 'negative-controls'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $cases = New-Object 'System.Collections.Generic.List[object]'

    $malformed = Join-Path $root 'malformed-events.jsonl'
    $validLine = '{"event":"probe","callId":"1"}'
    [IO.File]::WriteAllText($malformed, $validLine + "`n" + '{"event":"probe",}' + "`n", $script:IlA64Utf8)
    $malformedRejected = $false
    $malformedMessage = ''
    try { [void](Invoke-IlA64StrictParse $malformed (Join-Path $root 'malformed-parse.json')) }
    catch { $malformedRejected = $true; $malformedMessage = $_.Exception.Message }
    $cases.Add([ordered]@{ name='malformed_trailing_comma_event'; expected='rejected'; observed=($(if ($malformedRejected) { 'rejected' } else { 'accepted' })); pass=$malformedRejected; detail=$malformedMessage })

    $staleMap = Join-Path $root 'stale-map.json'
    $mapText = Get-Content -LiteralPath (Join-Path $Run 'source-map.json') -Raw
    $staleText = $mapText.Replace('"outputSha256": "EBF580381AA6EB6FFB26E2ACD40F30AA34B0311F71C6564607C6F48A53BCA15C"','"outputSha256": "0000000000000000000000000000000000000000000000000000000000000000"')
    if ($staleText -eq $mapText) { throw 'Could not construct the stale-map negative control' }
    [IO.File]::WriteAllText($staleMap,$staleText,$script:IlA64Utf8)
    $staleRejected = $false
    $staleMessage = ''
    try { [void](Get-IlA64Analysis -Run $Run -SourceMapPath $staleMap -SkipStrictParse) }
    catch { $staleRejected = $true; $staleMessage = $_.Exception.Message }
    $cases.Add([ordered]@{ name='stale_source_map_identity'; expected='rejected'; observed=($(if ($staleRejected) { 'rejected' } else { 'accepted' })); pass=$staleRejected; detail=$staleMessage })

    $phaseEvents = Join-Path $root 'phase-mismatched-events.jsonl'
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $changed = $false
    foreach ($line in Get-Content -LiteralPath (Join-Path $Run 'events.jsonl')) {
        if (!$changed -and $line -match '"event":"node_prefetch"' -and $line -match '"nodeIndex":"0"') {
            $line = $line.Replace('"y":"9A64"','"y":"9A66"').Replace('"token":"7B6D"','"token":"7982"')
            $changed = $true
        }
        $lines.Add($line)
    }
    if (!$changed) {
        $cases.Add([ordered]@{ name='phase_mismatched_node_prefetch'; expected='rejected when a natural prefetch exists'; observed='not_applicable_no_natural_node_prefetch'; pass=$true; detail='No natural node_prefetch record was present to mutate. The focused test still checks mapped-event phase validation separately; no event was fabricated as natural evidence.' })
    }
    else {
        [IO.File]::WriteAllLines($phaseEvents,$lines,$script:IlA64Utf8)
        $phaseRejected = $false
        $phaseMessage = ''
        try { [void](Get-IlA64Analysis -Run $Run -EventsPath $phaseEvents -SkipStrictParse) }
        catch { $phaseRejected = $true; $phaseMessage = $_.Exception.Message }
        $cases.Add([ordered]@{ name='phase_mismatched_node_prefetch'; expected='rejected'; observed=($(if ($phaseRejected) { 'rejected' } else { 'accepted' })); pass=$phaseRejected; detail=$phaseMessage })
    }

    $missingReturn = Join-Path $root 'missing-return-events.jsonl'
    $remaining = @(Get-Content -LiteralPath (Join-Path $Run 'events.jsonl') | Where-Object { $_ -notmatch '"event":"post_return_prefetch"' -and $_ -notmatch '"event":"call_complete"' })
    [IO.File]::WriteAllLines($missingReturn,$remaining,$script:IlA64Utf8)
    $missingAccepted = $false
    $missingMessage = ''
    try {
        $missingAnalysis = Get-IlA64Analysis -Run $Run -EventsPath $missingReturn -SkipStrictParse
        $missingAccepted = ([int]$missingAnalysis.callsCompleted -eq 0)
    }
    catch { $missingMessage = $_.Exception.Message }
    $cases.Add([ordered]@{ name='missing_post_return_not_accepted_as_complete'; expected='no complete call'; observed=($(if ($missingAccepted) { 'no complete call' } else { 'complete call or analysis failure' })); pass=$missingAccepted; detail=$missingMessage })

    foreach ($case in $cases) { if (-not $case.pass) { throw "Negative control failed: $($case.name) ($($case.detail))" } }
    return $cases.ToArray()
}

function Write-IlA64Evidence {
    param([string]$Run,$Analysis,[string]$OutputPath,$RunRecord,$MapRecord,$ReplayHash,$InputLuaHash,$MameHash,$MameVersion,$RomIdentity,$RunRomIdentity,$PreRunCounts,$PostRunRom,$StateFileCount,$NegativeControls,[string]$SourceDocument)
    $calls = @($Analysis.calls)
    $MapReconstructed = $false
    if ($MapRecord -is [System.Collections.IDictionary]) {
        if ($MapRecord.Contains('reconstructed')) { $MapReconstructed = [bool]$MapRecord['reconstructed'] }
    }
    elseif ($null -ne $MapRecord.PSObject.Properties['reconstructed']) {
        $MapReconstructed = [bool]$MapRecord.reconstructed
    }
    $evidence = [ordered]@{
        schemaVersion = 1
        taskId = 'il-9a64-finish-15'
        generatedUtc = [DateTime]::UtcNow.ToString('o')
        resultStatus = [string]$Analysis.status
        runtimeClaim = if ([int]$Analysis.callsCompleted -gt 0) { "At most $($Analysis.callsCompleted) complete natural 9A64 call(s) were observed; unobserved nodes are not labelled executed." } else { 'No complete natural 9A64 call is claimed. The static map is valid, but the runtime coverage claim is limited to the recorded no-hit/partial finding.' }
        classification = 'Natural fresh-boot original-ROM MAME 0.281 run with the tracked physical-input replay and read-only native debugger breakpoints. The source map was generated independently from NineASixFourDecoder + VmIlCompiler.CompileIdentity + VmIlSourceMap. No state, register, RAM or ROM injection, no save-state load and no checksum bypass.'
        evidenceClasses = [ordered]@{
            naturalExecution = 'Native MAME 0.281 breakpoint stops with Lua state reads during one fresh-boot original-image run.'
            staticDeduction = 'Source map, handler headers and branch contracts generated from the identity-checked original ROM by the accepted IL decoder/compiler/map API.'
            hypothesis = 'The tracked replay schedule is the only input sequence used; no alternate or speculative input search was performed.'
            synthetic = 'Negative controls only (malformed JSON, stale map identity, phase mismatch, missing return); they are not natural execution evidence.'
        }
        images = [ordered]@{
            original = $RomIdentity
            runRomBefore = $RunRomIdentity
            runRomAfter = $PostRunRom
            runRomUnchanged = ([string]$RunRomIdentity.sha256 -ieq [string]$PostRunRom.sha256 -and [string]$RunRomIdentity.sha1 -ieq [string]$PostRunRom.sha1)
        }
        sourceMap = $Analysis.map
        buildReport = $Analysis.build
        mame = [ordered]@{ executable=[IO.Path]::GetFullPath($MameExecutable); sha256=$MameHash; version=$MameVersion }
        inputs = [ordered]@{
            replayPath = [IO.Path]::GetFullPath($ReplayPath); replaySha256 = $ReplayHash
            inputLuaPath = [IO.Path]::GetFullPath($InputLuaPath); inputLuaSha256 = $InputLuaHash
            secondsToRun = $SecondsToRun; wallTimeoutSeconds = $WallTimeoutSeconds; maxCompleteCalls = $MaxCalls
            startingNvram = 'absent'; startingConfiguration = 'absent; -noreadconfig'; saveStateLoaded = $false
            preRunEmpty = $PreRunCounts; postRunStateFiles = $StateFileCount
        }
        run = [ordered]@{
            runDirectory = [IO.Path]::GetFullPath($Run)
            mameRecord = $RunRecord
            sourceMapGeneration = $MapRecord
            sessionComplete = $Analysis.sessionComplete
            eventRecordCount = $Analysis.events.recordCount
            strictJsonPass = $Analysis.events.strictJsonPass
            eventsSha256 = $Analysis.events.sha256
            debugLogSha256 = if (Test-Path -LiteralPath (Join-Path $Run 'debug.log')) { Get-IlA64Hash (Join-Path $Run 'debug.log') 'SHA256' } else { '' }
        }
        calls = $calls
        coverage = [ordered]@{
            callsStarted = $Analysis.callsStarted
            callsCompleted = $Analysis.callsCompleted
            branchPathsObserved = $Analysis.branchPathsObserved
            observedNodeIndexes = $Analysis.observedNodeIndexes
            observedNodeSequenceUnion = $Analysis.observedNodeSequenceUnion
            observedHandlerSequenceUnion = $Analysis.observedHandlerSequenceUnion
            observedNodes = $Analysis.observedNodes
            observedHandlers = $Analysis.observedHandlers
            unobservedNodes = $Analysis.unobservedNodes
            gaps = $Analysis.coverageGaps
        }
        returnTransitions = $Analysis.returnTransitions
        negativeControls = $NegativeControls
        commands = @(
            [ordered]@{ id=$MapRecord.commandId; description=$MapRecord.description; commandLine=$MapRecord.commandLine; exitCode=$MapRecord.exitCode; timedOut=$MapRecord.timedOut; wallSeconds=$MapRecord.wallSeconds; reconstructed=$MapReconstructed },
            [ordered]@{ id='il-9a64-natural-capture'; description='One fresh-boot original-image MAME natural observation at native 9A64 boundaries'; commandLine=$RunRecord.commandLine; exitCode=$RunRecord.exitCode; timedOut=$RunRecord.timedOut; wallSeconds=$RunRecord.wallSeconds }
        )
        limitations = @(
            'This report does not establish storage/memory OR or clear effects for the 7665/7671 handlers; only the observed branch and return boundaries are claimed.',
            'Only the fixed 9A64 identity definition and the two checked byte-branch handlers are in scope.',
            'Natural branch coverage is limited to the paths actually reached by the tracked fixed replay; unobserved nodes are reported as gaps, not successes.',
            'No 9A64 edit, operand replacement, extension range, linker, new word, native executor, hardware run or physical compatibility claim is included.',
            'The EE16/EE22 paid-window comparison remains unchanged and was not retried.'
        )
        validation = [ordered]@{
            capture = 'tools/Capture-IlNineA64Natural.ps1'
            focusedTest = 'tests/worker/Test-IlNineA64Natural.ps1'
            strictJsonHelper = 'tests/worker/Test-IlEventJson.ps1'
            sourceDocument = $SourceDocument
        }
    }
    Write-IlA64Json $OutputPath $evidence 30
    return $evidence
}

function Invoke-IlA64Analyze {
    if ([string]::IsNullOrWhiteSpace($RunDirectory)) { throw 'Analyze mode requires -RunDirectory' }
    if ([string]::IsNullOrWhiteSpace($EvidencePath)) { throw 'Analyze mode requires -EvidencePath' }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (!(Test-Path -LiteralPath $run -PathType Container)) { throw "Run directory is missing: $run" }
    $metadataPath = Join-Path $run 'session-metadata.json'
    if (!(Test-Path -LiteralPath $metadataPath -PathType Leaf)) { throw "Session metadata is missing: $metadataPath" }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ([string]$metadata.protocol -ne $script:IlA64Protocol) { throw 'Preserved session metadata protocol mismatch' }

    $originalRomPath = [string]$metadata.original_rom.path
    $romIdentity = Assert-IlA64Rom $originalRomPath $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'preserved-run original ROM'
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    $runRomBefore = Assert-IlA64Rom $runRom $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'preserved-run isolated ROM before analysis'
    $runRomAfter = Assert-IlA64Rom $runRom $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'preserved-run isolated ROM after analysis'

    $mapPath = Join-Path $run 'source-map.json'
    $buildPath = Join-Path $run 'build-report.json'
    $projectPath = Join-Path $run 'source-map-gen/IlNineA64MapGen.csproj'
    if (!(Test-Path -LiteralPath $mapPath -PathType Leaf)) { throw "Preserved source map is missing: $mapPath" }
    if (!(Test-Path -LiteralPath $buildPath -PathType Leaf)) { throw "Preserved build report is missing: $buildPath" }
    $mapRecord = [ordered]@{
        commandId = 'il-9a64-source-map-generation'
        description = 'Source-map generation reconstructed from the preserved run; the generator was not re-executed in Analyze mode.'
        commandLine = ('run --project {0} --configuration Release -- {1} {2} {3}' -f $projectPath,$originalRomPath,$mapPath,$buildPath)
        startUtc = $null
        endUtc = $null
        wallSeconds = $null
        timeoutSeconds = 300
        timedOut = $false
        exitCode = 0
        reconstructed = $true
    }

    $runRecordPath = Join-Path $run 'run-record.json'
    if (!(Test-Path -LiteralPath $runRecordPath -PathType Leaf)) { throw "Preserved run record is missing: $runRecordPath" }
    $runRecord = Get-Content -LiteralPath $runRecordPath -Raw | ConvertFrom-Json
    if ([bool]$runRecord.timedOut) { throw 'Preserved MAME run timed out' }
    if ([int]$runRecord.exitCode -ne 0) { throw "Preserved MAME run exited $($runRecord.exitCode)" }

    $mameVersionPath = Join-Path $run 'mame-version.txt'
    if (!(Test-Path -LiteralPath $mameVersionPath -PathType Leaf)) { throw "Preserved MAME version record is missing: $mameVersionPath" }
    $mameVersion = ((Get-Content -LiteralPath $mameVersionPath -Raw).Trim() -split "`r?`n")[0]
    if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected preserved MAME version: $mameVersion" }

    $preRunPath = Join-Path $run 'pre-run-empty.json'
    if (!(Test-Path -LiteralPath $preRunPath -PathType Leaf)) { throw "Preserved pre-run record is missing: $preRunPath" }
    $preRunCounts = Get-Content -LiteralPath $preRunPath -Raw | ConvertFrom-Json
    $stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'state') -Recurse -File -ErrorAction SilentlyContinue)
    if ($stateFiles.Count -ne 0) { throw 'State directory contains files; the preserved run may have written a save state' }

    $replayHash = [string]$metadata.replay_sha256
    $inputLuaHash = [string]$metadata.input_lua_sha256
    $mameHash = [string]$metadata.mame_sha256
    foreach ($pair in @(@('replay',$replayHash),@('inputLua',$inputLuaHash),@('mame',$mameHash))) {
        if ($pair[1] -notmatch '^[0-9A-Fa-f]{64}$') { throw "Preserved metadata $($pair[0]) hash is malformed" }
    }

    $analysis = Get-IlA64Analysis -Run $run
    $negatives = Test-IlA64NegativeControls $run $analysis
    Write-IlA64Json (Join-Path $run 'observation.json') $analysis 30
    $evidence = Write-IlA64Evidence -Run $run -Analysis $analysis -OutputPath $EvidencePath -RunRecord $runRecord -MapRecord $mapRecord -ReplayHash $replayHash -InputLuaHash $inputLuaHash -MameHash $mameHash -MameVersion $mameVersion -RomIdentity $romIdentity -RunRomIdentity $runRomBefore -PreRunCounts $preRunCounts -PostRunRom $runRomAfter -StateFileCount $stateFiles.Count -NegativeControls $negatives -SourceDocument 'docs/recovery/IL-9A64-NATURAL.md'
    Write-Output (ConvertTo-Json -InputObject ([ordered]@{
        run = $run
        mode = 'Analyze'
        generatorReexecuted = $false
        status = $analysis.status
        callsStarted = $analysis.callsStarted
        callsCompleted = $analysis.callsCompleted
        branchPaths = $analysis.branchPathsObserved
        evidence = [IO.Path]::GetFullPath($EvidencePath)
        evidenceSha256 = Get-IlA64Hash $EvidencePath 'SHA256'
    }) -Depth 6)
}

function Invoke-IlA64Capture {
    if ([string]::IsNullOrWhiteSpace($MameExecutable) -or [string]::IsNullOrWhiteSpace($RomDirectory) -or [string]::IsNullOrWhiteSpace($RunDirectory)) {
        throw 'Capture mode requires -MameExecutable, -RomDirectory and -RunDirectory'
    }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only run directory: $run" }
    if (!(Test-Path -LiteralPath $RomDirectory -PathType Container)) { throw "Installed ROM directory is missing: $RomDirectory" }
    foreach ($path in @($MameExecutable,$OriginalRom,$ReplayPath,$InputLuaPath)) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required input is missing: $path" }
    }
    $romIdentity = Assert-IlA64Rom $OriginalRom $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'original ROM'
    $mameHash = Get-IlA64Hash $MameExecutable 'SHA256'
    if ($mameHash -ine $script:IlA64MameSha256) { throw "MAME SHA256 is $mameHash, expected $script:IlA64MameSha256" }
    $replayHash = Get-IlA64Hash $ReplayPath 'SHA256'
    if ($replayHash -ine $script:IlA64ReplaySha256) { throw "Replay SHA256 is $replayHash, expected $script:IlA64ReplaySha256" }
    $inputLuaHash = Get-IlA64Hash $InputLuaPath 'SHA256'

    New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
    foreach ($name in @('roms/m4addr','cfg','nvram','inp','snap','comments','state','diff')) {
        New-Item -ItemType Directory -Path (Join-Path $run $name) -ErrorAction Stop | Out-Null
    }
    $runRom = Join-Path $run 'roms/m4addr/a6ls.p1'
    Copy-Item -LiteralPath $OriginalRom -Destination $runRom -ErrorAction Stop
    $runRomIdentity = Assert-IlA64Rom $runRom $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'isolated run ROM'
    Copy-Item -LiteralPath $ReplayPath -Destination (Join-Path $run 'replay-actions.csv') -ErrorAction Stop
    Copy-Item -LiteralPath $InputLuaPath -Destination (Join-Path $run 'input.lua') -ErrorAction Stop
    Copy-Item -LiteralPath (Join-Path $script:IlA64Root 'tools/lua/IlNineA64Natural.lua') -Destination (Join-Path $run 'IlNineA64Natural.lua') -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $run 'observer.lua'),"dofile('input.lua')`ndofile('IlNineA64Natural.lua')`n",$script:IlA64Utf8)

    $mapRecord = Invoke-IlA64MapGeneration $OriginalRom $run
    $map = Get-Content -LiteralPath $mapRecord.mapPath -Raw | ConvertFrom-Json
    $build = Get-Content -LiteralPath $mapRecord.buildPath -Raw | ConvertFrom-Json
    $mapCheck = Test-IlA64MapDocument $map ([IO.File]::ReadAllBytes($OriginalRom)) $script:IlA64OriginalSha256
    if (-not [bool]$build.identityImageUnchanged) { throw 'Generated build report is not an identity build' }
    $mapSha256 = Get-IlA64Hash $mapRecord.mapPath 'SHA256'
    $buildSha256 = Get-IlA64Hash $mapRecord.buildPath 'SHA256'
    Write-IlA64MapLua (Join-Path $run 'a64-map.lua') $map $mapSha256

    $sessionId = [guid]::NewGuid().ToString('D')
    $config = [ordered]@{
        schemaVersion = 1
        protocol = $script:IlA64Protocol
        sessionId = $sessionId
        secondsToRun = $SecondsToRun
        wallTimeoutSeconds = $WallTimeoutSeconds
        maxCalls = $MaxCalls
        expectedOriginalRomSha256 = $script:IlA64OriginalSha256
        expectedImageSha256 = $script:IlA64OriginalSha256
        expectedSourceMapSha256 = $mapSha256
        expectedBuildReportSha256 = $buildSha256
        expectedReplaySha256 = $replayHash
        expectedInputLuaSha256 = $inputLuaHash
        expectedMameSha256 = $mameHash
    }
    Write-IlA64ConfigLua (Join-Path $run 'session-config.lua') $config
    Write-IlA64Json (Join-Path $run 'session-config.json') $config 8
    Write-IlA64Json (Join-Path $run 'source-map-generated.json') ([ordered]@{
        schemaVersion = 1
        classification = 'Generated source map from the accepted independent decoder/compiler/map API.'
        sourceMapSha256 = $mapSha256
        buildReportSha256 = $buildSha256
        map = $map
    }) 30

    $preRunCounts = [ordered]@{}
    foreach ($name in @('cfg','nvram','inp','snap','comments','state','diff')) {
        $preRunCounts[$name] = @(Get-ChildItem -LiteralPath (Join-Path $run $name) -Recurse -File -ErrorAction SilentlyContinue).Count
        if ($preRunCounts[$name] -ne 0) { throw "Pre-run directory $name is not empty" }
    }
    $preRunRomFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'roms/m4addr') -File | ForEach-Object { $_.Name } | Sort-Object)
    if (($preRunRomFiles -join ',') -ne 'a6ls.p1') { throw 'Isolated ROM directory must contain exactly a6ls.p1 before launch' }
    Write-IlA64Json (Join-Path $run 'pre-run-empty.json') $preRunCounts 6

    $versionOut = Join-Path $run 'mame-version.txt'
    $versionErr = Join-Path $run 'mame-version.err.txt'
    $versionRecord = Invoke-IlA64Process -FilePath $MameExecutable -Arguments @('-version') -WorkingDirectory $run -StdOutPath $versionOut -StdErrPath $versionErr -TimeoutSeconds 60
    if ($versionRecord.timedOut -or $versionRecord.exitCode -ne 0) { throw "MAME -version failed: exit=$($versionRecord.exitCode)" }
    $mameVersion = ((Get-Content -LiteralPath $versionOut -Raw).Trim() -split "`r?`n")[0]
    if ($mameVersion -notmatch '^0\.281\b') { throw "Unexpected MAME version: $mameVersion" }

    $arguments = @('m4addr','-noreadconfig','-rompath',((Join-Path $run 'roms')+';'+$RomDirectory),
        '-cfg_directory',(Join-Path $run 'cfg'),'-nvram_directory',(Join-Path $run 'nvram'),
        '-input_directory',(Join-Path $run 'inp'),'-snapshot_directory',(Join-Path $run 'snap'),
        '-comment_directory',(Join-Path $run 'comments'),'-state_directory',(Join-Path $run 'state'),
        '-diff_directory',(Join-Path $run 'diff'),'-debug','-debugger','windows','-debuglog',
        '-video','none','-sound','none','-window','-skip_gameinfo','-nothrottle',
        '-seconds_to_run',[string]$SecondsToRun,'-autoboot_delay','0',
        '-autoboot_script',(Join-Path $run 'observer.lua'))
    Write-IlA64Json (Join-Path $run 'arguments.json') @($arguments) 6
    Write-IlA64Json (Join-Path $run 'session-metadata.json') ([ordered]@{
        protocol = $script:IlA64Protocol
        sessionId = $sessionId
        original_rom = $romIdentity
        run_rom_before = $runRomIdentity
        source_map_path = [IO.Path]::GetFullPath($mapRecord.mapPath)
        source_map_sha256 = $mapSha256
        build_report_path = [IO.Path]::GetFullPath($mapRecord.buildPath)
        build_report_sha256 = $buildSha256
        replay_path = [IO.Path]::GetFullPath($ReplayPath)
        replay_sha256 = $replayHash
        input_lua_path = [IO.Path]::GetFullPath($InputLuaPath)
        input_lua_sha256 = $inputLuaHash
        mame_executable = [IO.Path]::GetFullPath($MameExecutable)
        mame_sha256 = $mameHash
        seconds_to_run = $SecondsToRun
        wall_timeout_seconds = $WallTimeoutSeconds
        max_complete_calls = $MaxCalls
        starting_nvram = 'absent'
        starting_configuration = 'absent; -noreadconfig'
        save_state_loaded = $false
        debugger_writes = $false
        classification = 'Fresh-isolated natural original-ROM run with read-only native debugger boundary stops.'
    }) 14

    $previousReplay = $env:MPU4_REPLAY
    $previousPolicy = $env:MPU4_POLICY
    $previousMap = $env:FML_IL_9A64_MAP
    $previousConfig = $env:FML_IL_9A64_CONFIG
    try {
        $env:MPU4_REPLAY = Join-Path $run 'replay-actions.csv'
        $env:MPU4_POLICY = '7'
        $env:FML_IL_9A64_MAP = 'a64-map.lua'
        $env:FML_IL_9A64_CONFIG = 'session-config.lua'
        $runRecord = Invoke-IlA64Process -FilePath $MameExecutable -Arguments $arguments -WorkingDirectory $run -StdOutPath (Join-Path $run 'console.txt') -StdErrPath (Join-Path $run 'console.err.txt') -TimeoutSeconds $WallTimeoutSeconds
    }
    finally {
        $env:MPU4_REPLAY = $previousReplay
        $env:MPU4_POLICY = $previousPolicy
        $env:FML_IL_9A64_MAP = $previousMap
        $env:FML_IL_9A64_CONFIG = $previousConfig
    }
    $runRecord.commandId = 'il-9a64-natural-capture'
    $runRecord.description = 'One fresh-boot original-image MAME natural observation at native 9A64 boundaries'
    Write-IlA64Json (Join-Path $run 'run-record.json') $runRecord 8
    [IO.File]::WriteAllText((Join-Path $run 'exit-code.txt'),[string]$runRecord.exitCode,$script:IlA64Utf8)

    if ($runRecord.timedOut) { throw "MAME exceeded the ${WallTimeoutSeconds}s wall cap; partial run preserved at $run" }
    if ($runRecord.exitCode -ne 0) { throw "MAME exited $($runRecord.exitCode); inspect $run" }
    if (!(Test-Path -LiteralPath (Join-Path $run 'events.jsonl') -PathType Leaf)) { throw "Lua observer did not produce events.jsonl; inspect $run" }
    $postRunRom = Assert-IlA64Rom $runRom $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'run ROM after execution'
    $stateFiles = @(Get-ChildItem -LiteralPath (Join-Path $run 'state') -Recurse -File -ErrorAction SilentlyContinue)
    if ($stateFiles.Count -ne 0) { throw 'State directory contains files; a save state may have been seeded or written' }

    $analysis = Get-IlA64Analysis -Run $run
    $negatives = Test-IlA64NegativeControls $run $analysis
    Write-IlA64Json (Join-Path $run 'observation.json') $analysis 30
    $evidence = Write-IlA64Evidence -Run $run -Analysis $analysis -OutputPath $EvidencePath -RunRecord $runRecord -MapRecord $mapRecord.record -ReplayHash $replayHash -InputLuaHash $inputLuaHash -MameHash $mameHash -MameVersion $mameVersion -RomIdentity $romIdentity -RunRomIdentity $runRomIdentity -PreRunCounts $preRunCounts -PostRunRom $postRunRom -StateFileCount $stateFiles.Count -NegativeControls $negatives -SourceDocument 'docs/recovery/IL-9A64-NATURAL.md'
    Write-Output (ConvertTo-Json -InputObject ([ordered]@{
        run = $run
        status = $analysis.status
        callsStarted = $analysis.callsStarted
        callsCompleted = $analysis.callsCompleted
        branchPaths = $analysis.branchPathsObserved
        evidence = [IO.Path]::GetFullPath($EvidencePath)
        evidenceSha256 = Get-IlA64Hash $EvidencePath 'SHA256'
    }) -Depth 6)
}

function Invoke-IlA64Verify {
    if ([string]::IsNullOrWhiteSpace($RunDirectory)) { throw 'Verify mode requires -RunDirectory' }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (!(Test-Path -LiteralPath $run -PathType Container)) { throw "Run directory is missing: $run" }
    $analysis = Get-IlA64Analysis -Run $run
    $negatives = Test-IlA64NegativeControls $run $analysis
    $result = [ordered]@{
        run = $run
        status = $analysis.status
        callsStarted = $analysis.callsStarted
        callsCompleted = $analysis.callsCompleted
        branchPaths = $analysis.branchPathsObserved
        strictJsonPass = $analysis.events.strictJsonPass
        negativeControlCount = $negatives.Count
        negativeControlsPass = (@($negatives | Where-Object { -not $_.pass }).Count -eq 0)
    }
    if (!(Test-Path -LiteralPath $EvidencePath -PathType Leaf)) { throw "Evidence file is missing: $EvidencePath" }
    $evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
    if ([string]$evidence.sourceMap.sha256 -ine [string]$analysis.map.sha256) { throw 'Evidence source-map hash differs from the run' }
    if ([string]$evidence.buildReport.sha256 -ine [string]$analysis.build.sha256) { throw 'Evidence build-report hash differs from the run' }
    if ([int]$evidence.coverage.callsCompleted -ne [int]$analysis.callsCompleted) { throw 'Evidence completed-call count differs from the run' }
    if ([string]$evidence.resultStatus -ne [string]$analysis.status) { throw 'Evidence result status differs from the run' }
    $result.evidenceSha256 = Get-IlA64Hash $EvidencePath 'SHA256'
    Write-Output (ConvertTo-Json -InputObject $result -Depth 6)
}

if ($Mode -eq 'MapOnly') {
    if ([string]::IsNullOrWhiteSpace($RunDirectory)) { throw 'MapOnly mode requires -RunDirectory' }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    if (Test-Path -LiteralPath $run) { throw "Use a fresh create-only directory: $run" }
    New-Item -ItemType Directory -Path $run -ErrorAction Stop | Out-Null
    $romIdentity = Assert-IlA64Rom $OriginalRom $script:IlA64OriginalSha1 $script:IlA64OriginalSha256 'original ROM'
    $mapRecord = Invoke-IlA64MapGeneration $OriginalRom $run
    $map = Get-Content -LiteralPath $mapRecord.mapPath -Raw | ConvertFrom-Json
    $mapCheck = Test-IlA64MapDocument $map ([IO.File]::ReadAllBytes($OriginalRom)) $script:IlA64OriginalSha256
    $mapOnlySha256 = Get-IlA64Hash $mapRecord.mapPath 'SHA256'
    Write-IlA64MapLua (Join-Path $run 'a64-map.lua') $map $mapOnlySha256
    Write-Output (ConvertTo-Json -InputObject ([ordered]@{
        run = $run
        original = $romIdentity
        sourceMap = $mapRecord.mapPath
        sourceMapSha256 = $mapOnlySha256
        buildReport = $mapRecord.buildPath
        buildReportSha256 = Get-IlA64Hash $mapRecord.buildPath 'SHA256'
        entries = $mapCheck.entryCount
        nodes = $mapCheck.nodeCount
        branches = $mapCheck.branchCount
        mapGeneration = $mapRecord.record
    }) -Depth 8)
}
elseif ($Mode -eq 'Analyze') {
    Invoke-IlA64Analyze
}
elseif ($Mode -eq 'Verify') {
    Invoke-IlA64Verify
}
else {
    Invoke-IlA64Capture
}
