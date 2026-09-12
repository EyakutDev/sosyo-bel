namespace SosyoBel.Infrastructure.Logging;

/// <summary>
/// İstek boyunca yalnız tanımlı işlem aşamasını taşır; form, kullanıcı ve dosya
/// bilgileri burada tutulmaz. Aşama değiştirmek tek başına log üretmez.
/// </summary>
public sealed class RequestLogContext
{
    public string? Method { get; set; }
    public string? Route { get; set; }
    public string? TraceId { get; set; }
    public RequestLogStage Stage { get; set; } = RequestLogStage.RequestHandling;
}

public enum RequestLogStage
{
    RequestHandling,
    ReadSubmission,
    ValidateSubmission,
    CheckReplay,
    ResolveCitizen,
    VerifyKps,
    InitializePhotoStorage,
    StorePhotos,
    BeginTransaction,
    CheckTransactionReplay,
    CreateApplication,
    PrepareFamily,
    SaveFamilyAndPhotos,
    CommitTransaction,
    ValidateApplicationUpdate,
    LoadApplicationForUpdate,
    ResolveApplicationUpdateReferences,
    SaveApplicationUpdate,
}
