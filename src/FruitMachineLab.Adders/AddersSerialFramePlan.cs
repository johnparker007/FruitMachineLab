using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Selected positive one-byte51B1 queue->frame. Negative messages/manufacturer
// packets and enabled5744 callback remain explicit boundaries.
public sealed class AddersSerialFramePlan(Machine m,ushort stack,ushort initialX,byte initialA,byte initialB)
{
    private ushort s=stack,x=initialX;private byte a=initialA,b=initialB;private bool zero;
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        yield return new NativeRoutineStep(0x51B1,"3416",()=>{s-=4;m.WriteWord(s,(ushort)((a<<8)|b));m.WriteWord((ushort)(s+2),x);});
        yield return new NativeRoutineStep(0x51B3,"0D84",()=>zero=m.Memory[0x84]==0);yield return new NativeRoutineStep(0x51B5,"102700C9",Branch:zero);if(zero){foreach(var op in End())yield return op;yield break;}
        yield return new NativeRoutineStep(0x51B9,"B603DA",()=>a=m.Memory[0x3DA]);yield return new NativeRoutineStep(0x51BC,"260C");
        if(a==0){yield return new NativeRoutineStep(0x51BE,"8E03A8",()=>x=0x3A8);yield return new NativeRoutineStep(0x51C1,"BF03D8",()=>m.WriteWord(0x3D8,x));yield return new NativeRoutineStep(0x51C4,"BF03D6",()=>m.WriteWord(0x3D6,x));yield return new NativeRoutineStep(0x51C7,"1600B8");foreach(var op in End())yield return op;yield break;}
        yield return new NativeRoutineStep(0x51CA,"7D03A5",()=>zero=m.Memory[0x3A5]==0);yield return new NativeRoutineStep(0x51CD,"102600B1",Branch:!zero);if(!zero){foreach(var op in End())yield return op;yield break;}
        yield return new NativeRoutineStep(0x51D1,"BE03D6",()=>x=m.ReadWord(0x3D6));yield return new NativeRoutineStep(0x51D4,"8C03A8");yield return new NativeRoutineStep(0x51D7,"2505");
        bool valid=x>=0x3A8;if(valid){yield return new NativeRoutineStep(0x51D9,"8C03D6");yield return new NativeRoutineStep(0x51DC,"2503");valid=x<0x3D6;}if(!valid)yield return new NativeRoutineStep(0x51DE,"8E03A8",()=>x=0x3A8);
        yield return new NativeRoutineStep(0x51E1,"E680",()=>{b=m.Memory[x];x++;});yield return new NativeRoutineStep(0x51E3,"2A23");if((sbyte)b<0)throw new NotSupportedException("Serial negative queue message needs two-byte handling");
        yield return new NativeRoutineStep(0x5208,"7A03DA",()=>m.Memory[0x3DA]--);yield return new NativeRoutineStep(0x520B,"3404",()=>{s--;m.Memory[s]=b;});yield return new NativeRoutineStep(0x520D,"50",()=>b=unchecked((byte)-b));yield return new NativeRoutineStep(0x520E,"FB03DB",()=>b+=m.Memory[0x3DB]);yield return new NativeRoutineStep(0x5211,"F703DB",()=>m.Memory[0x3DB]=b);yield return new NativeRoutineStep(0x5214,"3504",()=>{b=m.Memory[s];s++;});yield return new NativeRoutineStep(0x5216,"BF03D6",()=>m.WriteWord(0x3D6,x));
        yield return new NativeRoutineStep(0x5219,"C12D",()=>zero=b==0x2D);yield return new NativeRoutineStep(0x521B,"2609");
        bool modeChange=false;
        if(zero){yield return new NativeRoutineStep(0x521D,"86FF",()=>a=255);yield return new NativeRoutineStep(0x521F,"B10323",()=>zero=a==m.Memory[0x323]);yield return new NativeRoutineStep(0x5222,"260C");modeChange=!zero;if(zero)yield return new NativeRoutineStep(0x5224,"2019");}
        else{yield return new NativeRoutineStep(0x5226,"C12E",()=>zero=b==0x2E);yield return new NativeRoutineStep(0x5228,"2615");if(zero){yield return new NativeRoutineStep(0x522A,"4F",()=>a=0);yield return new NativeRoutineStep(0x522B,"B10323",()=>zero=a==m.Memory[0x323]);yield return new NativeRoutineStep(0x522E,"270F");modeChange=!zero;}}
        if(modeChange){
            yield return new NativeRoutineStep(0x5230,"0F73",()=>m.Memory[0x73]=0);yield return new NativeRoutineStep(0x5232,"7D0323",()=>zero=(sbyte)m.Memory[0x323]>=0);yield return new NativeRoutineStep(0x5235,"2B04");
            if(zero){yield return new NativeRoutineStep(0x5237,"C62E",()=>b=0x2E);yield return new NativeRoutineStep(0x5239,"2014");}else{yield return new NativeRoutineStep(0x523B,"C62D",()=>b=0x2D);yield return new NativeRoutineStep(0x523D,"2010");}
        }else{
            yield return new NativeRoutineStep(0x523F,"7F0073",()=>m.Memory[0x73]=0);yield return new NativeRoutineStep(0x5242,"7DFF44",()=>zero=m.Memory[0xFF44]==0);yield return new NativeRoutineStep(0x5245,"2608");
            if(zero){yield return new NativeRoutineStep(0x5247,"7D0323",()=>zero=(sbyte)m.Memory[0x323]>=0);yield return new NativeRoutineStep(0x524A,"2B03");if(zero)yield return new NativeRoutineStep(0x524C,"730073",()=>m.Memory[0x73]=(byte)~m.Memory[0x73]);}
        }
        yield return new NativeRoutineStep(0x524F,"860D",()=>a=13);yield return new NativeRoutineStep(0x5251,"B7038E",()=>m.Memory[0x38E]=a);yield return new NativeRoutineStep(0x5254,"7D038D",()=>zero=m.Memory[0x38D]==0);yield return new NativeRoutineStep(0x5257,"270C");
        if(!zero){yield return new NativeRoutineStep(0x5259,"7F038D",()=>m.Memory[0x38D]=0);yield return new NativeRoutineStep(0x525C,"BE6917",()=>x=m.ReadWord(0x6917));yield return new NativeRoutineStep(0x525F,"BF038B",()=>m.WriteWord(0x38B,x));yield return new NativeRoutineStep(0x5262,"BF0389",()=>m.WriteWord(0x389,x));}
        yield return new NativeRoutineStep(0x5265,"BD5744",()=>{s-=2;m.WriteWord(s,0x5268);});yield return new NativeRoutineStep(0x5744,"3410",()=>{s-=2;m.WriteWord(s,x);});yield return new NativeRoutineStep(0x5746,"7D719A",()=>zero=m.Memory[0x719A]==0);yield return new NativeRoutineStep(0x5749,"2707");
        if(!zero){yield return new NativeRoutineStep(0x574B,"BE00A3",()=>x=m.ReadWord(0xA3));yield return new NativeRoutineStep(0x574E,"2702");if(x!=0)throw new NotSupportedException("Serial5744 hook needs explicit native callback owner");}
        yield return new NativeRoutineStep(0x5752,"3590",()=>{x=m.ReadWord(s);s+=4;});
        yield return new NativeRoutineStep(0x5268,"8E038F",()=>x=0x38F);yield return new NativeRoutineStep(0x526B,"BF03A3",()=>m.WriteWord(0x3A3,x));yield return new NativeRoutineStep(0x526E,"E780",()=>{m.Memory[x]=b;x++;});yield return new NativeRoutineStep(0x5270,"7C03A5",()=>m.Memory[0x3A5]++);yield return new NativeRoutineStep(0x5273,"7C03A6",()=>m.Memory[0x3A6]++);yield return new NativeRoutineStep(0x5276,"C160");yield return new NativeRoutineStep(0x5278,"240A");
        if(b>=0x60)throw new NotSupportedException("Serial extended packet requires payload recovery");
        yield return new NativeRoutineStep(0x527A,"E780",()=>{m.Memory[x]=b;x++;});yield return new NativeRoutineStep(0x527C,"7C03A5",()=>m.Memory[0x3A5]++);yield return new NativeRoutineStep(0x527F,"7C03A6",()=>m.Memory[0x3A6]++);foreach(var op in End())yield return op;
    }
    private static IEnumerable<NativeRoutineWork> End(){yield return new NativeRoutineStep(0x5282,"3596");}
}
