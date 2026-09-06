import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/models/auction.dart';
import 'package:studyswap/core/models/message.dart';

void main() {
  final now = DateTime(2026, 9, 3, 12);

  Map<String, dynamic> doc([Map<String, dynamic> overrides = const {}]) => {
    'listingId': 'listing-1',
    'sellerId': 'amina',
    'startPrice': 20,
    'bidCount': 0,
    'status': 'live',
    'endsAt': Timestamp.fromDate(now.add(const Duration(hours: 6))),
    'extensionsMs': 0,
    'hasReserve': false,
    'createdAt': Timestamp.fromDate(now),
    ...overrides,
  };

  group('Auction.fromMap', () {
    test('reads an open floor', () {
      final auction = Auction.fromMap('a1', doc());

      expect(auction.status, AuctionStatus.live);
      expect(auction.startPrice, 20);
      expect(auction.hasBids, isFalse);
      expect(auction.displayPrice, 20);
      expect(auction.minimumBid, 20);
    });

    test('a leading bid becomes the price to beat', () {
      final auction = Auction.fromMap(
        'a1',
        doc({'currentBid': 50, 'currentBidderId': 'ben', 'bidCount': 3}),
      );

      expect(auction.hasBids, isTrue);
      expect(auction.displayPrice, 50);
      expect(auction.minimumBid, 53);
      expect(auction.isLeading('ben'), isTrue);
      expect(auction.isLeading('chloe'), isFalse);
    });

    test('an empty currentBid is absent, not zero', () {
      // Zero would read as "somebody bid nothing" and would break the
      // starting-price-is-biddable rule.
      final auction = Auction.fromMap('a1', doc());

      expect(auction.currentBid, isNull);
      expect(auction.currentBidderId, isNull);
    });

    test('a status this build does not know is treated as closed', () {
      // Every status a newer server could add comes after `live`. Guessing
      // `live` would offer a Bid button the server is going to refuse.
      final auction = Auction.fromMap('a1', doc({'status': 'in_arbitration'}));

      expect(auction.status, AuctionStatus.endedUnsold);
      expect(auction.acceptsBids(now), isFalse);
    });

    test('a malformed document degrades rather than throwing', () {
      final auction = Auction.fromMap('a1', const {});

      expect(auction.startPrice, 0);
      expect(auction.endsAt, isNull);
      expect(auction.timeLeft(now), Duration.zero);
      expect(auction.acceptsBids(now), isFalse);
    });

    test('the reserve is never on the document, only the fact of it', () {
      // The number lives in a subcollection the seller alone can read; a rule
      // can deny a document but cannot hide a field.
      final auction = Auction.fromMap(
        'a1',
        doc({'hasReserve': true, 'reservePrice': 400}),
      );

      expect(auction.hasReserve, isTrue);
      expect(auction.props, isNot(contains(400)));
    });
  });

  group('the clock', () {
    test('counts down', () {
      final auction = Auction.fromMap('a1', doc());

      expect(auction.timeLeft(now), const Duration(hours: 6));
      expect(
        auction.timeLeft(now.add(const Duration(hours: 5))),
        const Duration(hours: 1),
      );
    });

    test('never runs negative', () {
      final auction = Auction.fromMap('a1', doc());

      expect(auction.timeLeft(now.add(const Duration(days: 2))), Duration.zero);
    });

    test('a live auction whose time has passed accepts no more bids', () {
      // The closer runs once a minute, so there is always a window where the
      // document still says live and the clock has already run out. The button
      // has to be off in that window.
      final auction = Auction.fromMap('a1', doc());

      expect(auction.status, AuctionStatus.live);
      expect(auction.acceptsBids(now.add(const Duration(hours: 7))), isFalse);
    });
  });

  group('the snipe window', () {
    test('opens in the last two minutes', () {
      final auction = Auction.fromMap('a1', doc());

      expect(auction.isInSnipeWindow(now), isFalse);
      expect(
        auction.isInSnipeWindow(
          now.add(const Duration(hours: 5, minutes: 59)),
        ),
        isTrue,
      );
    });

    test('is closed once the auction is over', () {
      final auction = Auction.fromMap('a1', doc({'status': 'ended_sold'}));

      expect(
        auction.isInSnipeWindow(
          now.add(const Duration(hours: 5, minutes: 59)),
        ),
        isFalse,
      );
    });
  });

  group('Bid.fromMap', () {
    test('reads a standing bid', () {
      final bid = Bid.fromMap('b1', {
        'bidderId': 'ben',
        'bidderName': 'Ben Ito',
        'amount': 55,
        'stakeLocked': 6,
        'status': 'active',
        'placedAt': Timestamp.fromDate(now),
      });

      expect(bid.bidderId, 'ben');
      expect(bid.stakeLocked, 6);
      expect(bid.status, BidStatus.active);
    });

    test('an unknown status is treated as outbid, never as standing', () {
      // A bid wrongly shown as active claims credits are locked that are not.
      final bid = Bid.fromMap('b1', const {'status': 'something_new'});

      expect(bid.status, BidStatus.outbid);
    });

    test('falls back to a readable name', () {
      final bid = Bid.fromMap('b1', const {'bidderId': 'ben'});

      expect(bid.bidderName, 'Student');
    });
  });

  group('a deal that came out of an auction', () {
    test('remembers which one', () {
      // Settlement finds the auction back from the deal, so the link has to
      // survive the round trip.
      final deal = DealRequest.fromMap(const {
        'itemId': 'listing-1',
        'title': 'Signed rugby ball',
        'price': 96,
        'status': 'accepted',
        'buyerId': 'ben',
        'sellerId': 'amina',
        'auctionId': 'a1',
      });

      expect(deal.auctionId, 'a1');
      expect(deal.isFromAuction, isTrue);
    });

    test('an ordinary deal has no auction on it', () {
      final deal = DealRequest.fromMap(const {
        'title': 'Campbell Biology',
        'price': 24.5,
        'buyerId': 'ben',
        'sellerId': 'amina',
      });

      expect(deal.auctionId, isNull);
      expect(deal.isFromAuction, isFalse);
    });

    test('arrives already accepted', () {
      // The bid was the agreement.
      final deal = DealRequest.fromMap(const {
        'status': 'accepted',
        'auctionId': 'a1',
      });

      expect(deal.status, DealStatus.accepted);
    });
  });
}
