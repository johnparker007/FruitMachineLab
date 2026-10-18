using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

public readonly record struct AddersIrq6B4DZeroState(
    ulong Cycle,ushort PC,ushort S,ushort U,ushort X,ushort Y,byte A,byte B,byte CC);

public sealed record AddersIrq6B4DZeroStateResult(
    AddersIrq6B4DZeroState Entry,
    IReadOnlyList<AddersIrq6B4DZeroState> Boundaries,
    AddersIrq6B4DZeroState Return,
    ulong CallCycles,
    ulong PathCycles,
    byte[] MemoryAfter);

public static class AddersIrq6B4DZeroStateExecution
{
    public const ushort Call=0xFEC3;
    public const ushort Entry=0x6B4D;
    public const ushort Return=0xFEC6;
    public const ushort CaptureS=0x0786;
    public const ushort CaptureU=0x0672;
    public const string CallBytes="BD6B4D";

    private enum Kind { Plain,ShortBranch,LongBranch,LongJump,Jsr,Rts,Pull }

    private readonly record struct Step(
        ushort PC,string Bytes,string Name,Kind Kind,bool? Taken,ushort Next);

    private static readonly Step[] Path=
    [
        new(0x6B4D,"0D83","TST <$83",Kind.Plain,null,0x6B4F),
        new(0x6B4F,"2764","BEQ $6BB5",Kind.ShortBranch,false,0x6B51),
        new(0x6B51,"9602","LDA <$02",Kind.Plain,null,0x6B53),
        new(0x6B53,"8480","ANDA #$80",Kind.Plain,null,0x6B55),
        new(0x6B55,"B10323","CMPA $0323",Kind.Plain,null,0x6B58),
        new(0x6B58,"270B","BEQ $6B65",Kind.ShortBranch,true,0x6B65),
        new(0x6B65,"0F85","CLR <$85",Kind.Plain,null,0x6B67),
        new(0x6B67,"BD5330","JSR $5330",Kind.Jsr,null,0x5330),
        new(0x5330,"0D73","TST <$73",Kind.Plain,null,0x5332),
        new(0x5332,"2775","BEQ $53A9",Kind.ShortBranch,true,0x53A9),
        new(0x53A9,"0F7D","CLR <$7D",Kind.Plain,null,0x53AB),
        new(0x53AB,"0F80","CLR <$80",Kind.Plain,null,0x53AD),
        new(0x53AD,"39","RTS",Kind.Rts,null,0x6B6A),
        new(0x6B6A,"0D7C","TST <$7C",Kind.Plain,null,0x6B6C),
        new(0x6B6C,"2704","BEQ $6B72",Kind.ShortBranch,true,0x6B72),
        new(0x6B72,"0D71","TST <$71",Kind.Plain,null,0x6B74),
        new(0x6B74,"263F","BNE $6BB5",Kind.ShortBranch,false,0x6B76),
        new(0x6B76,"0D72","TST <$72",Kind.Plain,null,0x6B78),
        new(0x6B78,"264D","BNE $6BC7",Kind.ShortBranch,false,0x6B7A),
        new(0x6B7A,"7D03A5","TST $03A5",Kind.Plain,null,0x6B7D),
        new(0x6B7D,"1027E630","LBEQ $51B1",Kind.LongBranch,true,0x51B1),
        new(0x51B1,"3416","PSHS X,D",Kind.Plain,null,0x51B3),
        new(0x51B3,"0D84","TST <$84",Kind.Plain,null,0x51B5),
        new(0x51B5,"102700C9","LBEQ $5282",Kind.LongBranch,false,0x51B9),
        new(0x51B9,"B603DA","LDA $03DA",Kind.Plain,null,0x51BC),
        new(0x51BC,"260C","BNE $51CA",Kind.ShortBranch,false,0x51BE),
        new(0x51BE,"8E03A8","LDX #$03A8",Kind.Plain,null,0x51C1),
        new(0x51C1,"BF03D8","STX $03D8",Kind.Plain,null,0x51C4),
        new(0x51C4,"BF03D6","STX $03D6",Kind.Plain,null,0x51C7),
        new(0x51C7,"1600B8","LBRA $5282",Kind.LongJump,null,0x5282),
        new(0x5282,"3596","PULS D,X,PC",Kind.Pull,null,0xFEC6)
    ];

    public static ulong CallCycles {get;}=
        (ulong)M6809InstructionTiming.Decode(Convert.FromHexString(CallBytes)).Cycles;

