import 'package:backlog_manager/domain/models.dart';
import 'package:backlog_manager/domain/split_list.dart';

/// The values of the entry dialog's form; list fields are comma separated
/// text.
class EntryForm {
  const EntryForm({
    required this.imageLink,
    required this.genre,
    required this.platform,
    required this.status,
    required this.owned,
    required this.interest,
    required this.reviewStars,
    required this.review,
    required this.note,
    this.playtime,
  });

  final String imageLink;
  final double? playtime;
  final String genre;
  final String platform;
  final String status;
  final bool owned;
  final int interest;
  final int reviewStars;
  final String review;
  final String note;

  EntryForm copyWith({
    String? genre,
    String? platform,
    String? status,
    String? note,
    bool clearPlaytime = false,
  }) {
    return EntryForm(
      imageLink: imageLink,
      playtime: clearPlaytime ? null : playtime,
      genre: genre ?? this.genre,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      owned: owned,
      interest: interest,
      reviewStars: reviewStars,
      review: review,
      note: note ?? this.note,
    );
  }
}

/// The fields of the form that differ from the stored entry, in the shape the
/// update call takes; null fields stay untouched.
class EntryFormChanges {
  const EntryFormChanges({
    this.imageLink,
    this.genre,
    this.platform,
    this.status,
    this.owned,
    this.interest,
    this.playtime,
    this.reviewStars,
    this.review,
    this.note,
  });

  final String? imageLink;
  final List<String>? genre;
  final List<String>? platform;
  final String? status;
  final bool? owned;
  final int? interest;
  final double? playtime;
  final int? reviewStars;
  final String? review;
  final String? note;

  /// True when there is nothing to save.
  bool get isEmpty =>
      imageLink == null &&
      genre == null &&
      platform == null &&
      status == null &&
      owned == null &&
      interest == null &&
      playtime == null &&
      reviewStars == null &&
      review == null &&
      note == null;
}

EntryFormChanges diffEntryForm(EntryForm form, BacklogEntry entry) {
  return EntryFormChanges(
    imageLink: form.imageLink != entry.imageLink ? form.imageLink : null,
    playtime: form.playtime != null && form.playtime != entry.playtime
        ? form.playtime
        : null,
    genre: form.genre != entry.genre.join(', ') ? splitList(form.genre) : null,
    platform: form.platform != entry.platform.join(', ')
        ? splitList(form.platform)
        : null,
    status: form.status != entry.status ? form.status : null,
    owned: form.owned != entry.owned ? form.owned : null,
    interest: form.interest != entry.interest ? form.interest : null,
    reviewStars: form.reviewStars != (entry.reviewStars ?? 0)
        ? form.reviewStars
        : null,
    review: form.review != (entry.review ?? '') ? form.review : null,
    note: form.note != (entry.note ?? '') ? form.note : null,
  );
}
