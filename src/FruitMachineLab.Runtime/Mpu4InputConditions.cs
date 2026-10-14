namespace FruitMachineLab.Runtime;

// Native 67EC/67F0 condition flags and VM wrapper 7721's sign-extended byte.
public static class Mpu4InputConditions
{
    public static ushort Evaluate(Machine machine,byte selector)
    {
        if((selector&0x80)!=0) {
            ushort address=(ushort)(0x7226+unchecked((byte)(selector<<1)));
            if(address>0x7248)throw new NotSupportedException("Unrecovered invalid input selector trap");
            return Cell.Flag((machine.Memory[6]&machine.Memory[address])!=0 || (machine.Memory[7]&machine.Memory[address+1])!=0);
        }
        ushort start=(ushort)(0x71AA+unchecked((byte)(selector<<2)));
        if(start>0x7226)throw new NotSupportedException("Unrecovered invalid input selector trap");
        bool any=false,all=true;
        for(int port=0;port<4;port++) {
            byte mask=machine.Memory[start+port];byte selected=(byte)(machine.Memory[port]&mask);
            any|=selected!=0;all&=selected==mask;
        }
        return !any ? (ushort)0 : all ? ushort.MaxValue : (ushort)1;
    }
}
