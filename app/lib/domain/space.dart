import 'package:backlog_manager/domain/creation_form.dart';
import 'package:backlog_manager/domain/format.dart';
import 'package:backlog_manager/domain/models.dart';

/// Where the signed-in user stands with the shared space.
enum SpaceStage { none, invited, active }

/// What the screens say and do about the space of the signed-in user: none,
/// an invitation to answer, or a space they are part of (with a partner who
/// may still be invited).
extension SpaceView on Space {
  SpaceStage get stage => switch (myStatus) {
    'active' => SpaceStage.active,
    'invited' => SpaceStage.invited,
    _ => SpaceStage.none,
  };

  /// The id of the space whose games the user can see; null unless they have
  /// accepted.
  int? get activeSpaceId => stage == SpaceStage.active ? spaceId : null;

  SpaceMember? get partner {
    for (final member in members) {
      if (!member.isMe) return member;
    }
    return null;
  }

  bool get partnerIsActive => partner?.status == 'active';

  bool get waitingForPartner => partner?.status == 'invited';

  /// An active space nobody was invited into yet.
  bool get needsInvitation => stage == SpaceStage.active && partner == null;

  /// The partner's name, or "Shared space" while there is no active partner.
  String get controlLabel =>
      partnerIsActive ? partner!.username : 'Shared space';

  String get infoText => partnerIsActive
      ? 'Shared with ${partner!.username}. Status and categories are '
            'shared; rating and playtime stay your own.'
      : 'A shared co-op backlog for two. Status and categories are shared; '
            'rating and playtime stay your own.';

  String get leaveLabel =>
      waitingForPartner ? 'Cancel invitation' : 'Leave space';

  String get caption => partnerIsActive
      ? 'with ${partner!.username} - ratings and playtime stay your own'
      : 'ratings and playtime stay your own';

  String? get waitingLine => waitingForPartner
      ? 'Waiting for ${partner!.username} to accept your invitation'
      : null;

  String get invitationTitle =>
      '${partner?.username ?? 'Someone'} invited you to a shared space';
}

/// "TH" for "theo", the letters of the avatar of a member.
String memberInitials(String username) {
  if (username.isEmpty) return '?';
  final end = username.length < 2 ? username.length : 2;
  return username.substring(0, end).toUpperCase();
}

/// "12 h" beside the progress bar of a member.
String memberHoursLabel(double? hours) => '${formatHours(hours ?? 0)} h';

String sharedGamesLabel(int count) =>
    '$count shared ${count == 1 ? 'game' : 'games'}';

/// The username typed into the invitation form, or null when it is blank.
String? inviteName(String input) {
  final trimmed = input.trim();
  return trimmed.isEmpty ? null : trimmed;
}

const leaveWarning =
    'You lose access to its entries. They stay with your partner; once '
    'nobody is left they are deleted.';

const shareToSpaceHint = 'Only Steam games can be added to the shared space';

/// Only Steam games can live in a space.
bool canShareToSpace(BacklogEntry entry) => entry.steamAppId != null;

/// The copy of a personal game that goes into the space, with all its fields.
NewEntry sharedCopyOf(BacklogEntry entry) {
  return NewEntry(
    title: entry.title,
    genre: entry.genre,
    platform: entry.platform,
    status: entry.status,
    owned: entry.owned,
    interest: entry.interest,
    playtime: entry.playtime ?? 0,
    steamAppId: entry.steamAppId,
    imageLink: entry.imageLink.isEmpty ? null : entry.imageLink,
    description: entry.description,
    trailerLink: entry.trailerLink,
    mainTime: entry.mainTime,
    mainPlusExtraTime: entry.mainPlusExtraTime,
    completionTime: entry.completionTime,
    reviewStars: entry.reviewStars,
    review: entry.review,
    note: entry.note,
  );
}

String sharedToastMessage(String title) =>
    'Added "$title" to your shared space';
