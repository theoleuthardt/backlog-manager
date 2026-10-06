// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/achievement_progress.dart';
import '../models/backlog_entry_response.dart';
import '../models/backup_summary.dart';
import '../models/category_response.dart';
import '../models/create_backlog_entry_request.dart';
import '../models/create_category_request.dart';
import '../models/create_custom_status_request.dart';
import '../models/create_user_request.dart';
import '../models/csv_headers_request.dart';
import '../models/csv_headers_response.dart';
import '../models/custom_status_response.dart';
import '../models/enriched_result.dart';
import '../models/game_price.dart';
import '../models/igdb_cover.dart';
import '../models/igdb_game_data.dart';
import '../models/igdb_game_time_to_beat.dart';
import '../models/igdb_genre.dart';
import '../models/igdb_platform.dart';
import '../models/igdb_search_result.dart';
import '../models/invite_to_space_request.dart';
import '../models/key_shop_offer.dart';
import '../models/login_params.dart';
import '../models/login_result.dart';
import '../models/match_csv_request.dart';
import '../models/public_user.dart';
import '../models/public_username.dart';
import '../models/rename_backup_request.dart';
import '../models/restore_result.dart';
import '../models/space_response.dart';
import '../models/steam_grid_db_search_result.dart';
import '../models/steam_preview_item.dart';
import '../models/steam_wishlist_item.dart';
import '../models/submit_csv_entry.dart';
import '../models/token_response.dart';
import '../models/two_factor_disable_params.dart';
import '../models/two_factor_enroll_response.dart';
import '../models/two_factor_login_verify_params.dart';
import '../models/two_factor_verify_enrollment_params.dart';
import '../models/two_factor_verify_enrollment_response.dart';
import '../models/update_backlog_entry_request.dart';
import '../models/update_category_request.dart';
import '../models/update_custom_status_request.dart';
import '../models/update_own_user_request.dart';
import '../models/update_user_admin_request.dart';

part 'fallback_client.g.dart';

@RestApi()
abstract class FallbackClient {
  factory FallbackClient(Dio dio, {String? baseUrl}) = _FallbackClient;

  /// Health
  @GET('/health')
  Future<void> healthHealth();

  /// ProxyImage
  @GET('/api/images/proxy')
  Future<void> apiImagesProxyProxyImage({@Query('url') required String url});

  /// Login
  @POST('/api/auth/login')
  Future<LoginResult> apiAuthLoginLogin({@Body() required LoginParams body});

  /// LoginVerify
  @POST('/api/auth/2fa/login-verify')
  Future<TokenResponse> apiAuth2FaLoginVerifyLoginVerify({
    @Body() required TwoFactorLoginVerifyParams body,
  });

  /// EnrollTwoFactor
  @POST('/api/auth/2fa/enroll')
  Future<TwoFactorEnrollResponse> apiAuth2FaEnrollEnrollTwoFactor();

  /// VerifyTwoFactor
  @POST('/api/auth/2fa/verify')
  Future<TwoFactorVerifyEnrollmentResponse> apiAuth2FaVerifyVerifyTwoFactor({
    @Body() required TwoFactorVerifyEnrollmentParams body,
  });

  /// DisableTwoFactor
  @POST('/api/auth/2fa/disable')
  Future<void> apiAuth2FaDisableDisableTwoFactor({
    @Body() required TwoFactorDisableParams body,
  });

  /// LogoutAllSessions
  @POST('/api/auth/logout-all')
  Future<void> apiAuthLogoutAllLogoutAllSessions();

  /// ListEntries
  @GET('/api/backlog/entries')
  Future<List<BacklogEntryResponse>> apiBacklogEntriesListEntries({
    @Query('status') String? status,
    @Query('space_id') int? spaceId,
  });

  /// CreateEntry
  @POST('/api/backlog/entries')
  Future<BacklogEntryResponse> apiBacklogEntriesCreateEntry({
    @Body() required CreateBacklogEntryRequest body,
    @Query('space_id') int? spaceId,
  });

  /// DeleteAllEntries
  @DELETE('/api/backlog/entries')
  Future<int> apiBacklogEntriesDeleteAllEntries({
    @Query('space_id') int? spaceId,
  });

  /// GetEntryDuplicates
  @GET('/api/backlog/entries/duplicates')
  Future<List<BacklogEntryResponse>>
  apiBacklogEntriesDuplicatesGetEntryDuplicates({
    @Query('title') required String title,
    @Query('steam_app_id') int? steamAppId,
    @Query('space_id') int? spaceId,
  });