    public static void Validate(Machine machine,ushort s,ushort u)
    {
        ArgumentNullException.ThrowIfNull(machine);
        if(s!=CaptureS)throw new NotSupportedException(
            $"6B4D component requires captured S={CaptureS:X4}, got {s:X4}");
        if(u!=CaptureU)throw new NotSupportedException(
            $"6B4D component requires captured U={CaptureU:X4}, got {u:X4}");

        if(machine.Memory[0x0083]!=0xFF)
            throw new NotSupportedException("6B4F BEQ $6BB5 path requires captured 0x83=FF");
        if(machine.Memory[0x0002]!=0x00 || machine.Memory[0x0323]!=0x00)
            throw new NotSupportedException("6B58 BEQ $6B65 path requires captured 0x02=00 and byte 0x323=00");
        if(machine.Memory[0x0073]!=0x00)
            throw new NotSupportedException("5332 BEQ $53A9 requires captured 0x73=00; nonzero 5330 path is unobserved");
        if(machine.Memory[0x007C]!=0x00)
            throw new NotSupportedException("6B6C BEQ $6B72 requires captured 0x7C=00");
        if(machine.Memory[0x0071]!=0x00)
            throw new NotSupportedException("6B74 BNE $6BB5 not-taken path requires captured 0x71=00");
        if(machine.Memory[0x0072]!=0x00)
            throw new NotSupportedException("6B78 BNE $6BC7 not-taken path requires captured 0x72=00");
        if(machine.Memory[0x03A5]!=0x00)
            throw new NotSupportedException("6B7D LBEQ $51B1 requires captured byte 0x03A5=00");
        if(machine.Memory[0x0084]!=0xFF)
            throw new NotSupportedException("51B5 LBEQ $5282 not-taken path requires captured 0x84=FF");
        if(machine.Memory[0x03DA]!=0x00)
            throw new NotSupportedException("51BC BNE $51CA not-taken path requires captured 0x03DA=00");

        var call=Convert.FromHexString(CallBytes);
        if(!machine.Memory.AsSpan(Call,call.Length).SequenceEqual(call))
            throw new NotSupportedException("FEC3 JSR $6B4D bytes differ");
        var callInfo=M6809InstructionTiming.Decode(call);
        if(callInfo.Length!=call.Length ||
           machine.ReadWord(Cell.Add(Call,1))!=Entry ||
           Cell.Add(Call,(ushort)callInfo.Length)!=Return)
            throw new NotSupportedException("FEC3 JSR $6B4D encoding differs");

        foreach(var step in Path)
        {
            var bytes=Convert.FromHexString(step.Bytes);
            if(!machine.Memory.AsSpan(step.PC,bytes.Length).SequenceEqual(bytes))
                throw new NotSupportedException($"{step.PC:X4} {step.Name} bytes differ from the certified path");
            var info=M6809InstructionTiming.Decode(bytes,step.Taken);
            if(info.Length!=bytes.Length)
                throw new NotSupportedException($"{step.PC:X4} {step.Name} length differs");
            switch(step.Kind)
            {
                case Kind.ShortBranch:
                {
                    ushort target=BranchTarget(machine,step.PC,false);
                    ushort fallThrough=Cell.Add(step.PC,2);
                    if((step.Taken==true ? target : fallThrough)!=step.Next)
                        throw new NotSupportedException($"{step.PC:X4} short branch boundary differs");
                    break;
                }
                case Kind.LongBranch:
                {
                    ushort target=BranchTarget(machine,step.PC,true);
                    ushort fallThrough=Cell.Add(step.PC,4);
                    if((step.Taken==true ? target : fallThrough)!=step.Next)
                        throw new NotSupportedException($"{step.PC:X4} long branch boundary differs");
                    break;
                }
                case Kind.LongJump:
                    if(JumpTarget(machine,step.PC)!=step.Next)
                        throw new NotSupportedException($"{step.PC:X4} LBRA target differs");
                    break;
                case Kind.Jsr:
                    if(machine.ReadWord(Cell.Add(step.PC,1))!=step.Next)
                        throw new NotSupportedException($"{step.PC:X4} JSR target differs");
                    break;
                case Kind.Rts:
                case Kind.Pull:
                    break;
                default:
                    if(Cell.Add(step.PC,(ushort)info.Length)!=step.Next)
                        throw new NotSupportedException($"{step.PC:X4} fall-through differs");
                    break;
            }
        }
    }

