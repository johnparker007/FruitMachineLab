namespace FruitMachineLab.Runtime;

// 27D2 mux acquisition followed by 19B8 -> 1A87 OR/AND accumulation.
// BLACK2 Start is active high, bit 80. Release clears the sampled level but
// not the sticky OR latch; recovered VM 847A explicitly clears that latch.
public sealed class Mpu4PanelInput(Machine machine)
{
    private readonly byte[] ports=new byte[8];
    public bool StartPressed {get;private set;}
    public byte PhysicalBlack2=>ports[3];
    public void SetStart(bool pressed){StartPressed=pressed;ports[3]=(byte)((ports[3]&0x7F)|(pressed ? 0x80 : 0));}
    public void SeedOtherPorts(IReadOnlyList<byte> values)
    {
        if(values.Count!=8)throw new ArgumentException("Eight mux port values required");
        for(int n=0;n<8;n++)ports[n]=n==3 ? (byte)(values[n]&0x7F) : values[n];
        ports[4]=ports[0];ports[5]=ports[1];SetStart(false);
    }
    public void Sample(byte column)
    {
        if(column>7)throw new ArgumentOutOfRangeException(nameof(column));
        byte value=ports[column];machine.Memory[column]=value;
        if(column<2)machine.Memory[column+4]=value;
        machine.Memory[0x8E+column]|=value;machine.Memory[0x96+column]&=value;
    }
    public void Release()=>SetStart(false);
}
