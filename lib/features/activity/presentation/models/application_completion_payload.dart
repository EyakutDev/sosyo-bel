import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

/// Tamamla ekranındaki işlemi bütün başvuru taslağıyla üst akışa taşır.
///
/// Kolaylık sağlayan [householdDraft] ve [note] getter'ları mevcut ekran/test
/// çağrılarını okunur tutar; asıl tek veri kaynağı [applicationDraft] alanıdır.
class ApplicationCompletionPayload {
  const ApplicationCompletionPayload({required this.applicationDraft});

  final ApplicationDraft applicationDraft;

  HouseholdStatusDraft get householdDraft => applicationDraft.householdStatus!;

  String get note => applicationDraft.completionNote;
}
