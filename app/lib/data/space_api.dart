import 'dart:async';

import 'package:backlog_manager/api/api_providers.dart';
import 'package:backlog_manager/api/generated/export.dart' as wire;
import 'package:backlog_manager/api/mappers.dart';
import 'package:backlog_manager/auth/auth_controller.dart';
import 'package:backlog_manager/data/backlog_providers.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shared space of the signed-in user.
abstract interface class SpaceApi {
  Future<Space> get();

  /// Invites a user by username into the space, which is created if the
  /// caller has none.
  Future<void> invite(String username);

  Future<Space> accept();

  /// Leaves the space, or declines a pending invitation.
  Future<void> leave();
}

class ApiSpaceApi implements SpaceApi {
  const ApiSpaceApi(this._dio);

  final Future<Dio> Function() _dio;

  Future<wire.FallbackClient> _client() async =>
      wire.RestClient(await _dio()).fallback;

  @override
  Future<Space> get() async =>
      spaceFromResponse(await (await _client()).apiSpaceGetSpace());

  @override
  Future<void> invite(String username) async {
    await (await _client()).apiSpaceInvitationsInviteToSpace(
      body: wire.InviteToSpaceRequest(username: username),
    );
  }

  @override
  Future<Space> accept() async => spaceFromResponse(
    await (await _client()).apiSpaceInvitationsAcceptAcceptSpaceInvitation(),
  );

  @override
  Future<void> leave() async {
    await (await _client()).apiSpaceMembershipLeaveSpace();
  }
}

final spaceApiProvider = Provider<SpaceApi>(
  (ref) => ApiSpaceApi(() => ref.read(apiDioProvider.future)),
);

/// How often the space is read again so an invitation, a decline or the
/// partner leaving shows up without a reload.
const spaceRefreshInterval = Duration(seconds: 30);

bool _windowVisible() {
  final state = WidgetsBinding.instance.lifecycleState;
  return state != AppLifecycleState.hidden &&
      state != AppLifecycleState.paused &&
      state != AppLifecycleState.detached;
}

/// The space of the user, read again every [spaceRefreshInterval] while the
/// window is visible. Reading again keeps the old value on screen, a failed
/// read keeps it too.
class SpaceNotifier extends AsyncNotifier<Space> {
  @override
  Future<Space> build() async {
    ref.watch(sessionGenerationProvider);
    final timer = Timer.periodic(spaceRefreshInterval, (_) {
      if (_windowVisible()) unawaited(_refresh());
    });
    ref.onDispose(timer.cancel);
    return ref.watch(spaceApiProvider).get();
  }

  Future<void> _refresh() async {
    try {
      final next = await ref.read(spaceApiProvider).get();
      if (ref.mounted) state = AsyncData(next);
    } on Object {
      return;
    }
  }

  /// Reads the space now, for the screen the user is looking at.
  Future<void> refresh() => _refresh();

  Future<void> invite(String username) async {
    await ref.read(spaceApiProvider).invite(username);
    await _refresh();
  }

  Future<void> accept() async {
    final next = await ref.read(spaceApiProvider).accept();
    if (ref.mounted) state = AsyncData(next);
  }

  /// Leaves the space or declines the invitation and drops everything cached
  /// of the space, since its games are not the user's to see any more.
  Future<void> leave() async {
    final spaceId = state.value?.spaceId;
    await ref.read(spaceApiProvider).leave();
    if (!ref.mounted) return;
    if (spaceId != null) {
      ref
        ..invalidate(entriesProvider(spaceId))
        ..invalidate(categoriesProvider(spaceId))
        ..invalidate(entryCategoriesProvider(spaceId))
        ..invalidate(customStatusesProvider(spaceId));
    }
    ref.invalidate(entriesProvider(null));
    await _refresh();
  }
}

final spaceProvider = AsyncNotifierProvider<SpaceNotifier, Space>(
  SpaceNotifier.new,
);

/// The id of the space the user is an active member of, or null.
final activeSpaceIdProvider = Provider<int?>(
  (ref) => ref.watch(spaceProvider).value?.activeSpaceId,
);

/// Whether an invitation waits for an answer, for the dot in the sidebar.
final hasSpaceInvitationProvider = Provider<bool>(
  (ref) => ref.watch(spaceProvider).value?.stage == SpaceStage.invited,
);
