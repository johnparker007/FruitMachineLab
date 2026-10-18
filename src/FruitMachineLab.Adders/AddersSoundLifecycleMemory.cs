using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Memory effects of native5E2C. Audio synthesis and instruction scheduling are
// separate owners. Validation rejects unsupported/corrupt chains before mutation.
public static class AddersSoundLifecycleMemory
{
    // Native5E6D root C0 path only, after5CEC has unlinked this due task.
    // Nested sound call frames require a different return continuation.
    public static void FinishRoot(Machine m,ushort task,Action<byte,byte>? ymWrite=null)
    {
        ValidateTask(task);
        if(m.ReadWord((ushort)(task+6))!=task+0x25)throw new NotSupportedException("Sound C0 has a nonempty native frame");
        var seen=new HashSet<ushort>();
        foreach(ushort head in new ushort[]{m.ReadWord(0x47),m.ReadWord(0x49)})
            for(ushort at=head;at!=0;at=m.ReadWord(at)){
                ValidateTask(at);if(at==task || !seen.Add(at))throw new InvalidDataException("Sound completion has conflicting list ownership");
            }
        ValidateRelease(m,task);ReleaseChannels(m,task,ymWrite);
        m.WriteWord(task,m.ReadWord(0x49));m.WriteWord(0x49,task);
        //5E8C continues5CDE at the SAME clock;44 decrement belongs to the
        // scheduler exit5D38, not to this C0 handler.
    }
    public static void ValidateCancel(Machine m,ushort stream)
    {
        if((m.Memory[0x719B]&0x80)!=0)throw new NotSupportedException("719B bit80 disabled-tone cancel requires independent evidence");
        var visited=new HashSet<ushort>();ushort link=0x47;
        for(ushort at=m.ReadWord(link);at!=0;at=m.ReadWord(link)){
            ValidateTask(at);if(!visited.Add(at))throw new InvalidDataException("Cyclic active sound list");
            if(m.ReadWord((ushort)(at+0x13))==stream){ValidateRelease(m,at);return;}
            link=at;
        }
        throw new InvalidDataException($"Active sound list has no {stream:X4} root");
    }
    // Native5C7A/5CB5 removes the FIRST matching root. The sound-disabled
    // gate60C8 returns before touching lists. No logical scheduler is modified.
    public static bool Cancel(Machine m,ushort stream,Action<byte,byte>? ymWrite=null)
    {
        if((m.Memory[0x719B]&0x80)!=0)return false;
        var visited=new HashSet<ushort>();ushort link=0x47;
        for(ushort at=m.ReadWord(link);at!=0;at=m.ReadWord(link)){
            ValidateTask(at);if(!visited.Add(at))throw new InvalidDataException("Cyclic active sound list");
            if(m.ReadWord((ushort)(at+0x13))==stream){
                ValidateRelease(m,at); // Preflight before changing list ownership.
                ushort free=m.ReadWord(0x49);if(free!=0)ValidateTask(free);
                byte guard=m.Memory[0x44];m.Memory[0x44]=unchecked((byte)(guard+1));
                m.WriteWord(link,m.ReadWord(at));m.WriteWord(at,free);m.WriteWord(0x49,at);
                ReleaseChannels(m,at,ymWrite);m.Memory[0x44]=guard;return true;
            }
            link=at;
        }
        return true; // Enabled native call succeeds even when the root is absent.
    }
    public static void ValidateTask(ushort task)
    {
        if(task<0x1A0 || task>0x259 || (task-0x1A0)%0x25!=0)
            throw new NotSupportedException("Unrecovered sound task pool pointer");
    }
    private static List<byte> ValidateRelease(Machine m,ushort task)
    {
        ValidateTask(task);
        var owned=new List<byte>();var seen=new HashSet<byte>();
        for(byte at=m.Memory[task+0xA];(sbyte)at>=0;at=m.Memory[0x27E+at]) {
            if(at>5 || !seen.Add(at))throw new InvalidDataException("Invalid sound channel chain");
            owned.Add(at);
        }
        byte tail=m.Memory[0x4C];
        if((sbyte)tail>=0 && (tail>5 || seen.Contains(tail)))throw new InvalidDataException("Invalid sound free-channel tail");
        return owned;
    }
    public static void ReleaseChannels(Machine m,ushort task,Action<byte,byte>? ymWrite=null)
    {
        var owned=ValidateRelease(m,task);
        void Write(byte register,byte value){int cached=0x284+unchecked((sbyte)register);if(m.Memory[cached]==value)return;m.Memory[cached]=value;ymWrite?.Invoke(register,value);}
        byte rhythm=m.Memory[task+0x11];
        if(rhythm!=0){m.Memory[task+0x11]=0;Write(0x0E,(byte)(m.Memory[0x292]&~rhythm));}
        m.Memory[task+0xF]=0;
        foreach(byte channel in owned){
            m.Memory[task+0xA]=m.Memory[0x27E+channel];
            Write((byte)(0x20+channel),(byte)(m.Memory[0x2A4+channel]&0xEF));
            byte tail=m.Memory[0x4C];if((sbyte)tail<0)m.Memory[0x4B]=channel;else m.Memory[0x27E+tail]=channel;
            m.Memory[0x4C]=channel;m.Memory[0x27E+channel]=0xFF;
        }
    }
}
