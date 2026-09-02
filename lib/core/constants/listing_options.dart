/// Shared vocabulary for listing categories and conditions.
///
/// The sell form and the marketplace filters used to hold two independent
/// string lists that never matched, so every filter returned nothing. Both
/// sides now read from these enums: [wire] is what goes to Firestore, [label]
/// is what the user sees.
library;

/// The category a listing belongs to.
enum ListingCategory {
  textbooks('textbooks', 'Textbooks'),
  studySummaries('study_summaries', 'Study Summaries'),
  electronics('electronics', 'Electronics'),
  stationery('stationery', 'Stationery'),
  housing('housing', 'Housing'),
  other('other', 'Other');

  const ListingCategory(this.wire, this.label);

  /// The value persisted in Firestore.
  final String wire;

  /// The value shown to the user.
  final String label;

  /// Parses a stored value, tolerating the legacy uppercase values
  /// (`TEXTBOOKS`, `ELECTRONICS`, …) written before the vocabularies merged.
  static ListingCategory? tryParse(Object? value) =>
      _lookup(value, ListingCategory.values, (c) => [c.wire, c.label]);

  /// The label for a stored value, falling back to [ListingCategory.other].
  static String labelFor(Object? value) =>
      tryParse(value)?.label ?? ListingCategory.other.label;
}

/// Where a listing is in its lifecycle.
enum ListingStatus {
  /// Visible in the marketplace and open to deal requests.
  active('active'),

  /// A deal has been accepted; held for that buyer.
  reserved('reserved'),

  /// The deal completed.
  sold('sold'),

  /// Taken down by a moderator.
  hidden('hidden');

  const ListingStatus(this.wire);

  /// The value persisted in Firestore.
  final String wire;

  /// Parses a stored value, defaulting to [active] for anything unrecognised —
  /// an unreadable status should not make a listing disappear.
  static ListingStatus fromWire(Object? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return ListingStatus.active;
  }

  /// Whether the listing should appear in the public marketplace feed.
  bool get isPubliclyVisible =>
      this == ListingStatus.active || this == ListingStatus.reserved;

  /// Whether a buyer can still open a deal on it.
  bool get acceptsDeals => this == ListingStatus.active;

  /// Display label for badges and overlays.
  String get label => switch (this) {
    ListingStatus.active => 'Active',
    ListingStatus.reserved => 'Reserved',
    ListingStatus.sold => 'Sold',
    ListingStatus.hidden => 'Hidden',
  };
}

/// The physical condition of a listed item.
enum ListingCondition {
  likeNew('like_new', 'Like New'),
  good('good', 'Good'),
  fair('fair', 'Fair'),
  poor('poor', 'Poor');

  const ListingCondition(this.wire, this.label);

  /// The value persisted in Firestore.
  final String wire;

  /// The value shown to the user.
  final String label;

  /// Parses a stored value, tolerating the legacy display-cased values
  /// (`Like New`, `Good`, …) written before the vocabularies merged.
  static ListingCondition? tryParse(Object? value) =>
      _lookup(value, ListingCondition.values, (c) => [c.wire, c.label]);

  /// The label for a stored value, or an empty string when unrecognised.
  static String labelFor(Object? value) => tryParse(value)?.label ?? '';
}

/// Matches [value] against every alias of every candidate, ignoring case and
/// the difference between spaces and underscores.
T? _lookup<T>(
  Object? value,
  List<T> candidates,
  List<String> Function(T) aliases,
) {
  if (value == null) return null;
  final needle = _normalise(value.toString());
  if (needle.isEmpty) return null;

  for (final candidate in candidates) {
    for (final alias in aliases(candidate)) {
      if (_normalise(alias) == needle) return candidate;
    }
  }
  return null;
}

String _normalise(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
