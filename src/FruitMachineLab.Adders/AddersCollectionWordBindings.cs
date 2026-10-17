using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Shared semantic bindings for both collection hosts. Sound-list mismatch is a
// real recovery boundary; neither host may fabricate a nonzero native head.
public sealed class AddersCollectionWordBindings(Machine machine,Action<LampRequest> lampOutput,
    Mpu4Alpha alpha,Mpu4ChoiceStreamScheduler scheduler,Action<byte,byte>? ymWrite=null)
{
    private readonly Mpu4LampRequests lamps=new(machine,lampOutput);
    public bool Handle(Instruction instruction,Machine m)
    {
        if(instruction.Token==0x856F){bool nativeActive=m.ReadWord(0x47)!=0;if(nativeActive!=scheduler.Active)throw new NotSupportedException("Collect prompt native sound list differs from logical scheduler; background pool lifecycle requires recovery");m.Data.Push(Cell.Flag(!nativeActive));return true;}
        if(instruction.Native==0x5C18){ushort stream=m.Pop();if(AddersSoundQueueMemory.Queue(m,stream) && !scheduler.Queue(stream))throw new InvalidOperationException("Sound queue memory and scheduler disagree");return true;}
        bool handled=AddersNativeWords.Handle(instruction,m,lamps,scheduler,alpha);if(handled && instruction.Native==0x5B77)AddersSoundResetMemory.Apply(m,ymWrite);return handled;
    }
}
