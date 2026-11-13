import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/widgets/hero_text_blocks.dart';

import '../test_helpers/media_items.dart';

void main() {
  testWidgets('original title hidden when empty or equal to title', (tester) async {
    for (final originalTitle in <String?>[null, '', '  ', 'TITLE', ' title ']) {
      final item = testMediaItem(title: 'Title', originalTitle: originalTitle);
      await tester.pumpWidget(_shell(HeroOriginalTitle(item: item, displayTitle: 'Title', color: Colors.white)));

      expect(heroHasOriginalTitle(item, 'Title'), isFalse);
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(HeroOriginalTitle)), Size.zero);
    }
  });

  testWidgets('different original title is uppercase and follows supplied style', (tester) async {
    final item = testMediaItem(title: 'Title', originalTitle: '  Original Title  ');
    await tester.pumpWidget(
      _shell(
        HeroOriginalTitle(
          item: item,
          displayTitle: 'Title',
          color: Colors.white,
          fontSize: 10,
          textAlign: TextAlign.left,
        ),
      ),
    );

    expect(heroHasOriginalTitle(item, 'Title'), isTrue);
    final text = tester.widget<Text>(find.text('ORIGINAL TITLE'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.left);
    expect(text.style!.fontSize, 10);
    expect(text.style!.fontFamily, 'Georgia');
    expect(text.style!.fontFamilyFallback, ['Go Noto Current', 'serif']);
    expect(text.style!.color, Colors.white.withValues(alpha: .8));
  });

  testWidgets('summary respects max lines with actual paragraph overflow', (tester) async {
    final item = testMediaItem(summary: List.filled(40, 'A very long story with many details.').join(' '));
    await tester.pumpWidget(_shell(SizedBox(width: 180, child: _summary(item))));

    final richTextFinder = find.descendant(of: find.byType(HeroSummary), matching: find.byType(RichText));
    final richText = tester.widget<RichText>(richTextFinder);
    final paragraph = tester.renderObject<RenderParagraph>(richTextFinder);
    expect(richText.maxLines, 2);
    expect(richText.overflow, TextOverflow.ellipsis);
    expect(paragraph.didExceedMaxLines, isTrue);
  });

  testWidgets('summary inherits the system text scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _summary(testMediaItem(summary: 'An accessible summary.')),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(HeroSummary), matching: find.byType(RichText)),
    );
    expect(paragraph.textScaler.scale(13), 26);
  });

  testWidgets('visible episode summary includes a bold season and episode prefix', (tester) async {
    final item = testMediaItem(kind: MediaKind.episode, parentIndex: 1, index: 2, summary: 'The episode story.');
    await tester.pumpWidget(_shell(_summary(item)));

    final richText = tester.widget<RichText>(
      find.descendant(of: find.byType(HeroSummary), matching: find.byType(RichText)),
    );
    expect(richText.text.toPlainText(), 'S1, E2: The episode story.');
    final prefix = (richText.text as TextSpan).children!.first as TextSpan;
    expect(prefix.style!.fontWeight, FontWeight.bold);
  });

  testWidgets('spoiler hiding exposes only the episode identity with two lines', (tester) async {
    final item = testMediaItem(
      kind: MediaKind.episode,
      title: 'Episode title',
      parentIndex: 1,
      index: 2,
      summary: 'The hidden story.',
    );
    await tester.pumpWidget(_shell(_summary(item, hideSpoiler: true, maxLines: 3)));

    final text = tester.widget<Text>(find.text('S1, E2: Episode title'));
    expect(text.maxLines, 2);
    expect(find.textContaining('The hidden story.', findRichText: true), findsNothing);
    expect(heroHasSummary(item, true), isTrue);
  });

  testWidgets('empty summary has no text or reserved space', (tester) async {
    for (final summary in <String?>[null, '', '   ']) {
      final item = testMediaItem(summary: summary);
      await tester.pumpWidget(_shell(_summary(item)));

      expect(heroHasSummary(item, false), isFalse);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(RichText), findsNothing);
      expect(tester.getSize(find.byType(HeroSummary)), Size.zero);
    }
  });

  testWidgets('hidden episode identity is present without a summary', (tester) async {
    final item = testMediaItem(kind: MediaKind.episode, title: 'Episode title', parentIndex: 1, index: 2);
    await tester.pumpWidget(_shell(_summary(item, hideSpoiler: true)));
    expect(find.text('S1, E2: Episode title'), findsOneWidget);
  });

  testWidgets('spoiler hiding preserves empty content for missing episode indices', (tester) async {
    final item = testMediaItem(kind: MediaKind.episode, title: 'Episode title', summary: 'The hidden story.');
    await tester.pumpWidget(_shell(_summary(item, hideSpoiler: true)));
    expect(heroHasSummary(item, true), isFalse);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(RichText), findsNothing);
  });
}

Widget _shell(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

HeroSummary _summary(MediaItem item, {bool hideSpoiler = false, int maxLines = 2}) => HeroSummary(
  item: item,
  hideSpoiler: hideSpoiler,
  maxLines: maxLines,
  fontSize: 13,
  height: 1.4,
  color: Colors.white,
);