  /// GetEntry
  @GET('/api/backlog/entries/{entry_id}')
  Future<BacklogEntryResponse> apiBacklogEntriesEntryIdGetEntry({
    @Path('entry_id') required int entryId,
    @Query('space_id') int? spaceId,
  });

  /// UpdateEntry
  @PUT('/api/backlog/entries/{entry_id}')
  Future<BacklogEntryResponse> apiBacklogEntriesEntryIdUpdateEntry({
    @Path('entry_id') required int entryId,
    @Body() required UpdateBacklogEntryRequest body,
    @Query('space_id') int? spaceId,
  });

  /// DeleteEntry
  @DELETE('/api/backlog/entries/{entry_id}')
  Future<void> apiBacklogEntriesEntryIdDeleteEntry({
    @Path('entry_id') required int entryId,
    @Query('space_id') int? spaceId,
  });

  /// GetCategoriesForEntry
  @GET('/api/backlog/entries/{entry_id}/categories')
  Future<List<CategoryResponse>>
  apiBacklogEntriesEntryIdCategoriesGetCategoriesForEntry({
    @Path('entry_id') required int entryId,
    @Query('space_id') int? spaceId,
  });

  /// AddCategoryToEntry
  @POST('/api/backlog/entries/{entry_id}/categories/{category_id}')
  Future<void> apiBacklogEntriesEntryIdCategoriesCategoryIdAddCategoryToEntry({
    @Path('entry_id') required int entryId,
    @Path('category_id') required int categoryId,
    @Query('space_id') int? spaceId,
  });

  /// RemoveCategoryFromEntry
  @DELETE('/api/backlog/entries/{entry_id}/categories/{category_id}')
  Future<void>
  apiBacklogEntriesEntryIdCategoriesCategoryIdRemoveCategoryFromEntry({
    @Path('entry_id') required int entryId,
    @Path('category_id') required int categoryId,
    @Query('space_id') int? spaceId,
  });

  /// ListCategories
  @GET('/api/backlog/categories')
  Future<List<CategoryResponse>> apiBacklogCategoriesListCategories({
    @Query('space_id') int? spaceId,
  });

  /// CreateCategory
  @POST('/api/backlog/categories')
  Future<CategoryResponse> apiBacklogCategoriesCreateCategory({
    @Body() required CreateCategoryRequest body,
    @Query('space_id') int? spaceId,
  });

  /// UpdateCategory
  @PUT('/api/backlog/categories/{category_id}')
  Future<CategoryResponse> apiBacklogCategoriesCategoryIdUpdateCategory({
    @Path('category_id') required int categoryId,
    @Body() required UpdateCategoryRequest body,
    @Query('space_id') int? spaceId,
  });

  /// DeleteCategory
  @DELETE('/api/backlog/categories/{category_id}')
  Future<void> apiBacklogCategoriesCategoryIdDeleteCategory({
    @Path('category_id') required int categoryId,
    @Query('space_id') int? spaceId,
  });

  /// GetEntriesForCategory
  @GET('/api/backlog/categories/{category_id}/entries')
  Future<List<BacklogEntryResponse>>
  apiBacklogCategoriesCategoryIdEntriesGetEntriesForCategory({
    @Path('category_id') required int categoryId,
    @Query('space_id') int? spaceId,
  });

  /// ListCustomStatuses
  @GET('/api/backlog/statuses')
  Future<List<CustomStatusResponse>> apiBacklogStatusesListCustomStatuses({
    @Query('space_id') int? spaceId,
  });

  /// CreateCustomStatus
  @POST('/api/backlog/statuses')
  Future<CustomStatusResponse> apiBacklogStatusesCreateCustomStatus({
    @Body() required CreateCustomStatusRequest body,
    @Query('space_id') int? spaceId,
  });

  /// UpdateCustomStatus
  @PUT('/api/backlog/statuses/{status_id}')
  Future<CustomStatusResponse> apiBacklogStatusesStatusIdUpdateCustomStatus({
    @Path('status_id') required int statusId,
    @Body() required UpdateCustomStatusRequest body,
    @Query('space_id') int? spaceId,
  });

  /// DeleteCustomStatus
  @DELETE('/api/backlog/statuses/{status_id}')
  Future<void> apiBacklogStatusesStatusIdDeleteCustomStatus({
    @Path('status_id') required int statusId,
    @Query('space_id') int? spaceId,
  });

  /// ListBackups
  @GET('/api/backups')
  Future<List<BackupSummary>> apiBackupsListBackups();

  /// CreateBackup
  @POST('/api/backups')
  Future<BackupSummary> apiBackupsCreateBackup();

