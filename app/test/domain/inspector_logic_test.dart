import 'package:backlog_manager/domain/entry_changes.dart';
import 'package:backlog_manager/domain/inspector_logic.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entryFormFrom', () {
    test('turns an entry into the values of the form', () {
      final form = entryFormFrom(
        const BacklogEntry(
          id: 1,
          title: 'Hades',
          imageLink: 'https://img.example/h.jpg',
          genre: ['Roguelike', 'Action'],
          platform: ['PC'],
          status: 'In Progress',
          owned: true,
          interest: 8,
          reviewStars: 9,
          review: 'Great',
          note: 'Replay',
          playtime: 18.5,
        ),
      );

      expect(form.imageLink, 'https://img.example/h.jpg');
      expect(form.genre, 'Roguelike, Action');
      expect(form.platform, 'PC');
      expect(form.status, 'In Progress');
      expect(form.owned, isTrue);
      expect(form.interest, 8);
      expect(form.reviewStars, 9);
      expect(form.review, 'Great');
      expect(form.note, 'Replay');
      expect(form.playtime, 18.5);
    });

    test('uses empty values for what the entry does not have', () {
      final form = entryFormFrom(const BacklogEntry(id: 1, title: 'Hades'));

      expect(form.reviewStars, 0);
      expect(form.review, '');
      expect(form.note, '');
      expect(form.playtime, isNull);
    });

    test('has no changes against its own entry', () {
      const entry = BacklogEntry(
        id: 1,
        title: 'Hades',
        genre: ['RPG'],
        playtime: 3,
        review: 'x',
      );

      expect(diffEntryForm(entryFormFrom(entry), entry).isEmpty, isTrue);
    });
  });

  group('EntryForm.copyWith', () {
    final form = entryFormFrom(const BacklogEntry(id: 1, title: 'Hades'));

    test('changes every field of the form', () {
      final next = form.copyWith(
        imageLink: 'https://img.example/new.jpg',
        genre: 'RPG',
        platform: 'PC',
        status: 'Completed',
        owned: true,
        interest: 5,
        reviewStars: 7,
        review: 'Good',
        note: 'n',
        playtime: 12,
      );

      expect(next.imageLink, 'https://img.example/new.jpg');
      expect(next.genre, 'RPG');
      expect(next.platform, 'PC');
      expect(next.status, 'Completed');
      expect(next.owned, isTrue);
      expect(next.interest, 5);
      expect(next.reviewStars, 7);
      expect(next.review, 'Good');
      expect(next.note, 'n');
      expect(next.playtime, 12);
    });

    test('clears the playtime on request', () {
      final with3 = form.copyWith(playtime: 3);
      expect(with3.copyWith(clearPlaytime: true).playtime, isNull);
    });
  });

  group('canReview', () {
    test('is only true for a completed game', () {
      expect(canReview('Completed'), isTrue);
      expect(canReview('In Progress'), isFalse);
      expect(canReview(''), isFalse);
    });
  });

  group('completedOnLabel', () {
    test('names the month and the year', () {
      expect(
        completedOnLabel(DateTime.utc(2026, 3, 14)),
        'Completed on March 2026',
      );
      expect(
        completedOnLabel(DateTime.utc(2025, 12, 1)),
        'Completed on December 2025',
      );
    });

    test('is null without a date', () {
      expect(completedOnLabel(null), isNull);
    });
  });

  group('the beat-time bars', () {
    test('fill by the share of the hours played, capped at the full bar', () {
      expect(beatFraction(22, 11), 0.5);
      expect(beatFraction(22, 44), 1);
      expect(beatFraction(22, null), 0);
    });

    test('are empty without hours to beat', () {
      expect(beatFraction(null, 10), 0);
      expect(beatFraction(0, 10), 0);
    });

    test('show the hours or two dashes', () {
      expect(beatHoursLabel(22), '22 h');
      expect(beatHoursLabel(7.5), '7.5 h');
      expect(beatHoursLabel(null), '--');
      expect(beatHoursLabel(0), '--');
    });
  });

  group('parsePlaytime', () {
    test('reads a number', () {
      expect(parsePlaytime('12.5'), 12.5);
      expect(parsePlaytime(' 3 '), 3);
    });

    test('is null for empty or unreadable text', () {
      expect(parsePlaytime(''), isNull);
      expect(parsePlaytime('abc'), isNull);
    });

    test('never goes below zero', () {
      expect(parsePlaytime('-4'), 0);
    });
  });

  group('rebaseForm', () {
    const base = BacklogEntry(
      id: 1,
      title: 'Hades',
      status: 'Not Started',
      owned: false,
      interest: 3,
      note: 'old',
    );
    final from = entryFormFrom(base);

    test('takes over what changed outside while the field was untouched', () {
      final to = from.copyWith(status: 'Completed');

      final form = rebaseForm(form: from, from: from, to: to);

      expect(form.status, 'Completed');
    });

    test('keeps what the user edited, even when it changed outside too', () {
      final edited = from.copyWith(note: 'mine', interest: 9);
      final to = from.copyWith(note: 'theirs', status: 'Dropped');

      final form = rebaseForm(form: edited, from: from, to: to);

      expect(form.note, 'mine');
      expect(form.interest, 9);
      expect(form.status, 'Dropped');
    });

    test('leaves a form alone when nothing changed outside', () {
      final edited = from.copyWith(review: 'Great', owned: true);

      expect(rebaseForm(form: edited, from: from, to: from).review, 'Great');
      expect(rebaseForm(form: edited, from: from, to: from).owned, isTrue);
    });

    test('follows an empty playtime that was filled outside', () {
      final to = from.copyWith(playtime: 4);

      expect(rebaseForm(form: from, from: from, to: to).playtime, 4);
    });

    test('keeps an edited playtime', () {
      final edited = from.copyWith(playtime: 7);
      final to = from.copyWith(playtime: 4);

      expect(rebaseForm(form: edited, from: from, to: to).playtime, 7);
    });
  });
}
