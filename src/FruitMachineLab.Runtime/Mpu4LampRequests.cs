namespace FruitMachineLab.Runtime;

public record LampRequest(byte Id,byte Pattern,ushort Native,ushort? TableAddress=null);

/// <summary>Decoded native lamp requests; hardware characteriser/frame RAM is not emulated.</summary>
public sealed class Mpu4LampRequests(Machine machine,Action<LampRequest> output)
{
    public void Set(byte id,byte pattern,ushort native)=>output(new(id,pattern,native));
    public void Range(ushort start,ushort end,byte pattern,ushort native)
    {
        // Native CMPX/BCC: unsigned exclusive-end iteration, no host clamping.
        for(ushort address=start;address<end;address=Cell.Add(address,1))
            output(new(machine.Memory[address],pattern,native,address));
    }
    public bool HandleWord(Instruction instruction)
    {
        switch(instruction.Native)
        {
            case 0x4A83: {var end=machine.Pop();var start=machine.Pop();Range(start,end,0x80,0x4A83);return true;}
            case 0x4A8C: {var pattern=(byte)machine.Pop();var end=machine.Pop();var start=machine.Pop();Range(start,end,pattern,0x4A8C);return true;}
            case 0x498B: Set((byte)machine.Pop(),5,0x498B);return true;
            case 0x49C5: {var pattern=(byte)machine.Pop();Set((byte)machine.Pop(),pattern,0x49C5);return true;}
            default:return false;
        }
    }
}
