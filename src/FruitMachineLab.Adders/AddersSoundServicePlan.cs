using FruitMachineLab.Runtime;

namespace FruitMachineLab.Adders;

// Bounded native5CD0 service and C0 return. Other sound commands remain explicit
// boundaries; this is not a replacement for the full choice-stream scheduler.
public sealed class AddersSoundServicePlan(Machine m,ushort stack,ushort initialU,ushort initialX,ushort initialY,ushort entry=0x5CD0,Action<byte,byte>? ymWrite=null)
{
    private ushort s=stack,u=initialU,x=initialX,y=initialY,clock;
    private byte command;
    private bool zero;
    public int CompletedTasks {get;private set;}
    public IEnumerable<NativeRoutineWork> Instructions()
    {
        if(entry is not (0x5CD0 or 0x5E6D))throw new NotSupportedException("Unrecovered sound service entry");
        if(entry==0x5CD0){
            yield return new NativeRoutineStep(0x5CD0,"9644",()=>zero=m.Memory[0x44]==0);
            yield return new NativeRoutineStep(0x5CD2,"2666");
            if(!zero){yield return new NativeRoutineStep(0x5D3A,"39");yield break;}
            yield return new NativeRoutineStep(0x5CD4,"0C44",()=>m.Memory[0x44]++);
            yield return new NativeRoutineStep(0x5CD6,"0F2C",()=>m.Memory[0x2C]=0);
            yield return new NativeRoutineStep(0x5CD8,"0C46",()=>{m.Memory[0x46]++;zero=m.Memory[0x46]==0;});
            yield return new NativeRoutineStep(0x5CDA,"2602");
            if(zero)yield return new NativeRoutineStep(0x5CDC,"0C45",()=>m.Memory[0x45]++);
        }
        bool root=entry==0x5E6D;int budget=10000;
        while(--budget>0){
            if(!root){
                yield return new NativeRoutineStep(0x5CDE,"109E47",()=>y=m.ReadWord(0x47));
                yield return new NativeRoutineStep(0x5CE1,"2755");if(y==0)break;
                AddersSoundLifecycleMemory.ValidateTask(y);
                yield return new NativeRoutineStep(0x5CE3,"DC45",()=>clock=m.ReadWord(0x45));
                yield return new NativeRoutineStep(0x5CE5,"10A322",()=>zero=clock==m.ReadWord((ushort)(y+2)));
                yield return new NativeRoutineStep(0x5CE8,"264E");if(!zero)break;
                yield return new NativeRoutineStep(0x5CEA,"AEA4",()=>x=m.ReadWord(y));
                yield return new NativeRoutineStep(0x5CEC,"9F47",()=>m.WriteWord(0x47,x));
                yield return new NativeRoutineStep(0x5CEE,"EE28",()=>u=m.ReadWord((ushort)(y+8)));
                yield return new NativeRoutineStep(0x5CF0,"6EB804");
                if(m.ReadWord((ushort)(y+4))!=0x5D3B)throw new NotSupportedException("Unrecovered native sound callback");
            }
            bool rescan=false;
            while(!rescan){
                if(!root){
                    yield return new NativeRoutineStep(0x5D3B,"E6C0",()=>{command=m.Memory[u];u++;});
                    yield return new NativeRoutineStep(0x5D3D,"C1C0");
                    yield return new NativeRoutineStep(0x5D3F,"2507");
                    if(command<0xC0)throw new NotSupportedException($"Native sound note at{u-1:X4} needs channel acquisition");
                    yield return new NativeRoutineStep(0x5D41,"8E5963",()=>x=0x5963);
                    yield return new NativeRoutineStep(0x5D44,"3A",()=>x+=command);
                    yield return new NativeRoutineStep(0x5D45,"3A",()=>x+=command);
                    yield return new NativeRoutineStep(0x5D46,"6E94");
                    if(command!=0xC0 || m.ReadWord(x)!=0x5E6D)throw new NotSupportedException($"Unrecovered native sound command{command:X2} target{m.ReadWord(x):X4}");
                }
                root=false;
                AddersSoundLifecycleMemory.ValidateTask(y);
                yield return new NativeRoutineStep(0x5E6D,"8DBD",()=>{s-=2;m.WriteWord(s,0x5E6F);});
                foreach(var op in new AddersSoundReleasePlan(m,y,s,u,x,ymWrite).Instructions())yield return op;
                s+=2;x=0x27E; //5E2C preserves U and returns X=27E, then pops its return.
                yield return new NativeRoutineStep(0x5E6F,"30A823",()=>x=(ushort)(y+0x23));
                yield return new NativeRoutineStep(0x5E72,"AC26",()=>zero=x<m.ReadWord((ushort)(y+6)));
                yield return new NativeRoutineStep(0x5E74,"250F");
                if(!zero){
                    ushort frame=m.ReadWord((ushort)(y+6));
                    if(frame<y+0x15 || frame>y+0x23 || ((y+0x25-frame)&1)!=0)throw new NotSupportedException("Unrecovered native sound return frame");
                    yield return new NativeRoutineStep(0x5E76,"AE26",()=>x=m.ReadWord((ushort)(y+6)));
                    yield return new NativeRoutineStep(0x5E78,"EE81",()=>{u=m.ReadWord(x);x+=2;});
                    yield return new NativeRoutineStep(0x5E7A,"AF26",()=>m.WriteWord((ushort)(y+6),x));
                    yield return new NativeRoutineStep(0x5E7C,"7E5D3B");
                }else{
                    if(m.ReadWord((ushort)(y+6))!=y+0x25)throw new NotSupportedException("Unrecovered empty sound stack pointer");
                    yield return new NativeRoutineStep(0x5E85,"9E49",()=>x=m.ReadWord(0x49));
                    yield return new NativeRoutineStep(0x5E87,"AFA4",()=>m.WriteWord(y,x));
                    yield return new NativeRoutineStep(0x5E89,"109F49",()=>{m.WriteWord(0x49,y);CompletedTasks++;});
                    yield return new NativeRoutineStep(0x5E8C,"7E5CDE");rescan=true;
                }
            }
        }
        if(budget==0)throw new InvalidDataException("Native sound service failed to yield");
        yield return new NativeRoutineStep(0x5D38,"0A44",()=>m.Memory[0x44]--);
        yield return new NativeRoutineStep(0x5D3A,"39");
    }
}
