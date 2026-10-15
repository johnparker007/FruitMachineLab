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
    public ushort? DataStackBase {get;set;}
    public ushort DataPointer=>Cell.Subtract(DataStackBase ?? throw new NotSupportedException("Physical U-stack mapping required"),unchecked((ushort)(2*Data.Count)));
    public void SyncDataToMemory()
    {
        ushort address=DataPointer;foreach(var cell in Data){WriteWord(address,cell);address=Cell.Add(address,2);}
    }
    public void SetDataPointer(ushort pointer)
    {
        ushort size=Cell.Subtract(DataStackBase ?? throw new NotSupportedException("Physical U-stack mapping required"),pointer);
        if((size&1)!=0 || size>0x8000)throw new NotSupportedException("Unrecovered invalid U-stack pointer");
        Data.Clear();for(int offset=size-2;offset>=0;offset-=2)Data.Push(ReadWord(Cell.Add(pointer,(ushort)offset)));
    }
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

public record DiagnosticEvent(ushort Site, string Kind, int Value, string Evidence);
