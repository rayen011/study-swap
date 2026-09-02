import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/features/profile/data/rating_repository.dart';

void main() {
  group('getTitleForDeals', () {
    test('awards a title at every tier boundary', () {
      expect(RatingRepository.getTitleForDeals(0), 'Freshman Trader');
      expect(RatingRepository.getTitleForDeals(2), 'Freshman Trader');
      expect(RatingRepository.getTitleForDeals(3), 'Campus Seller');
      expect(RatingRepository.getTitleForDeals(7), 'Campus Seller');
      expect(RatingRepository.getTitleForDeals(8), 'Trade Regular');
      expect(RatingRepository.getTitleForDeals(15), 'Trade Regular');
      expect(RatingRepository.getTitleForDeals(16), 'Deal Maker');
      expect(RatingRepository.getTitleForDeals(30), 'Deal Maker');
      expect(RatingRepository.getTitleForDeals(31), 'Campus Pro');
      expect(RatingRepository.getTitleForDeals(4000), 'Campus Pro');
    });

    test('never regresses as the deal count grows', () {
      const order = [
        'Freshman Trader',
        'Campus Seller',
        'Trade Regular',
        'Deal Maker',
        'Campus Pro',
      ];
      var highest = 0;
      for (var deals = 0; deals <= 60; deals++) {
        final rank = order.indexOf(RatingRepository.getTitleForDeals(deals));
        expect(rank, greaterThanOrEqualTo(highest), reason: 'at $deals deals');
        highest = rank;
      }
    });
  });
}
