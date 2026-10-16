using FruitMachineLab.Runtime;
namespace FruitMachineLab.Adders;

// Translated 61F6/6287/6403. Callers supply actual service boundaries and optic
// reads; this class does not choose outcomes or manufacture a motor clock.
public sealed class AddersReelMotion(Machine machine)
{
    private readonly Machine m=machine;
    public bool Busy=>(m.Memory[0x6B]&0x80)!=0;
    public void Prepare(Func<byte,ushort> condition)
    {
        if((m.Memory[0x719B]&0x20)!=0)throw new NotSupportedException("Motor-disabled native shortcut is outside normal motion recovery");
        Array.Clear(m.Memory,0x158,8);PrepareCommon(condition);
    }
    // Native61D5 preserves existing stop streams, installing defaults only
    // when the high byte at0158 is zero. It clears6B before shared6200.
    public void PrepareAsync(Func<byte,ushort> condition)
    {
        m.Memory[0x6B]=0;
        if(m.Memory[0x158]==0){m.WriteWord(0x158,0x3457);m.WriteWord(0x15A,0x3462);m.WriteWord(0x15C,0x346D);m.WriteWord(0x15E,0);}
        PrepareCommon(condition);
    }
    private void PrepareCommon(Func<byte,ushort> condition)
    {
        if((m.Memory[0x719B]&0x20)!=0)throw new NotSupportedException("Motor-disabled native shortcut is outside normal motion recovery");
        for(ushort x=0x150;x<0x158;x+=2) {
            m.Memory[x+0x21]=0;
            foreach(int offset in new[]{0x40,0x48,0x28,0x38})m.WriteWord((ushort)(x+offset),0);
        }
        for(ushort x=0;x<8;x+=2) {
            byte steps=(m.Memory[0x6A]&1)!=0 ? (byte)4 : m.Memory[0x75CC+x];
            byte request=m.Memory[0x169+x];byte magnitude=(sbyte)request<0 ? unchecked((byte)-request) : request;
            ushort distance=(ushort)(steps*magnitude);
            ushort table=m.ReadWord(Cell.Add(0x661B,unchecked((ushort)(short)(sbyte)m.Memory[0x170+x])));
            if(table==0x6659 && (condition(0x84)!=0 || (m.Memory[0x6A]&2)!=0))table=0x6623;
            byte index=distance>255 ? (byte)8 : (byte)Math.Min(8,(byte)distance>>1);
            ushort profile=m.ReadWord(Cell.Add(table,(ushort)(index*2)));
            m.WriteWord((ushort)(0x180+x),Cell.Add(Cell.Add(distance,unchecked((ushort)(short)(sbyte)m.Memory[profile])),m.ReadWord(0xC2)));
            m.WriteWord((ushort)(0x150+x),Cell.Add(profile,3));
        }
        if((m.Memory[0x6B]&4)!=0) {
            ushort maximum=0;for(ushort x=0x150;x<0x158;x+=2)maximum=Math.Max(maximum,Timing(x));
            for(ushort x=0x150;x<0x158;x+=2) {
                ushort delta=Cell.Subtract(maximum,Timing(x));
                if(delta!=0 && (sbyte)m.Memory[m.ReadWord(x)]>=0)m.WriteWord((ushort)(x+0x38),(ushort)(delta>>3));
            }
        }
        for(ushort x=0x152;x<0x158;x+=2)m.WriteWord((ushort)(x+0x38),Cell.Add(m.ReadWord((ushort)(x+0x38)),(ushort)((x-0x150)/2)));
    }
    private ushort Timing(ushort x)
    {
        ushort pointer=m.ReadWord(x);byte factor=m.Memory[Cell.Subtract(pointer,1)];
        int upper=m.Memory[x+0x30]*factor;
        ushort value=unchecked((ushort)(m.Memory[x+0x31]*factor+((upper&255)<<8)));
        return Cell.Add(value,m.Memory[Cell.Subtract(pointer,2)]);
    }
    // Separate native stages: 6228 enables drive; 623A follows a change of 6E.
    public void Enable(){m.Memory[0x6C]++;m.Memory[0xB03]|=0x3C;m.Memory[0x6D]=0;}
    public void Activate(){if((m.Memory[0x6B]&8)!=0)throw new NotSupportedException("Unrecovered synchronous reel wait mode");m.Memory[0x6B]|=0x80;}
    public void Service(Func<ushort,byte,byte> readOptic,Action<ushort>? queueSound=null)
    {
        if(!Busy)return;
        bool ended=true;for(ushort x=0x150;x<0x158;x+=2)ended&=m.Memory[m.ReadWord(x)]==255;
        if(ended){Stop();return;}
        m.Memory[0x6D]=0;ushort sound=0;
        for(ushort x=0x150;x<0x158;x+=2) {
            int reel=(x-0x150)/2;byte mask=(byte)(0x40>>reel);m.Memory[0x6D]>>=1;
            int budget=256;bool loaded=false,parse=m.ReadWord((ushort)(x+0x40))==0 && m.ReadWord((ushort)(x+0x28))==0;
            while(parse) {
                if(--budget==0)throw new InvalidDataException("Reel profile has no progress boundary");
                ushort cursor=m.ReadWord(x);byte flags=m.Memory[cursor],count=m.Memory[Cell.Add(cursor,1)];
                if(flags==255){if((m.Memory[0x6E]&1)!=0)m.Memory[0x6D]|=128;goto nextReel;}
                if(flags==254) {
                    ushort candidate=m.ReadWord((ushort)(x+8));if(candidate!=0)sound=candidate;m.WriteWord(x,Cell.Add(cursor,1));
                    if((m.Memory[0x6B]&3)==0)MarkReelLamps(reel);continue;
                }
                m.Memory[x+0x21]=flags;byte interval=(byte)(flags&31);
                if(interval==0) {
                    ushort delay=m.ReadWord((ushort)(x+0x38));m.WriteWord((ushort)(x+0x40),delay);m.WriteWord((ushort)(x+0x48),delay);m.WriteWord((ushort)(x+0x28),8);
                } else {
                    m.WriteWord((ushort)(x+0x28),count==0 ? m.ReadWord((ushort)(x+0x30)) : count);
                    m.WriteWord((ushort)(x+0x40),interval);m.WriteWord((ushort)(x+0x48),interval);
                }
                m.WriteWord(x,Cell.Add(cursor,2));
                loaded=true;parse=m.ReadWord((ushort)(x+0x40))==0;
            }
            if(loaded || m.ReadWord((ushort)(x+0x40))==0) {
                m.WriteWord((ushort)(x+0x28),Cell.Subtract(m.ReadWord((ushort)(x+0x28)),1));
                Optic(x,mask,readOptic(x,mask),reel);
                byte position=m.Memory[x+0x18],flags=m.Memory[x+0x21];
                if((flags&0xC0)!=0) {
                    if(((flags&0xC0)^m.Memory[x+0x19])>=128){position=unchecked((byte)(position-1));if((sbyte)position<0)position=95;}
                    else {position=unchecked((byte)(position+1));if(position>95)position=0;}
                    m.Memory[x+0x18]=position;
                }
                m.WriteWord((ushort)(x+0x40),m.ReadWord((ushort)(x+0x48)));
            }
            if((m.Memory[x+0x21]&0x20)!=0 && (m.Memory[0x6E]&1)!=0)m.Memory[0x6D]|=128;
            m.WriteWord((ushort)(x+0x40),Cell.Subtract(m.ReadWord((ushort)(x+0x40)),1));
            nextReel:;
        }
        EncodePhases();if(sound!=0 && (m.Memory[0x719B]&0x40)==0)(queueSound ?? throw new NotSupportedException("Reel sound callback required"))(sound);
    }
    private void Optic(ushort x,byte mask,byte port,int reel)
    {
        if((port&mask)==0){if((m.Memory[0x6B]&2)!=0)throw new NotSupportedException("Native reel optic fault 1400");return;}
        byte position=m.Memory[x+0x18],mode=m.Memory[0x6A];
        if((mode&1)!=0){if((position&7)!=0){if((m.Memory[0x6B]&2)!=0)throw new NotSupportedException("Native reel optic fault 1400");return;}m.Memory[x+0x18]=0;}
        else if(position>7 && position<89) {
            if((mode&2)==0){mode|=2;m.Memory[0x86]|=1;}
            else if((m.Memory[0x719B]&0x30)==0)throw new NotSupportedException($"Native reel alignment fault {reel}");
            m.Memory[x+0x18]=(byte)(position&7);
        }
        m.Memory[0x6A]=(byte)(mode|mask);
        if((m.Memory[0x6B]&2)!=0)MarkReelLamps(reel);
    }
    private void MarkReelLamps(int reel)
    {
        int table=0x1453+reel;if((m.Memory[0x6B]&2)!=0){table+=5;m.Memory[5]=unchecked((byte)-m.Memory[5]);}
        for(int x=0x100;x<0x140;x+=0x10){m.Memory[x]|=m.Memory[table];m.Memory[x+1]|=m.Memory[table];if(table!=0x1456)m.Memory[x+2]|=m.Memory[table];}
    }
    private void Stop()
    {
        int nvram=0x2F2;
        for(int x=0;x<8;x+=2) {
            byte steps=m.Memory[0x75CC+x];if(steps==0)throw new InvalidDataException("Zero reel step size");
            m.Memory[0x198+x]=(byte)(m.Memory[0x168+x]/steps);m.Memory[0x169+x]=0;m.WriteWord((ushort)(0x158+x),0);
            if((m.Memory[0x6A]&1)==0)m.Memory[nvram++]=m.Memory[0x168+x];
        }
        if((sbyte)m.Memory[0x323]>=0) {
            byte delta=0;for(int x=0x2F2;x<0x2F6;x++){delta=unchecked((byte)(delta-m.Memory[x+0x19]));m.Memory[x+0x19]=unchecked((byte)~m.Memory[x]);delta=unchecked((byte)(delta+m.Memory[x+0x19]));}
            m.Memory[0x322]=unchecked((byte)(m.Memory[0x322]+delta));
        }
        m.Memory[0x6D]=0;EncodePhases();m.Memory[0x6C]=0;m.Memory[0x6B]=0;m.Memory[0xB03]&=0xF7;
    }
    private void EncodePhases()
    {
        byte disabled=m.Memory[0x6D];
        byte Phase(int x,int bit,int offset)=>(disabled&bit)!=0 ? (byte)0 : m.Memory[0x666B+(m.Memory[x]&7)+offset];
        m.Memory[0x70]=(byte)(Phase(0x16E,128,8)|Phase(0x16C,64,0));m.Memory[0x6F]=(byte)(Phase(0x16A,32,8)|Phase(0x168,16,0));
    }
}
