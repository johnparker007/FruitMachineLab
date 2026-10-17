using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// m4addr's R4/RT1 hardware: four Barcrest 48-step motors, index (1,3),
// initial phase 2. Seed relation must be verified against device-state capture;
// this is a recovered feature-entry adapter, not startup or another game's model.
public sealed class AddersReelHardware
{
    private readonly Machine m;
    private readonly BarcrestStepper[] motors;
    public IReadOnlyList<BarcrestStepper> Motors=>motors;
    public AddersReelHardware(Machine machine)
    {
        m=machine;
        motors=Enumerable.Range(0,4).Select(reel=>{
            int position=m.Memory[0x168+2*reel];
            return new BarcrestStepper((98-position)%96,position&7,m.Memory[0x666B+(position&7)],1,3);
        }).ToArray();
    }
    // 27D2 writes the PREVIOUS service's phase latches before 6403 runs.
    public void WriteDrive()
    {
        int drive=m.Memory[0x6C]==0 && (m.Memory[0x6E]&1)!=0 ? 0 : m.ReadWord(0x6F);
        WriteDriveBank(0xD02,(byte)(drive>>8));WriteDriveBank(0xE00,(byte)drive);
    }
    public void WriteDriveBank(ushort address,byte value)
    {
        int first=address switch{0xD02=>0,0xE00=>2,_=>throw new ArgumentOutOfRangeException(nameof(address))};
        motors[first].Drive((byte)(value&15));motors[first+1].Drive((byte)(value>>4));
    }
    public byte ReadOptics()
    {
        byte result=0;for(int reel=0;reel<4;reel++)if(motors[reel].Optic)result|=(byte)(0x40>>reel);return result;
    }
}
