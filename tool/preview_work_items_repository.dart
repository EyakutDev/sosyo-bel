import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';

/// Görsel önizlemelerin backend çalışmadan açılabilmesi için boş iş kaynağı.
class PreviewWorkItemsRepository implements WorkItemsRepository {
  const PreviewWorkItemsRepository();

  @override
  Future<List<WorkItem>> getMyWorkItems({int limit = 100}) async {
    return const [];
  }
}
