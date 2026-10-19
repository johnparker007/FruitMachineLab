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
                    repositoryRoot, "artifacts", "deepseek", "il-integrity-03", "runs",
                    DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff"));

            NineEdNineVerification.Run(romPath, repositoryRoot, outputDirectory);
            Console.WriteLine("Report: " + Path.Combine(outputDirectory, "verification-report.json"));
            Console.WriteLine("Log: " + Path.Combine(outputDirectory, "verification.log"));

            string nineASixFourOutput = Path.Combine(outputDirectory, "9a64");
            NineASixFourVerification.Run(romPath, repositoryRoot, nineASixFourOutput);
            Console.WriteLine("9A64 report: " +
                Path.Combine(nineASixFourOutput, "verification-report.json"));
            Console.WriteLine("9A64 log: " +
                Path.Combine(nineASixFourOutput, "verification.log"));

            string allocatorOutput = Path.Combine(outputDirectory, "allocator");
            ExtensionRangeAllocatorVerification.Run(romPath, repositoryRoot, allocatorOutput);
            Console.WriteLine("Allocator report: " +
                Path.Combine(allocatorOutput, "verification-report.json"));
            Console.WriteLine("Allocator log: " +
                Path.Combine(allocatorOutput, "verification.log"));

            string emitterOutput = Path.Combine(outputDirectory, "emitter");
            ExtensionRangeEmitterVerification.Run(romPath, repositoryRoot, emitterOutput);
            Console.WriteLine("Emitter report: " +
                Path.Combine(emitterOutput, "verification-report.json"));
            Console.WriteLine("Emitter log: " +
                Path.Combine(emitterOutput, "verification.log"));

            string compositeOutput = Path.Combine(outputDirectory, "composite");
            CompositeWordVerification.Run(romPath, repositoryRoot, compositeOutput);
            Console.WriteLine("Composite report: " +
                Path.Combine(compositeOutput, "verification-report.json"));
            Console.WriteLine("Composite log: " +
                Path.Combine(compositeOutput, "verification.log"));

            string nativePrimitiveOutput = Path.Combine(outputDirectory, "native-primitive");
            NativePrimitiveWordVerification.Run(
                romPath, repositoryRoot, nativePrimitiveOutput);
            Console.WriteLine("Native-primitive report: " +
                Path.Combine(nativePrimitiveOutput, "verification-report.json"));
            Console.WriteLine("Native-primitive log: " +
                Path.Combine(nativePrimitiveOutput, "verification.log"));

            string largerReplacementOutput = Path.Combine(
                outputDirectory, "larger-replacement");
            LargerReplacementVerification.Run(
                romPath, repositoryRoot, largerReplacementOutput);
            Console.WriteLine("Larger-replacement report: " +
                Path.Combine(largerReplacementOutput, "verification-report.json"));
            Console.WriteLine("Larger-replacement log: " +
                Path.Combine(largerReplacementOutput, "verification.log"));
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
