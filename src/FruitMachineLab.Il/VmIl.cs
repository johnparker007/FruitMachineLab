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

public enum VmIlBranchCondition
{
    Always,
    IfZero
}

public sealed record VmIlBranch(
    ushort HandlerAddress,
    ushort OperandAddress,
    byte OperandByte,
    ushort TargetAddress,
    VmIlBranchCondition Condition,
    string OffsetBase,
    bool OffsetUnsigned,
    int OperandWidthBytes,
    string EvidenceClass);

public sealed record VmIlNode(
    int Index,
    ushort Address,
    ushort Token,
    string Operation,
    byte[] Bytes,
    VmIlOperand? Operand,
    VmIlEvidenceClass EvidenceClass)
{
    public VmIlBranch? Branch { get; init; }
}

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

public sealed record VmIlRepairedEditCompileResult(
    VmIlEditCompileResult Unrepaired,
    VmIlIntegrityResult Integrity);

public static class VmIlVocabulary
{
    public const ushort InlineWordLiteral = 0x795B;
    public const ushort AddWords = 0x787E;
    public const ushort BitwiseXor = 0x7AAF;
    public const ushort ReturnToCallerStream = 0x792F;

    public const ushort RotateThreeCells = 0x7B6D;
    public const ushort BranchForward8IfZero = 0x7982;
    public const ushort OrWordMemory = 0x7665;
    public const ushort BranchUnsignedForward8 = 0x7979;
    public const ushort ClearWordMemoryBits = 0x7671;

    public const string InlineWordLiteralOperation = "vm_push_inline_word_literal";
    public const string AddWordsOperation = "vm_add_words";
    public const string BitwiseXorOperation = "vm_bitwise_xor";
    public const string ReturnToCallerStreamOperation = "vm_return_to_caller_stream";

    public const string RotateThreeCellsOperation = "vm_rotate_three_cells";
    public const string BranchForward8IfZeroOperation = "vm_branch_forward8_if_zero";
    public const string OrWordMemoryOperation = "vm_or_word_memory";
    public const string BranchUnsignedForward8Operation = "vm_branch_unsigned_forward8";
    public const string ClearWordMemoryBitsOperation = "vm_clear_word_memory_bits";

    public static bool TryGetOperation(
        ushort token, out string operation, out int operandBytes) =>
        TryGetOperation(token, out operation, out operandBytes, includeNineASixFour: false);

    public static bool TryGetOperation(
        ushort token,
        out string operation,
        out int operandBytes,
        bool includeNineASixFour)
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
            case RotateThreeCells when includeNineASixFour:
                operation = RotateThreeCellsOperation;
                operandBytes = 0;
                return true;
            case BranchForward8IfZero when includeNineASixFour:
                operation = BranchForward8IfZeroOperation;
                operandBytes = 1;
                return true;
            case OrWordMemory when includeNineASixFour:
                operation = OrWordMemoryOperation;
                operandBytes = 0;
                return true;
            case BranchUnsignedForward8 when includeNineASixFour:
                operation = BranchUnsignedForward8Operation;
                operandBytes = 1;
                return true;
            case ClearWordMemoryBits when includeNineASixFour:
                operation = ClearWordMemoryBitsOperation;
                operandBytes = 0;
                return true;
            default:
                operation = string.Empty;
                operandBytes = 0;
                return false;
        }
    }

    public static bool IsBranchWithByteOperand(ushort token) =>
        token is BranchForward8IfZero or BranchUnsignedForward8;

    public static bool IsNineASixFourToken(ushort token) =>
        token is RotateThreeCells or BranchForward8IfZero or OrWordMemory or
            BranchUnsignedForward8 or ClearWordMemoryBits or ReturnToCallerStream;
}
