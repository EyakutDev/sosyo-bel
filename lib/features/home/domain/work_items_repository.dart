import 'package:sosyo_bel/features/home/domain/work_item.dart';

/// Birleşik iş listesinin HTTP ve veri kaynağı ayrıntılarını ekrandan gizler.
abstract interface class WorkItemsRepository {
  Future<List<WorkItem>> getMyWorkItems({int limit = 100});
}
