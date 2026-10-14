namespace FruitMachineLab.Runtime;

// Native 49C5 memory effects using the measured characteriser column responses.
// Frame buffers are distinct from physical scan timing and cabinet output.
public sealed class Mpu4LampFrames(Machine machine,IReadOnlyList<byte> responses)
{
    public byte Apply(byte id,byte pattern)
    {
        if(responses.Count!=8)throw new InvalidDataException("Eight characteriser column responses are required");
        byte bit=(byte)(1<<(id&7));byte column=(byte)(((responses[id&7]^id)&0x78)>>3);
        for(int frame=0;frame<4;frame++) {
            int address=0x100+frame*16+column;
            byte value=(byte)(machine.Memory[address]|bit);
            if((pattern&(1<<frame))==0)value=unchecked((byte)(value-bit));
            machine.Memory[address]=value;
        }
        return column;
    }
    public byte[] Snapshot()=>machine.Memory[0x100..0x140];
}
