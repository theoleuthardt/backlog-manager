import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A partial update of an entry (`PUT /api/backlog/entries/{id}`). Only the
/// fields that are set are sent: the backend reads an explicit `null` as
/// "clear this field", and the generated request class sends every field.
class EntryUpdate {
  const EntryUpdate({
    this.status,
    this.playtime,
    this.interest,
    this.reviewStars,
    this.review,
    this.note,
    this.owned,
    this.genre,
    this.platform,
    this.imageLink,
  });

  final String? status;
  final double? playtime;
  final int? interest;
  final int? reviewStars;
  final String? review;
  final String? note;
  final bool? owned;
  final List<String>? genre;
  final List<String>? platform;
  final String? imageLink;

  Map<String, Object?> toJson() => {
    'status': ?status,
    'playtime': ?playtime,
    'interest': ?interest,
    'review_stars': ?reviewStars,
    'review': ?review,
    'note': ?note,
    'owned': ?owned,
    'genre': ?genre,
    'platform': ?platform,
    'image_link': ?imageLink,
  };
}

/// The backlog calls the app needs. Every call takes the id of a shared space
/// or null for the personal backlog.
abstract interface class BacklogApi {
  Future<List<BacklogEntry>> entries(int? spaceId);

  Future<BacklogEntry> createEntry(
    wire.CreateBacklogEntryRequest request,
    int? spaceId,
  );

  Future<BacklogEntry> updateEntry(
    int entryId,
    EntryUpdate update,
    int? spaceId,
  );

  Future<void> deleteEntry(int entryId, int? spaceId);

  Future<List<CustomStatus>> customStatuses(int? spaceId);

  Future<CustomStatus> createCustomStatus(String name, int? spaceId);

  Future<void> deleteCustomStatus(int statusId, int? spaceId);

  Future<List<Category>> categories(int? spaceId);

  Future<Category> createCategory(String name, String color, int? spaceId);

  /// Changes the given fields of a category; fields left null stay as they
  /// are.
  Future<Category> updateCategory(
    int categoryId,
    int? spaceId, {
    String? name,
    String? color,
  });

  Future<void> deleteCategory(int categoryId, int? spaceId);

  Future<void> setEntryCategory(
    int entryId,
    int categoryId,
    int? spaceId, {
    required bool assigned,
  });

  Future<List<BacklogEntry>> entriesOfCategory(int categoryId, int? spaceId);

  Future<wire.AchievementProgress> achievements(int steamAppId);
}

class ApiBacklogApi implements BacklogApi {
  const ApiBacklogApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<wire.FallbackClient> _client() async =>
      wire.RestClient(await _dio()).fallback;

  @override
  Future<List<BacklogEntry>> entries(int? spaceId) async {
    final entries = await (await _client()).apiBacklogEntriesListEntries(
      spaceId: spaceId,
    );
    return entries.map(entryFromResponse).toList();
  }

  @override
  Future<BacklogEntry> createEntry(
    wire.CreateBacklogEntryRequest request,
    int? spaceId,
  ) async {
    final entry = await (await _client()).apiBacklogEntriesCreateEntry(
      body: request,
      spaceId: spaceId,
    );
    return entryFromResponse(entry);
  }

  @override
  Future<BacklogEntry> updateEntry(
    int entryId,
    EntryUpdate update,
    int? spaceId,
  ) async {
    final response = await (await _dio()).put<Map<String, dynamic>>(
      '/api/backlog/entries/$entryId',
      data: update.toJson(),
      queryParameters: {'space_id': ?spaceId},
    );
    return entryFromResponse(
      wire.BacklogEntryResponse.fromJson(response.data!),
    );
  }

  @override
  Future<void> deleteEntry(int entryId, int? spaceId) async {
    await (await _client()).apiBacklogEntriesEntryIdDeleteEntry(
      entryId: entryId,
      spaceId: spaceId,
    );
  }

  @override
  Future<List<CustomStatus>> customStatuses(int? spaceId) async {
    final statuses = await (await _client())
        .apiBacklogStatusesListCustomStatuses(spaceId: spaceId);
    return statuses.map(customStatusFromResponse).toList();
  }

  @override
  Future<CustomStatus> createCustomStatus(String name, int? spaceId) async {
    final created = await (await _client())
        .apiBacklogStatusesCreateCustomStatus(
          body: wire.CreateCustomStatusRequest(name: name),
          spaceId: spaceId,
        );
    return customStatusFromResponse(created);
  }

  @override
  Future<void> deleteCustomStatus(int statusId, int? spaceId) async {
    await (await _client()).apiBacklogStatusesStatusIdDeleteCustomStatus(
      statusId: statusId,
      spaceId: spaceId,
    );
  }

  @override
  Future<List<Category>> categories(int? spaceId) async {
    final categories = await (await _client())
        .apiBacklogCategoriesListCategories(spaceId: spaceId);
    return categories.map(categoryFromResponse).toList();
  }

  @override
  Future<Category> createCategory(
    String name,
    String color,
    int? spaceId,
  ) async {
    final created = await (await _client()).apiBacklogCategoriesCreateCategory(
      body: wire.CreateCategoryRequest(categoryName: name, color: color),
      spaceId: spaceId,
    );
    return categoryFromResponse(created);
  }

  @override
  Future<Category> updateCategory(
    int categoryId,
    int? spaceId, {
    String? name,
    String? color,
  }) async {
    final response = await (await _dio()).put<Map<String, dynamic>>(
      '/api/backlog/categories/$categoryId',
      data: {'category_name': ?name, 'color': ?color},
      queryParameters: {'space_id': ?spaceId},
    );
    return categoryFromResponse(wire.CategoryResponse.fromJson(response.data!));
  }

  @override
  Future<void> deleteCategory(int categoryId, int? spaceId) async {
    await (await _client()).apiBacklogCategoriesCategoryIdDeleteCategory(
      categoryId: categoryId,
      spaceId: spaceId,
    );
  }

  @override
  Future<void> setEntryCategory(
    int entryId,
    int categoryId,
    int? spaceId, {
    required bool assigned,
  }) async {
    final client = await _client();
    if (assigned) {
      await client
          .apiBacklogEntriesEntryIdCategoriesCategoryIdAddCategoryToEntry(
            entryId: entryId,
            categoryId: categoryId,
            spaceId: spaceId,
          );
    } else {
      await client
          .apiBacklogEntriesEntryIdCategoriesCategoryIdRemoveCategoryFromEntry(
            entryId: entryId,
            categoryId: categoryId,
            spaceId: spaceId,
          );
    }
  }

  @override
  Future<List<BacklogEntry>> entriesOfCategory(
    int categoryId,
    int? spaceId,
  ) async {
    final entries = await (await _client())
        .apiBacklogCategoriesCategoryIdEntriesGetEntriesForCategory(
          categoryId: categoryId,
          spaceId: spaceId,
        );
    return entries.map(entryFromResponse).toList();
  }

  @override
  Future<wire.AchievementProgress> achievements(int steamAppId) async {
    return (await _client()).apiUserSteamAchievementsGetSteamAchievements(
      steamAppId: steamAppId,
    );
  }
}

final backlogApiProvider = Provider<BacklogApi>(
  (ref) => ApiBacklogApi(() => ref.read(apiDioProvider.future)),
);
