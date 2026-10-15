// SPDX-License-Identifier: BSD-3-Clause
// Phase/optic translation derived from MAME mame0281 steppers.cpp,
// copyright James Wallace. See THIRD-PARTY-NOTICES.md.
namespace FruitMachineLab.Runtime;

public sealed class BarcrestStepper
{
    public int Position {get;private set;}
    public int Phase {get;private set;}
    public byte Pattern {get;private set;}
    private readonly int indexStart,indexEnd;
    public bool Optic=>indexStart>indexEnd ? Position>indexStart || Position<indexEnd : Position>indexStart && Position<indexEnd;
    // Explicit externally verified feature-entry seed, not machine startup.
    public BarcrestStepper(int position,int phase,byte pattern,int indexStart,int indexEnd)
    {
        if(position is <0 or >=96 || phase is <0 or >7 || pattern>15)throw new ArgumentOutOfRangeException(nameof(position));
        if(indexStart is <0 or >96 || indexEnd is <0 or >96)throw new ArgumentOutOfRangeException(nameof(indexStart));
        Position=position;Phase=phase;Pattern=pattern;this.indexStart=indexStart;this.indexEnd=indexEnd;
    }
    public void Drive(byte pattern)
    {
        int phase=pattern switch {
            1=>7,3=>6,2=>5,6=>4,4=>3,12=>2,8=>1,9=>0,
            5=>Phase is 6 or 0 ? 7 : 3,10=>Phase is 6 or 4 ? 5 : 1,_=>Phase
        };
        int steps=Phase-phase;if(steps< -4)steps+=8;if(steps>4)steps-=8;
        Position=(Position+steps+96)%96;Phase=phase;Pattern=pattern;
    }
}
