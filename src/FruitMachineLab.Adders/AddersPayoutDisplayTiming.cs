using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Selected display VM CPU budgets, not instruction-level execution. Native alpha
// stream work remains an explicitly supplied adapter. All other selected paths
// derive their costs from byte-checked original instructions and current cells.
public static class AddersPayoutDisplayTiming
{
    private readonly record struct Op(ushort At,string Bytes,bool? Branch=null);
    private static readonly Op[] Next=[new(0xFC,"AEA1"),new(0xFE,"6E91")];
    public static ulong ReturnDispatchCycles(Machine m)=>Cost(m,Next);
    public static ulong Cycles(Instruction i,Machine m,Func<Instruction,Machine,ulong> alphaCycles)
    {
        if(i.Operation=="vm_execute_alpha_stream"){
            ulong cost=alphaCycles(i,m);if(cost==0)throw new NotSupportedException("Alpha timing adapter cannot supply zero CPU work");return cost;
        }
        IEnumerable<Op> body;
        if(i.PushAddress is not null){if(i.PushAddress!=Cell.Add(i.Token,2))throw new InvalidDataException("Display word-body address differs");ushort entry=Cell.Subtract(i.Body!.Value,3);body=[new(entry,"BD796E"),new(0x796E,"3610"),new(0x7970,"AEE4"),new(0x7972,"10AFE4"),new(0x7975,"3184"),new(0x7977,"0EFC")];Header(entry);}
        else if(i.Body is not null){if(i.Body!=Cell.Add(i.Token,2))throw new InvalidDataException("Display threaded body differs");Header(0xF8);body=[new(0xF8,"3420"),new(0xFA,"3184")];}
        else if(i.Operation is "vm_push_word_body_word" or "vm_push_word_body_byte"){
            bool word=i.Operation=="vm_push_word_body_word";Header(word ? (ushort)0x794F : (ushort)0x7946);
            ushort value=word ? m.ReadWord(Cell.Add(i.Token,2)) : m.Memory[Cell.Add(i.Token,2)];
            if(i.Value!=value)throw new InvalidDataException("Display literal encoding differs from recovered listing");
            body=word ? [new(0x794F,"EC84"),new(0x7951,"3606"),new(0x7953,"0EFC")] : [new(0x7946,"4F"),new(0x7947,"E684"),new(0x7949,"3606"),new(0x794B,"0EFC")];
        }else body=i.Token switch {
            0x7915=>[new(0x7917,"AEC4"),new(0x7919,"EC02"),new(0x791B,"EDC4"),new(0x791D,"EC84"),new(0x791F,"3606"),new(0x7921,"0EFC")],
            0x767F=>Mask(m),
            0x7574=>ConditionalReturn(m),
            0x765F=>[new(0x7661,"6FD1"),new(0x7663,"0EFC")],
            0x786B=>[new(0x786D,"E6D4"),new(0x786F,"4F"),new(0x7870,"EDC4"),new(0x7872,"0EFC")],
            0x790D=>[new(0x790F,"ECD4"),new(0x7911,"EDC4"),new(0x7913,"0EFC")],
            0x787E=>[new(0x7880,"3706"),new(0x7882,"E3C4"),new(0x7884,"EDC4"),new(0x7886,"0EFC")],
            0x7874=>[new(0x7876,"3710"),new(0x7878,"3706"),new(0x787A,"ED84"),new(0x787C,"0EFC")],
            0x7A46=>Zero(m),
            0x7979=>[new(0x797B,"E6A4"),new(0x797D,"4F"),new(0x797E,"31AB"),new(0x7980,"0EFC")],
            0x7982=>Mpu4VmConditionalTiming.Path(i.Token,m.Data.Peek()==0).Skip(2).Select(v=>new Op(v.Address,v.Bytes)),
            0x792F=>[new(0x7931,"3520"),new(0x7933,"0EFC")],
            _=>throw new NotSupportedException($"No selected payout display CPU path for{i.Site:X4}/{i.Token:X4}")
        };
        return Cost(m,Next.Concat(body));
        void Header(ushort expected){if(m.ReadWord(i.Token)!=expected)throw new InvalidDataException($"Display token{i.Token:X4} native header differs");}
    }
    private static IEnumerable<Op> Mask(Machine m)
    {
        ushort[] cells=m.Data.Take(2).ToArray();if(cells.Length!=2)throw new InvalidOperationException("Mask stack underflow");ushort mask=cells[0],value=m.ReadWord(cells[1]);
        yield return new(0x7681,"3716");yield return new(0x7683,"A484");yield return new(0x7685,"2604");
        if((mask&value&0xFF00)==0){yield return new(0x7687,"E401");yield return new(0x7689,"2703");}
        if((mask&value)!=0)yield return new(0x768B,"CCFFFF");yield return new(0x768E,"3606");yield return new(0x7690,"0EFC");
    }
    private static IEnumerable<Op> ConditionalReturn(Machine m)
    {
        bool take=m.Data.Peek()!=0;yield return new(0x7576,"ECC1");yield return new(0x7578,"102603BB",take);
        if(!take){yield return new(0x757C,"0EFC");yield break;}
        var control=m.Control ?? throw new NotSupportedException("Display conditional return needs native frame");
        if(control.Pointer==control.LoopFrame)throw new NotSupportedException("Display return crossing an active loop needs another timing path");
        yield return new(0x7937,"119CF6");yield return new(0x793A,"26F5");yield return new(0x7931,"3520");yield return new(0x7933,"0EFC");
    }
    private static IEnumerable<Op> Zero(Machine m)
    {
        yield return new(0x7A48,"ECC4");yield return new(0x7A4A,"26F3");
        if(m.Data.Peek()==0){yield return new(0x7A4C,"CCFFFF");yield return new(0x7A4F,"EDC4");yield return new(0x7A51,"0EFC");}
        else{yield return new(0x7A3F,"CC0000");yield return new(0x7A42,"EDC4");yield return new(0x7A44,"0EFC");}
    }
    private static ulong Cost(Machine m,IEnumerable<Op> path)
    {
        ulong sum=0;foreach(var op in path){byte[] bytes=Convert.FromHexString(op.Bytes);if(!m.Memory.AsSpan(op.At,bytes.Length).SequenceEqual(bytes))throw new InvalidDataException($"Payout display native bytes differ at{op.At:X4}");sum=checked(sum+(ulong)M6809InstructionTiming.Decode(bytes,op.Branch).Cycles);}return sum;
    }
    public static void LoadRomData(Machine m,string evidence)
    {
        using var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","display-vm-data.json")));
        foreach(var region in doc.RootElement.GetProperty("regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
        using var gateway=System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","native-vm-gateway.json")));
        foreach(var region in gateway.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(region.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,region.GetProperty("address").GetInt32());
    }
}
