[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RomPath,
    [string]$RepositoryRoot = '',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepositoryRoot 'artifacts/deepseek/il-composite-phase-32/checker'
}
$repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
$outDir = (Resolve-Path -LiteralPath $OutputDirectory).Path

$contractPath = Join-Path $repo 'evidence/mpu4/integrity/il-composite-contract.json'
$tracePath = Join-Path $repo 'evidence/mpu4/integrity/il-lua-vm-trace.json'
$log = New-Object System.Collections.Generic.List[string]
$checks = New-Object System.Collections.ArrayList
$script:failed = $false

$romLength = 65536
$romSha1 = '402d1518bb78fdc489b06c2aabc771e5ce151847'
$romSha256 = 'ebf580381aa6eb6ffb26e2acd40f30aa34b0311f71c6564607c6f48a53bca15c'
$rangeStart = 0x1010
$rangeEnd = 0x13EF
$rangeLength = 0x03E0
$rangeSha1 = 'eee7e8ec3670c1fb218bb9839c01277394e00c09'
$rangeSha256 = '1a7a6a16a718aaf4221baa1f787612dd995aaa5b083cfb9409023ac6c0985c16'

function Write-Log([string]$text) {
    $log.Add($text) | Out-Null
    Write-Output $text
}

function Add-Check([string]$id, [bool]$ok, [string]$detail) {
    $checks.Add([ordered]@{ id = $id; ok = $ok; detail = $detail }) | Out-Null
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Log ("{0} {1}: {2}" -f $tag, $id, $detail)
    if (-not $ok) { $script:failed = $true }
}

function Get-HashHex([byte[]]$bytes, [string]$algorithm) {
    $h = [System.Security.Cryptography.HashAlgorithm]::Create($algorithm)
    try {
        $hash = $h.ComputeHash($bytes)
    }
    finally {
        $h.Dispose()
    }
    $sb = New-Object System.Text.StringBuilder
    foreach ($b in $hash) { [void]$sb.Append($b.ToString('x2')) }
    return $sb.ToString()
}

function Get-Hex([byte[]]$bytes) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($b in $bytes) { [void]$sb.Append($b.ToString('X2')) }
    return $sb.ToString()
}

function Get-RomHex([byte[]]$bytes, [int]$start, [int]$length) {
    $slice = New-Object byte[] $length
    [Array]::Copy($bytes, $start, $slice, 0, $length)
    return Get-Hex $slice
}

function Read-Word([byte[]]$bytes, [int]$address) {
    if ($address -lt 0 -or $address + 1 -ge $bytes.Length) {
        throw ("Word read at {0:X4} is outside the image" -f $address)
    }
    return (([int]$bytes[$address] -shl 8) -bor [int]$bytes[$address + 1])
}

function Test-AllFill([byte[]]$bytes, [int]$start, [int]$length, [byte]$fill) {
    for ($i = 0; $i -lt $length; $i++) {
        if ($bytes[$start + $i] -ne $fill) { return $false }
    }
    return $true
}

function Test-RomIdentity([byte[]]$bytes) {
    if ($bytes.Length -ne $romLength) {
        throw ("ROM length mismatch: expected {0}, got {1}" -f $romLength, $bytes.Length)
    }
    $sha1 = Get-HashHex $bytes 'SHA1'
    if ($sha1 -ne $romSha1) {
        throw ("ROM SHA1 mismatch: expected {0}, got {1}" -f $romSha1, $sha1)
    }
    $sha256 = Get-HashHex $bytes 'SHA256'
    if ($sha256 -ne $romSha256) {
        throw ("ROM SHA256 mismatch: expected {0}, got {1}" -f $romSha256, $sha256)
    }
}

function Test-RomBytes([byte[]]$bytes, [int]$start, [string]$expectedHex, [string]$label) {
    $length = [int]($expectedHex.Length / 2)
    $actual = Get-RomHex $bytes $start $length
    if ($actual -ne $expectedHex) {
        throw ("{0} at {1:X4}: expected {2}, got {3}" -f $label, $start, $expectedHex, $actual)
    }
}

function Get-RangeBytes([byte[]]$bytes, [int]$start, [int]$endInclusive) {
    $length = $endInclusive - $start + 1
    $slice = New-Object byte[] $length
    [Array]::Copy($bytes, $start, $slice, 0, $length)
    return $slice
}

function Test-ExtensionReservation([byte[]]$rom) {
    Test-RomIdentity $rom

    if ((Get-RomHex $rom 0x1000 16) -ne 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') {
        throw 'Left guard 1000-100F is not all FF'
    }
    if ((Get-RomHex $rom 0x1000 4) -ne 'FFFFFFFF') {
        throw 'Protected cells 1000-1003 are not all FF'
    }
    if ((Get-RomHex $rom 0x13F0 16) -ne 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') {
        throw 'Right guard 13F0-13FF is not all FF'
    }
    if (-not (Test-AllFill $rom $rangeStart $rangeLength 0xFF)) {
        throw 'Approved range 1010-13EF is not all FF'
    }
    if ((Get-RomHex $rom 0x1400 8) -ne '343631A9145D8E01') {
        throw 'Integrity-range neighbor 1400-1407 differs from the recorded bytes'
    }

    $range = Get-RangeBytes $rom $rangeStart $rangeEnd
    $actualSha1 = Get-HashHex $range 'SHA1'
    $actualSha256 = Get-HashHex $range 'SHA256'
    if ($actualSha1 -ne $rangeSha1) {
        throw ("Range SHA1 mismatch: expected {0}, got {1}" -f $rangeSha1, $actualSha1)
    }
    if ($actualSha256 -ne $rangeSha256) {
        throw ("Range SHA256 mismatch: expected {0}, got {1}" -f $rangeSha256, $actualSha256)
    }
}

