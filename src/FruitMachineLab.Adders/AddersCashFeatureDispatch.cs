using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

public record CashFeatureSelection(byte BoardPosition,ushort Index,ushort Token);
public static class AddersCashFeatureDispatch
{
    // Executes the recovered DFF8..E0A1 selector, not a handwritten position map.
    // This is the pure board-position dispatch boundary, not full machine play.
    public static CashFeatureSelection Select(string evidence,byte boardPosition)
    {
        var machine=new Machine();machine.Memory[0xC9]=boardPosition;
        SkillCashData.LoadExtensions(machine,evidence);
        new ScriptExecutor(machine).RunRange(new(Path.Combine(evidence,"VM-SCRIPTS","DFF6.txt")),0xDFF8,0xE0A1);
        ushort index=machine.Pop();if(index>8 || machine.Data.Count!=0)throw new InvalidDataException("Cash feature selector left an invalid result");
        return new(boardPosition,index,machine.ReadWord(Cell.Add(0xDFD8,(ushort)(2*index))));
    }
}
