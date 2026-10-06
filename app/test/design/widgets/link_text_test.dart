import 'package:backlog_manager/design/widgets/link_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// The centre on screen of the characters [start] to [end] of the paragraph.
Offset centerOf(WidgetTester tester, {required int start, required int end}) {
  final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );
  return paragraph.localToGlobal(boxes.first.toRect().center);
}

void main() {
  final tokens = tokensOf('shelfOled');

  testWidgets(
    'writes plain parts in the faint colour and links in the accent',
    (tester) async {
      await pumpThemed(
        tester,
        LinkText(
          onOpen: (_) {},
          parts: const [
            LinkPart("Don't know your ID? Use "),
            LinkPart(
              "SteamDB's SteamID finder",
              url: 'https://steamdb.com/en/tools/steam-id-finder',
            ),
            LinkPart('.'),
          ],
        ),
        width: 400,
      );

      final text = tester.widget<Text>(find.byType(Text));
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect((text.textSpan! as TextSpan).style!.color, tokens.faint);
      expect(spans[0].style, isNull);
      expect(spans[1].style!.color, tokens.accent);
      expect(spans[1].style!.decoration, TextDecoration.underline);
    },
  );

  testWidgets('opens the address of a tapped link', (tester) async {
    Uri? opened;
    await pumpThemed(
      tester,
      LinkText(
        onOpen: (uri) => opened = uri,
        parts: const [
          LinkPart('Key on '),
          LinkPart('API page', url: 'https://steamcommunity.com/dev/apikey'),
        ],
      ),
      width: 400,
    );

    await tester.tapAt(centerOf(tester, start: 7, end: 15));

    expect(opened, Uri.parse('https://steamcommunity.com/dev/apikey'));
  });

  testWidgets('does nothing when plain text is tapped', (tester) async {
    Uri? opened;
    await pumpThemed(
      tester,
      LinkText(
        onOpen: (uri) => opened = uri,
        parts: const [
          LinkPart('Plain '),
          LinkPart('link', url: 'https://example.com'),
        ],
      ),
      width: 600,
    );

    await tester.tapAt(centerOf(tester, start: 0, end: 5));

    expect(opened, isNull);
  });
}
