using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native5330 frame handshake. Physical bit transfer and retry PTM reset70C9
// remain separate hardware boundaries. No captured ACK/timer is applied here.
public sealed class AddersSerialTransferPlan(Machine m,ushort stack)
{
    private byte a,b;private ushort x;private bool zero;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x5330,"0D73",()=>zero=m.Memory[0x73]==0);yield return new NativeRoutineStep(0x5332,"2775");
        if(zero){foreach(var op in Clear(true))yield return op;yield break;}
        yield return new NativeRoutineStep(0x5334,"0D71",()=>zero=m.Memory[0x71]==0);yield return new NativeRoutineStep(0x5336,"2673");if(!zero){foreach(var op in Clear(false))yield return op;yield break;}
        yield return new NativeRoutineStep(0x5338,"0D72",()=>zero=m.Memory[0x72]==0);yield return new NativeRoutineStep(0x533A,"2713");
        if(!zero){
            yield return new NativeRoutineStep(0x533C,"DC7A",()=>zero=m.ReadWord(0x7A)==0);yield return new NativeRoutineStep(0x533E,"266D");if(!zero){yield return new NativeRoutineStep(0x53AD,"39");yield break;}
            yield return new NativeRoutineStep(0x5340,"0C7B",()=>m.Memory[0x7B]++);yield return new NativeRoutineStep(0x5342,"9675",()=>a=m.Memory[0x75]);yield return new NativeRoutineStep(0x5344,"850F",()=>zero=(a&15)==0);yield return new NativeRoutineStep(0x5346,"2665");
            if(!zero){yield return new NativeRoutineStep(0x53AD,"39");yield break;}
            yield return new NativeRoutineStep(0x5348,"0F72",()=>m.Memory[0x72]=0);throw new NotSupportedException("Serial retry requires explicit70C9 PTM reset owner");
        }
        yield return new NativeRoutineStep(0x534F,"9675",()=>a=m.Memory[0x75]);yield return new NativeRoutineStep(0x5351,"2A5A");if((sbyte)a>=0){yield return new NativeRoutineStep(0x53AD,"39");yield break;}
        yield return new NativeRoutineStep(0x5353,"847F",()=>a&=0x7F);yield return new NativeRoutineStep(0x5355,"9775",()=>m.Memory[0x75]=a);yield return new NativeRoutineStep(0x5357,"8560",()=>zero=(a&0x60)==0);yield return new NativeRoutineStep(0x5359,"260F");
        if(zero){
            yield return new NativeRoutineStep(0x535B,"B603A7",()=>a=m.Memory[0x3A7]);yield return new NativeRoutineStep(0x535E,"BD53AE",()=>m.WriteWord((ushort)(stack-2),0x5361));
            var reply=new AddersSerialReplyPlan(m,a,(ushort)(stack-2));foreach(var op in reply.Instructions())yield return op;b=reply.Result;
            yield return new NativeRoutineStep(0x5361,"C102",()=>zero=b==2);yield return new NativeRoutineStep(0x5363,"10270046",Branch:zero);if(zero){yield return new NativeRoutineStep(0x53AD,"39");yield break;}
            yield return new NativeRoutineStep(0x5367,"5D",()=>zero=b==0);yield return new NativeRoutineStep(0x5368,"2736");
            if(zero){yield return new NativeRoutineStep(0x53A0,"7F03A5",()=>m.Memory[0x3A5]=0);yield return new NativeRoutineStep(0x53A3,"867F",()=>a=0x7F);yield return new NativeRoutineStep(0x53A5,"942B",()=>a&=m.Memory[0x2B]);yield return new NativeRoutineStep(0x53A7,"972B",()=>m.Memory[0x2B]=a);foreach(var op in Clear(true))yield return op;yield break;}
        }
        yield return new NativeRoutineStep(0x536A,"967E",()=>a=m.Memory[0x7E]);yield return new NativeRoutineStep(0x536C,"977C",()=>m.Memory[0x7C]=a);yield return new NativeRoutineStep(0x536E,"2700");
        yield return new NativeRoutineStep(0x5370,"0D80",()=>zero=m.Memory[0x80]==0);yield return new NativeRoutineStep(0x5372,"2639");if(!zero){yield return new NativeRoutineStep(0x53AD,"39");yield break;}
        yield return new NativeRoutineStep(0x5374,"0380",()=>m.Memory[0x80]=(byte)~m.Memory[0x80]);yield return new NativeRoutineStep(0x5376,"8E038F",()=>x=0x38F);yield return new NativeRoutineStep(0x5379,"BF03A3",()=>m.WriteWord(0x3A3,x));
        yield return new NativeRoutineStep(0x537C,"E684",()=>b=m.Memory[x]);yield return new NativeRoutineStep(0x537E,"2B17");
        bool repeat=(sbyte)b<0;
        if(!repeat){yield return new NativeRoutineStep(0x5380,"CA80",()=>b|=0x80);yield return new NativeRoutineStep(0x5382,"E784",()=>m.Memory[x]=b);yield return new NativeRoutineStep(0x5384,"B603A5",()=>a=m.Memory[0x3A5]);yield return new NativeRoutineStep(0x5387,"270B");}
        else{yield return new NativeRoutineStep(0x5397,"B603A5",()=>a=m.Memory[0x3A5]);yield return new NativeRoutineStep(0x539A,"27F8");}
        if(a==0){yield return new NativeRoutineStep(0x5394,"0F7D",()=>m.Memory[0x7D]=0);yield return new NativeRoutineStep(0x5396,"39");yield break;}
        if(repeat){yield return new NativeRoutineStep(0x539C,"B703A6",()=>m.Memory[0x3A6]=a);yield return new NativeRoutineStep(0x539F,"39");yield break;}
        yield return new NativeRoutineStep(0x5389,"B703A6",()=>m.Memory[0x3A6]=a);yield return new NativeRoutineStep(0x538C,"4A",()=>a--);yield return new NativeRoutineStep(0x538D,"E686",()=>b=m.Memory[x+unchecked((sbyte)a)]);yield return new NativeRoutineStep(0x538F,"CB80",()=>b+=0x80);yield return new NativeRoutineStep(0x5391,"E786",()=>m.Memory[x+unchecked((sbyte)a)]=b);yield return new NativeRoutineStep(0x5393,"39");
    }
    private IEnumerable<NativeRoutineWork> Clear(bool busy){if(busy)yield return new NativeRoutineStep(0x53A9,"0F7D",()=>m.Memory[0x7D]=0);yield return new NativeRoutineStep(0x53AB,"0F80",()=>m.Memory[0x80]=0);yield return new NativeRoutineStep(0x53AD,"39");}
}
