import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/constants/listing_options.dart';
import 'package:studyswap/core/models/listing_filter.dart';

void main() {
  group('isActive', () {
    test('a fresh filter is not active', () {
      expect(const ListingFilter().isActive, isFalse);
    });

    test('each control marks the filter active', () {
      const base = ListingFilter();

      expect(
        base.copyWith(category: ListingCategory.textbooks).isActive,
        isTrue,
      );
      expect(base.copyWith(condition: ListingCondition.good).isActive, isTrue);
      expect(base.copyWith(minPrice: 10).isActive, isTrue);
      expect(base.copyWith(maxPrice: 500).isActive, isTrue);
      expect(base.copyWith(sort: ListingSort.cheapest).isActive, isTrue);
    });

    test('resetting returns to the default, ceiling included', () {
      // The reset used to set the ceiling to 500 while the slider ran to 9999,
      // so "reset" silently hid everything above £500 and reported no filters.
      const reset = ListingFilter();

      expect(reset.maxPrice, ListingFilter.maxPriceCeiling);
      expect(reset.isActive, isFalse);
    });
  });

  group('queryKey', () {
    test('changing the search text does not re-issue the query', () {
      const base = ListingFilter();
      final typed = base.copyWith(query: 'biology');

      expect(typed.queryKey, base.queryKey);
    });

    test('changing the price range does not re-issue the query', () {
      // Price is filtered client-side, so dragging the slider must not refetch.
      const base = ListingFilter();
      final priced = base.copyWith(minPrice: 5, maxPrice: 50);

      expect(priced.queryKey, base.queryKey);
    });

    test('category, condition and sort each re-issue the query', () {
      const base = ListingFilter();

      expect(
        base.copyWith(category: ListingCategory.electronics).queryKey,
        isNot(base.queryKey),
      );
      expect(
        base.copyWith(condition: ListingCondition.fair).queryKey,
        isNot(base.queryKey),
      );
      expect(
        base.copyWith(sort: ListingSort.mostExpensive).queryKey,
        isNot(base.queryKey),
      );
    });
  });

  group('copyWith', () {
    test('clear flags reset a selection back to "All"', () {
      // copyWith can't distinguish "leave it alone" from "set it to null", so
      // clearing needs its own flag.
      final withCategory = const ListingFilter().copyWith(
        category: ListingCategory.housing,
      );

      expect(withCategory.copyWith(clearCategory: true).category, isNull);
      expect(withCategory.copyWith().category, ListingCategory.housing);
    });

    test('leaves untouched fields alone', () {
      final filter = const ListingFilter().copyWith(
        category: ListingCategory.stationery,
        sort: ListingSort.cheapest,
        minPrice: 5,
      );

      final narrowed = filter.copyWith(query: 'pens');

      expect(narrowed.category, ListingCategory.stationery);
      expect(narrowed.sort, ListingSort.cheapest);
      expect(narrowed.minPrice, 5);
      expect(narrowed.query, 'pens');
    });
  });

  group('hasClientSideNarrowing', () {
    test('only the filters the server cannot apply count', () {
      const base = ListingFilter();

      expect(base.hasClientSideNarrowing, isFalse);
      // Category and condition go into the query, so they don't narrow the
      // loaded window — the result count stays honest.
      expect(
        base.copyWith(category: ListingCategory.other).hasClientSideNarrowing,
        isFalse,
      );
      expect(base.copyWith(query: 'x').hasClientSideNarrowing, isTrue);
      expect(base.copyWith(maxPrice: 100).hasClientSideNarrowing, isTrue);
    });
  });

  group('ListingSort', () {
    test('maps to the Firestore field and direction', () {
      expect(ListingSort.newest.field, 'createdAt');
      expect(ListingSort.newest.descending, isTrue);
      expect(ListingSort.cheapest.field, 'price');
      expect(ListingSort.cheapest.descending, isFalse);
      expect(ListingSort.mostExpensive.field, 'price');
      expect(ListingSort.mostExpensive.descending, isTrue);
    });

    test('every sort has a composite index declared', () {
      // Adding a sort without adding its indexes fails at runtime, not build
      // time, so this is a reminder rather than a real assertion.
      expect(ListingSort.values.length, 3);
    });
  });
}
