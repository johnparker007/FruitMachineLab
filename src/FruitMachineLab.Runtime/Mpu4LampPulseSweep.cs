namespace FruitMachineLab.Runtime;

public record Timer3Arm(ushort Timer,ushort Callback);
// Native 19C2/19FA and software effects of timer-3 arm 70EF.
// Visible brightness and electrical timer elapsed time are not inferred here.
public static class Mpu4LampPulseSweep
{
    public static void Advance(Machine machine,Action<Timer3Arm> arm)
    {
        if(machine.Memory[0xB3]==0)return;
        ushort timer=machine.ReadWord(0x32D);
        byte count=unchecked((byte)(machine.Memory[0xE8]-1));machine.Memory[0xE8]=count;
        if((sbyte)count<=0) {
            machine.Memory[0xE8]=machine.Memory[0xE9];
            if((short)timer>=300 || (short)timer<=30)machine.Memory[0xEA]=unchecked((byte)(0-machine.Memory[0xEA]));
            timer=Cell.Add(timer,unchecked((ushort)(short)(sbyte)machine.Memory[0xEA]));machine.WriteWord(0x32D,timer);
        }
        machine.WriteWord(0x3D,0x48FD);machine.Memory[0x3F]&=0xFE;machine.Memory[0x40]=0x63;
        arm(new(timer,0x48FD));
    }
}