    public static AddersIrq6B4DZeroStateResult Execute(
        Machine machine,ulong startCycle,ushort s,ushort u,ushort x,ushort y,byte a,byte b,byte cc)
    {
        Validate(machine,s,u);
        var entryState=new AddersIrq6B4DZeroState(startCycle,Call,s,u,x,y,a,b,cc);
        var boundaries=new List<AddersIrq6B4DZeroState>(32);
        ulong cycle=startCycle;
        ushort pc=Call;

        cycle=checked(cycle+CallCycles);
        PushWord(machine,ref s,Return);
        pc=Entry;
        boundaries.Add(State(cycle,pc,s,u,x,y,a,b,cc));

        foreach(var step in Path)
        {
            if(pc!=step.PC)throw new InvalidDataException(
                $"6B4D path expected PC {step.PC:X4}, got {pc:X4}");
            var bytes=Convert.FromHexString(step.Bytes);
            var info=M6809InstructionTiming.Decode(bytes,step.Taken);
            cycle=checked(cycle+(ulong)info.Cycles);
            switch(step.Kind)
            {
                case Kind.ShortBranch:
                {
                    bool taken=M6809InstructionTiming.EvaluateBranch(bytes[0],cc);
                    if(taken!=step.Taken)throw new InvalidDataException(
                        $"{step.PC:X4} {step.Name} branch outcome differs");
                    pc=taken ? BranchTarget(machine,step.PC,false) : Cell.Add(step.PC,2);
                    break;
                }
                case Kind.LongBranch:
                {
                    bool taken=M6809InstructionTiming.EvaluateBranch(bytes[1],cc);
                    if(taken!=step.Taken)throw new InvalidDataException(
                        $"{step.PC:X4} {step.Name} branch outcome differs");
                    pc=taken ? BranchTarget(machine,step.PC,true) : Cell.Add(step.PC,4);
                    break;
                }
                case Kind.LongJump:
                    pc=JumpTarget(machine,step.PC);
                    break;
                case Kind.Jsr:
                    PushWord(machine,ref s,Cell.Add(step.PC,(ushort)bytes.Length));
                    pc=machine.ReadWord(Cell.Add(step.PC,1));
                    break;
                case Kind.Rts:
                {
                    ushort returnAddress=PopWord(machine,ref s);
                    if(returnAddress!=step.Next)throw new InvalidDataException(
                        $"53AD RTS returned {returnAddress:X4}, expected {step.Next:X4}");
                    pc=returnAddress;
                    break;
                }
                default:
                    ApplyPlain(machine,step,ref pc,ref s,ref a,ref b,ref x,ref cc);
                    break;
            }
            boundaries.Add(State(cycle,pc,s,u,x,y,a,b,cc));
        }

        if(boundaries.Count!=32)throw new InvalidDataException(
            $"6B4D component produced {boundaries.Count} boundaries, expected 32");
        var returnState=boundaries[^1];
        if(returnState.PC!=Return)
            throw new InvalidDataException($"6B4D component returned to {returnState.PC:X4}, expected {Return:X4}");
        if(returnState.Cycle-startCycle!=CallCycles+PathCycles)
            throw new InvalidDataException("6B4D component elapsed cycle split differs");
        if(machine.ReadWord(Cell.Subtract(returnState.S,2))!=Return)
            throw new InvalidDataException("6B4D component return word differs");

        return new(
            entryState,boundaries,returnState,CallCycles,PathCycles,
            machine.Memory.AsSpan(0,0x800).ToArray());
    }

    public static ulong PathCycles {get;}=
        Path.Aggregate(0UL,(total,step)=>
            checked(total+(ulong)M6809InstructionTiming.Decode(
                Convert.FromHexString(step.Bytes),step.Taken).Cycles));