  /// DownloadBackup
  @GET('/api/backups/{backup_id}/download')
  Future<void> apiBackupsBackupIdDownloadDownloadBackup({
    @Path('backup_id') required int backupId,
  });

  /// RestoreBackup
  @POST('/api/backups/{backup_id}/restore')
  Future<RestoreResult> apiBackupsBackupIdRestoreRestoreBackup({
    @Path('backup_id') required int backupId,
  });

  /// RenameBackup
  @PUT('/api/backups/{backup_id}')
  Future<BackupSummary> apiBackupsBackupIdRenameBackup({
    @Path('backup_id') required int backupId,
    @Body() required RenameBackupRequest body,
  });

  /// DeleteBackup
  @DELETE('/api/backups/{backup_id}')
  Future<void> apiBackupsBackupIdDeleteBackup({
    @Path('backup_id') required int backupId,
  });

  /// GetSpace
  @GET('/api/space')
  Future<SpaceResponse> apiSpaceGetSpace();

  /// InviteToSpace
  @POST('/api/space/invitations')
  Future<void> apiSpaceInvitationsInviteToSpace({
    @Body() required InviteToSpaceRequest body,
  });

  /// AcceptSpaceInvitation
  @POST('/api/space/invitations/accept')
  Future<SpaceResponse> apiSpaceInvitationsAcceptAcceptSpaceInvitation();

  /// LeaveSpace
  @DELETE('/api/space/membership')
  Future<void> apiSpaceMembershipLeaveSpace();

  /// GetOwnUser
  @GET('/api/user/me')
  Future<PublicUser> apiUserMeGetOwnUser();

  /// UpdateOwnUser
  @PUT('/api/user/me')
  Future<PublicUser> apiUserMeUpdateOwnUser({
    @Body() required UpdateOwnUserRequest body,
  });

  /// DeleteOwnUser
  @DELETE('/api/user/me')
  Future<void> apiUserMeDeleteOwnUser();

  /// GetUserByUsername
  @GET('/api/user/by-username/{username}')
  Future<PublicUsername> apiUserByUsernameGetUserByUsername({
    @Path('username') required String username,
  });

  /// ListAllUsers
  @GET('/api/admin/users')
  Future<List<PublicUser>> apiAdminUsersListAllUsers();

  /// CreateUserAdmin
  @POST('/api/admin/users')
  Future<PublicUser> apiAdminUsersCreateUserAdmin({
    @Body() required CreateUserRequest body,
  });

  /// GetUserByIdAdmin
  @GET('/api/admin/users/{user_id}')
  Future<PublicUser> apiAdminUsersUserIdGetUserByIdAdmin({
    @Path('user_id') required int userId,
  });

  /// UpdateUserAdmin
  @PUT('/api/admin/users/{user_id}')
  Future<PublicUser> apiAdminUsersUserIdUpdateUserAdmin({
    @Path('user_id') required int userId,
    @Body() required UpdateUserAdminRequest body,
  });

  /// DeleteUserAdmin
  @DELETE('/api/admin/users/{user_id}')
  Future<void> apiAdminUsersUserIdDeleteUserAdmin({
    @Path('user_id') required int userId,
  });

  /// SyncSteamPlaytimes
  @POST('/api/user/steam/sync')
  Future<List<BacklogEntryResponse>> apiUserSteamSyncSyncSteamPlaytimes();

  /// ImportSteamLibrary
  @POST('/api/user/steam/import')
  Future<List<BacklogEntryResponse>> apiUserSteamImportImportSteamLibrary();

  /// SyncSteamPlaytimesStream
  @POST('/api/user/steam/sync/stream')
  Future<void> apiUserSteamSyncStreamSyncSteamPlaytimesStream();

  /// ImportSteamLibraryStream
  @POST('/api/user/steam/import/stream')
  Future<void> apiUserSteamImportStreamImportSteamLibraryStream({
    @Body() required List<SteamWishlistItem>? body,
  });

  /// GetSteamAchievements
  @GET('/api/user/steam/achievements')
  Future<AchievementProgress> apiUserSteamAchievementsGetSteamAchievements({
    @Query('steam_app_id') required int steamAppId,
  });

  /// PreviewSteamWishlist
  @GET('/api/user/steam/wishlist/preview')
  Future<List<SteamPreviewItem>>
  apiUserSteamWishlistPreviewPreviewSteamWishlist();

  /// ImportSteamWishlistStream
  @POST('/api/user/steam/wishlist/import/stream')
  Future<void> apiUserSteamWishlistImportStreamImportSteamWishlistStream({
    @Body() required List<SteamWishlistItem> body,
  });

