namespace SosyoBel.Application.References;

/// <summary>
/// Mobil hane ekranındaki sabit beş sorunun tek kaynak sözleşmesidir.
/// Şirket veritabanında bu alanlar için tablo bulunmadığından seçenekler DB'den okunmaz.
/// </summary>
public static class HouseholdFormContract
{
    public const string SingleChoiceAnswerType = "TEK_SECIM";

    public static IReadOnlyList<HouseholdQuestionDefinition> Questions { get; } =
        Array.AsReadOnly<HouseholdQuestionDefinition>(
        [
            Question(
                "MULKIYET_DURUMU",
                "Mülkiyet Durumu",
                1,
                ("EV_SAHIBI", "Ev Sahibi"),
                ("KIRACI", "Kiracı"),
                ("LOJMAN", "Lojman"),
                ("DIGER", "Diğer")),
            Question(
                "MULK_TIPI",
                "Mülkün Tipi",
                2,
                ("APARTMAN_DAIRESI", "Apartman Dairesi"),
                ("MUSTAKIL_EV", "Müstakil Ev"),
                ("GECEKONDU", "Gecekondu"),
                ("DIGER", "Diğer")),
            Question(
                "EV_TEMIZLIGI",
                "Ev Temiz mi?",
                3,
                ("EVET", "Evet"),
                ("HAYIR", "Hayır")),
            Question(
                "BARINMA_DURUMU",
                "Barınılan Yerin Durumu",
                4,
                ("IYI", "İyi"),
                ("ORTA", "Orta"),
                ("KOTU", "Kötü")),
            Question(
                "EV_ESYALARI",
                "Evdeki Eşyalar",
                5,
                ("YETERLI", "Yeterli"),
                ("KISMEN_YETERLI", "Kısmen Yeterli"),
                ("YETERSIZ", "Yetersiz")),
        ]);

    public static HouseholdQuestionDefinition? FindQuestion(string code) =>
        Questions.FirstOrDefault(value =>
            string.Equals(value.Code, code, StringComparison.Ordinal));

    public static HouseholdQuestionOption? FindOption(
        HouseholdQuestionDefinition question,
        string code) =>
        question.Options.FirstOrDefault(value =>
            string.Equals(value.Code, code, StringComparison.Ordinal));

    private static HouseholdQuestionDefinition Question(
        string code,
        string label,
        short order,
        params (string Code, string Label)[] options) =>
        new(
            code,
            label,
            SingleChoiceAnswerType,
            IsRequired: true,
            order,
            options
                .Select((value, index) => new HouseholdQuestionOption(
                    value.Code,
                    value.Label,
                    checked((short)(index + 1))))
                .ToArray());
}
