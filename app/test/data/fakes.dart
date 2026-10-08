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

  int _nextStatusId = 50;
  Future<void> Function(String name)? onCreateStatus;
  Future<void> Function(int statusId)? onDeleteStatus;

  @override
  Future<CustomStatus> createCustomStatus(String name, int? spaceId) async {
    calls.add('create-status $name ${spaceId ?? 'personal'}');
    await onCreateStatus?.call(name);
    final created = CustomStatus(id: _nextStatusId++, name: name);
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

  int _nextCategoryId = 100;
  Future<void> Function(String name)? onCreateCategory;
  Future<void> Function(int categoryId)? onUpdateCategory;
  Future<void> Function(int entryId, int categoryId, bool assigned)?
  onSetEntryCategory;

  @override
  Future<Category> createCategory(
    String name,
    String color,
    int? spaceId,
  ) async {
    calls.add('create-category $name $color ${spaceId ?? 'personal'}');
    await onCreateCategory?.call(name);
    final created = Category(id: _nextCategoryId++, name: name, color: color);
    categoryList = [...categoryList, created];
    return created;
  }

  @override
  Future<Category> updateCategory(
    int categoryId,
    int? spaceId, {
    String? name,
    String? color,
  }) async {
    calls.add(
      'update-category $categoryId ${name ?? '-'} ${color ?? '-'} '
      '${spaceId ?? 'personal'}',
    );
    await onUpdateCategory?.call(categoryId);
    final old = categoryList.firstWhere((c) => c.id == categoryId);
    final updated = Category(
      id: categoryId,
      name: name ?? old.name,
      color: color ?? old.color,
    );
    categoryList = [
      for (final c in categoryList) c.id == categoryId ? updated : c,
    ];
    return updated;
  }

  @override
  Future<void> deleteCategory(int categoryId, int? spaceId) async {
    calls.add('delete-category $categoryId ${spaceId ?? 'personal'}');
    categoryList = [
      for (final c in categoryList)
        if (c.id != categoryId) c,
    ];
    entriesByCategory = {
      for (final item in entriesByCategory.entries)
        if (item.key != categoryId) item.key: item.value,
    };
  }

  @override
  Future<void> setEntryCategory(
    int entryId,
    int categoryId,
    int? spaceId, {
    required bool assigned,
  }) async {
    calls.add(
      '${assigned ? 'add' : 'remove'}-category $entryId $categoryId '
      '${spaceId ?? 'personal'}',
    );
    await onSetEntryCategory?.call(entryId, categoryId, assigned);
    final entry = stored[entryId] ?? BacklogEntry(id: entryId, title: 'Game');
    final current = entriesByCategory[categoryId] ?? const [];
    entriesByCategory = {
      ...entriesByCategory,
      categoryId: assigned
          ? [...current.where((e) => e.id != entryId), entry]
          : [
              for (final e in current)
                if (e.id != entryId) e,
            ],
    };
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
