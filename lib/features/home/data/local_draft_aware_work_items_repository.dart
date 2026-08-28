import 'package:sosyo_bel/features/application/domain/local_application_draft_repository.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';

/// Sunucudaki görev ve başvurular ile yalnız bu cihazda bulunan personel
/// taslaklarını Bekleyen Liste için tek zaman sıralı koleksiyonda birleştirir.
final class LocalDraftAwareWorkItemsRepository implements WorkItemsRepository {
  const LocalDraftAwareWorkItemsRepository({
    required WorkItemsRepository remoteRepository,
    required LocalApplicationDraftRepository localDraftRepository,
    required String ownerUserId,
  }) : _remoteRepository = remoteRepository,
       _localDraftRepository = localDraftRepository,
       _ownerUserId = ownerUserId;

  final WorkItemsRepository _remoteRepository;
  final LocalApplicationDraftRepository _localDraftRepository;
  final String _ownerUserId;

  @override
  Future<List<WorkItem>> getMyWorkItems({int limit = 100}) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Limit 1-100 arasında olmalıdır.',
      );
    }

    // İki veri kaynağı birbirinden bağımsız olduğu için aynı anda okunur.
    final results = await Future.wait<List<WorkItem>>([
      _remoteRepository.getMyWorkItems(limit: limit),
      _loadLocalDrafts(),
    ]);
    final merged = <WorkItem>[...results[0], ...results[1]]
      ..sort((a, b) => b.activityAtUtc.compareTo(a.activityAtUtc));
    return List.unmodifiable(merged.take(limit));
  }

  Future<List<WorkItem>> _loadLocalDrafts() async {
    final records = await _localDraftRepository.list(ownerUserId: _ownerUserId);
    return records
        .map((record) {
          final profile = record.draft.citizenProfile;
          final applicationNumber = profile.applicationNumber.trim();
          return WorkItem(
            localDraftId: record.localDraftId,
            applicationNumber:
                applicationNumber.isEmpty || applicationNumber == '—'
                ? 'Yerel Taslak'
                : applicationNumber,
            applicantFullName: profile.fullName,
            address: profile.address,
            sourceCode: WorkItem.localDraftSourceCode,
            statusCode: 'TASLAK',
            isCompleted: false,
            isEditable: true,
            description: record.draft.applicationForm?.description,
            activityAtUtc: record.updatedAtUtc,
          );
        })
        .toList(growable: false);
  }
}
