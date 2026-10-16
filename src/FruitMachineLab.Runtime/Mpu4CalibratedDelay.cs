namespace FruitMachineLab.Runtime;

// A6L native7159/7164, enabled719B gate only. Counts CPU work, excluding
// interrupts. The ROM's byte decrement deliberately makes B=0 repeat256 times.
public static class Mpu4CalibratedDelay
{
    private static ulong Cost(string bytes)=>(ulong)M6809InstructionTiming.Decode(Convert.FromHexString(bytes)).Cycles;
    public static ulong SinglePassCycles {get;}=Cost("3404")+Cost("C628")+
        40*(Cost("8654")+84*(Cost("4A")+Cost("26FD"))+Cost("5A")+Cost("26F8"))+Cost("3584");
    private static readonly ulong EnabledGateCycles=Cost("3404")+Cost("F6719B")+Cost("C580")+Cost("2602")+Cost("3584");
    public static ulong RepeatCycles(byte count)
    {
        ulong repetitions=count==0 ? 256UL : count;
        return Cost("8D2F")+EnabledGateCycles+Cost("3406")+
            repetitions*(Cost("8D05")+SinglePassCycles+Cost("5A")+Cost("26FB"))+Cost("3586");
    }
    // Native5A05 LDB1,S; JSR7159; the fixed5A14 wrapper supplied B=2.
    public static ulong StartToneWaitCycles {get;}=Cost("E661")+Cost("BD7159")+RepeatCycles(2);
}
