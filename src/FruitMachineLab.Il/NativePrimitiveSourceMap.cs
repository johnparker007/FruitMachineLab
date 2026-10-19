using System.Collections.ObjectModel;
using System.Security.Cryptography;

namespace FruitMachineLab.Il;

public enum NativePrimitiveMapKind
{
    TokenCell,
    NativeHandler,
    CallerToken,
    CallerSuccessor
}

public sealed record NativePrimitiveMapEntry(
    ushort Address,
    NativePrimitiveMapKind Kind,
    ushort? Token,
    ushort? ReplacementToken,
    ushort? HandlerAddress,
    string Operation,
    byte ImageByte);

public sealed record NativePrimitiveHandlerInstruction(
    int Index,
    ushort Address,
    ushort NextAddress,
    string BytesHex,
    string Operation);

public sealed record NativePrimitiveDispatchBinding(
    ushort StreamAddressC,
    ushort TokenCellT,
    ushort HandlerAddressH,
    ushort TokenValue,
    ushort HandlerValue,
    ushort AfterDispatchPc,
    ushort AfterDispatchX,
    ushort AfterDispatchY,
    ushort OriginalCallerToken,
    ushort ReplacementCallerToken,
    ushort SuccessorAddress,
    ushort SuccessorToken,
    ushort RejoinAddress,
    ushort RejoinY,
    ushort ParentTokenAddress,
    ushort ParentToken,
    ushort ParentSuccessorAddress,
    ushort ParentSuccessorToken);

public sealed record NativePrimitiveSemanticContract(
    string StackEffect,
    bool DataStackPointerUnchanged,
    bool ControlStackPointerUnchanged,
    bool CursorUnchanged,
    bool DClobbered,
    bool HDefinedOutput,
    string FlagContract,
    string HContract,
    string IntentionalChange,
    string Classification);

public sealed record NativePrimitiveStaticPhase(
    string Phase,
    string Classification,
    ushort Pc,
    ushort? X,
    ushort Y,
    ushort U,
    ushort S,
    ushort? TopCell,
    string Note);

public sealed record NativePrimitiveOuterReturnContext(
    ushort TokenAddress,
    ushort Token,
    ushort SuccessorAddress,
    ushort SuccessorToken,
    string Classification);

public sealed record NativePrimitiveProvenance(
    string ProposalId,
    string ContractTaskId,
    string OriginalDefinitionListingPath,
    string OriginalDefinitionListingSha256,
    string Classification);

public sealed class NativePrimitiveSourceMap
{
    public const string PhaseClassification =
        "static_prediction_not_execution";
    public const string PointerCellRole =
        "direct_native_handler_pointer_not_00f8_definition_header";
    public const string BuildClassification =
        "static_native_primitive_map_bound_to_exact_output_sha256";

    private readonly ReadOnlyCollection<NativePrimitiveMapEntry> _entries;
    private readonly ReadOnlyCollection<NativePrimitiveHandlerInstruction> _instructions;
    private readonly ReadOnlyCollection<NativePrimitiveStaticPhase> _phases;

    private NativePrimitiveSourceMap(
        string originalRomSha1,
        string originalRomSha256,
        string outputImageSha1,
        string outputImageSha256,
        NativePrimitiveMapEntry[] entries,
        NativePrimitiveHandlerInstruction[] instructions,
        NativePrimitiveStaticPhase[] phases,
        NativePrimitiveDispatchBinding dispatch,
        NativePrimitiveSemanticContract semantics,
        NativePrimitiveOuterReturnContext outerReturn,
        NativePrimitiveProvenance provenance)
    {
        OriginalRomSha1 = originalRomSha1;
        OriginalRomSha256 = originalRomSha256;
        OutputImageSha1 = outputImageSha1;
        OutputImageSha256 = outputImageSha256;
        _entries = Array.AsReadOnly((NativePrimitiveMapEntry[])entries.Clone());
        _instructions = Array.AsReadOnly(
            (NativePrimitiveHandlerInstruction[])instructions.Clone());
        _phases = Array.AsReadOnly((NativePrimitiveStaticPhase[])phases.Clone());
        Dispatch = dispatch;
        Semantics = semantics;
        OuterReturn = outerReturn;
        Provenance = provenance;
    }

    public string OriginalRomSha1 { get; }

    public string OriginalRomSha256 { get; }

    public string OutputImageSha1 { get; }

    public string OutputImageSha256 { get; }

    public string BuildId => OutputImageSha256;

    public ushort TokenAddress => NativePrimitiveWordBuilder.TokenAddress;

