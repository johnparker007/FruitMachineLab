namespace FruitMachineLab.Runtime;

// Address ownership comes from decoded listings, not guessed body lengths.
public sealed class RecoveredScriptCatalog
{
    private readonly Dictionary<ushort,RecoveredScript> owners=new();
    public RecoveredScriptCatalog(string directory)
    {
        foreach(string path in Directory.EnumerateFiles(directory,"*.txt").Order()) {
            if(!ushort.TryParse(Path.GetFileNameWithoutExtension(path),System.Globalization.NumberStyles.HexNumber,null,out _))continue;
            var script=new RecoveredScript(path);
            foreach(var instruction in script.Instructions)
                if(!owners.TryAdd(instruction.Site,script))throw new InvalidDataException($"Ambiguous recovered address {instruction.Site:X4}");
        }
    }
    public RecoveredScript Owner(ushort address)=>owners.TryGetValue(address,out var script) ? script : throw new NotSupportedException($"Unrecovered continuation {address:X4}");
}
