import 'package:backlog_manager/domain/diff_fields.dart';
import 'package:backlog_manager/domain/entry_changes.dart';
import 'package:backlog_manager/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> changedFields(EntryFormChanges changes) {
  return {
    'imageLink': changes.imageLink,
    'genre': changes.genre,
    'platform': changes.platform,
    'status': changes.status,
    'owned': changes.owned,
    'interest': changes.interest,
    'playtime': changes.playtime,
    'reviewStars': changes.reviewStars,
    'review': changes.review,
    'note': changes.note,
  }..removeWhere((_, value) => value == null);
}

void main() {
  group('computeFieldDiffs', () {
    const baseline = DiffableFields(
      genre: ['Platformer'],
      platform: ['PC'],
      status: 'Completed',
      owned: true,
      playtime: 12.5,
      reviewStars: 8,
      note: 'Great game',
    );

    test('returns no diffs when both sides are identical', () {
      expect(computeFieldDiffs(baseline, baseline), isEmpty);
    });

    test('reports only the fields that differ', () {
      final proposed = baseline.copyWith(status: 'In Progress', owned: false);

      final diffs = computeFieldDiffs(baseline, proposed);

      expect(diffs, [
        const FieldDiffEntry(
          field: 'status',
          existing: 'Completed',
          proposed: 'In Progress',
        ),
        const FieldDiffEntry(field: 'owned', existing: 'Yes', proposed: 'No'),
      ]);
    });

    test('joins genre and platform arrays for comparison and display', () {
      final proposed = baseline.copyWith(genre: ['Platformer', 'Metroidvania']);

      expect(computeFieldDiffs(baseline, proposed), [
        const FieldDiffEntry(
          field: 'genre',
          existing: 'Platformer',
          proposed: 'Platformer, Metroidvania',
        ),
      ]);
    });

    test('shows a whole number of hours without a decimal part', () {
      final proposed = DiffableFields(
        genre: baseline.genre,
        platform: baseline.platform,
        status: baseline.status,
        owned: baseline.owned,
        playtime: 12.0,
        reviewStars: baseline.reviewStars,
        note: baseline.note,
      );

      expect(computeFieldDiffs(baseline, proposed), [
        const FieldDiffEntry(
          field: 'playtime',
          existing: '12.5',
          proposed: '12',
        ),
      ]);
    });

    test(
      "treats missing playtime/reviewStars/note as empty rather than 'null'",
      () {
        const existing = DiffableFields(
          genre: ['Platformer'],
          platform: ['PC'],
          status: 'Completed',
          owned: true,
        );

        expect(computeFieldDiffs(existing, baseline), [
          const FieldDiffEntry(
            field: 'playtime',
            existing: '',
            proposed: '12.5',
          ),
          const FieldDiffEntry(
            field: 'review_stars',
            existing: '',
            proposed: '8',
          ),
          const FieldDiffEntry(
            field: 'note',
            existing: '',
            proposed: 'Great game',
          ),
        ]);
      },
    );
  });

  group('diffEntryForm', () {
    const entry = BacklogEntry(
      id: 1,
      title: 'Celeste',
      imageLink: 'https://example.com/a.jpg',
      playtime: 4,
      genre: ['Platformer', 'Indie'],
      platform: ['PC'],
      status: 'Not Started',
      owned: true,
      interest: 5,
      reviewStars: 0,
      review: '',
      note: '',
    );

    const unchanged = EntryForm(
      imageLink: 'https://example.com/a.jpg',
      playtime: 4,
      genre: 'Platformer, Indie',
      platform: 'PC',
      status: 'Not Started',
      owned: true,
      interest: 5,
      reviewStars: 0,
      review: '',
      note: '',
    );

    test('returns no changes for an untouched form', () {
      expect(diffEntryForm(unchanged, entry).isEmpty, isTrue);
    });

    test('only includes the fields that differ', () {
      final changes = diffEntryForm(
        unchanged.copyWith(status: 'Completed', note: 'great'),
        entry,
      );

      expect(changedFields(changes), {'status': 'Completed', 'note': 'great'});
    });

    test('splits genre and platform lists', () {
      final changes = diffEntryForm(
        unchanged.copyWith(genre: 'RPG,  Action', platform: 'PC, Switch'),
        entry,
      );

      expect(changedFields(changes), {
        'genre': ['RPG', 'Action'],
        'platform': ['PC', 'Switch'],
      });
    });

    test('ignores an unset playtime', () {
      expect(
        diffEntryForm(unchanged.copyWith(clearPlaytime: true), entry).isEmpty,
        isTrue,
      );
    });

    test('treats missing entry values as their form defaults', () {
      const bare = BacklogEntry(id: 2, title: 'Bare', status: '');

      const form = EntryForm(
        imageLink: '',
        genre: '',
        platform: '',
        status: '',
        owned: false,
        interest: 0,
        reviewStars: 0,
        review: '',
        note: '',
      );

      expect(diffEntryForm(form, bare).isEmpty, isTrue);
    });
  });
}
