using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Native5A14 ->59FF/59D9: no VM cells consumed. YM synthesis is outside this model.
public static class AddersTimedTone
{
    public static void Begin(Machine m,Mpu4ChoiceStreamScheduler scheduler)
    {
        m.Memory[0x4D]=0x31; // 91-60 is nonnegative in native byte arithmetic.
        scheduler.Queue(0x59EB);
    }
    public static void End(Machine m,Mpu4ChoiceStreamScheduler scheduler)
    {
        scheduler.Cancel(0x59EB);m.Memory[0x4D]=0;
    }
}