    private static void ApplyPlain(
        Machine machine,Step step,ref ushort pc,ref ushort s,ref byte a,ref byte b,ref ushort x,ref byte cc)
    {
        switch(step.PC)
        {
            case 0x6B4D:
                cc=SetNZV(cc,machine.Memory[0x0083],8);
                break;
            case 0x6B51:
                a=machine.Memory[0x0002];
                cc=SetNZV(cc,a,8);
                break;
            case 0x6B53:
                a=(byte)(a&0x80);
                cc=SetNZV(cc,a,8);
                break;
            case 0x6B55:
                cc=CompareA(cc,a,machine.Memory[0x0323]);
                break;
            case 0x6B65:
                machine.Memory[0x0085]=0;
                cc=SetNZV(cc,0,8);
                break;
            case 0x5330:
                cc=SetNZV(cc,machine.Memory[0x0073],8);
                break;
            case 0x53A9:
                machine.Memory[0x007D]=0;
                cc=SetNZV(cc,0,8);
                break;
            case 0x53AB:
                machine.Memory[0x0080]=0;
                cc=SetNZV(cc,0,8);
                break;
            case 0x6B6A:
                cc=SetNZV(cc,machine.Memory[0x007C],8);
                break;
            case 0x6B72:
                cc=SetNZV(cc,machine.Memory[0x0071],8);
                break;
            case 0x6B76:
                cc=SetNZV(cc,machine.Memory[0x0072],8);
                break;
            case 0x6B7A:
                cc=SetNZV(cc,machine.Memory[0x03A5],8);
                break;
            case 0x51B1:
                PushByte(machine,ref s,unchecked((byte)x));
                PushByte(machine,ref s,unchecked((byte)(x>>8)));
                PushByte(machine,ref s,b);
                PushByte(machine,ref s,a);
                break;
            case 0x51B3:
                cc=SetNZV(cc,machine.Memory[0x0084],8);
                break;
            case 0x51B9:
                a=machine.Memory[0x03DA];
                cc=SetNZV(cc,a,8);
                break;
            case 0x51BE:
                x=0x03A8;
                cc=SetNZV(cc,x,16);
                break;
            case 0x51C1:
                machine.WriteWord(0x03D8,x);
                break;
            case 0x51C4:
                machine.WriteWord(0x03D6,x);
                break;
            case 0x5282:
                a=PopByte(machine,ref s);
                b=PopByte(machine,ref s);
                byte xh=PopByte(machine,ref s);
                byte xl=PopByte(machine,ref s);
                x=unchecked((ushort)((xh<<8)|xl));
                byte ph=PopByte(machine,ref s);
                byte pl=PopByte(machine,ref s);
                pc=unchecked((ushort)((ph<<8)|pl));
                if(pc!=step.Next)
                    throw new InvalidDataException($"5282 PULS returned {pc:X4}, expected {step.Next:X4}");
                return;
            default:
                throw new InvalidOperationException($"Unexpected plain step {step.PC:X4}");
        }
        pc=step.Next;
    }

    private static ushort BranchTarget(Machine machine,ushort pc,bool longBranch)
    {
        if(longBranch)
            return unchecked((ushort)(pc+4+(short)machine.ReadWord(Cell.Add(pc,2))));
        return unchecked((ushort)(pc+2+(sbyte)machine.Memory[Cell.Add(pc,1)]));
    }

    private static ushort JumpTarget(Machine machine,ushort pc)=>
        unchecked((ushort)(pc+3+(short)machine.ReadWord(Cell.Add(pc,1))));

    private static byte SetNZV(byte cc,ushort value,int bits)
    {
        cc=(byte)(cc&~0x0E);
        if(value==0)cc|=0x04;
        if((value&(1<<(bits-1)))!=0)cc|=0x08;
        return cc;
    }

    private static byte CompareA(byte cc,byte a,byte operand)
    {
        int difference=a-operand;
        byte result=unchecked((byte)difference);
        cc=(byte)(cc&~0x0F);
        if(result==0)cc|=0x04;
        if((result&0x80)!=0)cc|=0x08;
        if(((a^operand)&(a^result)&0x80)!=0)cc|=0x02;
        if(a<operand)cc|=0x01;
        return cc;
    }

    private static AddersIrq6B4DZeroState State(
        ulong cycle,ushort pc,ushort s,ushort u,ushort x,ushort y,byte a,byte b,byte cc)=>
        new(cycle,pc,s,u,x,y,a,b,cc);

    private static void PushByte(Machine machine,ref ushort s,byte value)
    {
        s=unchecked((ushort)(s-1));
        machine.Memory[s]=value;
    }

    private static byte PopByte(Machine machine,ref ushort s)
    {
        byte value=machine.Memory[s];
        s=unchecked((ushort)(s+1));
        return value;
    }

    private static void PushWord(Machine machine,ref ushort s,ushort value)
    {
        PushByte(machine,ref s,unchecked((byte)value));
        PushByte(machine,ref s,unchecked((byte)(value>>8)));
    }

    private static ushort PopWord(Machine machine,ref ushort s)
    {
        byte high=PopByte(machine,ref s);
        byte low=PopByte(machine,ref s);
        return unchecked((ushort)((high<<8)|low));
    }
}