function Get-BodyTokenSequence([byte[]]$body) {
    $tokens = New-Object System.Collections.ArrayList
    $cursor = 0
    $sawReturn = $false
    while ($cursor -lt $body.Length) {
        if ($cursor + 2 -gt $body.Length) {
            throw ("Body token at {0:X2} crosses the body end" -f $cursor)
        }
        $token = Read-Word $body $cursor
        $width = 0
        switch ([int]$token) {
            0x795B { $width = 4 }
            0x787E { $width = 2 }
            0x7AAF { $width = 2 }
            0x792F { $width = 2 }
            default {
                throw ("Unsupported body token {0:X4} at body offset {1:X2}" -f $token, $cursor)
            }
        }
        if ($cursor + $width -gt $body.Length) {
            throw ("Body token {0:X4} at {1:X2} crosses the body end" -f $token, $cursor)
        }
        if ($token -eq 0x792F) {
            if ($cursor + $width -ne $body.Length) {
                throw 'The return token 792F is not the final body token'
            }
            $sawReturn = $true
        }
        $tokens.Add([ordered]@{ token = $token; offset = $cursor; width = $width }) | Out-Null
        $cursor += $width
    }
    if (-not $sawReturn) {
        throw 'The body has no final return token 792F'
    }
    return @($tokens.ToArray())
}

function Get-StackContract($tokens) {
    $u = 0
    $s = 0
    $sawReturn = $false
    foreach ($item in $tokens) {
        switch ([int]$item.token) {
            0x795B { $u -= 2 }
            0x787E { $u += 2 }
            0x7AAF { $u += 2 }
            0x792F { $s += 2; $sawReturn = $true }
        }
    }
    return [pscustomobject]@{
        UNet = $u
        SDeltaAtReturn = $s
        SawReturn = $sawReturn
    }
}

function Get-HandlerSemantics([byte[]]$image, [int]$handlerAddress) {
    $known = [ordered]@{
        'ECA136060EFC' = @{ Kind = 'push_inline'; InlineAdvance = 2 }
        '3706E3C4EDC40EFC' = @{ Kind = 'add'; InlineAdvance = 0 }
        '3706A8C4E841EDC40EFC' = @{ Kind = 'xor'; InlineAdvance = 0 }
        '35200EFC' = @{ Kind = 'return'; InlineAdvance = 0 }
    }
    foreach ($key in $known.Keys) {
        $length = [int]($key.Length / 2)
        if ((Get-RomHex $image $handlerAddress $length) -eq $key) {
            return [pscustomobject]$known[$key]
        }
    }
    throw ("Unsupported native handler bytes at {0:X4}: {1}" -f $handlerAddress, (Get-RomHex $image $handlerAddress 10))
}

function Add-ExpectedPhase($list, [string]$phase, [string]$classification, [string]$pc, $x, [string]$y,
    [string]$token, [int]$u, [int]$s, [int]$top, [int]$second, [string]$boundary,
    [string]$predictedNext, $inlineOperand = $null, $savedAfterPush = $null, $savedCursor = $null) {
    $row = [ordered]@{
        phase = $phase
        classification = $classification
        pc = $pc
        y = $y
        token = $token
        u = ('{0:X4}' -f $u)
        s = ('{0:X4}' -f $s)
        top = ('{0:X4}' -f $top)
        second = ('{0:X4}' -f $second)
        boundary = $boundary
        predictedNext = $predictedNext
    }
    if ($null -ne $x) { $row.x = [string]$x }
    if ($null -ne $inlineOperand) { $row.inlineOperand = [string]$inlineOperand }
    if ($null -ne $savedAfterPush) { $row.savedAfterPush = [string]$savedAfterPush }
    if ($null -ne $savedCursor) { $row.savedCursor = [string]$savedCursor }
    $list.Add($row) | Out-Null
}

