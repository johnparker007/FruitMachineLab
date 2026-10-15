namespace FruitMachineLab.Runtime;

public static class Mpu4Memory
{
    // Native 7B8B chooses direction by unsigned source/destination comparison.
    // Preserve that choice, including 16-bit address wrap; do not replace with
    // host memmove semantics that could change wraparound overlap behaviour.
    public static void Move(Machine m,ushort source,ushort destination,ushort count)
    {
        if(source>=destination)for(int n=0;n<count;n++)m.Memory[Cell.Add(destination,(ushort)n)]=m.Memory[Cell.Add(source,(ushort)n)];
        else for(int n=count-1;n>=0;n--)m.Memory[Cell.Add(destination,(ushort)n)]=m.Memory[Cell.Add(source,(ushort)n)];
    }
}
