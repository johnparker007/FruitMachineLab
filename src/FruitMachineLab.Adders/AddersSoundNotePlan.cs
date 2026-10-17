using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Selected melodic notes,5D48..5DDC and gate-free timed tail. Acquires real
// channel lists/cache registers before duration yield. Rhythm/gated tails stop.
public sealed class AddersSoundNotePlan(Machine m,ushort task,ushort cursor,ushort stack,ushort initialX,byte note,Action<byte,byte>? write=null)
{
    private ushort u=cursor,s=stack,x=initialX;private byte a,b=note;private bool negative,immediate;
    public ushort Cursor=>u;public ushort X=>x;public bool Yielded {get;private set;}
    private IEnumerable<NativeRoutineWork> Cache(ushort site,ushort next)
    {
        yield return new NativeRoutineStep(site,"BD60AB",()=>{s-=2;m.WriteWord(s,next);});
        foreach(var op in new AddersYmCachedWritePlan(m,a,b,x,s,write).Instructions())yield return op;s+=2;
    }
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x5D48,"C160");yield return new NativeRoutineStep(0x5D4A,"2502");
        if(b>=0x60)yield return new NativeRoutineStep(0x5D4C,"C060",()=>b-=0x60);
        yield return new NativeRoutineStep(0x5D4E,"C15B");yield return new NativeRoutineStep(0x5D50,"253E");
        if(b>=0x5B){
            yield return new NativeRoutineStep(0x5D52,"8E5A79",()=>x=0x5A79);
            yield return new NativeRoutineStep(0x5D55,"3A",()=>x+=b);
            yield return new NativeRoutineStep(0x5D56,"A684",()=>a=m.Memory[x]);
            yield return new NativeRoutineStep(0x5D58,"AAA811",()=>a|=m.Memory[task+0x11]);
            yield return new NativeRoutineStep(0x5D5B,"A7A811",()=>m.Memory[task+0x11]=a);
            yield return new NativeRoutineStep(0x5D5E,"BA0292",()=>a|=m.Memory[0x292]);
            yield return new NativeRoutineStep(0x5D61,"C60E",()=>b=0x0E);foreach(var op in Cache(0x5D63,0x5D66))yield return op;
            yield return new NativeRoutineStep(0x5D66,"E605",()=>b=m.Memory[x+5]);
            yield return new NativeRoutineStep(0x5D68,"6D0A",()=>negative=m.Memory[x+10]!=0);
            yield return new NativeRoutineStep(0x5D6A,"2610");
            if(!negative){
                yield return new NativeRoutineStep(0x5D6C,"8E0284",()=>x=0x284);
                yield return new NativeRoutineStep(0x5D6F,"A62B",()=>a=m.Memory[task+0xB]);
                yield return new NativeRoutineStep(0x5D71,"A885",()=>a^=m.Memory[x+b]);
                yield return new NativeRoutineStep(0x5D73,"840F",()=>a&=15);
                yield return new NativeRoutineStep(0x5D75,"A885",()=>a^=m.Memory[x+b]);foreach(var op in Cache(0x5D77,0x5D7A))yield return op;
                yield return new NativeRoutineStep(0x5D7A,"205C");
            }else{
                yield return new NativeRoutineStep(0x5D7C,"8E0284",()=>x=0x284);
                yield return new NativeRoutineStep(0x5D7F,"A62B",()=>a=m.Memory[task+0xB]);
                yield return new NativeRoutineStep(0x5D81,"48",()=>a<<=1);yield return new NativeRoutineStep(0x5D82,"48",()=>a<<=1);
                yield return new NativeRoutineStep(0x5D83,"48",()=>a<<=1);yield return new NativeRoutineStep(0x5D84,"48",()=>a<<=1);
                yield return new NativeRoutineStep(0x5D85,"A885",()=>a^=m.Memory[x+b]);
                yield return new NativeRoutineStep(0x5D87,"84F0",()=>a&=0xF0);
                yield return new NativeRoutineStep(0x5D89,"A885",()=>a^=m.Memory[x+b]);foreach(var op in Cache(0x5D8B,0x5D8E))yield return op;
                yield return new NativeRoutineStep(0x5D8E,"2048");
            }
        }else{
        yield return new NativeRoutineStep(0x5D90,"964B",()=>{a=m.Memory[0x4B];negative=(sbyte)a<0;});
        yield return new NativeRoutineStep(0x5D92,"2B44");
        if(!negative){
            if(a>5)throw new InvalidDataException("Invalid free sound channel");
            yield return new NativeRoutineStep(0x5D94,"3404",()=>{s--;m.Memory[s]=b;});
            yield return new NativeRoutineStep(0x5D96,"8E027E",()=>x=0x27E);
            yield return new NativeRoutineStep(0x5D99,"E686",()=>{b=m.Memory[x+a];negative=(sbyte)b<0;});
            yield return new NativeRoutineStep(0x5D9B,"D74B",()=>m.Memory[0x4B]=b);
            yield return new NativeRoutineStep(0x5D9D,"2A02");
            if(negative)yield return new NativeRoutineStep(0x5D9F,"D74C",()=>m.Memory[0x4C]=b);
            yield return new NativeRoutineStep(0x5DA1,"E62A",()=>b=m.Memory[task+0xA]);
            yield return new NativeRoutineStep(0x5DA3,"E786",()=>m.Memory[x+a]=b);
            yield return new NativeRoutineStep(0x5DA5,"A72A",()=>m.Memory[task+0xA]=a);
            yield return new NativeRoutineStep(0x5DA7,"3504",()=>{b=m.Memory[s];s++;});
            yield return new NativeRoutineStep(0x5DA9,"6DA812",()=>negative=(sbyte)m.Memory[task+0x12]<0);
            yield return new NativeRoutineStep(0x5DAC,"2A02");if(negative)yield return new NativeRoutineStep(0x5DAE,"DB4D",()=>b+=m.Memory[0x4D]);
            yield return new NativeRoutineStep(0x5DB0,"EB2C",()=>b+=m.Memory[task+0xC]);
            yield return new NativeRoutineStep(0x5DB2,"EB2D",()=>{b+=m.Memory[task+0xD];negative=(sbyte)b<0;});
            yield return new NativeRoutineStep(0x5DB4,"2B22");
            bool playable=!negative;
            if(playable){yield return new NativeRoutineStep(0x5DB6,"C160");yield return new NativeRoutineStep(0x5DB8,"241E");playable=b<0x60;}
            if(playable){
                yield return new NativeRoutineStep(0x5DBA,"8E5A1E",()=>x=0x5A1E);
                yield return new NativeRoutineStep(0x5DBD,"3A",()=>x+=b);yield return new NativeRoutineStep(0x5DBE,"3A",()=>x+=b);
                yield return new NativeRoutineStep(0x5DBF,"E62A",()=>b=m.Memory[task+0xA]);
                yield return new NativeRoutineStep(0x5DC1,"CB30",()=>b+=0x30);
                yield return new NativeRoutineStep(0x5DC3,"A62B",()=>a=m.Memory[task+0xB]);foreach(var op in Cache(0x5DC5,0x5DC8))yield return op;
                yield return new NativeRoutineStep(0x5DC8,"A601",()=>a=m.Memory[x+1]);
                yield return new NativeRoutineStep(0x5DCA,"CBE0",()=>b+=0xE0);foreach(var op in Cache(0x5DCC,0x5DCF))yield return op;
                yield return new NativeRoutineStep(0x5DCF,"A684",()=>a=m.Memory[x]);
                yield return new NativeRoutineStep(0x5DD1,"AA2F",()=>a|=m.Memory[task+0xF]);
                yield return new NativeRoutineStep(0x5DD3,"CB10",()=>b+=0x10);foreach(var op in Cache(0x5DD5,0x5DD8))yield return op;
            }
        }
        }
        yield return new NativeRoutineStep(0x5DD8,"E65F",()=>{b=m.Memory[unchecked((ushort)(u-1))];immediate=b<0x60;});
        yield return new NativeRoutineStep(0x5DDA,"C160");yield return new NativeRoutineStep(0x5DDC,"1025FF5B",Branch:immediate);if(immediate)yield break;
        yield return new NativeRoutineStep(0x5DE0,"E6A810",()=>b=m.Memory[task+0x10]);yield return new NativeRoutineStep(0x5DE3,"2735");
        if(b!=0)throw new NotSupportedException("Native melodic gate requires its remaining split-duration callbacks");
        yield return new NativeRoutineStep(0x5E1A,"E6C0",()=>{b=m.Memory[u];u++;});
        yield return new NativeRoutineStep(0x5E1C,"BD5CF3",()=>{s-=2;m.WriteWord(s,0x5E1F);});
        foreach(var op in new AddersSoundYieldPlan(m,task,u,s,b).Instructions())yield return op;s+=2;Yielded=true;
    }
}
