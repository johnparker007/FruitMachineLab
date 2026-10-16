using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native482F. IC5 low output bits and IC8 output shadow must be initialized.
public static class AddersStatusService
{
    public static void Refresh(Machine m,Mpu4LampRequests lamps)
    {
        byte mask=(byte)(m.Memory[0x32F]==0 ? 15 : 7);
        lamps.Set(0x59,(byte)((m.Memory[0xC02]&mask)==mask ? 0x80 : 0x8F),0x49C5);
        if(m.Memory[0x338]!=0){lamps.Set(0x38,0x80,0x4982);lamps.Set(0x38,0x80,0x4982);return;}
        bool eligible=m.Memory[0x32F]==0 ? (m.Memory[0xF02]&0x20)!=0 : (m.Memory[0xC02]&1)==0;
        if(!eligible){lamps.Set(0x38,0x80,0x4982);return;}
        if(Mpu4InputConditions.Evaluate(m,4)==0 || Mpu4InputConditions.Evaluate(m,3)==0){lamps.Set(0x38,0x8F,0x497F);return;}
        if(m.Memory[0xFF34]!=0)lamps.Set(0x38,0x83,0x4985);else lamps.Set(0x38,0x80,0x4982);
    }
}
