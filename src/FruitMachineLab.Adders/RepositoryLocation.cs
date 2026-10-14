namespace FruitMachineLab.Adders;

public static class RepositoryLocation
{
    public static string Find(string workingDirectory, string executableDirectory)
    {
        foreach (var start in new[] { workingDirectory, executableDirectory })
        {
            for (var directory = new DirectoryInfo(start); directory is not null; directory = directory.Parent)
            {
                if (File.Exists(Path.Combine(directory.FullName, "FruitMachineLab.sln")) &&
                    Directory.Exists(Path.Combine(directory.FullName, "evidence", "mpu4")))
                    return directory.FullName;
            }
        }
        return workingDirectory;
    }
}