function Get-ExpectedPhases([byte[]]$image, $doc, $baseline, $definition) {
    $proposal = $doc.proposal
    $callerTokenAddress = [Convert]::ToInt32([string]$doc.naturalCaller.callerTokenAddress, 16)
    $originalToken = [string]$proposal.tokenReplacement.expectedOriginalBytes
    $replacement = [string]$proposal.tokenReplacement.replacementBytes
    $headerAddress = [Convert]::ToInt32([string]$proposal.headerAddress, 16)
    $bodyStart = [Convert]::ToInt32([string]$proposal.bodyStart, 16)
    $bodyEndExclusive = [Convert]::ToInt32([string]$proposal.bodyEndExclusive, 16)
    $u = [Convert]::ToInt32([string]$baseline.u, 16)
    $s = [Convert]::ToInt32([string]$baseline.s, 16)
    $top = [Convert]::ToInt32([string]$baseline.top, 16)
    $second = [Convert]::ToInt32([string]$baseline.second, 16)
    $stack = @{}
    $stack[$u] = $top
    $stack[$u + 2] = $second
    $phases = New-Object System.Collections.ArrayList
    $y = $callerTokenAddress
    $x = $null

    Add-ExpectedPhase $phases 'caller-dispatch' 'static_prediction' '00FC' $null ('{0:X4}' -f $y) `
        ($originalToken + '->' + $replacement) $u $s $top $second `
        'Pre-fetch at 00FC; LDX ,Y++ has not executed.' `
        'LDX ,Y++ -> Y=9F16, X=1010; JMP [,X++] -> PC=00F8, X=1012.'

    $callerWord = Read-Word $image $y
    if ($callerWord -ne [Convert]::ToInt32($replacement, 16)) {
        throw ("Caller token at {0:X4} is {1:X4}; expected replacement {2}" -f $y, $callerWord, $replacement)
    }
    $y = $y + 2
    $x = $callerWord
    $headerValue = Read-Word $image $x
    if ($headerValue -ne 0x00F8) {
        throw ("Definition header at {0:X4} is {1:X4}; expected 00F8" -f $x, $headerValue)
    }
    $x = $x + 2
    if ($x -ne $bodyStart) {
        throw ("Definition pointer at {0:X4} implies body {1:X4}, not declared {2:X4}" -f $headerAddress, $x, $bodyStart)
    }
    $savedY = $y

    Add-ExpectedPhase $phases 'header-trampoline-entry' 'static_prediction' '00F8' ('{0:X4}' -f $x) `
        ('{0:X4}' -f $y) '00F8 pointer' $u $s $top $second `
        'After JMP [,X++] and before PSHS Y; LDX ,Y++ already advanced Y.' `
        'PSHS Y saves 9F16 and S=0796; LEAY ,X sets Y=1012; PC=00FC.' `
        $null ('{0:X4}' -f $y)

    $s = $s - 2
    $y = $x
    $index = 0
    while ($true) {
        if ($y -lt $bodyStart -or $y + 1 -ge $bodyEndExclusive) {
            throw ("Body cursor {0:X4} is outside the declared body {1:X4}-{2:X4}" -f $y, $bodyStart, ($bodyEndExclusive - 1))
        }
        $tokenAddress = $y
        $token = Read-Word $image $y
        Add-ExpectedPhase $phases ('body-prefetch-{0}' -f $index) 'static_prediction' '00FC' `
            ('{0:X4}' -f $x) ('{0:X4}' -f $y) ('{0:X4}' -f $token) $u $s $top $second `
            'Pre-fetch at 00FC before LDX ,Y++.' 'Advance to the native handler through the token pointer cell.'
        $y = $y + 2
        $handler = Read-Word $image $token
        if ($handler -ne ($token + 2)) {
            throw ("Body token {0:X4} pointer cell at {1:X4} contains {2:X4}; expected primitive handler {3:X4}" -f `
                $token, $token, $handler, ($token + 2))
        }
        $x = $handler
        $semantic = Get-HandlerSemantics $image $handler
        $inlineOperand = $null
        if ($semantic.InlineAdvance -gt 0) {
            $inlineOperand = '{0:X4}' -f (Read-Word $image $y)
        }
        if ($semantic.Kind -eq 'return') {
            Add-ExpectedPhase $phases 'return-handler' 'static_prediction' ('{0:X4}' -f $handler) `
                ('{0:X4}' -f $handler) ('{0:X4}' -f $y) ('{0:X4}' -f $token) $u $s $top $second `
                'Handler entry before PULS Y; Y points just past the final body token.' `
                'PULS Y restores 9F16 and S=0798; JMP 00FC.' `
                $null $null ('{0:X4}' -f $savedY)
        }
        else {
            Add-ExpectedPhase $phases ('handler-{0}' -f $index) 'static_prediction' ('{0:X4}' -f $handler) `
                ('{0:X4}' -f $handler) ('{0:X4}' -f $y) ('{0:X4}' -f $token) $u $s $top $second `
                'Native handler entry before any inline operand/stack effect.' `
                'Apply the native handler effect and continue at 00FC.' `
                $inlineOperand
        }

        switch ($semantic.Kind) {
            'push_inline' {
                $u = $u - 2
                $stack[$u] = [Convert]::ToInt32($inlineOperand, 16)
                $y = $y + $semantic.InlineAdvance
            }
            'add' {
                $popped = $stack[$u]
                $u = $u + 2
                $stack[$u] = (($stack[$u] + $popped) -band 0xFFFF)
            }
            'xor' {
                $popped = $stack[$u]
                $u = $u + 2
                $stack[$u] = (($stack[$u] -bxor $popped) -band 0xFFFF)
            }
            'return' { }
        }
        $top = $stack[$u]
        $second = if ($stack.ContainsKey($u + 2)) { $stack[$u + 2] } else { 0 }
        if ($semantic.Kind -eq 'return') { break }
        $index++
    }

    $y = $savedY
    $s = $s + 2
    Add-ExpectedPhase $phases 'post-return-prefetch' 'static_prediction' '00FC' ('{0:X4}' -f $x) `
        ('{0:X4}' -f $y) ('{0:X4}' -f (Read-Word $image $y)) $u $s $top $second `
        'Pre-fetch at 00FC after PULS Y restored the caller cursor.' `
        'Next caller token in the stream is 7B7D at 9F18, subject to 75A9 branch behaviour.'
    return @($phases.ToArray())
}

function Get-PhaseProperty($row, [string]$name) {
    $property = $row.PSObject.Properties[$name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Format-PhaseValue($value) {
    if ($null -eq $value) { return '' }
    return ([string]$value).Trim().ToUpperInvariant()
}

function Test-PhaseField($row, [string]$name, $expected, [string]$phaseId) {
    $expectedText = Format-PhaseValue $expected
    $actualText = Format-PhaseValue (Get-PhaseProperty $row $name)
    if ($expectedText -ne $actualText) {
        $expectedDisplay = if ($expectedText -eq '') { '(none)' } else { $expectedText }
        $actualDisplay = if ($actualText -eq '') { '(none)' } else { $actualText }
        throw ("Phase {0} field {1}: expected {2}, got {3}" -f $phaseId, $name, $expectedDisplay, $actualDisplay)
    }
}

function Test-PhaseMap([byte[]]$image, $doc, $baseline, $definition) {
    $proposal = $doc.proposal
    if ([string]$doc.status -ne 'static-contract-only-not-implemented-not-executed') {
        throw ("Contract status '{0}' does not state static-only/not-executed" -f [string]$doc.status)
    }
    if ($null -eq $proposal.PSObject.Properties['executionStatus'] -or
        [string]$proposal.executionStatus -ne 'static_prediction_not_executed') {
        throw 'Proposal executionStatus is not static_prediction_not_executed'
    }
    if ($null -eq $proposal.PSObject.Properties['naturalExecutionObserved'] -or
        [bool]$proposal.naturalExecutionObserved) {
        throw 'Proposal falsely claims natural execution of the new word'
    }

    $expected = @(Get-ExpectedPhases $image $doc $baseline $definition)
    $declared = @($proposal.phases)
    if ($declared.Count -ne $expected.Count) {
        throw ("Proposal declares {0} phase rows; byte-derived chain has {1}" -f $declared.Count, $expected.Count)
    }

    for ($index = 0; $index -lt $expected.Count; $index++) {
        $want = $expected[$index]
        $row = $declared[$index]
        if ((Format-PhaseValue (Get-PhaseProperty $row 'phase')) -ne (Format-PhaseValue $want.phase)) {
            throw ("Phase row {0} is '{1}'; expected '{2}'" -f $index, (Get-PhaseProperty $row 'phase'), $want.phase)
        }
        if ((Format-PhaseValue (Get-PhaseProperty $row 'classification')) -ne 'STATIC_PREDICTION') {
            throw ("Phase {0} is not marked static_prediction" -f $want.phase)
        }
        foreach ($field in @('pc', 'x', 'y', 'token', 'u', 's', 'top', 'second', 'inlineOperand', 'savedAfterPush', 'savedCursor')) {
            if ($want.Contains($field)) {
                Test-PhaseField $row $field $want[$field] $want.phase
            }
            else {
                $actual = Format-PhaseValue (Get-PhaseProperty $row $field)
                if ($actual -ne '') {
                    throw ("Phase {0} declares {1}={2} but the byte-derived chain has no such value" -f $want.phase, $field, $actual)
                }
            }
        }
        foreach ($textField in @('boundary', 'predictedNext')) {
            $actual = Format-PhaseValue (Get-PhaseProperty $row $textField)
            if ($actual -eq '') {
                throw ("Phase {0} is missing {1}" -f $want.phase, $textField)
            }
        }
    }
}

function Test-NewDefinition([byte[]]$rom, [int]$headerAddress, [string]$headerHex, [string]$bodyHex) {
    if ($headerHex.Length -ne 4) { throw 'Header must be exactly two bytes' }
    if ($headerHex -ne '00F8') { throw ("Unsupported definition header {0}; expected 00F8" -f $headerHex) }

    if ($bodyHex.Length -lt 2 -or ($bodyHex.Length % 2) -ne 0) {
        throw 'Body hex is empty or not byte aligned'
    }
    $body = New-Object byte[] ($bodyHex.Length / 2)
    for ($i = 0; $i -lt $body.Length; $i++) {
        $body[$i] = [Convert]::ToByte($bodyHex.Substring($i * 2, 2), 16)
    }

    $allocationLength = 2 + $body.Length
    $allocationEnd = $headerAddress + $allocationLength - 1
    if ($headerAddress -lt $rangeStart -or $allocationEnd -gt $rangeEnd) {
        throw ("Allocation {0:X4}-{1:X4} is outside the approved range {2:X4}-{3:X4}" -f $headerAddress, $allocationEnd, $rangeStart, $rangeEnd)
    }
    if (-not (Test-AllFill $rom $headerAddress $allocationLength 0xFF)) {
        throw ("Allocation {0:X4}-{1:X4} is not all FF in the original ROM" -f $headerAddress, $allocationEnd)
    }

    $tokens = Get-BodyTokenSequence $body
    $stack = Get-StackContract $tokens
    if ($stack.UNet -ne 0) {
        throw ("Composite body U effect is {0}; this proposal requires 0" -f $stack.UNet)
    }
    if (-not $stack.SawReturn -or $stack.SDeltaAtReturn -ne 2) {
        throw 'Composite body must end with exactly one 792F return token'
    }

    return [pscustomobject]@{
        HeaderAddress = $headerAddress
        HeaderHex = $headerHex
        BodyStart = $headerAddress + 2
        BodyEndExclusive = $headerAddress + $allocationLength
        Body = $body
        BodyHex = $bodyHex
        AllocationEnd = $allocationEnd
        AllocationLength = $allocationLength
        Tokens = $tokens
        Stack = $stack
    }
}

function Test-DeclaredStackEffect($computed, $declared) {
    if ([int]$declared.callSiteUNet -ne [int]$computed.UNet) {
        throw ("Declared callSiteUNet {0} does not match computed {1}" -f $declared.callSiteUNet, $computed.UNet)
    }
    if ([int]$declared.tokenBodyUNet -ne [int]$computed.UNet) {
        throw ("Declared tokenBodyUNet {0} does not match computed {1}" -f $declared.tokenBodyUNet, $computed.UNet)
    }
    if ([int]$declared.entryTrampolineSDelta -ne -2) {
        throw 'Declared entryTrampolineSDelta must be -2'
    }
    if ([int]$declared.returnHandlerSDelta -ne [int]$computed.SDeltaAtReturn) {
        throw ("Declared returnHandlerSDelta {0} does not match computed {1}" -f $declared.returnHandlerSDelta, $computed.SDeltaAtReturn)
    }
    if ([int]$declared.callSiteSNet -ne 0) {
        throw 'Declared callSiteSNet must be 0'
    }
    if ([string]$declared.callerSuccessor -ne '9F16') {
        throw ("Declared callerSuccessor {0} is not the observed 9F16" -f $declared.callerSuccessor)
    }
    if ([string]$declared.postReturnToken -ne '75A9') {
        throw ("Declared postReturnToken {0} is not the observed 75A9" -f $declared.postReturnToken)
    }
}

function Get-SumXor([byte[]]$image) {
    [int]$sum = 0
    [int]$xor = 0
    [int]$pointer = 0x1400
    while ($true) {
        [int]$value = $image[$pointer]
        $sum = ($sum + $value) -band 0xFF
        $xor = $xor -bxor $value
        if ($pointer -eq 0xFFFF) { break }
        $pointer++
        if ($pointer -eq 0xFFD1) { $pointer = 0xFFD6 }
    }
    return [pscustomobject]@{ Sum = $sum; Xor = $xor }
}

function Get-RotateAdd([byte[]]$image) {
    [int]$a = 0
    [int]$b = 0
    [int]$carry = 0
    [int]$pointer = 0x1400
    while ($true) {
        [int]$value = $image[$pointer]
        [int]$next = ($b -shr 7) -band 1
        $b = (($b -shl 1) -bor $carry) -band 0xFF
        $carry = $next
        [int]$total = $a + $value + $carry
        $a = $total -band 0xFF
        $carry = ($total -shr 8) -band 1
        $next = $b -band 1
        $b = (($carry -shl 7) -bor ($b -shr 1)) -band 0xFF
        $carry = $next
        if ($pointer -eq 0xFFFF) { break }
        $pointer++
        if ($pointer -eq 0xFFD3) { $pointer = 0xFFD6 }
        if ($pointer -lt 0xFFD3) { $carry = 1 } else { $carry = 0 }
    }
    return $a
}

function Get-RotateSubXor([byte[]]$image) {
    [int]$a = 0
    [int]$b = 0
    [int]$carry = 0
    [int]$pointer = 0x1400
    while ($true) {
        [int]$value = $image[$pointer]
        [int]$next = ($b -shr 7) -band 1
        $b = ($b -shl 1) -band 0xFF
        $carry = $next
        [int]$total = $b + $carry
        $b = $total -band 0xFF
        $carry = ($total -shr 8) -band 1
        $total = $b - $value
        $b = $total -band 0xFF
        if ($total -lt 0) { $carry = 1 } else { $carry = 0 }
        [int]$savedB = $b
        $b = $a
        for ($i = 0; $i -lt 3; $i++) {
            $carry = $b -band 1
            $b = (($b -shr 1) -bor ($b -band 0x80)) -band 0xFF
            $a = (($carry -shl 7) -bor ($a -shr 1)) -band 0xFF
        }
        $b = $savedB
        $a = $a -bxor $value
        if ($pointer -eq 0xFFFF) { break }
        $pointer++
        if ($pointer -eq 0xFFD4) { $pointer = 0xFFD6 }
    }
    return [pscustomobject]@{ A = $a; B = $b }
}

function Get-StoredIntegrityFields([byte[]]$image) {
    $sx = Get-SumXor $image
    $rotateAdd = Get-RotateAdd $image
    $rotateSubXor = Get-RotateSubXor $image
    return [pscustomobject]@{
        Sum = $sx.Sum
        Xor = $sx.Xor
        RotateAdd = $rotateAdd
        RotateSubXorA = $rotateSubXor.A
        RotateSubXorB = $rotateSubXor.B
        FieldsHex = ('{0:X2}{1:X2}{2:X2}{3:X2}{4:X2}' -f `
            $sx.Sum, $sx.Xor, $rotateAdd, $rotateSubXor.A, $rotateSubXor.B)
    }
}

