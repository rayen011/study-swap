import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/constants/listing_options.dart';

void main() {
  group('ListingCategory', () {
    test('round-trips its own wire value', () {
      for (final category in ListingCategory.values) {
        expect(ListingCategory.tryParse(category.wire), category);
      }
    });

    test('parses its own display label', () {
      for (final category in ListingCategory.values) {
        expect(ListingCategory.tryParse(category.label), category);
      }
    });

    test('parses the legacy uppercase values written by the old sell form', () {
      // These are the four values the sell screen wrote before the sell form
      // and the marketplace filters shared a vocabulary.
      expect(ListingCategory.tryParse('TEXTBOOKS'), ListingCategory.textbooks);
      expect(
        ListingCategory.tryParse('ELECTRONICS'),
        ListingCategory.electronics,
      );
      expect(ListingCategory.tryParse('HOUSING'), ListingCategory.housing);
      expect(ListingCategory.tryParse('OTHER'), ListingCategory.other);
    });

    test('ignores spacing and separator differences', () {
      expect(
        ListingCategory.tryParse('Study Summaries'),
        ListingCategory.studySummaries,
      );
      expect(
        ListingCategory.tryParse('study_summaries'),
        ListingCategory.studySummaries,
      );
      expect(
        ListingCategory.tryParse('  STUDY-SUMMARIES  '),
        ListingCategory.studySummaries,
      );
    });

    test('returns null for unknown, empty and null values', () {
      expect(ListingCategory.tryParse('vehicles'), isNull);
      expect(ListingCategory.tryParse(''), isNull);
      expect(ListingCategory.tryParse('   '), isNull);
      expect(ListingCategory.tryParse(null), isNull);
    });

    test('labelFor falls back to Other so cards never render blank', () {
      expect(ListingCategory.labelFor('TEXTBOOKS'), 'Textbooks');
      expect(ListingCategory.labelFor(null), 'Other');
      expect(ListingCategory.labelFor('nonsense'), 'Other');
    });
  });

  group('ListingCondition', () {
    test('round-trips its own wire value and label', () {
      for (final condition in ListingCondition.values) {
        expect(ListingCondition.tryParse(condition.wire), condition);
        expect(ListingCondition.tryParse(condition.label), condition);
      }
    });

    test('parses the legacy display-cased values already in Firestore', () {
      expect(ListingCondition.tryParse('Like New'), ListingCondition.likeNew);
      expect(ListingCondition.tryParse('Good'), ListingCondition.good);
      expect(ListingCondition.tryParse('Fair'), ListingCondition.fair);
      expect(ListingCondition.tryParse('Poor'), ListingCondition.poor);
    });

    test('labelFor returns an empty string for unknown values', () {
      expect(ListingCondition.labelFor('Like New'), 'Like New');
      expect(ListingCondition.labelFor(null), '');
    });
  });

  group('sell form and marketplace filter agree', () {
    // The regression this whole file exists for: the sell screen writes
    // ListingCategory.wire, the home feed filters on the parsed enum. Every
    // value the sell form can produce must survive the round trip.
    test('every category the sell form can write is filterable', () {
      for (final written in ListingCategory.values.map((c) => c.wire)) {
        expect(
          ListingCategory.tryParse(written),
          isNotNull,
          reason: '"$written" would return zero results in the feed',
        );
      }
    });

    test('every condition the sell form can write is filterable', () {
      for (final written in ListingCondition.values.map((c) => c.wire)) {
        expect(
          ListingCondition.tryParse(written),
          isNotNull,
          reason: '"$written" would return zero results in the feed',
        );
      }
    });
  });
}
