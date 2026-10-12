import 'dart:typed_data';

import 'package:backlog_manager/auth/user_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What identifies one version of one user's profile picture.
typedef AvatarKey = ({int userId, DateTime version});

/// The bytes of a profile picture, read once per version: a new upload has a
/// new `avatarUpdatedAt`, so the key changes and the picture is read again.
final avatarBytesProvider = FutureProvider.family<Uint8List?, AvatarKey>(
  (ref, key) => ref.read(userApiProvider).avatar(key.userId),
);

/// A round profile picture of [size], or [fallback] (the initials) while the
/// user has none, while it loads and when it cannot be read.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    required this.fallback,
    required this.size,
    this.userId,
    this.version,
    super.key,
  });

  final int? userId;

  /// The version of the picture, null when the user has none.
  final DateTime? version;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    final stamp = version;
    if (id == null || id == 0 || stamp == null) return fallback;
    final bytes = ref
        .watch(avatarBytesProvider((userId: id, version: stamp)))
        .value;
    if (bytes == null) return fallback;
    return ClipOval(
      key: const Key('user-avatar-picture'),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
