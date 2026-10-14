namespace FruitMachineLab.Runtime;

public record OutputScanState(byte Phase,byte Count,byte Reload,byte Alternate,byte AlternateReload,
    ushort Column,string Ports);

// Native 28FE memory/port-latch effects. PIA input polling and PTM callbacks
// remain outside this slice; enabled pulse-width control requires an explicit adapter.
public sealed class Mpu4OutputScan(Machine machine,Action<Machine>? pulseSweep=null)
{
    public OutputScanState Snapshot()=>new(machine.Memory[0x23],machine.Memory[0x24],machine.Memory[0x25],machine.Memory[0x26],machine.Memory[0x27],
        machine.ReadWord(0x28),Convert.ToHexString(new byte[]{machine.Memory[0xA00],machine.Memory[0xA02],machine.Memory[0xB00],machine.Memory[0xE01],machine.Memory[0xB01],machine.Memory[0xF01]}));
    public void Advance()
    {
        if(machine.Memory[0x8D]!=0)return;
        machine.Memory[0xA00]=0;machine.Memory[0xA02]=0;machine.Memory[0xB00]=0;
        ushort column=Cell.Add(machine.ReadWord(0x28),1);
        if(column>=8) {
            byte phase=machine.Memory[0x23];
            if(machine.Memory[0x27]!=0) {
                machine.Memory[0x26]=unchecked((byte)(machine.Memory[0x26]-1));
                if(machine.Memory[0x26]==0){phase^=2;machine.Memory[0x26]=machine.Memory[0x27];}
                machine.Memory[0x24]=unchecked((byte)(machine.Memory[0x24]-1));
                if(machine.Memory[0x24]==0){phase^=1;machine.Memory[0x24]=machine.Memory[0x25];}
                machine.Memory[0x23]=phase;
            } else {
                machine.Memory[0x24]=unchecked((byte)(machine.Memory[0x24]-1));
                if(machine.Memory[0x24]==0){machine.Memory[0x24]=machine.Memory[0x25];machine.Memory[0x23]=(byte)((phase+1)&3);}
            }
            column=0;
        }
        machine.WriteWord(0x28,column);
        void WriteControl(int address,byte value) {
            // 6821 bits 7/6 are read-only IRQ flags, not software control bits.
            // The observed selector values configure C2 output, hiding IRQ2.
            byte status=(byte)(machine.Memory[address]&0x80);
            if((value&0x20)==0)status|=(byte)(machine.Memory[address]&0x40);
            machine.Memory[address]=(byte)((value&0x3F)|status);
        }
        WriteControl(0xE01,machine.Memory[0x28E6+column]);WriteControl(0xB01,machine.Memory[0x28EE+column]);WriteControl(0xF01,machine.Memory[0x28F6+column]);
        if(machine.Memory[8+column]<=3) {
            if(machine.Memory[0xB3]!=0) {
                if(pulseSweep is null)throw new NotSupportedException("Enabled lamp pulse-width sweep requires an explicit timer adapter");
                pulseSweep(machine);
            }
            int address=0x100+16*machine.Memory[0x23]+column;
            machine.Memory[0xA00]=machine.Memory[address];machine.Memory[0xA02]=machine.Memory[address+8];
        }
        byte glyph=machine.Memory[0x1A+column];
        if((machine.Memory[0x22]&(1<<column))!=0)glyph|=0x80;
        if((machine.Memory[0x2BE+column]&machine.Memory[0x29BB+machine.Memory[0x23]])!=0)glyph&=0x80;
        machine.Memory[0xB00]=glyph;
    }
}
