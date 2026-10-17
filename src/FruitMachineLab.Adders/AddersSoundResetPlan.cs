using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public sealed class AddersSoundResetPlan(Machine m,ushort stack,ushort initialX,ushort initialY,byte initialA,byte initialB,Action<byte,byte>? write=null)
{
    private ushort s=stack,x=initialX,y=initialY;private byte a=initialA,b=initialB;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x5B77,"BD60C8",()=>{s-=2;m.WriteWord(s,0x5B7A);});
        yield return new NativeRoutineStep(0x60C8,"3404",()=>{s--;m.Memory[s]=b;});yield return new NativeRoutineStep(0x60CA,"F6719B",()=>b=m.Memory[0x719B]);
        yield return new NativeRoutineStep(0x60CD,"C580");yield return new NativeRoutineStep(0x60CF,"2602");
        if((b&0x80)!=0){yield return new NativeRoutineStep(0x60D3,"3263");yield return new NativeRoutineStep(0x60D5,"39");yield break;}
        yield return new NativeRoutineStep(0x60D1,"3584",()=>{b=m.Memory[s];s+=3;});
        yield return new NativeRoutineStep(0x5B7A,"8D13",()=>{s-=2;m.WriteWord(s,0x5B7C);});
        yield return new NativeRoutineStep(0x5B8F,"3436",()=>{s-=6;m.WriteWord(s,(ushort)((a<<8)|b));m.WriteWord((ushort)(s+2),x);m.WriteWord((ushort)(s+4),y);});
        yield return new NativeRoutineStep(0x5B91,"0C44",()=>m.Memory[0x44]++);
        yield return new NativeRoutineStep(0x5B93,"4F",()=>a=0);yield return new NativeRoutineStep(0x5B94,"5F",()=>b=0);yield return new NativeRoutineStep(0x5B95,"DD47",()=>m.WriteWord(0x47,0));
        yield return new NativeRoutineStep(0x5B97,"8E01A0",()=>x=0x1A0);yield return new NativeRoutineStep(0x5B9A,"9F49",()=>m.WriteWord(0x49,x));
        do{
            yield return new NativeRoutineStep(0x5B9C,"3184",()=>y=x);yield return new NativeRoutineStep(0x5B9E,"308825",()=>x+=0x25);yield return new NativeRoutineStep(0x5BA1,"AFA4",()=>m.WriteWord(y,x));
            yield return new NativeRoutineStep(0x5BA3,"8C027E");yield return new NativeRoutineStep(0x5BA6,"25F4");
        }while(x<0x27E);
        yield return new NativeRoutineStep(0x5BA8,"EDA4",()=>m.WriteWord(y,0));yield return new NativeRoutineStep(0x5BAA,"8E027E",()=>x=0x27E);
        yield return new NativeRoutineStep(0x5BAD,"4F",()=>a=0);yield return new NativeRoutineStep(0x5BAE,"974B",()=>m.Memory[0x4B]=a);
        do{yield return new NativeRoutineStep(0x5BB0,"4C",()=>a++);yield return new NativeRoutineStep(0x5BB1,"A780",()=>{m.Memory[x]=a;x++;});yield return new NativeRoutineStep(0x5BB3,"8105");yield return new NativeRoutineStep(0x5BB5,"25F9");}while(a<5);
        yield return new NativeRoutineStep(0x5BB7,"974C",()=>m.Memory[0x4C]=a);yield return new NativeRoutineStep(0x5BB9,"86FF",()=>a=255);yield return new NativeRoutineStep(0x5BBB,"A784",()=>m.Memory[x]=a);
        yield return new NativeRoutineStep(0x5BBD,"8E5BCE",()=>x=0x5BCE);
        do{
            yield return new NativeRoutineStep(0x5BC0,"EC81",()=>{a=m.Memory[x];b=m.Memory[x+1];x+=2;});yield return new NativeRoutineStep(0x5BC2,"BD60AB",()=>{s-=2;m.WriteWord(s,0x5BC5);});
            foreach(var op in new AddersYmCachedWritePlan(m,a,b,x,s,write).Instructions())yield return op;s+=2;
            yield return new NativeRoutineStep(0x5BC5,"8C5C18");yield return new NativeRoutineStep(0x5BC8,"25F6");
        }while(x<0x5C18);
        yield return new NativeRoutineStep(0x5BCA,"0A44",()=>m.Memory[0x44]--);
        yield return new NativeRoutineStep(0x5BCC,"35B6",()=>{a=m.Memory[s];b=m.Memory[s+1];x=m.ReadWord((ushort)(s+2));y=m.ReadWord((ushort)(s+4));s+=8;});
        yield return new NativeRoutineStep(0x5B7C,"0F4D",()=>m.Memory[0x4D]=0);yield return new NativeRoutineStep(0x5B7E,"0F4F",()=>m.Memory[0x4F]=0);
        yield return new NativeRoutineStep(0x5B80,"3402",()=>{s--;m.Memory[s]=a;});yield return new NativeRoutineStep(0x5B82,"8610",()=>a=16);yield return new NativeRoutineStep(0x5B84,"974E",()=>m.Memory[0x4E]=a);
        yield return new NativeRoutineStep(0x5B86,"8610",()=>a=16);yield return new NativeRoutineStep(0x5B88,"9750",()=>m.Memory[0x50]=a);yield return new NativeRoutineStep(0x5B8A,"3582");
    }
}
