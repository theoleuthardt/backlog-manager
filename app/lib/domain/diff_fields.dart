class FieldDiffEntry {
  const FieldDiffEntry({
    required this.field,
    required this.existing,
    required this.proposed,
  });

  final String field;
  final String existing;
  final String proposed;

  @override
  bool operator ==(Object other) =>
      other is FieldDiffEntry &&
      other.field == field &&
      other.existing == existing &&
      other.proposed == proposed;

  @override
  int get hashCode => Object.hash(field, existing, proposed);

  @override
  String toString() => 'FieldDiffEntry($field: "$existing" -> "$proposed")';
}

/// The fields of an entry that a duplicate comparison looks at.
class DiffableFields {
  const DiffableFields({
    required this.genre,
    required this.platform,
    required this.status,
    required this.owned,
    this.playtime,
    this.reviewStars,
    this.note,
  });

  final List<String> genre;
  final List<String> platform;
  final String status;
  final bool owned;
  final num? playtime;
  final int? reviewStars;
  final String? note;

  DiffableFields copyWith({
    List<String>? genre,
    List<String>? platform,
    String? status,
    bool? owned,
  }) {
    return DiffableFields(
      genre: genre ?? this.genre,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      owned: owned ?? this.owned,
      playtime: playtime,
      reviewStars: reviewStars,
      note: note,
    );
  }
}

String _formatNumber(num? value) => value == null ? '' : value.toString();

String _yesNo(bool value) => value ? 'Yes' : 'No';

/// The fields that differ between [existing] and [proposed], with both sides
/// formatted for display.
List<FieldDiffEntry> computeFieldDiffs(
  DiffableFields existing,
  DiffableFields proposed,
) {
  final pairs = [
    ('genre', existing.genre.join(', '), proposed.genre.join(', ')),
    ('platform', existing.platform.join(', '), proposed.platform.join(', ')),
    ('status', existing.status, proposed.status),
    ('owned', _yesNo(existing.owned), _yesNo(proposed.owned)),
    (
      'playtime',
      _formatNumber(existing.playtime),
      _formatNumber(proposed.playtime),
    ),
    (
      'review_stars',
      _formatNumber(existing.reviewStars),
      _formatNumber(proposed.reviewStars),
    ),
    ('note', existing.note ?? '', proposed.note ?? ''),
  ];
  return [
    for (final (field, existingValue, proposedValue) in pairs)
      if (existingValue != proposedValue)
        FieldDiffEntry(
          field: field,
          existing: existingValue,
          proposed: proposedValue,
        ),
  ];
}
