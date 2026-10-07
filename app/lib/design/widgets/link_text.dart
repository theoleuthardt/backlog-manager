import 'package:backlog_manager/design/shelf_text.dart';
import 'package:backlog_manager/design/shelf_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A piece of a [LinkText]: plain text, or a link when it has a [url].
class LinkPart {
  const LinkPart(this.text, {this.url});

  final String text;
  final String? url;
}

/// A paragraph of hint text with links inside it. [onOpen] opens an address
/// (the app passes the URL launcher, tests a recorder).
class LinkText extends StatefulWidget {
  const LinkText({required this.parts, required this.onOpen, super.key});

  final List<LinkPart> parts;
  final void Function(Uri uri) onOpen;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ShelfTokens>()!;
    final text = Theme.of(context).extension<ShelfTextStyles>()!;
    _disposeRecognizers();

    return Text.rich(
      TextSpan(
        style: text.caption.copyWith(color: tokens.faint),
        children: [
          for (final part in widget.parts)
            if (part.url == null)
              TextSpan(text: part.text)
            else
              TextSpan(
                text: part.text,
                style: TextStyle(
                  color: tokens.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: tokens.accent,
                ),
                recognizer: _recognizer(Uri.parse(part.url!)),
              ),
        ],
      ),
    );
  }

  TapGestureRecognizer _recognizer(Uri uri) {
    final recognizer = TapGestureRecognizer()..onTap = () => widget.onOpen(uri);
    _recognizers.add(recognizer);
    return recognizer;
  }
}
