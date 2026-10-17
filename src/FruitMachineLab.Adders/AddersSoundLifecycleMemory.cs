using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Memory effects of native5E2C. Audio synthesis and instruction scheduling are
// separate owners. Validation rejects unsupported/corrupt chains before mutation.
public static class AddersSoundLifecycleMemory
{
    public static void ValidateTask(ushort task)
    {
        if(task<0x1A0 || task>0x259 || (task-0x1A0)%0x25!=0)
            throw new NotSupportedException("Unrecovered sound task pool pointer");
    }
    public static void ReleaseChannels(Machine m,ushort task,Action<byte,byte>? ymWrite=null)
    {
        ValidateTask(task);
        var owned=new List<byte>();var seen=new HashSet<byte>();
        for(byte at=m.Memory[task+0xA];(sbyte)at>=0;at=m.Memory[0x27E+at]) {
            if(at>5 || !seen.Add(at))throw new InvalidDataException("Invalid sound channel chain");
            owned.Add(at);
        }
        byte tail=m.Memory[0x4C];
        if((sbyte)tail>=0 && (tail>5 || seen.Contains(tail)))throw new InvalidDataException("Invalid sound free-channel tail");
        void Write(byte register,byte value){int cached=0x284+unchecked((sbyte)register);if(m.Memory[cached]==value)return;m.Memory[cached]=value;ymWrite?.Invoke(register,value);}
        byte rhythm=m.Memory[task+0x11];
        if(rhythm!=0){m.Memory[task+0x11]=0;Write(0x0E,(byte)(m.Memory[0x292]&~rhythm));}
        m.Memory[task+0xF]=0;
        foreach(byte channel in owned){
            m.Memory[task+0xA]=m.Memory[0x27E+channel];
            Write((byte)(0x20+channel),(byte)(m.Memory[0x2A4+channel]&0xEF));
            tail=m.Memory[0x4C];if((sbyte)tail<0)m.Memory[0x4B]=channel;else m.Memory[0x27E+tail]=channel;
            m.Memory[0x4C]=channel;m.Memory[0x27E+channel]=0xFF;
        }
    }
}
