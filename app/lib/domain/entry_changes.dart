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
    this.title = '',
    this.publisher = '',
    this.playtime,
  });

  final String imageLink;
  final double? playtime;
  final String title;
  final String genre;
  final String platform;
  final String publisher;
  final String status;
  final bool owned;
  final int interest;
  final int reviewStars;
  final String review;
  final String note;

  EntryForm copyWith({
    String? imageLink,
    String? title,
    String? genre,
    String? platform,
    String? publisher,
    String? status,
    bool? owned,
    int? interest,
    int? reviewStars,
    String? review,
    String? note,
    double? playtime,
    bool clearPlaytime = false,
  }) {
    return EntryForm(
      imageLink: imageLink ?? this.imageLink,
      playtime: clearPlaytime ? null : playtime ?? this.playtime,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      platform: platform ?? this.platform,
      publisher: publisher ?? this.publisher,
      status: status ?? this.status,
      owned: owned ?? this.owned,
      interest: interest ?? this.interest,
      reviewStars: reviewStars ?? this.reviewStars,
      review: review ?? this.review,
      note: note ?? this.note,
    );
  }
}

/// The fields of the form that differ from the stored entry, in the shape the
/// update call takes; null fields stay untouched.
class EntryFormChanges {
  const EntryFormChanges({
    this.imageLink,
    this.title,
    this.genre,
    this.platform,
    this.publisher,
    this.status,
    this.owned,
    this.interest,
    this.playtime,
    this.reviewStars,
    this.review,
    this.note,
  });

  final String? imageLink;
  final String? title;
  final List<String>? genre;
  final List<String>? platform;
  final String? publisher;
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
      title == null &&
      genre == null &&
      platform == null &&
      publisher == null &&
      status == null &&
      owned == null &&
      interest == null &&
      playtime == null &&
      reviewStars == null &&
      review == null &&
      note == null;
}

/// The title as it would be stored: a blank title is never a change, the game
/// keeps the one it has.
String? _changedTitle(String typed, String stored) {
  final title = typed.trim();
  return title.isEmpty || title == stored ? null : title;
}

EntryFormChanges diffEntryForm(EntryForm form, BacklogEntry entry) {
  return EntryFormChanges(
    imageLink: form.imageLink != entry.imageLink ? form.imageLink : null,
    title: _changedTitle(form.title, entry.title),
    playtime: form.playtime != null && form.playtime != entry.playtime
        ? form.playtime
        : null,
    genre: form.genre != entry.genre.join(', ') ? splitList(form.genre) : null,
    platform: form.platform != entry.platform.join(', ')
        ? splitList(form.platform)
        : null,
    publisher: form.publisher != (entry.publisher ?? '')
        ? form.publisher.trim()
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
