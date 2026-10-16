namespace FruitMachineLab.Runtime;

// Selected A6L VM paths from NEXT at RAM00FC to the following NEXT boundary.
// RAM NEXT bytes are trace-backed; native bodies are ROM-byte checked. IRQ work
// is deliberately excluded. This is timing for translated words, not a CPU emulator.
public static class Mpu4VmPrimitiveTiming
{
    private static readonly IReadOnlyDictionary<ushort,ulong> Costs=new ushort[] {0x78B5,0x795B,0x7963,0x792F}
        .ToDictionary(token=>token,token=>(ulong)Path(token)!.Sum(i=>M6809InstructionTiming.Decode(Convert.FromHexString(i.Bytes)).Cycles));
    public static IReadOnlyList<(ushort Address,string Bytes)>? Path(ushort token) => token switch
    {
        0x78B5 => [(0x00FC,"AEA1"),(0x00FE,"6E91"),(0x78B7,"CC0000"),(0x78BA,"3606"),(0x78BC,"0EFC")],
        0x795B => [(0x00FC,"AEA1"),(0x00FE,"6E91"),(0x795D,"ECA1"),(0x795F,"3606"),(0x7961,"0EFC")],
        0x7963 => [(0x00FC,"AEA1"),(0x00FE,"6E91"),(0x7965,"4F"),(0x7966,"E6A0"),(0x7968,"3606"),(0x796A,"0EFC")],
        0x792F => [(0x00FC,"AEA1"),(0x00FE,"6E91"),(0x7931,"3520"),(0x7933,"0EFC")],
        _ => null
    };

    public static ulong? Cycles(ushort token)
    {
        return Costs.TryGetValue(token,out var cost) ? cost : null;
    }
}
