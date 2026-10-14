namespace FruitMachineLab.Runtime;

public static class Cell
{
    public static ushort Add(ushort a, ushort b) => unchecked((ushort)(a + b));
    public static ushort Subtract(ushort a, ushort b) => unchecked((ushort)(a - b));
    public static ushort Multiply(ushort a, ushort b) => unchecked((ushort)(a * b));
    public static ushort Flag(bool value) => value ? ushort.MaxValue : (ushort)0;
    public static ushort Min(ushort a, ushort b) => (short)a < (short)b ? a : b;
}

// Big-endian 6809 cells, with explicit 16-bit address wraparound.
public sealed class Machine
{
    public byte[] Memory { get; } = new byte[65536];
    public Stack<ushort> Data { get; } = new();
    public ushort LocalFrame { get=>ReadWord(0xF4);set=>WriteWord(0xF4,value); }
    public VmControlStack? Control { get; set; }
    public ushort ReadWord(ushort address) => (ushort)((Memory[address] << 8) | Memory[Cell.Add(address, 1)]);
    public void WriteWord(ushort address, ushort value)
    {
        Memory[address] = (byte)(value >> 8);
        Memory[Cell.Add(address, 1)] = (byte)value;
    }
    public ushort Pop() => Data.Count > 0 ? Data.Pop() : throw new InvalidOperationException("VM data stack underflow");
}

public record DiagnosticEvent(ushort Site, string Kind, ushort Value, string Evidence);