  /// PreviewSteamLibraryStream
  @POST('/api/user/steam/library/preview/stream')
  Future<void> apiUserSteamLibraryPreviewStreamPreviewSteamLibraryStream();

  /// GetSteamPlaytime
  @GET('/api/user/steam/playtime')
  Future<String?> apiUserSteamPlaytimeGetSteamPlaytime({
    @Query('steam_app_id') required int steamAppId,
  });

  /// GetPendingCount
  @GET('/api/igdb-sync/pending-count')
  Future<int> apiIgdbSyncPendingCountGetPendingCount();

  /// SyncIgdbDataStream
  @POST('/api/igdb-sync/stream')
  Future<void> apiIgdbSyncStreamSyncIgdbDataStream();

  /// GetCsvHeaders
  @POST('/api/csv/headers')
  Future<CsvHeadersResponse> apiCsvHeadersGetCsvHeaders({
    @Body() required CsvHeadersRequest body,
  });

  /// PreviewCsvStream
  @POST('/api/csv/preview/stream')
  Future<void> apiCsvPreviewStreamPreviewCsvStream({
    @Body() required MatchCsvRequest body,
  });

  /// SubmitCsvStream
  @POST('/api/csv/submit/stream')
  Future<void> apiCsvSubmitStreamSubmitCsvStream({
    @Body() required List<SubmitCsvEntry> body,
  });

  /// SearchGame
  @GET('/api/games/search')
  Future<List<IgdbSearchResult>> apiGamesSearchSearchGame({
    @Query('search_term') required String searchTerm,
  });

  /// EnrichedSearch
  @GET('/api/games/enriched-search')
  Future<List<EnrichedResult>> apiGamesEnrichedSearchEnrichedSearch({
    @Query('search_term') required String searchTerm,
    @Query('deep') bool? deep = false,
  });

  /// GetGame
  @GET('/api/games/{game_id}')
  Future<List<IgdbGameData>> apiGamesGameIdGetGame({
    @Path('game_id') required int gameId,
  });

  /// GetGameTimeToBeat
  @GET('/api/games/{game_id}/time-to-beat')
  Future<List<IgdbGameTimeToBeat>> apiGamesGameIdTimeToBeatGetGameTimeToBeat({
    @Path('game_id') required int gameId,
  });

  /// GetPlatform
  @GET('/api/games/platforms/{platform_id}')
  Future<List<IgdbPlatform>> apiGamesPlatformsPlatformIdGetPlatform({
    @Path('platform_id') required int platformId,
  });

  /// GetCover
  @GET('/api/games/covers/{cover_id}')
  Future<List<IgdbCover>> apiGamesCoversCoverIdGetCover({
    @Path('cover_id') required int coverId,
  });

  /// GetGenre
  @GET('/api/games/genres/{genre_id}')
  Future<List<IgdbGenre>> apiGamesGenresGenreIdGetGenre({
    @Path('genre_id') required int genreId,
  });

  /// GetSteamgriddbCovers
  @GET('/api/games/steamgriddb-covers')
  Future<List<String>> apiGamesSteamgriddbCoversGetSteamgriddbCovers({
    @Query('steam_app_id') required int steamAppId,
  });

  /// GetSteamgriddbCoversById
  @GET('/api/games/steamgriddb-covers-by-id')
  Future<List<String>> apiGamesSteamgriddbCoversByIdGetSteamgriddbCoversById({
    @Query('game_id') required int gameId,
  });

  /// SearchSteamgriddb
  @GET('/api/games/steamgriddb-search')
  Future<List<SteamGridDbSearchResult>>
  apiGamesSteamgriddbSearchSearchSteamgriddb({
    @Query('search_term') required String searchTerm,
  });

  /// GetGamePrice
  @GET('/api/games/{steam_app_id}/price')
  Future<GamePrice> apiGamesSteamAppIdPriceGetGamePrice({
    @Path('steam_app_id') required int steamAppId,
  });

  /// GetKeyShopPrices
  @GET('/api/games/key-shop-prices')
  Future<List<KeyShopOffer>> apiGamesKeyShopPricesGetKeyShopPrices({
    @Query('title') required String title,
  });

  /// GetSteamAppId
  @GET('/api/games/steam-app-id')
  Future<int?> apiGamesSteamAppIdGetSteamAppId({
    @Query('title') required String title,
  });

  /// CheckPrices
  @POST('/api/prices/check')
  Future<Map<String, int>> apiPricesCheckCheckPrices({
    @Header('X-Cron-Secret') String? xCronSecret,
  });
}
