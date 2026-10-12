import 'dart:async';
import 'dart:typed_data';

import 'package:backlog_manager/api/api_error.dart';
import 'package:backlog_manager/auth/user_api.dart';
import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:backlog_manager/design/widgets/buttons.dart';
import 'package:backlog_manager/design/widgets/toast.dart';
import 'package:backlog_manager/features/common/user_avatar.dart';
import 'package:backlog_manager/platform/avatar_image.dart';
import 'package:backlog_manager/platform/image_file_picker.dart';
import 'package:backlog_manager/routing/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The control of the "Profile Picture" row of the account: the picture (or
/// the initial), "Choose Picture" and, while there is one, "Remove". The
/// chosen file is cropped to a square and scaled before it is sent.
class ProfilePictureControl extends ConsumerStatefulWidget {
  const ProfilePictureControl({required this.user, super.key});

  final SessionUser user;

  @override
  ConsumerState<ProfilePictureControl> createState() =>
      _ProfilePictureControlState();
}

class _ProfilePictureControlState extends ConsumerState<ProfilePictureControl> {
  bool _busy = false;

  Future<void> _run(Future<SessionUser> Function() change, String done) async {
    setState(() => _busy = true);
    String message;
    try {
      final user = await change();
      if (mounted) ref.read(sessionProvider.notifier).signIn(user);
      message = done;
    } on FormatException {
      message = 'That file is not a picture that can be used.';
    } on Object catch (error) {
      message = ApiException.from(error, 'The picture was not saved').message;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showShelfToast(context, message);
  }

  Future<void> _choose() async {
    final file = await ref.read(imageFilePickerProvider).pick();
    if (file == null || !mounted) return;
    await _run(() async {
      final bytes = await file.readBytes();
      final png = await squareAvatarPng(bytes);
      return ref
          .read(userApiProvider)
          .setAvatar(Uint8List.fromList(png), 'image/png');
    }, 'Profile picture saved');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final style = Theme.of(context).extension<ShelfTextStyles>()!;
    final user = widget.user;
    final initial = user.name.isEmpty ? '?' : user.name[0].toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(
          userId: user.id,
          version: user.avatarUpdatedAt,
          size: 48,
          fallback: SizedBox(
            width: 48,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tokens.accentA, tokens.accentB],
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: style.section.copyWith(color: tokens.onAccent),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        ShelfButton(
          key: const Key('profile-picture-choose'),
          label: _busy ? 'Saving...' : 'Choose Picture',
          onPressed: _busy ? null : () => unawaited(_choose()),
        ),
        if (user.avatarUpdatedAt != null) ...[
          const SizedBox(width: 8),
          ShelfButton(
            key: const Key('profile-picture-remove'),
            label: 'Remove',
            kind: ShelfButtonKind.danger,
            onPressed: _busy
                ? null
                : () => unawaited(
                    _run(
                      ref.read(userApiProvider).removeAvatar,
                      'Profile picture removed',
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
