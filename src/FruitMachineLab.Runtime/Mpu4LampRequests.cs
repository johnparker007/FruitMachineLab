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
            case 0x4AC0:Range(0x7248,0x733D,0x80,0x4AC0);return true;
            case 0x4A83: {var end=machine.Pop();var start=machine.Pop();Range(start,end,0x80,0x4A83);return true;}
            case 0x4A8C: {var pattern=(byte)machine.Pop();var end=machine.Pop();var start=machine.Pop();Range(start,end,pattern,0x4A8C);return true;}
            case 0x498B: Set((byte)machine.Pop(),5,0x498B);return true;
            case 0x49C5: {var pattern=(byte)machine.Pop();Set((byte)machine.Pop(),pattern,0x49C5);return true;}
            default:return false;
        }
    }
    public ushort ExecuteStream(ushort cursor,int budget=10000)
    {
        byte pattern=0;
        byte Fetch(){byte value=machine.Memory[cursor];cursor=Cell.Add(cursor,1);return value;}
        for(int n=0;n<budget;n++) {
            byte command=Fetch();if(command<0x80){Set(command,pattern,0x49C5);continue;}
            if(command<0x90){pattern=(byte)(command&15);continue;}
            switch(command) {
                case 0x90:{byte value=Fetch();if(machine.Memory[0x25]!=value)machine.Memory[0x24]=machine.Memory[0x25]=value;break;}
                case 0x91:{byte value=Fetch();if(machine.Memory[0x27]!=value)machine.Memory[0x26]=machine.Memory[0x27]=value;break;}
                case 0x92:machine.Memory[0x26]=unchecked((byte)(Fetch()+1));machine.Memory[0x24]=1;machine.Memory[0x23]=0;break;
                case 0x93:return cursor;
                default:throw new NotSupportedException($"Untranslated lamp stream command {command:X2}");
            }
        }
        throw new InvalidOperationException("Lamp stream did not terminate");
    }
}
