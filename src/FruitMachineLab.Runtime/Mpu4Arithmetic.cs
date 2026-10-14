namespace FruitMachineLab.Runtime;

public static class Mpu4Arithmetic
{
    // 7C56..7C77: sixteen shifts/subtractions, including its native zero/overflow
    // behaviour. Do not replace with checked host division or saturate the result.
    public static (ushort Quotient, ushort Remainder) DivideDouble(ushort low, ushort high, ushort divisor)
    {
        ushort quotient=low, remainder=high;
        for(var bit=0;bit<16;bit++)
        {
            var carry=(remainder&0x8000)!=0;
            remainder=unchecked((ushort)((remainder<<1)|(quotient>>15)));
            quotient=unchecked((ushort)(quotient<<1));
            if(carry || remainder>=divisor)
            {
                remainder=unchecked((ushort)(remainder-divisor));
                quotient|=1;
            }
        }
        return (quotient,remainder);
    }
}
