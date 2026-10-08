import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/domain/models.dart';

class FakeBacklogApi implements BacklogApi {
  FakeBacklogApi({List<BacklogEntry>? entries})
    : stored = {for (final e in entries ?? <BacklogEntry>[]) e.id: e};

  Map<int, BacklogEntry> stored;
  final calls = <String>[];
  Future<void> Function(int entryId, EntryUpdate update)? onUpdate;
  Future<void> Function(int entryId)? onDelete;
  Future<List<BacklogEntry>> Function(int? spaceId)? onEntries;
  List<Category> categoryList = const [];
  Map<int, List<BacklogEntry>> entriesByCategory = const {};
  List<CustomStatus> statusList = const [];

  @override
  Future<List<BacklogEntry>> entries(int? spaceId) async {
    calls.add('entries ${spaceId ?? 'personal'}');
    final custom = onEntries;
    if (custom != null) return custom(spaceId);
    return stored.values.toList();
  }

  @override
  Future<BacklogEntry> createEntry(
    wire.CreateBacklogEntryRequest request,
    int? spaceId,
  ) async {
    calls.add('create ${request.title}');
    final entry = BacklogEntry(id: stored.length + 100, title: request.title);
    stored[entry.id] = entry;
    return entry;
  }

  @override
  Future<BacklogEntry> updateEntry(
    int entryId,
    EntryUpdate update,
    int? spaceId,
  ) async {
    calls.add('update $entryId ${update.toJson()}');
    await onUpdate?.call(entryId, update);
    final entry = stored[entryId]!.withStatus(
      update.status ?? stored[entryId]!.status,
    );
    stored[entryId] = entry;
    return entry;
  }

  @override
  Future<void> deleteEntry(int entryId, int? spaceId) async {
    calls.add('delete $entryId');
    await onDelete?.call(entryId);
    stored.remove(entryId);
  }

  @override
  Future<List<CustomStatus>> customStatuses(int? spaceId) async {
    calls.add('statuses ${spaceId ?? 'personal'}');
    return statusList;
  }

  Future<void> Function(String name)? onCreateStatus;
  Future<void> Function(int statusId)? onDeleteStatus;

  @override
  Future<CustomStatus> createCustomStatus(String name, int? spaceId) async {
    calls.add('create-status $name ${spaceId ?? 'personal'}');
    await onCreateStatus?.call(name);
    final created = CustomStatus(id: statusList.length + 50, name: name);
    statusList = [...statusList, created];
    return created;
  }

  @override
  Future<void> deleteCustomStatus(int statusId, int? spaceId) async {
    calls.add('delete-status $statusId ${spaceId ?? 'personal'}');
    await onDeleteStatus?.call(statusId);
    statusList = [
      for (final status in statusList)
        if (status.id != statusId) status,
    ];
  }

  @override
  Future<List<Category>> categories(int? spaceId) async {
    calls.add('categories ${spaceId ?? 'personal'}');
    return categoryList;
  }

  @override
  Future<List<BacklogEntry>> entriesOfCategory(
    int categoryId,
    int? spaceId,
  ) async {
    calls.add('category-entries $categoryId');
    return entriesByCategory[categoryId] ?? const [];
  }

  @override
  Future<wire.AchievementProgress> achievements(int steamAppId) async {
    calls.add('achievements $steamAppId');
    return const wire.AchievementProgress(
      unlocked: 3,
      total: 15,
      achievements: [],
    );
  }
}
