namespace FruitMachineLab.Adders;

public enum RuntimeEvidenceClass
{
    StaticDefinition,
    DeclaredCheckpoint,
    RecordedTiming,
    RecordedResult
}

public sealed record RuntimeEvidenceRequirement(
    string RelativePath,
    string Fields,
    RuntimeEvidenceClass Class,
    string Replacement,
    string OtherFields = "")
{
    public string Label => Class switch
    {
        RuntimeEvidenceClass.StaticDefinition => "static definition",
        RuntimeEvidenceClass.DeclaredCheckpoint => "declared checkpoint",
        RuntimeEvidenceClass.RecordedTiming => "recorded timing",
        RuntimeEvidenceClass.RecordedResult => "recorded result",
        _ => throw new ArgumentOutOfRangeException(nameof(Class))
    };
}

public sealed class RuntimeEvidencePolicy
{
    private RuntimeEvidencePolicy(bool captureFree,bool allowDeclaredCheckpoint)
    {
        IsCaptureFree=captureFree;
        AllowsDeclaredCheckpoint=allowDeclaredCheckpoint;
    }

    public static RuntimeEvidencePolicy Compatibility { get; }=new(false,false);
    public bool IsCaptureFree { get; }
    public bool AllowsDeclaredCheckpoint { get; }

    public static RuntimeEvidencePolicy CaptureFree(bool allowDeclaredCheckpoint=false)=>new(true,allowDeclaredCheckpoint);

    public string ReadText(string evidenceDirectory,RuntimeEvidenceRequirement requirement)
    {
        ArgumentException.ThrowIfNullOrEmpty(evidenceDirectory);
        ArgumentNullException.ThrowIfNull(requirement);
        Enforce(requirement);
        return File.ReadAllText(Path.Combine(evidenceDirectory,requirement.RelativePath));
    }

    private void Enforce(RuntimeEvidenceRequirement requirement)
    {
        if(!IsCaptureFree)return;
        string staticNote=string.IsNullOrEmpty(requirement.OtherFields) ? "" : $" File notes: {requirement.OtherFields}.";
        switch(requirement.Class)
        {
            case RuntimeEvidenceClass.StaticDefinition:
                return;
            case RuntimeEvidenceClass.DeclaredCheckpoint when AllowsDeclaredCheckpoint:
                return;
            case RuntimeEvidenceClass.DeclaredCheckpoint:
                throw new NotSupportedException(
                    $"Capture-free runtime evidence policy requires explicit permission for {requirement.Label} in {requirement.RelativePath}: consumed fields {requirement.Fields}. Static fields do not exempt captured state.{staticNote} Replacement: {requirement.Replacement}.");
            case RuntimeEvidenceClass.RecordedTiming:
                throw new NotSupportedException(
                    $"Capture-free runtime evidence policy rejects {requirement.Label} in {requirement.RelativePath}: consumed fields {requirement.Fields}. Recorded schedules, IRQ occupancy and timing are not permitted, including with declared-checkpoint permission.{staticNote} Replacement: {requirement.Replacement}.");
            case RuntimeEvidenceClass.RecordedResult:
                throw new NotSupportedException(
                    $"Capture-free runtime evidence policy rejects {requirement.Label} in {requirement.RelativePath}: consumed fields {requirement.Fields}. Recorded results are not permitted, including with declared-checkpoint permission.{staticNote} Replacement: {requirement.Replacement}.");
            default:
                throw new NotSupportedException($"Capture-free runtime evidence policy has no rule for {requirement.RelativePath}");
        }
    }
}
