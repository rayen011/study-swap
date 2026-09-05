import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/constants/credit_rules.dart';

void main() {
  group('what a bid costs', () {
    test('a stake is a tenth of the bid', () {
      expect(CreditRules.stakeFor(100), 10);
      expect(CreditRules.stakeFor(250), 25);
    });

    test('a fractional stake rounds up, never down', () {
      // Rounding down would let a run of small bids lock less than they should.
      expect(CreditRules.stakeFor(1), 1);
      expect(CreditRules.stakeFor(24.5), 3);
      expect(CreditRules.stakeFor(0), 0);
    });
  });

  group('the ceiling', () {
    test('a new account can bid, but not wildly', () {
      expect(CreditRules.maxBidFor(CreditRules.startingBalance), 500);
    });

    test('reputation raises the ceiling', () {
      expect(CreditRules.maxBidFor(135), 1350);
    });

    test('but only up to the hard cap', () {
      // The whole point: no reputation, however long, unlocks a £90,000 bid.
      expect(CreditRules.maxBidFor(900), CreditRules.maxBid);
      expect(CreditRules.maxBidFor(999999), CreditRules.maxBid);
    });

    test('an empty balance can bid nothing', () {
      expect(CreditRules.maxBidFor(0), 0);
    });

    test(
      'a negative balance is treated as empty, not as a negative ceiling',
      () {
        expect(CreditRules.maxBidFor(-50), 0);
      },
    );
  });

  group('reviews', () {
    test('four and five stars pay, three and below do not', () {
      expect(CreditRules.forReview(5), CreditRules.fiveStarReview);
      expect(CreditRules.forReview(4), CreditRules.fourStarReview);
      expect(CreditRules.forReview(3), 0);
      expect(CreditRules.forReview(1), 0);
    });

    test('a stored average rounds to the nearest star', () {
      expect(CreditRules.forReview(4.6), CreditRules.fiveStarReview);
      expect(CreditRules.forReview(3.5), CreditRules.fourStarReview);
    });
  });

  // ── The copy that matters ────────────────────────────────────────────────

  /// `functions/src/credits.ts` is the authority: it writes every balance in
  /// Firestore. The Dart constants exist only so the app can explain the rules
  /// without a round trip, which makes them a copy — and a copy of numbers
  /// nobody checks is a copy that will eventually be wrong.
  ///
  /// This reads the TypeScript source and compares the two. It is the same
  /// argument that removed the duplicated `titleForDeals` from the client;
  /// here the duplication buys something, so it gets a test instead.
  group('the Dart mirror matches the server', () {
    late Map<String, int> server;

    setUpAll(() {
      final source = File('functions/src/credits.ts').readAsStringSync();

      final block = RegExp(
        r'export const CREDITS = \{(.*?)\} as const;',
        dotAll: true,
      ).firstMatch(source);
      expect(
        block,
        isNotNull,
        reason:
            'CREDITS was renamed or restructured in credits.ts — this '
            'test parses it, so update the pattern along with the source.',
      );

      server = {
        for (final field in RegExp(
          r'(\w+):\s*(\d+),',
        ).allMatches(block!.group(1)!))
          field.group(1)!: int.parse(field.group(2)!),
      };
    });

    test('every server constant is mirrored', () {
      expect(server, {
        'startingBalance': CreditRules.startingBalance,
        'sellerCompletion': CreditRules.sellerCompletion,
        'buyerCompletion': CreditRules.buyerCompletion,
        'fiveStarReview': CreditRules.fiveStarReview,
        'fourStarReview': CreditRules.fourStarReview,
        'stakePercent': CreditRules.stakePercent,
        'bidMultiplier': CreditRules.bidMultiplier,
        'maxBid': CreditRules.maxBid,
      });
    });

    test('the rules pin the same opening balance the client writes', () {
      // firestore.rules accepts exactly one value for a new account's balance.
      // If that number and CreditRules.startingBalance disagree, every signup
      // fails with a permission error and no test above would notice.
      final rules = File('firestore.rules').readAsStringSync();

      expect(
        rules,
        contains(
          'request.resource.data.credits == ${CreditRules.startingBalance}',
        ),
      );
      expect(rules, contains('request.resource.data.creditsLocked == 0'));
    });
  });
}