    public ushort TokenValue => NativePrimitiveWordBuilder.TokenValue;

    public ushort HandlerStart => NativePrimitiveWordBuilder.HandlerStart;

    public int HandlerEndExclusive => NativePrimitiveWordBuilder.HandlerEndExclusive;

    public bool IsDefinitionHeader => false;

    public string PointerCellClassification => PointerCellRole;

    public ReadOnlyCollection<NativePrimitiveMapEntry> Entries => _entries;

    public ReadOnlyCollection<NativePrimitiveHandlerInstruction> Instructions => _instructions;

    public ReadOnlyCollection<NativePrimitiveStaticPhase> Phases => _phases;

    public NativePrimitiveDispatchBinding Dispatch { get; }

    public NativePrimitiveSemanticContract Semantics { get; }

    public NativePrimitiveOuterReturnContext OuterReturn { get; }

    public NativePrimitiveProvenance Provenance { get; }

    public string Classification => BuildClassification;

    public NativePrimitiveMapEntry Resolve(ushort address)
    {
        foreach (NativePrimitiveMapEntry entry in _entries)
        {
            if (entry.Address == address)
                return entry;
        }
        throw new KeyNotFoundException(
            $"Native-primitive source map has no entry for address {address:X4}");
    }

    public NativePrimitiveMapEntry Resolve(ushort address, string outputImageSha256)
    {
        ValidateBuild(outputImageSha256);
        return Resolve(address);
    }

    public NativePrimitiveMapEntry Resolve(ushort address, ReadOnlySpan<byte> outputImage)
    {
        ValidateImage(outputImage);
        NativePrimitiveMapEntry entry = Resolve(address);
        if (entry.ImageByte != outputImage[address])
            throw new InvalidDataException(
                $"Native-primitive source-map byte at {address:X4} is {entry.ImageByte:X2}; " +
                $"the bound image contains {outputImage[address]:X2}");
        return entry;
    }

