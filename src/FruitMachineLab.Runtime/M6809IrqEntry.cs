namespace FruitMachineLab.Runtime;

public readonly record struct M6809IrqRegisters(byte CC,byte A,byte B,byte DP,ushort X,ushort Y,ushort U,ushort S,ushort PC);
public sealed record M6809IrqAcceptance(ulong AcceptedCycle,ulong HandlerCycle,ushort StackPointer,byte HandlerCC,byte[] StackFrame);

// Ordinary MC6809 IRQ at a completed instruction boundary. Not an instruction
// interpreter: caller supplies completion time, registers and delivered IRQ level.
// Caller must resolve higher-priority interrupts first. CWAI/SYNC, FIRQ/NMI,
// source assertion/delivery and handler execution are outside this helper.
public static class M6809IrqEntry
{
    public const ulong EntryCycles=19;
    public static M6809IrqAcceptance? AtInstructionBoundary(ulong cycle,M6809IrqRegisters r,bool irqLevel)
    {
        if(!irqLevel || (r.CC&0x10)!=0)return null;
        byte savedCC=(byte)(r.CC|0x80);
        byte[] frame=[savedCC,r.A,r.B,r.DP,(byte)(r.X>>8),(byte)r.X,(byte)(r.Y>>8),(byte)r.Y,(byte)(r.U>>8),(byte)r.U,(byte)(r.PC>>8),(byte)r.PC];
        return new(cycle,checked(cycle+EntryCycles),unchecked((ushort)(r.S-12)),(byte)(savedCC|0x10),frame);
    }
}
