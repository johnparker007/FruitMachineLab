namespace FruitMachineLab.Runtime;

// Selected70EF protocol only. It does not model timer1/2, CPU delivery or infer
// a phase at rearm. The phase clock continues from its explicit entry seed.
public sealed class Mpu4Timer3ArmHardware(Mpu4Timer3PhaseClock timer,Func<ulong,decimal> time)
{
    private int stage;
    private byte msb;
    public void Access(OutputScanAccess access)
    {
        if(!access.Hardware || access.Address is not (0x900 or 0x901 or 0x906 or 0x907))return;
        ushort address=access.Address;
        if(stage==0 && address==0x901 && !access.Write){timer.AdvanceTo(time(access.Cycle));timer.ReadStatus();stage++;return;}
        if(stage==1 && address==0x906 && !access.Write){timer.AdvanceTo(time(access.Cycle));timer.ReadCounterMsb();stage++;return;}
        if(stage==2 && address==0x901 && access.Write && access.Value.HasValue && (access.Value.Value&0x41)==0){timer.AdvanceTo(time(access.Cycle));stage++;return;}
        if(stage==3 && address==0x900 && access.Write && access.Value==0x63){timer.AdvanceTo(time(access.Cycle));timer.WriteControl(0x63);stage++;return;}
        if(stage==4 && address==0x906 && access.Write && access.Value<=255){timer.AdvanceTo(time(access.Cycle));msb=(byte)access.Value.Value;stage++;return;}
        if(stage==5 && address==0x907 && access.Write && access.Value<=255){timer.AdvanceTo(time(access.Cycle));timer.WriteLatch((ushort)((msb<<8)|access.Value.Value));stage=0;return;}
        throw new NotSupportedException("Outside selected70EF timer3 arm protocol");
    }
}
