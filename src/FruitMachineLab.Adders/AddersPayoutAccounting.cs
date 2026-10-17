using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public readonly record struct AddersPayoutRecord(ushort Address,byte Condition,ushort Queue,byte Units,
    byte TailLimit,ushort Balance,ushort OptionalAccount,ushort Account,ushort TotalAccount,ushort Meter)
{
    public static AddersPayoutRecord Read(Machine m,ushort at)
    {
        if(at is not (0x4ACA or 0x4ADB or 0x4AEC or 0x4AFD))throw new NotSupportedException("Uncurated payout record");
        return new(at,m.Memory[at],m.ReadWord(Cell.Add(at,1)),m.Memory[at+3],m.Memory[at+4],
            m.ReadWord(Cell.Add(at,5)),m.ReadWord(Cell.Add(at,7)),m.ReadWord(Cell.Add(at,9)),
            m.ReadWord(Cell.Add(at,11)),m.ReadWord(Cell.Add(at,13)));
    }
}

public static class AddersPayoutAccounting
{
    // Native4CBE through4CF0. The caller continues at6858, not at an invented
    // delivered-coin counter. Display callback is the actual native->VM call.
    public static void Debit(Machine m,AddersPayoutRecord r,Action refreshDisplay)
    {
        m.WriteWord(r.Balance,Cell.Subtract(m.ReadWord(r.Balance),r.Units));
        Mpu4Nvram.Refresh(m);
        refreshDisplay();
        if((sbyte)m.Memory[0x323]>=0) {
            void Add24(ushort at) {
                uint sum=(((uint)m.Memory[at]<<16)|m.ReadWord(Cell.Add(at,1)))+r.Units;
                m.Memory[at]=(byte)(sum>>16);m.WriteWord(Cell.Add(at,1),(ushort)sum);
            }
            if(r.OptionalAccount!=0)Add24(r.OptionalAccount);
            Add24(r.Account);Add24(r.TotalAccount);
            m.WriteWord(r.Meter,Cell.Add(m.ReadWord(r.Meter),r.Units));
            RefreshMeterChecksum(m);
        }
        m.Memory[r.Queue]=unchecked((byte)(m.Memory[r.Queue]+1));
        RefreshOutputChecksum(m);
    }

    // Native6FC1/6FEC and7009/7032, including the final increment and35E..369.
    public static void RefreshMeterChecksum(Machine m)
    {
        byte sum=1;for(int at=0x35E;at<0x36A;at++)sum=unchecked((byte)(sum+m.Memory[at]+1));
        m.Memory[0x36A]=sum;if((sbyte)m.Memory[0x3A]<0)m.Memory[0x3A]=0;
    }
    public static void RefreshOutputChecksum(Machine m)
    {
        byte sum=1;for(int at=0x36B;at<0x373;at++)sum=unchecked((byte)(sum+m.Memory[at]+1));
        m.Memory[0x373]=sum;
    }

    // Native4D07..4D26 /4D51..4D70. Preserve guard overwrite and signed overflow
    // clamp (high byte80, already-subtracted low word), including service mode.
    public static void SubtractTokenCompensation(Machine m)
    {
        m.Memory[0x2C]=0xFF;ushort low=m.ReadWord(0x7D3);byte high=m.Memory[0x7D2];
        ushort result=Cell.Subtract(low,500);int borrow=low<500 ? 1 : 0;
        byte next=unchecked((byte)(high-borrow));
        if(high==0x80 && borrow!=0)next=0x80;
        m.Memory[0x7D2]=next;m.WriteWord(0x7D3,result);
        AddersAwardStatistics.RefreshAccounting(m);m.Memory[0x2C]=0;
    }
}