function Get-OrderedIntegrityFields([byte[]]$image) {
    $sx = Get-SumXor $image
    $image[0xFFD1] = [byte]$sx.Sum
    $image[0xFFD2] = [byte]$sx.Xor
    $rotateAdd = Get-RotateAdd $image
    $image[0xFFD3] = [byte]$rotateAdd
    $rotateSubXor = Get-RotateSubXor $image
    $image[0xFFD4] = [byte]$rotateSubXor.A
    $image[0xFFD5] = [byte]$rotateSubXor.B
    $stored = Get-StoredIntegrityFields $image
    $expected = ('{0:X2}{1:X2}{2:X2}{3:X2}{4:X2}' -f `
        $sx.Sum, $sx.Xor, $rotateAdd, $rotateSubXor.A, $rotateSubXor.B)
    if ($stored.FieldsHex -ne $expected) {
        throw ("Ordered integrity fields {0} do not re-verify as {1}" -f $stored.FieldsHex, $expected)
    }
    return $stored
}

function Get-DiffOffsets([byte[]]$before, [byte[]]$after) {
    if ($before.Length -ne $after.Length) { throw 'Image lengths differ' }
    $offsets = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $before.Length; $i++) {
        if ($before[$i] -ne $after[$i]) {
            $offsets.Add(('{0:X4}' -f $i)) | Out-Null
        }
    }
    return @($offsets.ToArray())
}

function Test-CallerContract([byte[]]$rom) {
    if ((Read-Word $rom 0x9F14) -ne 0x9ED7) {
        throw ("Caller token at 9F14 is {0:X4}; expected 9ED7" -f (Read-Word $rom 0x9F14))
    }
    if ((Read-Word $rom 0x9ED7) -ne 0x00F8) {
        throw ("Definition header at 9ED7 is {0:X4}; expected 00F8" -f (Read-Word $rom 0x9ED7))
    }
    Test-RomBytes $rom 0x9ED9 '795BFF80787E795BFF807AAF792F' '9ED9 body'
    Test-RomBytes $rom 0x9F12 '77F69ED775A97B7D7B3D792F' '9F12 caller body'
    Test-RomBytes $rom 0x9F3B '817D9F10792F' '9F3B parent body'
    if ((Read-Word $rom 0x9F10) -ne 0x00F8) {
        throw ("Caller definition header at 9F10 is {0:X4}; expected 00F8" -f (Read-Word $rom 0x9F10))
    }
}

function Test-ContractDocument([byte[]]$rom, $doc) {
    if ([int]$doc.schemaVersion -ne 1) { throw 'Contract schemaVersion is not 1' }
    if ([string]$doc.taskId -ne 'il-composite-contract-31') { throw 'Contract taskId mismatch' }
    if ([string]$doc.originalIdentity.sha1 -ne $romSha1 -or
        [string]$doc.originalIdentity.sha256 -ne $romSha256 -or
        [int]$doc.originalIdentity.length -ne $romLength) {
        throw 'Contract original identity does not match the explicit ROM'
    }

    Test-RomBytes $rom 0x7927 $doc.dispatchContract.templateRomBytes 'dispatch template'
    foreach ($step in @($doc.dispatchContract.copier)) {
        Test-RomBytes $rom ([Convert]::ToInt32([string]$step.address, 16)) ([string]$step.bytes) `
            ('copier ' + [string]$step.address)
    }
    foreach ($instruction in @($doc.dispatchContract.instructions)) {
        Test-RomBytes $rom ([Convert]::ToInt32([string]$instruction.romAddress, 16)) `
            ([string]$instruction.bytes) ('dispatch ' + [string]$instruction.romAddress)
    }

    foreach ($primitive in @($doc.primitiveTokens)) {
        $tokenAddress = [Convert]::ToInt32([string]$primitive.headerAddress, 16)
        if ((Read-Word $rom $tokenAddress) -ne [Convert]::ToInt32([string]$primitive.headerBytes, 16)) {
            throw ("Primitive header at {0:X4} does not contain {1}" -f $tokenAddress, [string]$primitive.headerBytes)
        }
        Test-RomBytes $rom ([Convert]::ToInt32([string]$primitive.handlerAddress, 16)) `
            ([string]$primitive.handlerBytes) ('handler ' + [string]$primitive.handlerAddress)
    }

    Test-RomBytes $rom 0x9ED7 $doc.originalDefinition9ed9.headerBytes '9ED7 header'
    if ((Read-Word $rom 0x9ED7) -ne 0x00F8) { throw 'Original 9ED7 header is not 00F8' }
    Test-RomBytes $rom 0x9ED9 $doc.originalDefinition9ed9.bodyHex '9ED9 body'
    Test-RomBytes $rom 0x9F10 $doc.naturalCaller.callerDefinitionHeaderBytes '9F10 header'
    Test-RomBytes $rom 0x9F12 $doc.naturalCaller.callerBodyHex '9F12 body'
    Test-RomBytes $rom 0x9F3B $doc.naturalCaller.parentBodyHex '9F3B body'
    Test-CallerContract $rom

    $listingSpecs = @(
        @{ path = [string]$doc.originalDefinition9ed9.listingPath; text = '9ED9  795B' },
        @{ path = [string]$doc.naturalCaller.listings[0]; text = '9F14  9ED7' },
        @{ path = [string]$doc.naturalCaller.listings[1]; text = '9F3D  9F10' }
    )
    foreach ($spec in $listingSpecs) {
        $full = Join-Path $repo $spec.path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw ("Listing is missing: {0}" -f $spec.path)
        }
        if (-not ((Get-Content -LiteralPath $full -Raw) -match [regex]::Escape($spec.text))) {
            throw ("Listing {0} does not contain {1}" -f $spec.path, $spec.text)
        }
    }
}