    public void ValidateBuild(string outputImageSha256)
    {
        if (!string.Equals(
                outputImageSha256, OutputImageSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException(
                $"Native-primitive source-map build identity mismatch: map is bound to " +
                $"{OutputImageSha256}, not {outputImageSha256}");
    }

    public void ValidateImage(ReadOnlySpan<byte> outputImage)
    {
        ValidateImageCore(outputImage, _entries);
    }

    internal static NativePrimitiveSourceMap CreateForBuild(
        ReadOnlySpan<byte> originalRom,
        ReadOnlySpan<byte> outputImage,
        NativePrimitiveProvenance provenance)
    {
        NineEdNineDecoder.ValidateIdentity(
            originalRom,
            NineEdNineDecoder.RequiredRomLength,
            NineEdNineDecoder.RequiredRomSha1,
            NineEdNineDecoder.RequiredRomSha256);
        if (outputImage.Length != originalRom.Length)
            throw new InvalidDataException(
                "Native-primitive source-map image length differs from the original ROM");

        ValidateOriginalContext(originalRom);

        var entries = new List<NativePrimitiveMapEntry>(15);
        entries.Add(new NativePrimitiveMapEntry(
            NativePrimitiveWordBuilder.TokenAddress,
            NativePrimitiveMapKind.TokenCell,
            NativePrimitiveWordBuilder.TokenValue,
            null,
            NativePrimitiveWordBuilder.HandlerStart,
            "direct-native-token-cell",
            outputImage[NativePrimitiveWordBuilder.TokenAddress]));
        entries.Add(new NativePrimitiveMapEntry(
            NativePrimitiveWordBuilder.TokenAddress + 1,
            NativePrimitiveMapKind.TokenCell,
            NativePrimitiveWordBuilder.TokenValue,
            null,
            NativePrimitiveWordBuilder.HandlerStart,
            "direct-native-token-cell",
            outputImage[NativePrimitiveWordBuilder.TokenAddress + 1]));

        foreach (NativePrimitiveHandlerInstruction instruction in
                 NativePrimitiveWordBuilder.HandlerInstructions)
        {
            byte[] bytes = Convert.FromHexString(instruction.BytesHex);
            for (int index = 0; index < bytes.Length; index++)
            {
                int address = instruction.Address + index;
                entries.Add(new NativePrimitiveMapEntry(
                    checked((ushort)address),
                    NativePrimitiveMapKind.NativeHandler,
                    null,
                    null,
                    instruction.Address,
                    instruction.Operation,
                    outputImage[address]));
            }
        }

        entries.Add(new NativePrimitiveMapEntry(
            NativePrimitiveWordBuilder.CallerTokenAddress,
            NativePrimitiveMapKind.CallerToken,
            NativePrimitiveWordBuilder.CallerOriginalToken,
            NativePrimitiveWordBuilder.CallerReplacementToken,
            NativePrimitiveWordBuilder.HandlerStart,
            "caller-token-redirect",
            outputImage[NativePrimitiveWordBuilder.CallerTokenAddress]));
        entries.Add(new NativePrimitiveMapEntry(
            NativePrimitiveWordBuilder.CallerTokenAddress + 1,
            NativePrimitiveMapKind.CallerToken,
            NativePrimitiveWordBuilder.CallerOriginalToken,
            NativePrimitiveWordBuilder.CallerReplacementToken,
            NativePrimitiveWordBuilder.HandlerStart,
            "caller-token-redirect",
            outputImage[NativePrimitiveWordBuilder.CallerTokenAddress + 1]));
        entries.Add(new NativePrimitiveMapEntry(
            NativePrimitiveWordBuilder.CallerSuccessorAddress,
            NativePrimitiveMapKind.CallerSuccessor,
            NativePrimitiveWordBuilder.CallerSuccessorToken,
            null,
            null,
            "caller-successor-token",
            outputImage[NativePrimitiveWordBuilder.CallerSuccessorAddress]));
        entries.Add(new NativePrimitiveMapEntry(
            NativePrimitiveWordBuilder.CallerSuccessorAddress + 1,
            NativePrimitiveMapKind.CallerSuccessor,
            NativePrimitiveWordBuilder.CallerSuccessorToken,
            null,
            null,
            "caller-successor-token",
            outputImage[NativePrimitiveWordBuilder.CallerSuccessorAddress + 1]));

        NativePrimitiveMapEntry[] entryArray = entries.ToArray();

        var dispatch = new NativePrimitiveDispatchBinding(
            NativePrimitiveWordBuilder.CallerTokenAddress,
            NativePrimitiveWordBuilder.TokenAddress,
            NativePrimitiveWordBuilder.HandlerStart,
            NativePrimitiveWordBuilder.TokenValue,
            NativePrimitiveWordBuilder.TokenValue,
            NativePrimitiveWordBuilder.HandlerStart,
            (ushort)(NativePrimitiveWordBuilder.TokenAddress + 2),
            (ushort)(NativePrimitiveWordBuilder.CallerTokenAddress + 2),
            NativePrimitiveWordBuilder.CallerOriginalToken,
            NativePrimitiveWordBuilder.CallerReplacementToken,
            NativePrimitiveWordBuilder.CallerSuccessorAddress,
            NativePrimitiveWordBuilder.CallerSuccessorToken,
            NativePrimitiveWordBuilder.RejoinAddress,
            NativePrimitiveWordBuilder.CallerSuccessorAddress,
            NativePrimitiveWordBuilder.ParentTokenAddress,
            NativePrimitiveWordBuilder.ParentToken,
            NativePrimitiveWordBuilder.ParentSuccessorAddress,
            NativePrimitiveWordBuilder.ParentSuccessorToken);

        var semantics = new NativePrimitiveSemanticContract(
            "n -- (n + 8000h) mod 10000h; one 16-bit in-place cell",
            DataStackPointerUnchanged: true,
            ControlStackPointerUnchanged: true,
            CursorUnchanged: true,
            DClobbered: true,
            HDefinedOutput: false,
            FlagContract:
                "LDD defines N/Z, clears V, preserves H/C; ADDD defines N/Z/V/C and " +
                "preserves H; STD defines N/Z, clears V, preserves H/C; JMP preserves all.",
            HContract:
                "H is not defined or asserted by this word; it is preserved from the " +
                "incoming state.",
            IntentionalChange:
                "Intentional behaviour change: observed input 0000 predicts handler 8000, " +
                "then FFFF after 75A9. This does not preserve the original 9ED9/9F12 " +
                "behaviour and is not a full-game proof.",
            Classification: PhaseClassification);

        var phases = new[]
        {
            new NativePrimitiveStaticPhase(
                "caller-prefetch", PhaseClassification, 0x00FC, null, 0x9F14,
                0x066E, 0x0798, 0x0000,
                "Before LDX ,Y++ at 00FC; caller word at 9F14 is replaced by 1010."),
            new NativePrimitiveStaticPhase(
                "direct-handler-entry", PhaseClassification, 0x1012, 0x1012, 0x9F16,
                0x066E, 0x0798, 0x0000,
                "After JMP [,X++] at 00FE; direct entry H=1012, X=T+2, Y=C+2."),
            new NativePrimitiveStaticPhase(
                "after-ldd", PhaseClassification, 0x1014, 0x1012, 0x9F16,
                0x066E, 0x0798, 0x0000,
                "After LDD ,U; D=0000, U and Y unchanged."),
            new NativePrimitiveStaticPhase(
                "after-addd", PhaseClassification, 0x1017, 0x1012, 0x9F16,
                0x066E, 0x0798, 0x0000,
                "After ADDD #$8000; D=8000, C=0, V=0; H preserved and not asserted."),
            new NativePrimitiveStaticPhase(
                "after-std", PhaseClassification, 0x1019, 0x1012, 0x9F16,
                0x066E, 0x0798, 0x8000,
                "After STD ,U; top cell is 8000 and S/U/Y are unchanged."),
            new NativePrimitiveStaticPhase(
                "post-handler-prefetch", PhaseClassification, 0x00FC, 0x1012, 0x9F16,
                0x066E, 0x0798, 0x8000,
                "Dispatcher rejoin at 00FC with Y=9F16; next token is 75A9."),
            new NativePrimitiveStaticPhase(
                "75ab-entry", PhaseClassification, 0x75AB, 0x75AB, 0x9F18,
                0x066E, 0x0798, 0x8000,
                "Static prediction: BMI taken from the 8000 result."),
            new NativePrimitiveStaticPhase(
                "negative-arm", PhaseClassification, 0x75B6, 0x75AB, 0x9F18,
                0x066E, 0x0798, 0x8000,
                "Static prediction: negative arm before LDD #$FFFF."),
            new NativePrimitiveStaticPhase(
                "post-75a9", PhaseClassification, 0x00FC, 0x75AB, 0x9F18,
                0x066E, 0x0798, 0xFFFF,
                "Static prediction: rejoin at 00FC with top FFFF and next token 7B7D."),
            new NativePrimitiveStaticPhase(
                "after-swap-drop", PhaseClassification, 0x00FC, 0x7B3F, 0x9F1C,
                0x0670, 0x0798, 0xFFFF,
                "Static prediction after swap/drop; next token 792F."),
            new NativePrimitiveStaticPhase(
                "return-handler", PhaseClassification, 0x7931, 0x7931, 0x9F1E,
                0x0670, 0x0798, 0xFFFF,
                "Static prediction: return handler; saved cursor 9F3F."),
            new NativePrimitiveStaticPhase(
                "9f12-post-return", PhaseClassification, 0x00FC, 0x7931, 0x9F3F,
                0x0670, 0x079A, 0xFFFF,
                "Static prediction only: parent return context restored by PULS Y.")
        };

        var outerReturn = new NativePrimitiveOuterReturnContext(
            NativePrimitiveWordBuilder.ParentTokenAddress,
            NativePrimitiveWordBuilder.ParentToken,
            NativePrimitiveWordBuilder.ParentSuccessorAddress,
            NativePrimitiveWordBuilder.ParentSuccessorToken,
            PhaseClassification);

        var map = new NativePrimitiveSourceMap(
            Sha1(originalRom),
            Sha256(originalRom),
            Sha1(outputImage),
            Sha256(outputImage),
            entryArray,
            NativePrimitiveWordBuilder.HandlerInstructions.ToArray(),
            phases,
            dispatch,
            semantics,
            outerReturn,
            provenance);
        map.ValidateImage(outputImage);
        return map;
    }

    private static void ValidateOriginalContext(ReadOnlySpan<byte> originalRom)
    {
        if (!originalRom.Slice(
                NativePrimitiveWordBuilder.OriginalDefinitionHeaderAddress, 2)
                .SequenceEqual(new byte[] { 0x00, 0xF8 }))
            throw new InvalidDataException(
                "Original 9ED7 definition header is not 00F8");
        if (!originalRom.Slice(
                NativePrimitiveWordBuilder.OriginalDefinitionBodyStart,
                NativePrimitiveWordBuilder.OriginalDefinitionBodyLength)
                .SequenceEqual(Convert.FromHexString(
                    NativePrimitiveWordBuilder.OriginalDefinitionBodyHex)))
            throw new InvalidDataException(
                "Original 9ED9 body differs from the certified reviewed body");
        if (!originalRom.Slice(
                NativePrimitiveWordBuilder.CallerTokenAddress, 2)
                .SequenceEqual(new byte[] { 0x9E, 0xD7 }))
            throw new InvalidDataException(
                "Original caller token at 9F14 is not 9ED7");
        if (!originalRom.Slice(
                NativePrimitiveWordBuilder.CallerSuccessorAddress, 2)
                .SequenceEqual(new byte[] { 0x75, 0xA9 }))
            throw new InvalidDataException(
                "Original caller successor at 9F16 is not 75A9");
        if (!originalRom.Slice(
                NativePrimitiveWordBuilder.ParentTokenAddress, 2)
                .SequenceEqual(new byte[] { 0x9F, 0x10 }) ||
            !originalRom.Slice(
                NativePrimitiveWordBuilder.ParentSuccessorAddress, 2)
                .SequenceEqual(new byte[] { 0x79, 0x2F }))
            throw new InvalidDataException(
                "Parent caller context at 9F3D/9F3F differs from the reviewed contract");
    }

    private void ValidateImageCore(
        ReadOnlySpan<byte> outputImage, IReadOnlyList<NativePrimitiveMapEntry> entries)
    {
        if (outputImage.Length != 0x10000)
            throw new InvalidDataException(
                $"Native-primitive source-map image length {outputImage.Length} differs " +
                "from 65536");
        string sha256 = Sha256(outputImage);
        ValidateBuild(sha256);

        if (!outputImage.Slice(NativePrimitiveWordBuilder.TokenAddress, 2)
                .SequenceEqual(Convert.FromHexString(
                    NativePrimitiveWordBuilder.TokenHex)))
            throw new InvalidDataException(
                "Native-primitive source-map token cell at 1010 is not 1012");
        if (!outputImage.Slice(
                NativePrimitiveWordBuilder.HandlerStart,
                NativePrimitiveWordBuilder.HandlerEndExclusive -
                NativePrimitiveWordBuilder.HandlerStart)
                .SequenceEqual(Convert.FromHexString(
                    NativePrimitiveWordBuilder.HandlerHex)))
            throw new InvalidDataException(
                "Native-primitive source-map handler at 1012-101A differs from the " +
                "reviewed bytes");
        if (!outputImage.Slice(NativePrimitiveWordBuilder.CallerTokenAddress, 2)
                .SequenceEqual(Convert.FromHexString(
                    NativePrimitiveWordBuilder.CallerReplacementTokenHex)))
            throw new InvalidDataException(
                "Native-primitive source-map caller at 9F14 is not 1010");
        if (!outputImage.Slice(NativePrimitiveWordBuilder.CallerSuccessorAddress, 2)
                .SequenceEqual(Convert.FromHexString(
                    NativePrimitiveWordBuilder.CallerSuccessorTokenHex)))
            throw new InvalidDataException(
                "Native-primitive source-map caller successor at 9F16 is not 75A9");
        if (!outputImage.Slice(
                NativePrimitiveWordBuilder.OriginalDefinitionHeaderAddress, 2)
                .SequenceEqual(new byte[] { 0x00, 0xF8 }) ||
            !outputImage.Slice(
                NativePrimitiveWordBuilder.OriginalDefinitionBodyStart,
                NativePrimitiveWordBuilder.OriginalDefinitionBodyLength)
                .SequenceEqual(Convert.FromHexString(
                    NativePrimitiveWordBuilder.OriginalDefinitionBodyHex)))
            throw new InvalidDataException(
                "Native-primitive source-map output changed the original 9ED7/9ED9 definition");

        ushort t = ReadWord(outputImage, NativePrimitiveWordBuilder.CallerTokenAddress);
        ushort h = ReadWord(outputImage, t);
        if (t != NativePrimitiveWordBuilder.CallerReplacementToken ||
            h != NativePrimitiveWordBuilder.TokenValue)
            throw new InvalidDataException(
                "Native-primitive dispatch arithmetic C/T/H differs from 9F14/1010/1012");
        if (h == 0x00F8)
            throw new InvalidDataException(
                "Native-primitive pointer cell must not be a 00F8 composite header");

        foreach (NativePrimitiveMapEntry entry in entries)
        {
            if (entry.ImageByte != outputImage[entry.Address])
                throw new InvalidDataException(
                    $"Native-primitive source-map byte at {entry.Address:X4} is " +
                    $"{entry.ImageByte:X2}; the bound image contains " +
                    $"{outputImage[entry.Address]:X2}");
        }
    }

    private static ushort ReadWord(ReadOnlySpan<byte> image, int address) =>
        (ushort)((image[address] << 8) | image[address + 1]);

    private static string Sha1(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA1.HashData(bytes));

    private static string Sha256(ReadOnlySpan<byte> bytes) =>
        Convert.ToHexString(SHA256.HashData(bytes));
}
