namespace SosyoBel.Application.Abstractions;

/// <summary>
/// Belediye kapsamı istek gövdesinden değil doğrulanmış kullanıcı kimliğinden gelir.
/// </summary>
public interface ICurrentMunicipality
{
    int? MunicipalityId { get; }

    int RequireMunicipalityId();
}
