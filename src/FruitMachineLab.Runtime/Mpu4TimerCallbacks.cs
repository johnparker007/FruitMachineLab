namespace FruitMachineLab.Runtime;

// Software dispatch subset of FE70/70B3 after a platform timer-3 interrupt.
// Interrupt status, elapsed counter time and CPU interrupt frames are separate.
public static class Mpu4TimerCallbacks
{
    public static bool DispatchTimer3(Machine machine,Action<ushort,Machine> invoke)
    {
        machine.Memory[0x3F]&=0xFE;machine.Memory[0x40]=0;
        ushort callback=machine.ReadWord(0x3D);
        if(callback<0x1400)return false;
        invoke(callback,machine);return true;
    }
}
