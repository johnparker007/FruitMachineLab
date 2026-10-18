namespace FruitMachineLab.Runtime;

public readonly record struct Mpu4CalibratedDelayState(ulong Cycle,ushort PC,ushort S,ushort X,ushort Y,ushort U,byte A,byte B,byte DP,byte CC);
public readonly record struct Mpu4CalibratedDelayStackWrite(ushort Address,byte Value,ushort Instruction,ushort TapPC,ulong Cycle);
public sealed record Mpu4CalibratedDelayCallResult(Mpu4CalibratedDelayState State,IReadOnlyList<Mpu4CalibratedDelayStackWrite> Writes,bool StoppedBeforeInstruction);

// Source-derived execution of the actual A6L foreground boundary
// 5A05 LDB1,S; 5A07 JSR7159 -> 7159/718A/7164. It executes the ROM's
// stack/register effects and uses M6809InstructionTiming for every cycle.
// 719B bit80 is a separate disabled-tone path with no independent evidence and
// fails closed. The caller's 5A0A..5A12 cancel/finish code is outside this slice.
public static class Mpu4CalibratedDelayExecution
{
    public const ushort CallerLdb=0x5A05,Call=0x5A07,Callee=0x7159,Continuation=0x5A0A;
    // Deepest live frame is JSR(2)+BSR718A(2)+PSHS B(1) after unwind,
    // then PSHS A,B(2)+BSR7164(2)+PSHS B(1): seven bytes below entry S.
    public const ushort MinimumStackPointer=7;
    private static ulong Cost(string bytes)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes)).Cycles;
    private static ulong Cost(string bytes,bool taken)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes),taken).Cycles;

    public static Mpu4CalibratedDelayCallResult CallFrom5A05(Machine machine,ulong startCycle,ushort s,byte a,ushort x,ushort y,ushort u,byte dp,byte cc,Func<Mpu4CalibratedDelayState,bool>? stopBefore=null)
    {
        if(s<MinimumStackPointer)throw new ArgumentOutOfRangeException(nameof(s));
        if((machine.Memory[0x719B]&0x80)!=0)throw new NotSupportedException("719B bit80 disabled-tone delay requires independent evidence");
        var writes=new List<Mpu4CalibratedDelayStackWrite>();ulong cycle=startCycle;ushort pc=CallerLdb;byte b=0;bool stopped=false;

        Mpu4CalibratedDelayState State()=>new(cycle,pc,s,x,y,u,a,b,dp,cc);
        Mpu4CalibratedDelayCallResult Result()=>new(State(),writes,stopped);
        bool Step(ushort at,string bytes,Action? effect=null,bool? branch=null)
        {
            if(stopBefore is not null && stopBefore(State() with{PC=at})){pc=at;stopped=true;return false;}
            cycle=checked(cycle+(branch.HasValue ? Cost(bytes,branch.Value) : Cost(bytes)));
            pc=at;effect?.Invoke();return true;
        }
        void PushWord(ushort value,ushort instruction,ushort tap)
        {
            s--;machine.Memory[s]=(byte)value;writes.Add(new(s,(byte)value,instruction,tap,cycle));
            s--;machine.Memory[s]=(byte)(value>>8);writes.Add(new(s,(byte)(value>>8),instruction,tap,cycle));
        }
        void PushByte(byte value,ushort instruction,ushort tap){s--;machine.Memory[s]=value;writes.Add(new(s,value,instruction,tap,cycle));}
        byte PopByte(){byte value=machine.Memory[s];s++;return value;}
        ushort PopWord(){byte high=machine.Memory[s],low=machine.Memory[s+1];s+=2;return (ushort)((high<<8)|low);}
        void SetNz(byte value)=>cc=(byte)((cc&~0x0E)|(value==0 ? 0x04 : 0)|((value&0x80)!=0 ? 0x08 : 0));
        void SetDec(byte value)=>cc=(byte)((cc&~0x0E)|(value==0 ? 0x04 : 0)|((value&0x80)!=0 ? 0x08 : 0)|(value==0x7F ? 0x02 : 0));

        // 5A05 LDB 1,S reads the caller's saved B, then 5A07 JSR 7159.
        if(!Step(CallerLdb,"E661",()=>{b=machine.Memory[Cell.Add(s,1)];SetNz(b);}))return Result();
        if(!Step(Call,"BD7159",()=>{PushWord(Continuation,Call,Continuation);pc=Callee;}))return Result();

        // 7159 BSR 718A (enabled gate).
        if(!Step(Callee,"8D2F",()=>{PushWord(0x715B,Callee,0x715B);pc=0x718A;}))return Result();
        if(!Step(0x718A,"3404",()=>PushByte(b,0x718A,0x718C)))return Result();
        if(!Step(0x718C,"F6719B",()=>{b=machine.Memory[0x719B];SetNz(b);}))return Result();
        if(!Step(0x718F,"C580",()=>SetNz((byte)(b&0x80))))return Result();
        if((b&0x80)!=0)throw new NotSupportedException("719B bit80 changed during the enabled delay");
        if(!Step(0x7191,"2602",null,false))return Result();
        if(!Step(0x7193,"3584",()=>{b=PopByte();ushort ret=PopWord();if(ret!=0x715B)throw new InvalidDataException($"718A returned {ret:X4}, expected715B");pc=ret;}))return Result();

        // 715B PSHS A,B; 715D BSR 7164; repeat B times.
        if(!Step(0x715B,"3406",()=>{PushByte(b,0x715B,0x715D);PushByte(a,0x715B,0x715D);}))return Result();
        while(true)
        {
            if(!Step(0x715D,"8D05",()=>{PushWord(0x715F,0x715D,0x715F);pc=0x7164;}))return Result();
            if(!Step(0x7164,"3404",()=>PushByte(b,0x7164,0x7166)))return Result();
            if(!Step(0x7166,"C628",()=>{b=0x28;SetNz(b);}))return Result();
            bool next;
            do {
                if(!Step(0x7168,"8654",()=>{a=0x54;SetNz(a);}))return Result();
                while(true){
                    if(!Step(0x716A,"4A",()=>{a=unchecked((byte)(a-1));SetDec(a);}))return Result();
                    next=a!=0;
                    if(!Step(0x716B,"26FD",null,next))return Result();
                    if(!next)break;
                }
                if(!Step(0x716D,"5A",()=>{b=unchecked((byte)(b-1));SetDec(b);}))return Result();
                next=b!=0;
                if(!Step(0x716E,"26F8",null,next))return Result();
            } while(next);
            if(!Step(0x7170,"3584",()=>{b=PopByte();ushort ret=PopWord();if(ret!=0x715F)throw new InvalidDataException($"7164 returned {ret:X4}, expected715F");pc=ret;}))return Result();
            if(!Step(0x715F,"5A",()=>{b=unchecked((byte)(b-1));SetDec(b);}))return Result();
            next=b!=0;
            if(!Step(0x7160,"26FB",null,next))return Result();
            if(!next)break;
        }
        if(!Step(0x7162,"3586",()=>{a=PopByte();b=PopByte();ushort ret=PopWord();if(ret!=Continuation)throw new InvalidDataException($"7159 returned {ret:X4}, expected5A0A");pc=ret;}))return Result();
        return Result();
    }
}
