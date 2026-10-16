namespace FruitMachineLab.Runtime;

/// <summary>6809 S-stack mechanics from 76AB/769F, 79DE/7A02 and 7937.</summary>
public sealed class VmControlStack(Machine machine,ushort pointer)
{
    public ushort Pointer { get; private set; }=pointer;
    public ushort LoopFrame { get=>machine.ReadWord(0xF6); set=>machine.WriteWord(0xF6,value); }
    public ushort ResumeCursor { get; private set; }
    public void Push(ushort word) { Pointer=Cell.Subtract(Pointer,2);machine.WriteWord(Pointer,word); }
    public ushort Pop() { var word=machine.ReadWord(Pointer);Pointer=Cell.Add(Pointer,2);return word; }
    // A full 6809 IRQ frame saves DP at pre-interrupt S-9. Call only when
    // the CPU adapter establishes S has no extra native stack depth. Other
    // register/CC bytes are deliberately not synthesized here.
    public void PreserveInterruptDirectPage(byte directPage)=>machine.Memory[Cell.Subtract(Pointer,9)]=directPage;
    public void EnterCall(ushort continuation)=>Push(continuation);
    public void AllocateLocalFrame(ushort size)
    {
        Push(machine.LocalFrame);
        Pointer=Cell.Subtract(Pointer,size);
        machine.LocalFrame=Pointer;
        Push(size);
        Push(0x76BD); // inline return word 769D -> native release handler 769F
    }
    public void EnterLoop(ushort start,ushort limit,ushort continuation)
    {
        Push(LoopFrame);Push(continuation);Push(limit);Push(start);LoopFrame=Pointer;
    }
    public ushort LoopIndex=>machine.ReadWord(LoopFrame);
    public ushort OuterLoopIndex=>machine.ReadWord(machine.ReadWord(Cell.Add(LoopFrame,6)));
    public ushort? IncrementLoop()
    {
        if(Pointer!=LoopFrame)throw new InvalidOperationException("Loop increment requires the current frame at S");
        var index=Cell.Add(machine.ReadWord(Pointer),1);machine.WriteWord(Pointer,index);
        if(index!=machine.ReadWord(Cell.Add(Pointer,2)))return machine.ReadWord(Cell.Add(Pointer,4));
        RemoveLoop();return null;
    }
    private void RemoveLoop() { LoopFrame=machine.ReadWord(Cell.Add(Pointer,6));Pointer=Cell.Add(Pointer,8); }
    public void LeaveLoop()
    {
        if(Pointer!=LoopFrame)throw new NotSupportedException("Loop leave requires the current physical frame at S");
        RemoveLoop();
    }
    public ushort Return()
    {
        while(Pointer==LoopFrame)RemoveLoop();
        var cursor=Pop();
        if(cursor==0x76BD)
        {
            var size=Pop();Pointer=Cell.Add(Pointer,size);machine.LocalFrame=Pop();cursor=Pop();
        }
        ResumeCursor=cursor;return cursor;
    }
}
