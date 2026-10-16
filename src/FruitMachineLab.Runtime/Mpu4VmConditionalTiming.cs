namespace FruitMachineLab.Runtime;

// Selected A6L native paths, chosen from pre-execution VM cells. These plans
// charge CPU work only. Captured IRQ service remains a separate Live adapter.
public static class Mpu4VmConditionalTiming
{
    public static int RequiredCells(ushort token) => token switch {
        0x7982 or 0x798C or 0x79A6 or 0x79B9 => 1,
        0x7A6F or 0x7ADC or 0x7AE7 => 2,
        _ => 0
    };

    public static bool SelectPath(ushort token,ushort top,ushort second) => token switch {
        0x7982 or 0x798C or 0x79A6 or 0x79B9 => top==0,
        0x7A6F => top==second,
        0x7ADC => (short)top<(short)second,
        0x7AE7 => (short)top<=(short)second,
        _ => throw new NotSupportedException($"No conditional timing for {token:X4}")
    };

    public static IReadOnlyList<(ushort Address,string Bytes)> Path(ushort token,bool selected)
    {
        (ushort,string)[] body=token switch {
            0x7982 or 0x798C when selected => [(0x7984,"ECC1"),(0x7986,"27F3"),(0x797B,"E6A4"),(0x797D,"4F"),(0x797E,"31AB"),(0x7980,"0EFC")],
            0x7982 or 0x798C => [(0x7984,"ECC1"),(0x7986,"27F3"),(0x7988,"3121"),(0x798A,"0EFC")],
            0x79A6 when selected => [(0x79A8,"ECC1"),(0x79AA,"27F0"),(0x799C,"E6A4"),(0x799E,"86FF"),(0x79A0,"31AB"),(0x79A2,"0EFC")],
            0x79A6 => [(0x79A8,"ECC1"),(0x79AA,"27F0"),(0x79AC,"3121"),(0x79AE,"0EFC")],
            0x79B9 when selected => [(0x79BB,"ECC1"),(0x79BD,"27F3"),(0x79B2,"10AEA4"),(0x79B5,"0EFC")],
            0x79B9 => [(0x79BB,"ECC1"),(0x79BD,"27F3"),(0x79BF,"3122"),(0x79C1,"0EFC")],
            0x7A6F when selected => [(0x7A71,"3706"),(0x7A73,"A3C4"),(0x7A75,"26C8"),(0x7A77,"20D3"),(0x7A4C,"CCFFFF"),(0x7A4F,"EDC4"),(0x7A51,"0EFC")],
            0x7A6F => [(0x7A71,"3706"),(0x7A73,"A3C4"),(0x7A75,"26C8"),(0x7A3F,"CC0000"),(0x7A42,"EDC4"),(0x7A44,"0EFC")],
            0x7ADC when selected => [(0x7ADE,"3706"),(0x7AE0,"10A3C4"),(0x7AE3,"2D0B"),(0x7AF0,"EDC4"),(0x7AF2,"0EFC")],
            0x7ADC => [(0x7ADE,"3706"),(0x7AE0,"10A3C4"),(0x7AE3,"2D0B"),(0x7AE5,"0EFC")],
            0x7AE7 when selected => [(0x7AE9,"3706"),(0x7AEB,"10A3C4"),(0x7AEE,"2FF5"),(0x7AE5,"0EFC")],
            0x7AE7 => [(0x7AE9,"3706"),(0x7AEB,"10A3C4"),(0x7AEE,"2FF5"),(0x7AF0,"EDC4"),(0x7AF2,"0EFC")],
            _ => throw new NotSupportedException($"No conditional timing for {token:X4}")
        };
        return new (ushort,string)[] {(0x00FC,"AEA1"),(0x00FE,"6E91")}.Concat(body).ToArray();
    }

    private static readonly Dictionary<(ushort,bool),ulong> Costs = new ushort[] {0x7982,0x798C,0x79A6,0x79B9,0x7A6F,0x7ADC,0x7AE7}
        .SelectMany(token=>new[] {false,true}.Select(selected=>(token,selected)))
        .ToDictionary(key=>key,key=>(ulong)Path(key.token,key.selected).Sum(i=>M6809InstructionTiming.Decode(Convert.FromHexString(i.Bytes)).Cycles));

    public static ulong Cycles(ushort token,ushort top,ushort second=0) => Costs[(token,SelectPath(token,top,second))];

    public static ulong? Cycles(ushort token,Stack<ushort> data)
    {
        int required=RequiredCells(token);if(required==0)return null;
        if(data.Count<required)throw new InvalidOperationException("VM data stack underflow while deriving conditional timing");
        using var cells=data.GetEnumerator();cells.MoveNext();ushort top=cells.Current,second=0;
        if(required==2){cells.MoveNext();second=cells.Current;}
        return Cycles(token,top,second);
    }
}
