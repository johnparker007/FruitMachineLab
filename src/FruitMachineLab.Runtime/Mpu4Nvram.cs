namespace FruitMachineLab.Runtime;

// Native 6E06/6E0D. This models memory effects, not CPU registers or IRQ timing.
public static class Mpu4Nvram
{
    public static bool Refresh(Machine machine, Action<ushort>? unprotectedRead = null)
    {
        if ((machine.Memory[0x323] & 0x80) != 0) return false;
        byte initialChecksum = machine.Memory[0x322];
        byte guard = machine.Memory[0x2C];
        byte sum = 0;
        machine.Memory[0x2C] = 1;
        for (ushort address = 0x2F0; address < 0x309; address++)
        {
            if (address == 0x2FA) machine.Memory[0x2C] = guard;
            if (address >= 0x2FA) unprotectedRead?.Invoke(address);
            byte value = machine.Memory[address];
            machine.Memory[address + 0x19] = unchecked((byte)~value);
            sum = unchecked((byte)(sum - value));
        }
        // IRQ-side changes to the checksum since its initial snapshot are retained.
        byte delta = unchecked((byte)(machine.Memory[0x322] - initialChecksum));
        machine.Memory[0x322] = unchecked((byte)(sum - 0x32 + delta));
        return true;
    }
}
