using System.Runtime.CompilerServices;

[assembly: InternalsVisibleTo("FruitMachineLab.IlVerification")]

namespace FruitMachineLab.Il;

[Flags]
public enum VmIlEvidenceClass
{
    None = 0,
    OriginalRomBytes = 1
}

public sealed record VmIlOperand(ushort Address, byte[] Bytes, ushort Value);

public sealed record VmIlNode(
    int Index,
    ushort Address,
    ushort Token,
    string Operation,
    byte[] Bytes,
    VmIlOperand? Operand,
    VmIlEvidenceClass EvidenceClass);

public sealed record VmIlProvenance(
    string EvidenceClass,
    string ListingPath,
    string ListingSha256,
    string CheckpointPath,
    string CheckpointSpanClassification,
    int ObservedSites);

public sealed record VmIlDefinition(
    int RomLength,
    string RomSha1,
    string RomSha256,
    ushort HeaderAddress,
    byte[] HeaderBytes,
    ushort BodyStart,
    int BodyEndExclusive,
    IReadOnlyList<VmIlNode> Nodes,
    VmIlProvenance Provenance)
{
    public int BodyLength => BodyEndExclusive - BodyStart;
}

public sealed record VmIlCompileResult(
    byte[] Image,
    byte[] EmittedBody,
    string InputSha256,
    string OutputSha256,
    int[] ChangedOffsets);

public sealed record VmIlOperandEdit(
    ushort OperandAddress,
    ushort ExpectedOriginalValue,
    ushort ReplacementValue);

public sealed record VmIlEditReport(
    int NodeIndex,
    ushort TokenAddress,
    ushort OperandAddress,
    ushort Token,
    string Operation,
    int OperandWidthBytes,
    ushort ExpectedOriginalValue,
    ushort ActualOriginalValue,
    ushort ReplacementValue,
    string ExpectedOriginalBytesHex,
    string ReplacementBytesHex,
    int[] ChangedOffsets);

public sealed record VmIlEditCompileResult(
    VmIlDefinition SourceDefinition,
    VmIlCompileResult Compile,
    VmIlEditReport Edit,
    string OriginalRomSha1,
    string OriginalRomSha256,
    bool IntegrityRepaired,
    string IntegrityStatus);

public static class VmIlVocabulary
{
    public const ushort InlineWordLiteral = 0x795B;
    public const ushort AddWords = 0x787E;
    public const ushort BitwiseXor = 0x7AAF;
    public const ushort ReturnToCallerStream = 0x792F;

    public const string InlineWordLiteralOperation = "vm_push_inline_word_literal";
    public const string AddWordsOperation = "vm_add_words";
    public const string BitwiseXorOperation = "vm_bitwise_xor";
    public const string ReturnToCallerStreamOperation = "vm_return_to_caller_stream";

    public static bool TryGetOperation(ushort token, out string operation, out int operandBytes)
    {
        switch (token)
        {
            case InlineWordLiteral:
                operation = InlineWordLiteralOperation;
                operandBytes = 2;
                return true;
            case AddWords:
                operation = AddWordsOperation;
                operandBytes = 0;
                return true;
            case BitwiseXor:
                operation = BitwiseXorOperation;
                operandBytes = 0;
                return true;
            case ReturnToCallerStream:
                operation = ReturnToCallerStreamOperation;
                operandBytes = 0;
                return true;
            default:
                operation = string.Empty;
                operandBytes = 0;
                return false;
        }
    }
}
