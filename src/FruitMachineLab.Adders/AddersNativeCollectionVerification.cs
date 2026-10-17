using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class AddersNativeCollectionVerification
{
    public static int PromptAndCollect(string evidence,bool timed)
    {
        var m=new Machine{DataStackBase=0x600};m.Control=new(m,0x784);SkillCashData.LoadFeature(m);SkillCashData.LoadAlpha(m);AddersPayoutCallerData.Load(m,evidence);
        using(var d=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"collection","sound-prompt.json"))))foreach(var r in d.RootElement.GetProperty("rom_regions").EnumerateArray())Convert.FromHexString(r.GetProperty("bytes_hex").GetString()!).CopyTo(m.Memory,r.GetProperty("address").GetInt32());
        Convert.FromHexString("34203184AEA16E91").CopyTo(m.Memory,0xF8);m.Memory[0x55]=0x1F;m.WriteWord(0x2FC,24);
        var sound=new AddersNativeSound(m);sound.Reset();var logical=new Mpu4ChoiceStreamScheduler(m,0);var panel=new Mpu4PanelInput(m);byte port=0x30;int edges=0,total=0;ulong cycle=0;
        int Poll(){m.Control.Push(0xBEEF);int polls=0;
            if(timed){using var e=new AddersTimedCollectionExecution(m,evidence,0xAAA1,cycle,_=>{},new(m),logical,(_,_)=>10,(_,_)=>1000,()=>port,v=>{port=v;edges++;},0,_=>{},nativeSound:sound);
                int budget=1000000;while(!e.Completed && --budget>0){if(e.Address==0x717C && (++polls&1)!=0)m.Memory[0x6E]++;e.AdvanceTo(e.NextEventCycle);}if(!e.Completed)throw new InvalidDataException("Native collection timed poll did not finish");cycle=e.Cycle;total+=e.Debits;
            }else{var e=new AddersCollectionExecution(m,evidence,0xAAA1,_=>{},new(m),logical,()=>port,v=>{port=v;edges++;},nativeSound:sound);int budget=1000000;while(!e.Completed && --budget>0){if(e.Waiting)m.Memory[0x6E]++;e.Step();}if(!e.Completed)throw new InvalidDataException("Native collection poll did not finish");total+=e.Debits;}
            if(m.Control.Pointer!=0x784 || m.Data.Count!=0 || logical.Active)throw new InvalidDataException("Native collection leaked VM/logical sound state");return total;
        }
        panel.Release();panel.Sample(3);Poll();if(!sound.Active)throw new InvalidDataException("Collection did not queue actual prompt");ushort head=m.ReadWord(0x47);Poll();if(head!=m.ReadWord(0x47))throw new InvalidDataException("Collection restarted an active prompt");
        for(int tick=0;sound.Active && tick<2000;tick++){
            // Explicit diagnostic service boundary, NOT an invented machine period.
            sound.BeginService(Math.Max(cycle,sound.Cycle),0x500,0x600,0x8784,0x1A0,true);while(sound.Servicing)sound.AdvanceTo(sound.NextEventCycle);cycle=sound.Cycle;
        }
        if(sound.Active || sound.CompletedTasks!=4)throw new InvalidDataException("Collection prompt did not drain four tasks");
        Poll();if(!sound.Active)throw new InvalidDataException("Collection did not requeue completed prompt");
        panel.SetCollect(true);Poll();if(total!=0)throw new InvalidDataException("Unsampled Collect paid");panel.Sample(3);
        int attempts=0;while(m.ReadWord(0x2FC)+m.ReadWord(0x2FE)+m.ReadWord(0x300)+m.ReadWord(0x302)!=0 && ++attempts<10)Poll();
        if(total!=4 || edges!=8 || sound.Active || m.ReadWord(0x47)!=0 || port!=0x30)throw new InvalidDataException($"Collection transition differs: debits{total}, edges{edges}, sound{sound.Active}, port{port:X2}, balances{m.ReadWord(0x2FC)}/{m.ReadWord(0x2FE)}/{m.ReadWord(0x300)}/{m.ReadWord(0x302)}");
        panel.Release();panel.Sample(3);Poll();if(total!=4 || sound.Active)throw new InvalidDataException("Released Collect repeated payout");return total;
    }
}
