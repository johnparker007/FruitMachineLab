using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native53AE. Byte-fed parser, not a serial line/IRQ emulator. Original53D7
// stores A (the byte) after ADDB: preserve that behaviour, not an assumed sum.
public sealed class AddersSerialReplyPlan(Machine m,byte value,ushort stack)
{
    private byte a=value,b;private bool zero;private ushort x;
    public byte Result {get;private set;}
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x53AE,"3402",()=>m.Memory[stack-1]=a);
        yield return new NativeRoutineStep(0x53B0,"7D0348",()=>zero=m.Memory[0x348]==0);yield return new NativeRoutineStep(0x53B3,"276C");
        if(zero){yield return new NativeRoutineStep(0x5421,"8106",()=>zero=a==6);yield return new NativeRoutineStep(0x5423,"27F3");if(zero){foreach(var op in Ack())yield return op;yield break;}foreach(var op in Error())yield return op;yield break;}
        yield return new NativeRoutineStep(0x53B5,"7D034A",()=>zero=m.Memory[0x34A]==0);yield return new NativeRoutineStep(0x53B8,"274C");
        if(zero){
            yield return new NativeRoutineStep(0x5406,"8106",()=>zero=a==6);yield return new NativeRoutineStep(0x5408,"270E");if(zero){foreach(var op in Ack())yield return op;yield break;}
            yield return new NativeRoutineStep(0x540A,"8165",()=>zero=a==0x65);yield return new NativeRoutineStep(0x540C,"2617");if(!zero){foreach(var op in Error())yield return op;yield break;}
            yield return new NativeRoutineStep(0x540E,"B7034A",()=>m.Memory[0x34A]=a);yield return new NativeRoutineStep(0x5411,"B70349",()=>m.Memory[0x349]=a);yield return new NativeRoutineStep(0x5414,"C602",()=>Result=2);yield return new NativeRoutineStep(0x5416,"3582");yield break;
        }
        yield return new NativeRoutineStep(0x53BA,"7D0347",()=>zero=m.Memory[0x347]==0);yield return new NativeRoutineStep(0x53BD,"271F");
        if(zero){
            yield return new NativeRoutineStep(0x53DE,"B70347",()=>m.Memory[0x347]=a);yield return new NativeRoutineStep(0x53E1,"BB0349",()=>a+=m.Memory[0x349]);yield return new NativeRoutineStep(0x53E4,"B70349",()=>m.Memory[0x349]=a);yield return new NativeRoutineStep(0x53E7,"7F034B",()=>m.Memory[0x34B]=0);yield return new NativeRoutineStep(0x53EA,"C602",()=>Result=2);yield return new NativeRoutineStep(0x53EC,"3582");yield break;
        }
        yield return new NativeRoutineStep(0x53BF,"F60347",()=>b=m.Memory[0x347]);yield return new NativeRoutineStep(0x53C2,"F1034B",()=>zero=b==m.Memory[0x34B]);yield return new NativeRoutineStep(0x53C5,"2727");
        if(!zero){
            yield return new NativeRoutineStep(0x53C7,"7C034B",()=>m.Memory[0x34B]++);yield return new NativeRoutineStep(0x53CA,"F6034B",()=>b=m.Memory[0x34B]);yield return new NativeRoutineStep(0x53CD,"8E034B",()=>x=0x34B);
            yield return new NativeRoutineStep(0x53D0,"A785",()=>m.Memory[x+unchecked((sbyte)b)]=a);yield return new NativeRoutineStep(0x53D2,"F60349",()=>b=m.Memory[0x349]);yield return new NativeRoutineStep(0x53D5,"EB85",()=>b+=m.Memory[x+unchecked((sbyte)b)]);
            yield return new NativeRoutineStep(0x53D7,"B70349",()=>m.Memory[0x349]=a);yield return new NativeRoutineStep(0x53DA,"C602",()=>Result=2);yield return new NativeRoutineStep(0x53DC,"3582");yield break;
        }
        yield return new NativeRoutineStep(0x53EE,"B10349",()=>zero=a==m.Memory[0x349]);yield return new NativeRoutineStep(0x53F1,"2632");if(!zero){foreach(var op in Error())yield return op;yield break;}
        yield return new NativeRoutineStep(0x53F3,"B6034C",()=>a=m.Memory[0x34C]);yield return new NativeRoutineStep(0x53F6,"B10348",()=>zero=a==m.Memory[0x348]);yield return new NativeRoutineStep(0x53F9,"262A");if(!zero){foreach(var op in Error())yield return op;yield break;}
        yield return new NativeRoutineStep(0x53FB,"7F0348",()=>m.Memory[0x348]=0);yield return new NativeRoutineStep(0x53FE,"C6FF",()=>b=255);yield return new NativeRoutineStep(0x5400,"F70346",()=>m.Memory[0x346]=b);yield return new NativeRoutineStep(0x5403,"5F",()=>Result=0);yield return new NativeRoutineStep(0x5404,"3582");
    }
    private IEnumerable<NativeRoutineWork> Ack(){yield return new NativeRoutineStep(0x5418,"7F0346",()=>m.Memory[0x346]=0);yield return new NativeRoutineStep(0x541B,"7F0348",()=>m.Memory[0x348]=0);yield return new NativeRoutineStep(0x541E,"5F",()=>Result=0);yield return new NativeRoutineStep(0x541F,"3582");}
    private IEnumerable<NativeRoutineWork> Error(){yield return new NativeRoutineStep(0x5425,"C601",()=>Result=1);yield return new NativeRoutineStep(0x5427,"3582");}
}
