using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Shared translated feature peripherals. 856F is a lifted zero-test of the
// active native list, not a fabricated emulated allocator/head pointer.
public static class AddersNativeWords
{
    public static bool Handle(Instruction instruction,Machine state,Mpu4LampRequests lamps,Mpu4ChoiceStreamScheduler scheduler,Mpu4Alpha alpha,Action? alphaChanged=null)
    {
        if(lamps.HandleWord(instruction))return true;
        if(instruction.Native==0x169B){state.Data.Push(AddersParameterProfiles.Compute(state,state.Pop()));return true;}
        if(instruction.Native==0x2C12){AddersReelSymbols.Refresh(state);return true;}
        if(instruction.Native==0x2BEB){AddersReelSymbols.RefreshWithoutRequests(state);return true;}
        if(instruction.Operation=="vm_execute_lamp_stream"){lamps.ExecuteStream(Cell.Add(instruction.Site,2));return true;}
        if(instruction.Token==0x856F){state.Data.Push(Cell.Flag(!scheduler.Active));return true;}
        if(instruction.Native==0x5C18)return scheduler.Queue(state.Pop());
        if(instruction.Native==0x5B77)return scheduler.Reset();
        if(instruction.Native==0x5CCB){if(scheduler.Active)throw new InvalidOperationException("Native scheduler wait resumed too soon");return true;}
        if(instruction.Native is 0x3D0E or 0x3CC0 or 0x3CF7 || instruction.Operation=="vm_execute_alpha_stream") {
            if(instruction.Native==0x3D0E)alpha.Reset();else if(instruction.Native==0x3CC0)alpha.Execute(state.Pop());else if(instruction.Native==0x3CF7){if(!alpha.Resume())return true;}else alpha.Execute(Cell.Add(instruction.Site,2));
            alphaChanged?.Invoke();return true;
        }
        return false;
    }
}
