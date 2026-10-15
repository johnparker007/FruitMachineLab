namespace FruitMachineLab.Runtime;

public static class Mpu4Arithmetic
{
    // 7C08: sign magnitudes, native unsigned divider, then complement quotient
    // on opposite signs with a remainder (floor rather than host truncation).
    public static (ushort Quotient,ushort Remainder) SignedDivideDouble(ushort low,ushort high,ushort divisor)
    {
        bool opposite=((high^divisor)&0x8000)!=0;
        uint numerator=((uint)high<<16)|low;if((high&0x8000)!=0)numerator=unchecked(0u-numerator);
        ushort magnitude=(divisor&0x8000)!=0 ? Cell.Subtract(0,divisor) : divisor;
        var result=DivideDouble((ushort)numerator,(ushort)(numerator>>16),magnitude);
        if(!opposite)return result;
        return result.Remainder==0 ? (Cell.Subtract(0,result.Quotient),(ushort)0) : ((ushort)~result.Quotient,Cell.Subtract(magnitude,result.Remainder));
    }
    // 1BA7 signs both 32-bit operands, calls 1C00, then negates the quotient
    // when signs differ. 1B93 discards the remainder. A zero divisor returns zero.
    public static uint SignedDoubleQuotient(uint numerator,uint divisor)
    {
        bool negative=((numerator^divisor)&0x80000000u)!=0;
        uint Magnitude(uint value)=>(value&0x80000000u)!=0 ? unchecked(0u-value) : value;
        var denominator=Magnitude(divisor);
        var quotient=denominator==0 ? 0u : Magnitude(numerator)/denominator;
        return negative ? unchecked(0u-quotient) : quotient;
    }
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
