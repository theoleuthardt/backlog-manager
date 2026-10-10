import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/data/backlog_api.dart';
import 'package:backlog_manager/data/games_api.dart';
import 'package:backlog_manager/domain/game_search.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/price_listings.dart';

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
  Future<wire.AchievementProgress> Function(int steamAppId)? onAchievements;

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
    final entry = _applied(stored[entryId]!, update);
    stored[entryId] = entry;
    return entry;
  }

  BacklogEntry _applied(BacklogEntry entry, EntryUpdate update) {
    return BacklogEntry(
      id: entry.id,
      title: update.title ?? entry.title,
      imageLink: update.imageLink ?? entry.imageLink,
      imageAlt: entry.imageAlt,
      genre: update.genre ?? entry.genre,
      platform: update.platform ?? entry.platform,
      status: update.status ?? entry.status,
      owned: update.owned ?? entry.owned,
      interest: update.interest ?? entry.interest,
      reviewStars: update.reviewStars ?? entry.reviewStars,
      review: update.review ?? entry.review,
      note: update.note ?? entry.note,
      description: update.description ?? entry.description,
      trailerLink: update.trailerLink ?? entry.trailerLink,
      mainTime: update.mainTime ?? entry.mainTime,
      mainPlusExtraTime: update.mainPlusExtraTime ?? entry.mainPlusExtraTime,
      completionTime: update.completionTime ?? entry.completionTime,
      playtime: update.playtime ?? entry.playtime,
      partnerPlaytime: entry.partnerPlaytime,
      inSharedSpace: entry.inSharedSpace,
      steamAppId: update.clearSteamAppId ? null : entry.steamAppId,
      completedAt: entry.completedAt,
    );
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
    final custom = onAchievements;
    if (custom != null) return custom(steamAppId);
    return const wire.AchievementProgress(
      unlocked: 3,
      total: 15,
      achievements: [],
    );
  }
}

class FakeGamesApi implements GamesApi {
  final calls = <String>[];
  Future<PriceInfo> Function(int steamAppId)? onPrice;
  Future<List<KeyShopOffer>> Function(String title)? onKeyShops;
  Future<List<GameSearchResult>> Function(String term, bool deep)? onSearch;
  Future<int?> Function(String title)? onSteamAppId;
  Future<List<String>> Function(int steamAppId)? onCovers;
  Future<List<SteamGridDbMatch>> Function(String term)? onGridSearch;
  Future<List<String>> Function(int gameId)? onCoversById;

  @override
  Future<PriceInfo> price(int steamAppId) async {
    calls.add('price $steamAppId');
    final custom = onPrice;
    if (custom != null) return custom(steamAppId);
    return const PriceInfo(deals: [], onSale: false);
  }

  @override
  Future<List<KeyShopOffer>> keyShopPrices(String title) async {
    calls.add('keys $title');
    final custom = onKeyShops;
    if (custom != null) return custom(title);
    return const [];
  }

  @override
  Future<List<GameSearchResult>> search(
    String term, {
    bool deep = false,
  }) async {
    calls.add('search $term${deep ? ' deep' : ''}');
    final custom = onSearch;
    return custom == null ? const [] : custom(term, deep);
  }

  @override
  Future<int?> steamAppId(String title) async {
    calls.add('steam-app-id $title');
    final custom = onSteamAppId;
    return custom == null ? null : custom(title);
  }

  @override
  Future<List<String>> steamGridDbCovers(int steamAppId) async {
    calls.add('covers $steamAppId');
    final custom = onCovers;
    return custom == null ? const [] : custom(steamAppId);
  }

  @override
  Future<List<SteamGridDbMatch>> steamGridDbSearch(String term) async {
    calls.add('grid-search $term');
    final custom = onGridSearch;
    return custom == null ? const [] : custom(term);
  }

  @override
  Future<List<String>> steamGridDbCoversById(int gameId) async {
    calls.add('covers-by-id $gameId');
    final custom = onCoversById;
    return custom == null ? const [] : custom(gameId);
  }
}
