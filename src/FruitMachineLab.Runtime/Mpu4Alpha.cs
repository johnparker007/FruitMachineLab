namespace FruitMachineLab.Runtime;

public record AlphaState(ushort Stream,byte Cursor,byte Control,byte Stop,byte Mirror,byte Digit,
    string Shadow,string Digits,string Text);

// Recovered software shadow/serial-byte subset. PIA edges and VFD device timing
// are separate from these native 3CC0/3D0E memory and byte-stream effects.
public sealed class Mpu4Alpha(Machine machine,Action<byte>? serialOutput=null)
{
    private byte Fetch() {var at=machine.ReadWord(0x52);machine.WriteWord(0x52,Cell.Add(at,1));return machine.Memory[at];}
    private ushort FetchWord()=>(ushort)((Fetch()<<8)|Fetch());
    private void Emit(byte value)=>serialOutput?.Invoke(value);
    public AlphaState Snapshot()
    {
        var shadow=machine.Memory[0x58..0x68];var text=new System.Text.StringBuilder();
        foreach(byte value in shadow) {
            byte code=(byte)(value&0x3F);text.Append((char)(code<32 ? code+64 : code));
            if((value&0xC0)==0xC0)text.Append(',');else if((value&0x80)!=0)text.Append('.');
        }
        return new(machine.ReadWord(0x52),machine.Memory[0x54],machine.Memory[0x55],machine.Memory[0x57],machine.Memory[0xC5],machine.Memory[0xC4],
            Convert.ToHexString(shadow),Convert.ToHexString(machine.Memory[0x1A..0x22]),text.ToString());
    }
    public void Reset()
    {
        machine.Memory[0x55]=0x1F;Emit(0xC0);
        for(int at=0x58;at<0x68;at++){machine.Memory[at]=0x20;Emit(0x20);}
        Emit(0xFF);machine.Memory[0x54]=0;machine.Memory[0x57]=0;Emit(0xAE);
    }
    public void SelectCursor(byte cursor)
    {
        machine.Memory[0x54]=(byte)(cursor&15);Emit((byte)(0xA0|((14-machine.Memory[0x54])&15)));
    }
    public void Put(byte character)
    {
        if(character is 0x2E or 0x2C) {
            machine.Memory[0x54]=unchecked((byte)(machine.Memory[0x54]-1));
            int address=0x58+(machine.Memory[0x54]&15);byte low=(byte)(machine.Memory[address]&0x3F);
            machine.Memory[address]=(byte)(low|(character==0x2E ? 0x80 : 0xC0));
            SelectCursor(machine.Memory[0x54]);Emit(low);
            machine.Memory[0x54]=(byte)((machine.Memory[0x54]+1)&15);Emit(character);
        } else {
            SelectCursor(machine.Memory[0x54]);machine.Memory[0x58+machine.Memory[0x54]]=(byte)(character&0x3F);
            Emit((byte)(character&0x3F));machine.Memory[0x54]=(byte)((machine.Memory[0x54]+1)&15);
        }
    }
    private void MirrorDigit(byte character)
    {
        if(machine.Memory[0xC5]==0)return;
        byte ascii=(byte)(character&0x7F);byte segments=0;
        if(ascii!=0x20) {
            if(ascii<0x30 || ascii>0x39)throw new NotSupportedException("Nondecimal digit mirror glyph requires further recovery");
            segments=machine.Memory[0x6C3C+ascii-0x30];
        }
        byte index=machine.Memory[0xC4];
        if(index>=16)throw new NotSupportedException("Digit mirror mapping outside recovered ROM table");
        byte target=machine.Memory[0x193B+index];if(target!=0xFF)machine.Memory[0x1A+target]=segments;
        machine.Memory[0xC4]=unchecked((byte)(index-1));
    }
    private void Format(int sourceBytes)
    {
        byte fill=Fetch();ushort address=FetchWord();byte width=Fetch(),decimals=Fetch();
        if(width is 0 or >9 || decimals>8)throw new NotSupportedException("Numeric alpha scratch bounds require additional recovery");
        uint value=0;for(int n=0;n<sourceBytes;n++)value=(value<<8)|machine.Memory[Cell.Add(address,(ushort)n)];
        byte[] digits=new byte[9];Array.Fill(digits,(byte)0x30);
        for(int index=8;index>0;index--){digits[index]=(byte)(0x30+value%10);value/=10;}
        digits[8-decimals]|=0x80;
        for(int index=9-width;index<9;index++) {
            byte character=digits[index];
            if(character==0x30 && fill!=0) {
                if(index+1<9 && digits[index+1]==character)character=0x20;
                else {character=fill;fill=0;}
            } else fill=0;
            MirrorDigit(character);Put((byte)(character&0x7F));
            if(index!=8 && (character&0x80)!=0)Put(0x2E);
        }
    }
    public void Execute(ushort stream,int budget=10000)
    {
        machine.WriteWord(0x52,stream);machine.Memory[0x51]=0;
        Continue(budget);
    }
    public bool Resume(int budget=10000)
    {
        if(machine.ReadWord(0x35)!=0 || machine.Memory[Cell.Subtract(machine.ReadWord(0x52),3)]!=0x68)return false;
        Continue(budget);return true;
    }
    private void Continue(int budget)
    {
        for(int ordinal=0;ordinal<budget;ordinal++) {
            byte command=(byte)(Fetch()&0x7F);
            if(command<=0x1F)continue;
            if(command<=0x5F){Put(command);if(machine.Memory[0x57]!=0)return;continue;}
            switch(command) {
                case 0x61:Reset();break;
                case 0x66:Emit(0xE0);break;
                case 0x6E:Emit((byte)(machine.Memory[0x55]|0xE0));break;
                case 0x68:machine.WriteWord(0x35,FetchWord());return;
                case 0x6A:machine.WriteWord(0x52,FetchWord());break;
                case 0x70:SelectCursor(Fetch());break;
                case 0x76: {
                    byte value=machine.Memory[FetchWord()];
                    byte bcd=unchecked((byte)((value/10)*16+value%10));
                    byte high=(byte)(bcd>>4),low=(byte)(bcd&15);
                    Put(high==0 ? (byte)0x20 : (byte)(high<10 ? high+0x30 : high+0x37));
                    Put((byte)(low<10 ? low+0x30 : low+0x37));break;
                }
                case 0x77:Format(1);break;
                case 0x78:Format(3);break;
                case 0x79:Format(2);break;
                case 0x7A:return;
                default:throw new NotSupportedException($"Untranslated alpha command {command:X2} before {machine.ReadWord(0x52):X4}");
            }
        }
        throw new InvalidOperationException("Alpha stream budget exhausted");
    }
}
