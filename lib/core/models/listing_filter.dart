import 'package:equatable/equatable.dart';

import '../constants/listing_options.dart';

/// What the marketplace feed is currently asking for.
///
/// The split between server and client is deliberate and constrained by
/// Firestore:
///
/// * [category], [condition] and [sort] go into the query. They're equality
///   filters plus an `orderBy`, which composite indexes handle.
/// * [minPrice] / [maxPrice] stay client-side. Firestore requires the first
///   `orderBy` to be the range field, so a price range would silently override
///   the user's chosen sort — showing cheapest-first when they asked for
///   newest.
/// * [query] stays client-side too. Firestore has no full-text search; doing
///   this properly means Algolia or Typesense.
///
/// The client-side half filters the loaded window, so the feed tells the user
/// when a filter is narrowing loaded results rather than the whole catalogue.
class ListingFilter extends Equatable {
  const ListingFilter({
    this.category,
    this.condition,
    this.minPrice = 0,
    this.maxPrice = maxPriceCeiling,
    this.sort = ListingSort.newest,
    this.query = '',
  });

  /// Matches the sell form's upper bound, and the ceiling in `firestore.rules`.
  static const double maxPriceCeiling = 9999;

  /// Null means every category.
  final ListingCategory? category;

  /// Null means every condition.
  final ListingCondition? condition;

  final double minPrice;
  final double maxPrice;
  final ListingSort sort;

  /// Lowercased free-text search over title and category.
  final String query;

  /// Whether anything is narrowing the feed.
  bool get isActive =>
      category != null ||
      condition != null ||
      minPrice > 0 ||
      maxPrice < maxPriceCeiling ||
      sort != ListingSort.newest;

  /// Whether any of the client-side-only filters are on. When true, the result
  /// count reflects the loaded window rather than the whole catalogue.
  bool get hasClientSideNarrowing =>
      minPrice > 0 || maxPrice < maxPriceCeiling || query.isNotEmpty;

  /// The part of the filter the Firestore query depends on.
  ///
  /// Changing only [query] or the price bounds must not re-issue the query —
  /// that would refetch the whole window on every keystroke.
  Object get queryKey => (category, condition, sort);

  ListingFilter copyWith({
    ListingCategory? category,
    ListingCondition? condition,
    double? minPrice,
    double? maxPrice,
    ListingSort? sort,
    String? query,
    bool clearCategory = false,
    bool clearCondition = false,
  }) {
    return ListingFilter(
      category: clearCategory ? null : (category ?? this.category),
      condition: clearCondition ? null : (condition ?? this.condition),
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      sort: sort ?? this.sort,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [
    category,
    condition,
    minPrice,
    maxPrice,
    sort,
    query,
  ];
}
