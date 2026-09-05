import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/constants/auction_rules.dart';
import 'package:studyswap/core/constants/credit_rules.dart';

void main() {
  group('the minimum bid', () {
    test('an auction with no bids can be met at its starting price', () {
      // The seller named it, so matching it is a real offer — asking for the
      // increment on top would mean the starting price is never the price.
      expect(AuctionRules.minimumBid(20), 20);
    });

    test('small bids step by a pound', () {
      // 5% of £10 is 50p, so the flat minimum is what bites down here.
      expect(AuctionRules.minimumBid(10, 10), 11);
      expect(AuctionRules.minimumBid(10, 15), 16);
    });

    test('large bids step by five percent', () {
      expect(AuctionRules.minimumBid(10, 100), 105);
      expect(AuctionRules.minimumBid(10, 500), 525);
    });

    test('the crossover is where five percent passes a pound', () {
      // £20 is exactly £1. Below it the flat minimum wins, above it the
      // percentage does, and the step is never smaller than a pound.
      expect(AuctionRules.minimumBid(10, 20), 21);
      expect(AuctionRules.minimumBid(10, 21), 23);
    });

    test('never asks for pennies', () {
      // A £52.55 minimum invites a £52.56 bid and reads as noise.
      expect(AuctionRules.minimumBid(10, 50.10), 53);
      expect(AuctionRules.minimumBid(10, 12.5), 14);
    });
  });

  group('the opening price', () {
    test('cannot be higher than anybody could ever bid', () {
      // A floor opened above the maximum possible bid is a floor nobody in the
      // app is able to bid on.
      expect(AuctionRules.maxStartPrice, CreditRules.maxBid);
    });

    test('has a floor of its own', () {
      expect(AuctionRules.minStartPrice, 1);
    });
  });

  group('durations', () {
    test('are the three the seller can pick', () {
      expect(
        AuctionRules.durations.map((d) => d.hours),
        containsAllInOrder([24, 72, 168]),
      );
    });

    test('convert to real durations', () {
      expect(AuctionRules.durations.last.duration, const Duration(days: 7));
    });
  });

  /// `functions/src/auctions.ts` re-runs every one of these checks server-side,
  /// where the client cannot reach them. The Dart copy exists so the app can
  /// grey out a bid button before a round trip — which makes it a copy, and a
  /// copy of numbers nobody checks eventually disagrees.
  group('the Dart mirror matches the server', () {
    test('every server constant is mirrored', () {
      final source = File('functions/src/auctions.ts').readAsStringSync();

      final block = RegExp(
        r'export const AUCTION = \{(.*?)\} as const;',
        dotAll: true,
      ).firstMatch(source);
      expect(
        block,
        isNotNull,
        reason:
            'AUCTION was renamed or restructured in auctions.ts — this '
            'test parses it, so update the pattern along with the source.',
      );

      // Underscore separators are legal in TypeScript numbers (120_000) and
      // are how the source reads; strip them before comparing.
      final server = {
        for (final field in RegExp(
          r'(\w+):\s*([\d_]+),',
        ).allMatches(block!.group(1)!))
          field.group(1)!: int.parse(field.group(2)!.replaceAll('_', '')),
      };

      expect(server, {
        'minIncrement': AuctionRules.minIncrement,
        'incrementPercent': AuctionRules.incrementPercent,
        'snipeWindowMs': AuctionRules.snipeWindowMs,
        'maxExtensionMs': AuctionRules.maxExtensionMs,
        'minStartPrice': AuctionRules.minStartPrice,
        'closeBatchSize': AuctionRules.closeBatchSize,
      });
    });

    test('the durations offered are the same list', () {
      final source = File('functions/src/auctions.ts').readAsStringSync();

      final block = RegExp(
        r'AUCTION_DURATIONS_HOURS = \[(.*?)\]',
        dotAll: true,
      ).firstMatch(source);
      expect(block, isNotNull);

      final hours = RegExp(r'\d+')
          .allMatches(block!.group(1)!)
          .map((m) => int.parse(m.group(0)!))
          .toList();

      expect(hours, AuctionRules.durations.map((d) => d.hours).toList());
    });
  });
}
