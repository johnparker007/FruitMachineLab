using System.Text.Json;
using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public static class BoardLinkState
{
    // Trace-backed shapes at the two natural DBC4 entries. Do not decode
    // arbitrary native stack bytes as calls or loops.
    public static SoundContinuation? ResolveSoundContinuation(Machine m,ushort at)
    {
        ushort root=m.ReadWord(Cell.Add(at,0x13)),cursor=m.ReadWord(Cell.Add(at,8)),callback=m.ReadWord(Cell.Add(at,4));
        if((cursor!=0x971A || callback!=0x5E1F) && (cursor!=0x971C || callback!=0x5E29))return null;
        if(m.Memory[0x971A]!=0xCE || m.Memory[0x971B]!=0xFF || m.Memory[0x971C]!=0xC0)return null;
        if(root==0x9714 && m.ReadWord(Cell.Add(at,6))==Cell.Add(at,0x25))return new(callback,[]);
        if(root==0x971F && m.ReadWord(0x9728)==0xC197 && m.Memory[0x972A]==0x14 && m.Memory[0x972B]==0xC0 && m.ReadWord(Cell.Add(at,6))==Cell.Add(at,0x23) && m.ReadWord(Cell.Add(at,0x23))==0x972B)return new(callback,[0x972B]);
        return null;
    }
    public static void LoadData(Machine machine,string evidence)
    {
        using var nudge=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","nudge-preparation-data.json")));
        foreach(var range in nudge.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToUInt16(range.Name,16));
        using var availability=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","nudge-availability-data.json")));
        foreach(var range in availability.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToUInt16(range.Name,16));
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"maps","board-link-data.json")));
        foreach(var range in data.RootElement.GetProperty("ranges").EnumerateObject())Convert.FromHexString(range.Value.GetString()!).CopyTo(machine.Memory,Convert.ToUInt16(range.Name,16));
    }
    // Inherited output latch at the recovered E247 hardware entry. No recorded
    // output events are applied after this initialization. Full PIA modes remain out of scope.
    public static void LoadIc8Entry(Machine m,string evidence)
    {
        using var capture=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-ic8.json")));
        var entry=capture.RootElement.GetProperty("entry_io");
        if(m.ReadWord(0x204A)!=0xF02 || m.Memory[0x204C]!=255 || (entry[1].GetByte()&4)==0)throw new InvalidDataException("Unsupported IC8 entry configuration");
        m.Memory[0xF02]=entry[0].GetByte();m.Memory[0xF03]=entry[1].GetByte();
        using var status=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-status.json")));
        m.Memory[0xC02]=status.RootElement.GetProperty("entry_aux").GetByte();
        using var stake=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash","nudge-stake.json")));
        var config=Convert.FromHexString(stake.RootElement.GetProperty("config_entry_hex").GetString()!);
        // These are ROM configuration bytes. Verify the bounded observation
        // against byte-checked static data rather than substituting capture values.
        if(m.Memory[0x719A]!=config[0xA] || m.Memory[0x71A2]!=config[0x12])throw new InvalidDataException("Entry ROM configuration differs");
    }
    public static ushort Apply(Machine machine,string evidence,string kind,bool continuation=false,bool availability=false,bool nudgeEntry=false,bool nudgePrompt=false,bool nudgeRequest=false,bool nudgeMotion=false,bool nudgeReturn=false,bool nudgeSequence=false,bool nudgeResult=false,bool nudgeExit=false,bool nudgeWinTransfer=false,bool nudgeTail=false,bool nudgeAccounting=false,bool nudgeBankReturn=false,bool nudgeCycleInit=false,bool nudgeIc8=false,bool nudgeBackground=false,bool nudgeStatus=false,bool nudgeServices=false,bool nudgePreplay=false,bool nudgeEligibility=false,bool nudgeStart=false,bool nudgeStake=false,bool nudgeTone=false,bool nudgeSpinFlags=false,bool nudgeSpinGates=false,bool nudgeFinalSelection=false,bool nudgeSpinPreparation=false,bool nudgePaidSpin=false,bool nudgeSpinResult=false,bool nudgePaidNudge=false,bool nudgePaidStep=false,bool nudgePaidResult=false,bool nudgePaidReturn=false,bool nudgePaidNextPrompt=false,bool paidFlagAccounting=false,bool paidFlagAnnouncement=false,bool paidFlagReelPlan=false,bool paidFlagTable=false,bool paidFlagBootstrap=false)
    {
        if(kind is not ("ladder" or "snake"))throw new ArgumentException("Unknown board link kind",nameof(kind));
        BoardMovementState.Apply(machine,evidence);LoadData(machine,evidence);
        using var data=JsonDocument.Parse(File.ReadAllText(Path.Combine(evidence,"skill-cash",paidFlagBootstrap ? "paid-flag-bootstrap.json" : paidFlagTable ? "paid-flag-table.json" : paidFlagReelPlan ? "paid-flag-reel-plan.json" : paidFlagAnnouncement ? "paid-flag-announcement.json" : paidFlagAccounting ? "paid-flag-accounting.json" : nudgePaidNextPrompt ? "nudge-paid-next-prompt.json" : nudgePaidReturn ? "nudge-paid-return.json" : nudgePaidResult ? "nudge-paid-result.json" : nudgePaidStep ? "nudge-paid-step.json" : nudgePaidNudge ? "nudge-paid-nudge.json" : nudgeSpinResult ? "nudge-spin-result.json" : nudgePaidSpin ? "nudge-paid-spin.json" : nudgeSpinPreparation ? "nudge-spin-preparation.json" : nudgeFinalSelection ? "nudge-final-selection.json" : nudgeSpinGates ? "nudge-spin-gates.json" : nudgeSpinFlags ? "nudge-spin-flags.json" : nudgeTone ? "nudge-tone.json" : nudgeStake ? "nudge-stake.json" : nudgeStart ? "nudge-start.json" : nudgeEligibility ? "nudge-eligibility.json" : nudgePreplay ? "nudge-preplay.json" : nudgeServices ? "nudge-services.json" : nudgeStatus ? "nudge-status.json" : nudgeBackground ? "nudge-background.json" : nudgeIc8 ? "nudge-ic8.json" : nudgeCycleInit ? "nudge-cycle-init.json" : nudgeBankReturn ? "nudge-bank-return.json" : nudgeAccounting ? "nudge-accounting.json" : nudgeTail ? "nudge-tail.json" : nudgeWinTransfer ? "nudge-win-transfer.json" : nudgeExit ? "nudge-exit.json" : nudgeResult ? "nudge-result.json" : nudgeSequence ? "nudge-sequence.json" : nudgeReturn ? "nudge-return.json" : nudgeMotion ? "nudge-motion-vm.json" : nudgeRequest ? "nudge-request.json" : nudgePrompt ? "nudge-prompt.json" : nudgeEntry ? "nudge-entry.json" : availability ? "ladder-availability.json" : kind+"-link"+(continuation ? "-next" : "")+".json")));var root=data.RootElement;
        Convert.FromHexString(root.GetProperty("ram_hex").GetString()!).CopyTo(machine.Memory,0);
        ushort First(string key)=>Convert.ToUInt16(root.GetProperty("initial").GetProperty(key).GetString(),16);
        machine.Control=new(machine,First("s"));machine.DataStackBase=Cell.Add(First("u"),8);machine.SetDataPointer(First("u"));
        machine.WriteWord(0x719F,First("opt"));machine.WriteWord(0x719B,First("abort"));return First("clock");
    }
}