function Test-TraceEvidence([byte[]]$rom, $doc) {
    if (-not (Test-Path -LiteralPath $tracePath -PathType Leaf)) {
        throw 'The prior natural trace evidence is missing'
    }
    $trace = Get-Content -LiteralPath $tracePath -Raw | ConvertFrom-Json
    if ([int]$trace.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace([string]$trace.task)) {
        throw 'The curated prior-trace summary is missing its schema/task identity'
    }
    if ([string]$trace.identities.original.sha256 -ne $romSha256) {
        throw 'The prior trace original SHA256 does not match'
    }
    $early = $trace.early_call.original
    if ([string]$early.saved_cursor -ne '9F16' -or
        [string]$early.return_s -ne '0796' -or
        [string]$early.post_return_s -ne '0798' -or
        [string]$early.result -ne '0000') {
        throw 'The prior early 9ED9 call cursor/stack/result facts differ from the contract'
    }

    $events = @($early.events)
    $first = $events | Where-Object { $_.event -eq 'NODE_PREFETCH' -and [string]$_.index -eq '0' } |
        Select-Object -First 1
    if ($null -eq $first -or [string]$first.y -ne '9ED9' -or [string]$first.token -ne '795B' -or
        [string]$first.u -ne '066E' -or [string]$first.s -ne '0796' -or [string]$first.top -ne '0000') {
        throw 'The prior first 9ED9 prefetch does not match Y/token/U/S/top'
    }
    $returnEvent = $events | Where-Object { $_.event -eq 'RETURN_HANDLER' } | Select-Object -Last 1
    if ($null -eq $returnEvent -or [string]$returnEvent.saved_cursor -ne '9F16' -or
        [string]$returnEvent.u -ne '066E' -or [string]$returnEvent.s -ne '0796' -or
        [string]$returnEvent.top -ne '0000') {
        throw 'The prior 7931 return event does not match saved cursor/stack/top'
    }
    $post = $events | Where-Object { $_.event -eq 'POST_RETURN_CALLER_PREFETCH' } | Select-Object -Last 1
    if ($null -eq $post -or [string]$post.y -ne '9F16' -or [string]$post.token -ne '75A9' -or
        [string]$post.u -ne '066E' -or [string]$post.s -ne '0798' -or [string]$post.w_at_s -ne '9F3F') {
        throw 'The prior post-return caller prefetch does not match Y/token/U/S/w@S'
    }

    $facts = $doc.naturalCaller.traceFacts
    if ([string]$facts.firstPrefetch.y -ne [string]$first.y -or
        [string]$facts.returnHandler.savedCursor -ne [string]$returnEvent.saved_cursor -or
        [string]$facts.postReturnPrefetch.token -ne [string]$post.token -or
        [string]$facts.result -ne [string]$early.result) {
        throw 'Contract traceFacts do not match the tracked prior trace'
    }

    return [pscustomobject]@{
        U = [string]$first.u
        S = [string]$early.post_return_s
        Top = [string]$first.top
        Second = [string]$first.second
        SavedCursor = [string]$early.saved_cursor
        Source = 'evidence/mpu4/integrity/il-lua-vm-trace.json'
        EvidenceKind = 'curated_prior_trace_summary_not_raw_logs'
    }
}

