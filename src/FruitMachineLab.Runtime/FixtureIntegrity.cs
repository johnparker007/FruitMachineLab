using System.Security.Cryptography;
using System.Text.Unicode;

namespace FruitMachineLab.Runtime;

public static class FixtureIntegrity
{
    public static bool MatchesPinnedHash(string path,string expected)
    {
        if(expected.Length!=64 || !expected.All(Uri.IsHexDigit))
            throw new InvalidDataException($"Fixture pin for {Path.GetFileName(path)} is not a SHA-256 value");
        byte[] bytes=ReadChecked(path);
        byte[] lf=CanonicalLf(bytes,path);
        return Hash(bytes).Equals(expected,StringComparison.OrdinalIgnoreCase) ||
               Hash(lf).Equals(expected,StringComparison.OrdinalIgnoreCase) ||
               Hash(ToCrlf(lf)).Equals(expected,StringComparison.OrdinalIgnoreCase);
    }

    public static string Sha256Canonical(string path)=>
        Hash(CanonicalLf(ReadChecked(path),path));

    private static byte[] ReadChecked(string path)
    {
        byte[] bytes=File.ReadAllBytes(path);
        bool bom=bytes.Length>=3 && bytes[0]==0xEF && bytes[1]==0xBB && bytes[2]==0xBF ||
                 bytes.Length>=2 && (bytes[0]==0xFF && bytes[1]==0xFE || bytes[0]==0xFE && bytes[1]==0xFF) ||
                 bytes.Length>=4 && bytes[0]==0x00 && bytes[1]==0x00 && bytes[2]==0xFE && bytes[3]==0xFF;
        if(bom)throw new InvalidDataException($"Fixture {Path.GetFileName(path)} has an explicit BOM");
        if(!Utf8.IsValid(bytes))
            throw new InvalidDataException($"Fixture {Path.GetFileName(path)} is not valid UTF-8");
        return bytes;
    }

    private static byte[] CanonicalLf(byte[] bytes,string path)
    {
        var lines=new List<byte>(bytes.Length);
        for(int index=0;index<bytes.Length;index++)
        {
            byte value=bytes[index];
            if(value==0x0D)
            {
                if(index+1>=bytes.Length || bytes[index+1]!=0x0A)
                    throw new InvalidDataException($"Fixture {Path.GetFileName(path)} contains a bare CR");
                index++;
                lines.Add(0x0A);
            }
            else lines.Add(value);
        }
        return lines.ToArray();
    }

    private static byte[] ToCrlf(byte[] lines)
    {
        var result=new List<byte>(lines.Length+lines.Length/8);
        foreach(byte value in lines)
        {
            if(value==0x0A)result.Add(0x0D);
            result.Add(value);
        }
        return result.ToArray();
    }

    private static string Hash(byte[] bytes)=>Convert.ToHexString(SHA256.HashData(bytes));
}
