using System.Text.Json;
using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public static class AddersPayoutVerification
{
    public static int TimedCollectionMatrix(string evidence,bool collectGate=false)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection",collectGate ? "collect-gate-matrix.json" : "router-matrix.json")));int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()){
            var m=new Machine{DataStackBase=0x600};m.Control=new(m,0x784);Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);SkillCashData.LoadFeature(m);SkillCashData.LoadAlpha(m);AddersPayoutCallerData.Load(m,evidence);
            // These old semantic fixtures start before76BF. Supply its proven
            // static NEXT template and a logical root frame, not per-step state.
            Convert.FromHexString("34203184AEA16E91").CopyTo(m.Memory,0xF8);m.Control.Push(0x4C34);
            using var lampDoc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")));var lamps=new Mpu4LampFrames(m,lampDoc.RootElement.GetProperty("responses").EnumerateArray().Select(v=>v.GetByte()).ToArray());
            byte port=0x30;var writes=new List<byte>();var debits=new List<(ushort,ushort)>();
            using var e=new AddersTimedCollectionExecution(m,evidence,collectGate ? (ushort)0xAB1B : (ushort)0xAA2B,0,r=>lamps.Apply(r.Id,r.Pattern),new(m),new(m,m.ReadWord(0x45)),(_,_)=>1,(_,_)=>1000,()=>port,v=>{port=v;writes.Add(v);},0x50,_=>{});
            e.ObserveDebit=(call,_)=>debits.Add((call.Y,m.ReadWord(AddersPayoutRecord.Read(m,call.Y).Balance)));int polls=0,budget=1000000;
            while(!e.Completed && --budget>0){if(e.Address==0x717C && (++polls&1)!=0)m.Memory[0x6E]++;e.AdvanceTo(e.NextEventCycle);}if(!e.Completed)throw new InvalidDataException("Timed collection did not complete");
            byte[] ram=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);foreach(int p in Enumerable.Range(0,0x700).Where(p=>p!=0x6E && p is not (>=0xF0 and <=0xFF) and not (>=0x5C0 and <=0x5FF)).Concat(Enumerable.Range(0x7C9,0x1F)))if(m.Memory[p]!=ram[p])throw new InvalidDataException($"Timed collection {row.GetProperty("case").GetProperty("id")} RAM{p:X4}: expected{ram[p]:X2}, actual{m.Memory[p]:X2}");
            if(!writes.SequenceEqual(row.GetProperty("triac_writes").EnumerateArray().Select(v=>v.GetByte())))throw new InvalidDataException("Timed collection output sequence differs");
            if(!debits.SequenceEqual(row.GetProperty("debits").EnumerateArray().Select(v=>(v.GetProperty("record").GetUInt16(),v.GetProperty("balance").GetUInt16()))))throw new InvalidDataException("Timed collection debit sequence differs");
            if(e.Debits!=debits.Count || m.Control.Pointer!=0x784)throw new InvalidDataException("Timed collection count/control imbalance");
            if(collectGate && m.Data.Single()!=row.GetProperty("result").GetUInt16())throw new InvalidDataException("Timed preplay gate result differs");count++;
        }return count;
    }
    public static int ServiceMatrix(string evidence,bool collection=false,bool collectGate=false)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection",collectGate ? "collect-gate-matrix.json" : collection ? "router-matrix.json" : "service-matrix.json")));
        int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()) {
            var m=new Machine{DataStackBase=0x600};m.Control=new(m,0x800);
            Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            SkillCashData.LoadFeature(m);SkillCashData.LoadAlpha(m);AddersPayoutDisplay.LoadRomData(m,evidence);
            var alpha=new Mpu4Alpha(m);byte triac=0x30;var writes=new List<byte>();var debits=new List<(ushort Record,ushort Balance)>();
            AddersPayoutExecution? execution=null;AddersCollectionExecution? router=null;
            if(collection || collectGate) {
                using var framesDoc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","lamp-frames.json")));
                var frames=new Mpu4LampFrames(m,framesDoc.RootElement.GetProperty("responses").EnumerateArray().Select(x=>x.GetByte()).ToArray());
                m.Control.Push(0x4C34);
                router=new(m,evidence,row.GetProperty("case").GetProperty("entry").GetUInt16(),r=>frames.Apply(r.Id,r.Pattern),alpha,new(m,m.ReadWord(0x45)),()=>triac,v=>{triac=v;writes.Add(v);});
                router.ObserveDebit=(record,balance)=>debits.Add((record.Address,balance));
            } else {
            execution=new AddersPayoutExecution(m,row.GetProperty("case").GetProperty("entry").GetUInt16(),
                ()=>AddersPayoutDisplay.Refresh(m,evidence,alpha),()=>triac,v=>{triac=v;writes.Add(v);},message=>AddersPayoutSerial.Enqueue(m,message));
            execution.ObserveDebit=(record,balance)=>debits.Add((record.Address,balance));
            }
            bool Completed()=>router?.Completed ?? execution!.Completed;
            int budget=100000;
            while(!Completed() && --budget>0){if(router?.Waiting ?? execution!.Waiting)m.Memory[0x6E]++;if(router is not null)router.Step();else execution!.Step();}
            if(!Completed())throw new InvalidDataException("Payout service did not complete");
            byte[] expected=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
            var compared=Enumerable.Range(0,0x700).Where(p=>p<0xF0 || p>=0x100).Where(p=>p<0x5C0 || p>=0x600)
                .Where(p=>p!=0x6E).Concat(Enumerable.Range(0x7C9,0x1F));
            var mismatch=compared.Where(p=>m.Memory[p]!=expected[p]).Take(12).ToArray();
            if(mismatch.Length!=0)throw new InvalidDataException($"Payout service {row.GetProperty("case").GetProperty("id")}: "+string.Join(", ",mismatch.Select(p=>$"{p:X4} expected{expected[p]:X2} actual{m.Memory[p]:X2}")));
            if((router?.Debits ?? execution!.Debits)!=row.GetProperty("debits").GetArrayLength())throw new InvalidDataException("Payout debit count differs");
            if(!debits.SequenceEqual(row.GetProperty("debits").EnumerateArray().Select(x=>(x.GetProperty("record").GetUInt16(),x.GetProperty("balance").GetUInt16()))))throw new InvalidDataException("Payout denomination/balance sequence differs");
            if(!writes.SequenceEqual(row.GetProperty("triac_writes").EnumerateArray().Select(x=>x.GetByte())))throw new InvalidDataException("Payout triac writes differ");
            if(collectGate && (m.Data.Count!=1 || m.Data.Peek()!=row.GetProperty("result").GetUInt16()))throw new InvalidDataException("Preplay credit/collect result differs");
            count++;
        }
        return count;
    }
    public static int DebitMatrix(string evidence)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","debit-matrix.json")));
        int count=0;
        foreach(var row in doc.RootElement.GetProperty("rows").EnumerateArray()) {
            var m=new Machine{DataStackBase=0x600};m.Control=new(m,0x800);
            Convert.FromHexString(row.GetProperty("before_hex").GetString()!).CopyTo(m.Memory,0);
            SkillCashData.LoadFeature(m);SkillCashData.LoadAlpha(m);AddersPayoutDisplay.LoadRomData(m,evidence);
            var alpha=new Mpu4Alpha(m);
            AddersPayoutAccounting.Debit(m,AddersPayoutRecord.Read(m,row.GetProperty("case").GetProperty("record").GetUInt16()),()=>AddersPayoutDisplay.Refresh(m,evidence,alpha));
            byte[] expected=Convert.FromHexString(row.GetProperty("after_hex").GetString()!);
            // Native gateway/trampoline F0..FF, stale physical U-stack residue
            // 5C0..5FF and native S-stack residue700..7FF are outside this model.
            // Persistent accounting/checksum7C9..7E7 IS compared separately.
            var compared=Enumerable.Range(0,0x700).Where(p=>p<0xF0 || p>=0x100).Where(p=>p<0x5C0 || p>=0x600)
                .Concat(Enumerable.Range(0x7C9,0x1F));
            var mismatch=compared.Where(p=>m.Memory[p]!=expected[p]).Take(12).ToArray();
            if(mismatch.Length!=0)throw new InvalidDataException($"Payout {row.GetProperty("case").GetProperty("id")}: "+string.Join(", ",mismatch.Select(p=>$"{p:X4} expected{expected[p]:X2} actual{m.Memory[p]:X2}")));
            if(m.Data.Count!=0 || m.Control.Pointer!=0x800)throw new InvalidDataException("Payout display stack imbalance");
            count++;
        }
        return count;
    }
}