function Test-ProposalDocument([byte[]]$rom, $doc) {
    $proposal = $doc.proposal
    $headerAddress = [Convert]::ToInt32([string]$proposal.headerAddress, 16)
    $definition = Test-NewDefinition $rom $headerAddress ([string]$proposal.headerBytes) `
        ([string]$proposal.bodyHex)
    if ($definition.BodyStart -ne [Convert]::ToInt32([string]$proposal.bodyStart, 16) -or
        $definition.BodyEndExclusive -ne [Convert]::ToInt32([string]$proposal.bodyEndExclusive, 16) -or
        $definition.AllocationEnd -ne [Convert]::ToInt32([string]$proposal.allocationEndInclusive, 16) -or
        $definition.AllocationLength -ne [int]$proposal.allocationLength) {
        throw 'Proposal header/body/allocation addresses do not agree'
    }
    if ([string]$proposal.bodyHex -ne [string]$doc.originalDefinition9ed9.bodyHex) {
        throw 'Proposal body is not the byte-identical 9ED9 body'
    }
    Test-DeclaredStackEffect $definition.Stack $proposal.stackEffect

    $replacement = $proposal.tokenReplacement
    if ([string]$replacement.expectedOriginalBytes -ne '9ED7') {
        throw 'Proposal expected original token bytes are not 9ED7'
    }
    if ([string]$replacement.replacementBytes -ne [string]$proposal.headerAddress) {
        throw 'Proposal replacement bytes do not equal the new header address'
    }
    if ([int]$replacement.widthBytes -ne 2 -or -not [bool]$replacement.sameSize) {
        throw 'Proposal callsite replacement is not a declared same-size two-byte patch'
    }
    if ((Read-Word $rom 0x9F14) -ne 0x9ED7) {
        throw 'Original callsite 9F14 is not the expected 9ED7 token'
    }

    $image = $rom.Clone()
    $header = New-Object byte[] 2
    $header[0] = [Convert]::ToByte([string]$proposal.headerBytes.Substring(0, 2), 16)
    $header[1] = [Convert]::ToByte([string]$proposal.headerBytes.Substring(2, 2), 16)
    [Array]::Copy($header, 0, $image, $headerAddress, 2)
    [Array]::Copy($definition.Body, 0, $image, $definition.BodyStart, $definition.Body.Length)
    $image[0x9F14] = [Convert]::ToByte([string]$replacement.replacementBytes.Substring(0, 2), 16)
    $image[0x9F15] = [Convert]::ToByte([string]$replacement.replacementBytes.Substring(2, 2), 16)

    $fields = Get-OrderedIntegrityFields $image
    if ($fields.FieldsHex -ne [string]$doc.integrity.proposedFieldsHex) {
        throw ("Proposed integrity fields {0} do not match the contract {1}" -f $fields.FieldsHex, [string]$doc.integrity.proposedFieldsHex)
    }

    $diff = @(Get-DiffOffsets $rom $image)
    $expected = New-Object System.Collections.ArrayList
    foreach ($offset in @($doc.proposedImageDiff.extensionRealizedChangedOffsets)) {
        $expected.Add([string]$offset) | Out-Null
    }
    foreach ($offset in @($doc.proposedImageDiff.callsiteChangedOffsets)) {
        $expected.Add([string]$offset) | Out-Null
    }
    foreach ($offset in @($doc.proposedImageDiff.integrityChangedOffsets)) {
        $expected.Add([string]$offset) | Out-Null
    }
    $expectedSorted = @($expected | Sort-Object)
    $actualSorted = @($diff | Sort-Object)
    if (($expectedSorted -join ',') -ne ($actualSorted -join ',')) {
        throw ("Proposed diff does not match the contract: actual {0}" -f ($actualSorted -join ','))
    }
    if ($diff.Count -ne [int]$doc.proposedImageDiff.totalChangedCount) {
        throw ("Proposed diff count {0} does not match {1}" -f $diff.Count, [int]$doc.proposedImageDiff.totalChangedCount)
    }
    foreach ($offset in @($doc.proposedImageDiff.extensionUnchangedAllocationOffsets)) {
        if ($rom[[Convert]::ToInt32([string]$offset, 16)] -ne $image[[Convert]::ToInt32([string]$offset, 16)]) {
            throw ("Allocation offset {0} was declared unchanged but differs" -f [string]$offset)
        }
    }
    $sha1 = Get-HashHex $image 'SHA1'
    $sha256 = Get-HashHex $image 'SHA256'
    if ($sha1 -ne [string]$doc.proposedImageDiff.proposedImageSha1) {
        throw ("Proposed image SHA1 {0} does not match the contract" -f $sha1)
    }
    if ($sha256 -ne [string]$doc.proposedImageDiff.proposedImageSha256) {
        throw ("Proposed image SHA256 {0} does not match the contract" -f $sha256)
    }
    if ([bool]$doc.proposedImageDiff.imageWritten) {
        throw 'The contract must not claim that an image was written'
    }

    $originalFields = Get-StoredIntegrityFields $rom
    if ($originalFields.FieldsHex -ne [string]$doc.integrity.originalFieldsHex) {
        throw ("Original integrity fields {0} do not match the contract {1}" -f $originalFields.FieldsHex, [string]$doc.integrity.originalFieldsHex)
    }

    return [pscustomobject]@{
        HeaderAddress = $headerAddress
        BodyStart = $definition.BodyStart
        BodyEndExclusive = $definition.BodyEndExclusive
        AllocationEnd = $definition.AllocationEnd
        FieldsHex = $fields.FieldsHex
        Diff = $diff
        Sha1 = $sha1
        Sha256 = $sha256
        Image = $image
        Definition = $definition
    }
}

function Test-Rejected([string]$id, [scriptblock]$action) {
    try {
        & $action | Out-Null
        Add-Check $id $false 'negative control was accepted but should have been rejected'
    }
    catch {
        Add-Check $id $true ('rejected as expected: ' + $_.Exception.Message)
    }
}

function Copy-ContractDocument($doc) {
    return ($doc | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
}

function Get-PhaseRow($doc, [string]$phaseId) {
    $row = @($doc.proposal.phases) | Where-Object { [string]$_.phase -eq $phaseId } | Select-Object -First 1
    if ($null -eq $row) { throw ("Phase {0} is missing" -f $phaseId) }
    return $row
}

# ---------------------------------------------------------------------------
# Positive checks
# ---------------------------------------------------------------------------
$rom = [System.IO.File]::ReadAllBytes([System.IO.Path]::GetFullPath($RomPath))
Test-ExtensionReservation $rom
Add-Check 'positive-original-identity' $true 'length/SHA1/SHA256 match the exact original'
Add-Check 'positive-extension-range' $true '1010-13EF, guards and 1400 neighbor match the approved reservation'

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    Add-Check 'positive-contract-document' $false 'contract evidence JSON is missing'
}
else {
    $doc = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    Test-ContractDocument $rom $doc
    Add-Check 'positive-byte-contracts' $true 'template, copier, handlers, 9ED9/9F12/9F3B bodies and headers match original bytes'
    Add-Check 'positive-contract-document' $true 'contract evidence matches independent ROM decode'
    $baseline = Test-TraceEvidence $rom $doc
    Add-Check 'positive-prior-trace' $true 'curated prior-trace summary (not raw MAME logs) matches 9F14/9F16/7931/75A9'
    $proposal = Test-ProposalDocument $rom $doc
    Add-Check 'positive-proposal-consistency' $true ('new header/body 1010/1012-101F, diff {0} offsets, fields {1}, SHA256 {2}' -f `
        $proposal.Diff.Count, $proposal.FieldsHex, $proposal.Sha256)
    Test-PhaseMap $proposal.Image $doc $baseline $proposal.Definition
    Add-Check 'positive-phase-chain' $true 'byte-derived static phase chain: 9F14 pre-fetch -> 9F16 saved at 00F8 -> X=1012 -> handlers 00FC/795D/7880/795D/7AB1/7931 -> 9F16/75A9'

    Test-Rejected 'negative-phase-trampoline-y-9f14' {
        $bad = Copy-ContractDocument $doc
        (Get-PhaseRow $bad 'header-trampoline-entry').y = '9F14'
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
    Test-Rejected 'negative-phase-wrong-x-body' {
        $bad = Copy-ContractDocument $doc
        (Get-PhaseRow $bad 'header-trampoline-entry').x = '9ED9'
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
    Test-Rejected 'negative-phase-wrong-saved-cursor' {
        $bad = Copy-ContractDocument $doc
        (Get-PhaseRow $bad 'header-trampoline-entry').savedAfterPush = '9F14'
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
    Test-Rejected 'negative-phase-wrong-restored-cursor' {
        $bad = Copy-ContractDocument $doc
        (Get-PhaseRow $bad 'return-handler').savedCursor = '9F14'
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
    Test-Rejected 'negative-phase-handler-inline-advance' {
        $bad = Copy-ContractDocument $doc
        (Get-PhaseRow $bad 'handler-2').y = '101C'
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
    Test-Rejected 'negative-phase-handler-inline-operand' {
        $bad = Copy-ContractDocument $doc
        (Get-PhaseRow $bad 'handler-0').inlineOperand = 'FF81'
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
    Test-Rejected 'negative-phase-false-natural-execution' {
        $bad = Copy-ContractDocument $doc
        $bad.proposal.naturalExecutionObserved = $true
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
    Test-Rejected 'negative-phase-false-execution-status' {
        $bad = Copy-ContractDocument $doc
        $bad.status = 'new-word-executed-naturally'
        Test-PhaseMap $proposal.Image $bad $baseline $proposal.Definition
    }
}

# ---------------------------------------------------------------------------
# Negative controls (all in memory; no ROM is written)
# ---------------------------------------------------------------------------
$bodyHex = '795BFF80787E795BFF807AAF792F'
Test-Rejected 'negative-wrong-identity' {
    $bad = $rom.Clone()
    $bad[0x1400] = [byte]($bad[0x1400] -bxor 0x01)
    Test-RomIdentity $bad
}
Test-Rejected 'negative-unsupported-token' {
    Test-NewDefinition $rom 0x1010 '00F8' ('0000' + 'FF80' + '787E' + '795B' + 'FF80' + '7AAF' + '792F')
}
Test-Rejected 'negative-bad-header' {
    Test-NewDefinition $rom 0x1010 '00F9' $bodyHex
}
Test-Rejected 'negative-overflow' {
    Test-NewDefinition $rom 0x13E8 '00F8' $bodyHex
}
Test-Rejected 'negative-callsite-expected-bytes' {
    $bad = $rom.Clone()
    $bad[0x9F14] = 0x00
    $bad[0x9F15] = 0x00
    Test-CallerContract $bad
}
Test-Rejected 'negative-stack-contract-overclaim' {
    $computed = [pscustomobject]@{ UNet = 0; SDeltaAtReturn = 2 }
    $overclaim = [pscustomobject]@{
        callSiteUNet = -2
        callSiteSNet = 0
        tokenBodyUNet = 0
        entryTrampolineSDelta = -2
        returnHandlerSDelta = 2
        callerSuccessor = '9F16'
        postReturnToken = '75A9'
    }
    Test-DeclaredStackEffect $computed $overclaim
}

if ($script:failed) {
    Write-Log 'RESULT: FAIL'
}
else {
    Write-Log 'RESULT: PASS'
}

$report = [ordered]@{
    schemaVersion = 1
    taskId = 'il-composite-phase-32'
    contractTaskId = 'il-composite-contract-31'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    result = if ($script:failed) { 'fail' } else { 'pass' }
    romPath = [System.IO.Path]::GetFullPath($RomPath)
    romSha1 = Get-HashHex $rom 'SHA1'
    romSha256 = Get-HashHex $rom 'SHA256'
    contractPath = 'evidence/mpu4/integrity/il-composite-contract.json'
    checks = @($checks.ToArray())
    summary = [ordered]@{
        total = $checks.Count
        passed = @($checks | Where-Object { $_.ok }).Count
        failed = @($checks | Where-Object { -not $_.ok }).Count
    }
    boundaries = [ordered]@{
        romWritten = $false
        mameRun = $false
        hardwareTested = $false
        newWordExecuted = $false
        priorTraceSource = 'curated-summary-not-raw-mame-logs'
    }
}
$reportJson = ConvertTo-Json -InputObject $report -Depth 8
$reportJson = $reportJson.Replace("`r`n", "`n")
[System.IO.File]::WriteAllText((Join-Path $outDir 'checker-report.json'), $reportJson,
    (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText((Join-Path $outDir 'checker-log.txt'), (($log -join "`n") + "`n"),
    (New-Object System.Text.UTF8Encoding($false)))

if ($script:failed) { exit 1 }
exit 0
