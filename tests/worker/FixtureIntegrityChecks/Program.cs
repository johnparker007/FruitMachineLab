using System.Security.Cryptography;
using System.Text;
using FruitMachineLab.Runtime;

try
{
    string root=Path.Combine(Path.GetTempPath(),"fml-fixture-integrity-"+Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(root);
    try
    {
        string text="{\n  \"value\": 1\n}\n";
        byte[] lf=Encoding.UTF8.GetBytes(text);
        byte[] crlf=Encoding.UTF8.GetBytes(text.Replace("\n","\r\n"));
        string lfPath=Write(root,"lf.json",lf);
        string crlfPath=Write(root,"crlf.json",crlf);
        string lfHash=Hash(lf);
        string crlfHash=Hash(crlf);

        Assert(FixtureIntegrity.MatchesPinnedHash(lfPath,lfHash),"LF pin must match LF");
        Assert(FixtureIntegrity.MatchesPinnedHash(crlfPath,lfHash),"LF pin must match CRLF");
        Assert(FixtureIntegrity.MatchesPinnedHash(lfPath,crlfHash),"CRLF pin must match LF");
        Assert(FixtureIntegrity.MatchesPinnedHash(crlfPath,crlfHash),"CRLF pin must match CRLF");

        byte[] mixed=Encoding.UTF8.GetBytes("{\r\n  \"value\": 1\n}\n");
        string mixedPath=Write(root,"mixed.json",mixed);
        Assert(FixtureIntegrity.MatchesPinnedHash(mixedPath,lfHash),"LF pin must match mixed CRLF/LF");
        Assert(FixtureIntegrity.MatchesPinnedHash(mixedPath,Hash(mixed)),"raw mixed pin must match mixed");

        string utf8Text="{\n  \"text\": \"é\"\n}\n";
        string utf8Path=Write(root,"utf8.json",Encoding.UTF8.GetBytes(utf8Text.Replace("\n","\r\n")));
        Assert(FixtureIntegrity.MatchesPinnedHash(utf8Path,Hash(Encoding.UTF8.GetBytes(utf8Text))),
            "LF pin must match CRLF UTF-8 multi-byte content");

        byte[] changed=Encoding.UTF8.GetBytes(text.Replace("1","2"));
        Assert(!FixtureIntegrity.MatchesPinnedHash(Write(root,"changed.json",changed),lfHash),
            "non-newline byte change must fail");
        byte[] appended=[..lf,..Encoding.UTF8.GetBytes(" ")];
        Assert(!FixtureIntegrity.MatchesPinnedHash(Write(root,"appended.json",appended),lfHash),
            "whitespace append must fail");

        byte[] bom=[0xEF,0xBB,0xBF,..lf];
        Reject(Write(root,"bom.json",bom),"BOM");
        Reject(Write(root,"barecr.json",Encoding.UTF8.GetBytes("{\r  \"value\": 1\n}\n")),"bare CR");
        Reject(Write(root,"invalid.json",[0x7B,0x0A,0x22,0xFF,0x22,0x0A,0x7D,0x0A]),"UTF-8");

        try
        {
            FixtureIntegrity.MatchesPinnedHash(lfPath,new string('Z',64));
            throw new Exception("invalid pin was accepted");
        }
        catch(InvalidDataException)
        {
        }

        Console.WriteLine("FixtureIntegrity checks passed: LF/CRLF equivalence, mixed legacy newlines, non-newline failure, BOM/bare CR/UTF-8 rejection");
        return 0;
    }
    finally
    {
        Directory.Delete(root,true);
    }
}
catch(Exception error)
{
    Console.Error.WriteLine("FAIL FixtureIntegrity checks: "+error);
    return 1;
}

static string Write(string root,string name,byte[] bytes)
{
    string path=Path.Combine(root,name);
    File.WriteAllBytes(path,bytes);
    return path;
}

static string Hash(byte[] bytes)=>Convert.ToHexString(SHA256.HashData(bytes));

static void Assert(bool condition,string message)
{
    if(!condition)throw new Exception(message);
}

static void Reject(string path,string expected)
{
    try
    {
        FixtureIntegrity.MatchesPinnedHash(path,new string('0',64));
    }
    catch(InvalidDataException error)
    {
        if(!error.Message.Contains(expected,StringComparison.OrdinalIgnoreCase))
            throw new Exception($"Expected {expected} rejection, got: {error.Message}");
        return;
    }
    throw new Exception($"Expected {expected} rejection but the fixture was accepted");
}
