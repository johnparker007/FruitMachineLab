using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Shared translated feature peripherals. 856F is a lifted zero-test of the
// active native list, not a fabricated emulated allocator/head pointer.
public static class AddersNativeWords
{
    public static bool Handle(Instruction instruction,Machine state,Mpu4LampRequests lamps,Mpu4ChoiceStreamScheduler scheduler,Mpu4Alpha alpha,Action? alphaChanged=null)
    {
        if(lamps.HandleWord(instruction))return true;
        if(instruction.Native==0x57DB){AddersStakeAccounting.Increment(state,state.Pop());return true;}
        if(instruction.Native==0x3AFA){AddersStakeAccounting.Decay(state);return true;}
        if(instruction.Native==0x14EB){AddersStakeAccounting.SubtractConfigured(state,state.Pop());return true;}
        if(instruction.Native==0x171D){lamps.ExecuteStream(0x1720);return true;}
        if(instruction.Native==0x2C5E){for(int n=0;n<9;n++)lamps.Set(state.Memory[0x732C+n],0x8F,0x49C5);return true;}
        if(instruction.Native==0x68F1){AddersBackgroundServices.VerifyCharacteriser(state,x=>AddersBackgroundServices.Mame6809CompatibilityResponse(state,x));return true;}
        if(instruction.Native==0x6EF7){AddersBackgroundServices.RefreshDoor(state);return true;}
        if(instruction.Native==0x6E99){AddersBackgroundServices.CheckNvram(state);return true;}
        if(instruction.Native==0x2E53){AddersBackgroundServices.CheckTestGate(state);return true;}
        if(instruction.Native==0x482F){AddersStatusService.Refresh(state,lamps);return true;}
        if(instruction.Native==0x4C34)return true; // Byte-checked RTS compatibility entry.
        // Native5429's idle branch is exactly TST7D; LBEQ53AD (RTS).
        // Busy serial processing has hardware/timing effects not yet translated.
        if(instruction.Native==0x5429){if(state.Memory[0x7D]!=0)throw new NotSupportedException("Native5429 busy serial transfer requires hardware recovery");return true;}
        if(instruction.Native is 0x1622 or 0x166D){AddersAwardStatistics.Execute(state,instruction.Native==0x1622);return true;}
        if(instruction.Native==0x151F){ushort selector=state.Pop();AddersAwardStatistics.AddScaled(state,state.Pop(),selector);return true;}
        if(instruction.Native==0x6F57){AddersAwardStatistics.RefreshAccounting(state);return true;}
        if(instruction.Native==0x1AA3){AddersNudgeAvailability.PushMatchingResult(state);return true;}
        if(instruction.Native==0x29EC){AddersNudgeAvailability.ExecuteFlagged(state);return true;}
        if(instruction.Native==0x29F4){AddersNudgeAvailability.Execute(state);return true;}
        if(instruction.Native==0x2A2F){AddersNudgeAvailability.PushMovementPlan(state);return true;}
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
