namespace FruitMachineLab.Runtime;

public readonly record struct M6809InstructionTimingInfo(int Length,int Cycles);

// Cycle/length decoding only, for the selected ordinary MC6809 paths. Does not
// execute instructions, infer register values or handle interrupts. Unsupported
// encodings fail instead of inheriting a guessed duration. Source: pinned MAME
// mame0281 m6809.lst/base6x09.lst; HD6309 and wait states are outside this model.
public static class M6809InstructionTiming
{
    public static M6809InstructionTimingInfo Decode(ReadOnlySpan<byte> bytes)
    {
        if(bytes.IsEmpty)throw new InvalidDataException("Missing opcode");
        byte op=bytes[0];M6809InstructionTimingInfo result;
        if(op is >=0x20 and <=0x2F)result=new(2,3);
        else if(op is 0x34 or 0x35)
        {
            Require(bytes,2);int pushed=0;
            for(int bit=0;bit<8;bit++)if((bytes[1]&(1<<bit))!=0)pushed+=bit<4 ? 1 : 2;
            result=new(2,5+pushed);
        }
        else if(op is 0x30 or 0x31 or 0x32 or 0x33 or 0xA4 or 0xA7 or 0xE0 or 0xE6 or 0xAE or 0xAD)
        {
            Require(bytes,2);var indexed=Indexed(bytes[1]);
            int basis=op==0xAE ? 5 : op==0xAD ? 7 : 4;
            result=new(2+indexed.OperandBytes,basis+indexed.ExtraCycles);
        }
        else result=op switch {
            0x12=>new(1,2),0x39=>new(1,5),
            0x1A or 0x1C=>new(2,3),
            0x85 or 0x89 or 0xC4 or 0xC5 or 0xC6=>new(2,2),
            0x8C=>new(3,4),0x8D=>new(2,7),
            0x96 or 0xD6 or 0xD7=>new(2,4),0x9E=>new(2,5),
            0xB6 or 0xF7=>new(3,5),0xBD=>new(3,8),0x0C=>new(2,6),
            _=>throw new NotSupportedException($"MC6809 timing for opcode {op:X2} is outside the selected paths")
        };
        Require(bytes,result.Length);return result;
    }

    private static (int OperandBytes,int ExtraCycles) Indexed(byte postbyte)
    {
        if((postbyte&0x80)==0)return (0,1); // signed five-bit displacement
        var value=(postbyte&15) switch {
            0 or 2=>(0,2),1 or 3=>(0,3),4=>(0,0),5 or 6=>(0,1),
            8 or 12=>(1,1),9=>(2,4),11=>(0,4),13=>(2,5),
            _=>throw new NotSupportedException($"Indexed timing postbyte {postbyte:X2} is outside the selected paths")
        };
        return (value.Item1,value.Item2+((postbyte&0x10)!=0 ? 3 : 0));
    }
    private static void Require(ReadOnlySpan<byte> bytes,int count)
    {
        if(bytes.Length<count)throw new InvalidDataException("Truncated MC6809 instruction encoding");
    }
}
