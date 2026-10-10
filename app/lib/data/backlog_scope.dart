import 'package:backlog_manager/data/space_api.dart';
import 'package:backlog_manager/domain/space.dart';
import 'package:backlog_manager/routing/current_path.dart';
import 'package:backlog_manager/routing/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which backlog the library and the inspector work on: the id of the shared
/// space on the space page, null (the personal backlog) everywhere else.
final backlogScopeProvider = Provider<int?>((ref) {
  if (ref.watch(currentPathProvider) != AppRoutes.space) return null;
  return ref.watch(activeSpaceIdProvider);
});

/// Who shares the space the page shows: the user and the partner, or null on
/// the personal pages.
final spaceMembersProvider = Provider<({String me, String? partner})?>((ref) {
  if (ref.watch(backlogScopeProvider) == null) return null;
  final space = ref.watch(spaceProvider).value;
  final me = space?.members.where((member) => member.isMe).firstOrNull;
  if (me == null) return null;
  return (
    me: me.username,
    partner: space!.partnerIsActive ? space.partner!.username : null,
  );
});
