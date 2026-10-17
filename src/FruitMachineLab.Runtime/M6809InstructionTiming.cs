namespace FruitMachineLab.Runtime;

public readonly record struct M6809InstructionTimingInfo(int Length,int Cycles);

// Cycle/length decoding only, for the selected ordinary MC6809 paths. Does not
// execute instructions, infer register values or handle interrupts. Unsupported
// encodings fail instead of inheriting a guessed duration. Source: pinned MAME
// mame0281 m6809.lst/base6x09.lst; HD6309 and wait states are outside this model.
public static class M6809InstructionTiming
{
    public static M6809InstructionTimingInfo Decode(ReadOnlySpan<byte> bytes,bool? branchTaken=null,byte? stackedCC=null)
    {
        if(bytes.IsEmpty)throw new InvalidDataException("Missing opcode");
        byte op=bytes[0];M6809InstructionTimingInfo result;
        if(op is 0x10 or 0x11)
        {
            Require(bytes,2);
            if(op==0x11){result=bytes[1]==0x8C ? new(4,5) : bytes[1]==0x9C ? new(3,7) : throw new NotSupportedException("Only selected CMPS prefix11 timing is covered");}
            else if(bytes[1]==0x3F)result=new(2,20); // ordinary SWI2 full frame/vector
            else if(bytes[1] is >=0x21 and <=0x2F){if(branchTaken is null)throw new NotSupportedException("Long conditional timing requires an explicit branch outcome");result=new(4,branchTaken.Value ? 6 : 5);}
            else if(bytes[1] is 0xAE or 0xAF or 0xA3){Require(bytes,3);var idx=Indexed(bytes[2]);result=new(3+idx.OperandBytes,(bytes[1]==0xA3 ? 7 : 6)+idx.ExtraCycles);}
            else result=bytes[1] switch {0x83 or 0x8C=>new(4,5),0x8E=>new(4,4),0x9E or 0x9F or 0xDF=>new(3,6),0xBE or 0xBF=>new(4,7),_=>throw new NotSupportedException($"MC6809 prefix10 timing for {bytes[1]:X2} is outside the selected paths")};
        }
        else if(op is >=0x20 and <=0x2F)result=new(2,3);
        else if(op is 0x34 or 0x35 or 0x36 or 0x37)
        {
            Require(bytes,2);int pushed=0;
            for(int bit=0;bit<8;bit++)if((bytes[1]&(1<<bit))!=0)pushed+=bit<4 ? 1 : 2;
            result=new(2,5+pushed);
        }
        else if(op is 0x30 or 0x31 or 0x32 or 0x33 or 0xA0 or 0xA1 or 0xA3 or 0xA4 or 0xA6 or 0xA7 or 0xA8 or 0xAA or 0xE0 or 0xE1 or 0xE3 or 0xE4 or 0xE5 or 0xE6 or 0xE7 or 0xEB or 0xAC or 0xAE or 0xAF or 0xAD or 0xEC or 0xED or 0xEE or 0xEF or 0x6A or 0x6C or 0x6D or 0x6E or 0x6F)
        {
            Require(bytes,2);var indexed=Indexed(bytes[1]);
            int basis=op is 0xAE or 0xAF or 0xEC or 0xED or 0xEE or 0xEF ? 5 : op==0xAD ? 7 : op is 0xE3 ? 6 : op is 0xA3 or 0x6A or 0x6C or 0x6D or 0x6F or 0xAC ? 6 : op==0x6E ? 3 : 4;
            result=new(2+indexed.OperandBytes,basis+indexed.ExtraCycles);
        }
else result=op switch {
            0x12=>new(1,2),0x39=>new(1,5),0x0E=>new(2,3),
            0x3B=>stackedCC.HasValue ? new(1,(stackedCC.Value&0x80)!=0 ? 15 : 6) : throw new NotSupportedException("RTI timing requires the stacked CC, not the current CC"),
            0x17=>new(3,9),0x3A=>new(1,3),0x3D=>new(1,11),0x16=>new(3,5),0x1F=>new(2,6),0x1E=>new(2,8),
            0x43 or 0x44 or 0x46 or 0x47 or 0x48 or 0x49 or 0x4A or 0x4C or 0x4D or 0x4F or 0x50 or 0x53 or 0x54 or 0x56 or 0x58 or 0x59 or 0x5A or 0x5C or 0x5D or 0x5F=>new(1,2),
            0x1A or 0x1C=>new(2,3),
            0x80 or 0x81 or 0x82 or 0x84 or 0x85 or 0x86 or 0x88 or 0x89 or 0x8A or 0xC0 or 0xC1 or 0xC4 or 0xC5 or 0xC6 or 0xCA or 0xCB=>new(2,2),
            0x83 or 0x8C or 0xC3=>new(3,4),0x8D=>new(2,7),0x8E or 0xCC or 0xCE=>new(3,3),
            0x91 or 0x94 or 0x96 or 0x97 or 0x9A or 0xD4 or 0xD5 or 0xD6 or 0xD7 or 0xDB=>new(2,4),0x9E or 0x9F or 0xDC or 0xDD=>new(2,5),0x93 or 0xD3=>new(2,6),
            0xB1 or 0xB4 or 0xB6 or 0xB7 or 0xB8 or 0xBA or 0xBB or 0xF1 or 0xF6 or 0xF7 or 0xFB=>new(3,5),0xBE or 0xBF or 0xFC or 0xFD=>new(3,6),0xF3=>new(3,7),0xBD=>new(3,8),0x7E=>new(3,4),0x03 or 0x04 or 0x0A or 0x0C or 0x0D or 0x0F=>new(2,6),0x70 or 0x73 or 0x7A or 0x7C or 0x7D or 0x7F=>new(3,7),
            _=>throw new NotSupportedException($"MC6809 timing for opcode {op:X2} is outside the selected paths")
        };
        Require(bytes,result.Length);return result;
    }

    private static (int OperandBytes,int ExtraCycles) Indexed(byte postbyte)
    {
        if((postbyte&0x80)==0)return (0,1); // signed five-bit displacement
        var value=(postbyte&15) switch {
            0 or 2=>(0,2),1 or 3=>(0,3),4=>(0,0),5 or 6=>(0,1),
            8 or 12=>(1,1),9=>(2,4),11=>(0,4),13=>(2,5),15 when (postbyte&0x10)!=0=>(2,2),
            _=>throw new NotSupportedException($"Indexed timing postbyte {postbyte:X2} is outside the selected paths")
        };
        return (value.Item1,value.Item2+((postbyte&0x10)!=0 ? 3 : 0));
    }
    private static void Require(ReadOnlySpan<byte> bytes,int count)
    {
        if(bytes.Length<count)throw new InvalidDataException("Truncated MC6809 instruction encoding");
    }
    public static bool EvaluateBranch(byte opcode,byte cc)
    {
        bool c=(cc&1)!=0,v=(cc&2)!=0,z=(cc&4)!=0,n=(cc&8)!=0;
        return opcode switch {
            0x20=>true,0x21=>false,0x22=>!c&&!z,0x23=>c||z,0x24=>!c,0x25=>c,
            0x26=>!z,0x27=>z,0x28=>!v,0x29=>v,0x2A=>!n,0x2B=>n,
            0x2C=>n==v,0x2D=>n!=v,0x2E=>!z&&n==v,0x2F=>z||n!=v,
            _=>throw new NotSupportedException($"Branch condition {opcode:X2} is not covered")
        };
    }
}
