namespace FruitMachineLab.IlVerification;

internal static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length is < 1 or > 2)
        {
            Console.Error.WriteLine(
                "Usage: FruitMachineLab.IlVerification <original-a6ls.p1> [new-output-directory]");
            return 2;
        }

        try
        {
            string romPath = Path.GetFullPath(args[0]);
            string repositoryRoot = FindRepositoryRoot(Directory.GetCurrentDirectory())
                ?? FindRepositoryRoot(AppContext.BaseDirectory)
                ?? throw new InvalidOperationException("Repository root was not found");
            string outputDirectory = args.Length == 2
                ? Path.GetFullPath(args[1])
                : Path.Combine(
                    repositoryRoot, "artifacts", "deepseek", "il-edit-02", "runs",
                    DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff"));

            NineEdNineVerification.Run(romPath, repositoryRoot, outputDirectory);
            Console.WriteLine("Report: " + Path.Combine(outputDirectory, "verification-report.json"));
            Console.WriteLine("Log: " + Path.Combine(outputDirectory, "verification.log"));
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("FAIL il verification: " + error.Message);
            return 1;
        }
    }

    private static string? FindRepositoryRoot(string start)
    {
        DirectoryInfo? current = new(Path.GetFullPath(start));
        while (current is not null)
        {
            if (File.Exists(Path.Combine(
                    current.FullName, "FruitMachineLab.Headless.sln")))
                return current.FullName;
            current = current.Parent;
        }
        return null;
    }
}
