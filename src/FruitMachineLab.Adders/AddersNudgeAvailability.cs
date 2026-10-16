using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Assembly translations of 29F4 / 2A7F / 1AC3 / 1B63 / 1B7B.
// Candidate order, byte wrap, ties and scratch writes are reference behaviour.
public static class AddersNudgeAvailability
{
    public static byte Lookup(Machine m)
    {
        byte a=m.Memory[0x160],b=m.Memory[0x162],c=m.Memory[0x164];
        if(a==b && a==c)return m.Memory[Cell.Add(0x75BD,unchecked((ushort)(sbyte)a))];
        byte common=(byte)(m.Memory[0x161]&m.Memory[0x163]&m.Memory[0x165]);
        byte result=(common&1)!=0 ? m.Memory[0x75BE] : (byte)0;
        if(result!=0)return result;
        if(m.Memory[0xDD]!=0 && (common&2)!=0){m.Memory[0xDE]=0xFF;return 0x11;}
        if(a==b || a==c)return m.Memory[Cell.Add(0x75C4,unchecked((ushort)(sbyte)a))];
        if(b==c)return m.Memory[Cell.Add(0x75C4,unchecked((ushort)(sbyte)b))];
        return 0;
    }
    // Native 1AA3 filters small pair results, then retries common flags.
    public static void PushMatchingResult(Machine m)
    {
        byte result=Lookup(m);if(result<7)result=0;
        if(result==0){
            byte common=(byte)(m.Memory[0x161]&m.Memory[0x163]&m.Memory[0x165]);
            result=(common&1)!=0 ? m.Memory[0x75BE] : (byte)0;
            if(result==0 && m.Memory[0xDD]!=0 && (common&2)!=0){m.Memory[0xDE]=0xFF;result=0x11;}
        }
        m.Data.Push(unchecked((ushort)(short)(sbyte)result));
    }
    // Native1AF1 uses the full award table for any equal pair, then falls
    // back to10 only for exactly two flag-bit0 symbols. It is not1AA3.
    public static void PushPairOrTwoFlagsResult(Machine m)
    {
        byte a=m.Memory[0x160],b=m.Memory[0x162],c=m.Memory[0x164],result=0;
        if(a==b || a==c)result=m.Memory[Cell.Add(0x75BD,unchecked((ushort)(sbyte)a))];
        else if(b==c)result=m.Memory[Cell.Add(0x75BD,unchecked((ushort)(sbyte)b))];
        if(result==0 && ((m.Memory[0x161]&1)+(m.Memory[0x163]&1)+(m.Memory[0x165]&1))==2)result=10;
        m.Data.Push(unchecked((ushort)(short)(sbyte)result));
    }
    public static void Search(Machine m,ushort frame)
    {
        ushort At(int offset)=>Cell.Add(frame,(ushort)offset);
        byte Get(int offset)=>m.Memory[At(offset)];
        void Set(int offset,byte value)=>m.Memory[At(offset)]=value;
        static byte NegativeMagnitude(byte value)=>(sbyte)value<0 ? value : unchecked((byte)-value);
        for(int n=0;n<3;n++)Set(14+n,unchecked((byte)(2*(m.Memory[0x198+2*n]-m.Memory[0x169+2*n]))));
        m.Memory[0xC8]=0;m.Memory[0xA8]=0xFF;
        Set(8,unchecked((byte)(2*Get(7)+2)));Set(11,0);Set(1,unchecked((byte)(2*Get(7))));Set(2,0);Set(3,0);
        do {
            Set(9,unchecked((byte)(NegativeMagnitude(Get(11))+Get(8))));Set(12,0);
            m.WriteWord(0x160,m.ReadWord((ushort)(0x75DB+((Get(14)-Get(11))&31))));
            do {
                Set(10,unchecked((byte)(NegativeMagnitude(Get(12))+Get(9))));Set(13,0);
                m.WriteWord(0x162,m.ReadWord((ushort)(0x75FB+((Get(15)-Get(12))&31))));
                do {
                    m.WriteWord(0x164,m.ReadWord((ushort)(0x761B+((Get(16)-Get(13))&31))));
                    byte result=Lookup(m);
                    if(result>m.Memory[0xC8]){m.Memory[0xC8]=result;for(int n=0;n<3;n++)Set(1+n,Get(11+n));}
                    Set(13,unchecked((byte)(Get(13)+2)));
                }while(Get(13)!=Get(10));
                Set(12,unchecked((byte)(Get(12)+2)));
            }while(Get(12)!=Get(9));
            Set(11,unchecked((byte)(Get(11)+2)));
        }while(Get(11)!=Get(8));
    }
    public static void ExecuteFlagged(Machine m)
    {
        m.Memory[0xDD]=0xFF;m.Memory[0xDE]=0;Execute(m);
    }
    // 2A2F returns three ASRB/SEX movement cells, not the best-result cell.
    // Unlike 29F4 it leaves DD alone. Search scratch and symbol restoration
    // remain observable native effects.
    public static void PushMovementPlan(Machine m)
    {
        m.SyncDataToMemory();ushort budget=m.Pop();
        ushort frame=Cell.Subtract(m.DataPointer,17);
        if(frame<=0x525)throw new NotSupportedException("Native counted frame SWI2 overflow requires recovery");
        ushort[] saved=[m.ReadWord(0x160),m.ReadWord(0x162),m.ReadWord(0x164)];
        m.Memory[frame]=17;m.Memory[Cell.Add(frame,7)]=(byte)budget;
        Search(m,frame);
        for(ushort n=1;n<=3;n++)m.Data.Push(unchecked((ushort)(short)((sbyte)m.Memory[Cell.Add(frame,n)]>>1)));
        for(int n=0;n<3;n++)m.WriteWord((ushort)(0x160+2*n),saved[n]);
    }
    public static void Execute(Machine m)
    {
        m.SyncDataToMemory();ushort budget=m.Pop();
        // Native PULU consumes one cell before the counted 17-byte frame.
        ushort frame=Cell.Subtract(m.DataPointer,17);
        if(frame<=0x525)throw new NotSupportedException("Native counted frame SWI2 overflow requires recovery");
        ushort[] saved=[m.ReadWord(0x160),m.ReadWord(0x162),m.ReadWord(0x164)];
        m.Memory[frame]=17;m.Memory[Cell.Add(frame,7)]=(byte)budget;
        Search(m,frame);
        m.Data.Push(unchecked((ushort)(short)(sbyte)m.Memory[0xC8]));
        for(int n=0;n<3;n++)m.WriteWord((ushort)(0x160+2*n),saved[n]);
        m.Memory[0xDD]=0;
    }
}
