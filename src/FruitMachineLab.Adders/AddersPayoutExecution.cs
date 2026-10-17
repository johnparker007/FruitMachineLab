using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

/// <summary>Recovered native payout control flow, advanced at semantic boundaries.
/// CPU instruction timing is not claimed. Waits observe actual changes of006E.</summary>
public sealed class AddersPayoutExecution
{
    private readonly Machine m;
    private readonly IEnumerator<ushort> steps;
    private readonly Action refreshDisplay;
    private readonly Func<byte> readTriac;
    private readonly Action<byte> writeTriac,serialMessage;
    private byte sampledCounter;
    private int remainingChanges;
    public bool Completed {get;private set;}
    public bool Waiting => remainingChanges!=0;
    public ushort Address {get;private set;}
    public int Debits {get;private set;}
    public string? Fault {get;private set;}
    public Action<AddersPayoutRecord,ushort>? ObserveDebit {get;set;}

    public AddersPayoutExecution(Machine machine,ushort entry,Action refreshDisplay,
        Func<byte> readTriac,Action<byte> writeTriac,Action<byte> serialMessage)
    {
        if(entry is not (0x4B39 or 0x4B8C or 0x6858))throw new ArgumentOutOfRangeException(nameof(entry));
        m=machine;this.refreshDisplay=refreshDisplay;this.readTriac=readTriac;
        this.writeTriac=writeTriac;this.serialMessage=serialMessage;
        steps=(entry==0x6858 ? Outputs() : entry==0x4B39 ? Cash() : Tokens()).GetEnumerator();
        Address=entry;
    }

    public void Step()
    {
        if(Completed)return;
        if(Fault is not null)throw new InvalidOperationException(Fault);
        try {
            if(remainingChanges!=0) {
                // Native718A abort skips the wait at entry, not midway through it.
                if(m.Memory[0x6E]==sampledCounter)return;
                sampledCounter=m.Memory[0x6E];if(--remainingChanges!=0)return;
            }
            if(steps.MoveNext())Address=steps.Current;else {Completed=true;steps.Dispose();}
        } catch(Exception e){Fault=e.Message;steps.Dispose();throw;}
    }

    private bool Condition(byte selector)=>Mpu4InputConditions.Evaluate(m,selector)!=0;
    private bool Forced()=>new ushort[]{0xFF48,0xFF4A,0xFF40,0xFF3C,0xFF3E,0xFF3A,0xFF36}.All(at=>m.Memory[at]!=0);
    private bool Tail(AddersPayoutRecord r)
    {
        byte a=m.Memory[r.Queue+1];bool store=false;
        if(!Condition(r.Condition)){if(a<=r.TailLimit){a=unchecked((byte)(r.TailLimit+1));store=true;}}
        else if(a>r.TailLimit){a=r.TailLimit;store=true;}
        if(store){m.Memory[r.Queue+1]=a;AddersPayoutAccounting.RefreshOutputChecksum(m);}
        return m.Memory[0xFF42]==0 || a!=0;
    }
    private IEnumerable<ushort> Debit(AddersPayoutRecord r,bool compensate=false,ushort compensationContinuation=0x4D27)
    {
        ObserveDebit?.Invoke(r,m.ReadWord(r.Balance));
        AddersPayoutAccounting.Debit(m,r,refreshDisplay);Debits++;yield return 0x4CF0;
        foreach(var at in Outputs())yield return at;
        if(compensate){AddersPayoutAccounting.SubtractTokenCompensation(m);yield return compensationContinuation;}
    }
    private IEnumerable<ushort> CashRecord(ushort record,bool force=false)
    {
        var r=AddersPayoutRecord.Read(m,record);
        while(m.ReadWord(r.Balance)>=r.Units) {
            if(!force && !Tail(r))yield break;
            foreach(var at in Debit(r))yield return at;
            if(force)Tail(r);
            yield return 0x4C25;
        }
    }
    private IEnumerable<ushort> Cash()
    {
        if(!Condition(0x82))foreach(var at in CashRecord(0x4ADB))yield return at;
        foreach(var at in CashRecord(0x4ACA))yield return at;
        if(Forced()){foreach(var at in CashRecord(0x4ACA,true))yield return at;yield break;}
        if(m.ReadWord(0x2FE)!=0)throw new NotSupportedException("Native4BC5 call-manager collection wait requires recovery");
    }
    private IEnumerable<ushort> TokenRecord(ushort record)
    {
        var r=AddersPayoutRecord.Read(m,record);
        if(Condition(r.Condition) || m.ReadWord(r.Balance)==0)yield break;
        while(m.ReadWord(r.Balance)!=0) {
            foreach(var at in Debit(r,true))yield return at;
            if(!Condition(r.Condition))continue;
            m.Memory[r.Queue+1]=r.TailLimit;
            while(m.Memory[r.Queue+1]!=0 && m.ReadWord(r.Balance)!=0)
                foreach(var at in Debit(r))yield return at;
            yield break;
        }
    }
    private IEnumerable<ushort> Tokens()
    {
        foreach(var at in TokenRecord(0x4AEC))yield return at;
        if(Forced()) {
            var r=AddersPayoutRecord.Read(m,0x4AFD);
            while(m.ReadWord(r.Balance)!=0)foreach(var at in Debit(r,true,0x4D71))yield return at;
            yield break;
        }
        foreach(var at in TokenRecord(0x4AFD))yield return at;
        if(m.ReadWord(0x300)!=0)throw new NotSupportedException("Native4BC5 call-manager token wait requires recovery");
    }
    private void BeginWait()
    {
        // Native7172 B=13, five observed006E changes per group. No recorded time.
        if((m.Memory[0x719B]&0x80)!=0)return;
        sampledCounter=m.Memory[0x6E];remainingChanges=13*5;
    }
    private IEnumerable<ushort> Outputs()
    {
        while(true) {
            int channel=0;while(channel<4 && m.Memory[0x36B+2*channel]==0)channel++;
            if(channel==4)yield break;
            ushort queue=(ushort)(0x36B+2*channel);byte mask=m.Memory[0x201A+channel];
            m.Memory[queue]--;if(m.Memory[queue+1]!=0)m.Memory[queue+1]--;
            AddersPayoutAccounting.RefreshOutputChecksum(m);yield return 0x687B;
            if(m.Memory[0x2B]!=0x20 && (sbyte)m.Memory[0x323]<0)
                throw new NotSupportedException("Native68CB service-mode tone/delay requires recovery");
            if((m.Memory[0x719B]&4)!=0)yield break;
            serialMessage(m.Memory[0x20B0+channel]);
            writeTriac((byte)(readTriac()|mask));BeginWait();yield return 0x68B2;
            writeTriac((byte)(readTriac()&~mask));BeginWait();yield return 0x68C6;
        }
    }
}
