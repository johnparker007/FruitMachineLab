using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native5429 owns the polling loop. External helpers are typed CPU handoffs;
// neither ACK bytes nor completion time are supplied by this plan.
public sealed class AddersSerialWaitPlan(Machine m,ushort stack,ushort y,byte conditionCode,ushort entry=0x5429,ushort initialX=0,byte initialA=0)
{
    private ushort x=initialX;private byte a=initialA;private bool zero;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(entry is not (0x5429 or 0x5434))throw new NotSupportedException("Unrecovered serial wait entry");
        if(entry==0x5429){
            yield return new NativeRoutineStep(0x5429,"0D7D",()=>zero=m.Memory[0x7D]==0);yield return new NativeRoutineStep(0x542B,"1027FF7E",Branch:zero);if(zero){yield return new NativeRoutineStep(0x53AD,"39");yield break;}
            yield return new NativeRoutineStep(0x542F,"86FF",()=>a=255);yield return new NativeRoutineStep(0x5431,"8EFFFF",()=>x=65535);
        }
        while(true){
            yield return new NativeRoutineStep(0x5434,"3086",()=>{x=unchecked((ushort)(x+unchecked((sbyte)a)));zero=x==0;});yield return new NativeRoutineStep(0x5436,"2607");
            if(zero){
                yield return new NativeRoutineStep(0x5438,"BD2CB3",()=>m.WriteWord((ushort)(stack-2),0x543B));yield return new NativeRoutineCall(0x2CB3,0x543B,y,(ushort)(stack-2),conditionCode);
                yield return new NativeRoutineStep(0x543B,"8E0000",()=>x=0);yield return new NativeRoutineStep(0x543E,"4F",()=>a=0);
            }
            yield return new NativeRoutineStep(0x543F,"8CF000",()=>zero=x==0xF000);yield return new NativeRoutineStep(0x5442,"2608");
            if(zero){
                byte b=0;yield return new NativeRoutineStep(0x5444,"D675",()=>b=m.Memory[0x75]);yield return new NativeRoutineStep(0x5446,"C40F",()=>b&=15);yield return new NativeRoutineStep(0x5448,"2702");if(b!=0)yield return new NativeRoutineStep(0x544A,"0F75",()=>m.Memory[0x75]=0);
            }
            yield return new NativeRoutineStep(0x544C,"8C1000");yield return new NativeRoutineStep(0x544F,"2204");
            if(x<=0x1000){
                yield return new NativeRoutineStep(0x5451,"8D1E",()=>m.WriteWord((ushort)(stack-2),0x5453));yield return new NativeRoutineCall(0x5471,0x5453,y,(ushort)(stack-2),conditionCode);
                yield return new NativeRoutineStep(0x5453,"0F75",()=>m.Memory[0x75]=0);
            }
            yield return new NativeRoutineStep(0x5455,"0D7D",()=>zero=m.Memory[0x7D]==0);yield return new NativeRoutineStep(0x5457,"2605");
            if(zero){
                yield return new NativeRoutineStep(0x5459,"8D0F",()=>m.WriteWord((ushort)(stack-2),0x545B));yield return new NativeRoutineCall(0x546A,0x545B,y,(ushort)(stack-2),conditionCode);
                yield return new NativeRoutineStep(0x545B,"16FF4F");yield return new NativeRoutineStep(0x53AD,"39");yield break;
            }
            yield return new NativeRoutineStep(0x545E,"BD6EF7",()=>m.WriteWord((ushort)(stack-2),0x5461));yield return new NativeRoutineCall(0x6EF7,0x5461,y,(ushort)(stack-2),conditionCode);
            yield return new NativeRoutineStep(0x5461,"7D0323",()=>zero=(sbyte)m.Memory[0x323]>=0);yield return new NativeRoutineStep(0x5464,"2ACE");if(zero)continue;
            yield return new NativeRoutineStep(0x5466,"0F73",()=>m.Memory[0x73]=0);yield return new NativeRoutineStep(0x5468,"20CA");
        }
    }
}
