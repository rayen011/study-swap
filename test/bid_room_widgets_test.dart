import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/models/auction.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:studyswap/features/auctions/data/auction_repository.dart';
import 'package:studyswap/features/auctions/widgets/auction_row.dart';
import 'package:studyswap/features/auctions/widgets/bid_room_entry_card.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);

  Auction auction({
    String id = 'a1',
    double? currentBid,
    String? currentBidderId,
    int bidCount = 0,
    Duration left = const Duration(hours: 6),
    String sellerId = 'amina',
  }) => Auction.fromMap(id, {
    'listingId': 'listing-1',
    'listingTitle': 'Signed university rugby ball',
    'listingImage': '',
    'sellerId': sellerId,
    'sellerName': 'Amina K',
    'startPrice': 12,
    'currentBid': ?currentBid,
    'currentBidderId': ?currentBidderId,
    'bidCount': bidCount,
    'status': 'live',
    'endsAt': Timestamp.fromDate(now.add(left)),
  });

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  group('the door in the feed', () {
    testWidgets('says how many floors are open', (tester) async {
      await pump(
        tester,
        BidRoomEntryCard(liveCount: 4, onTap: () {}, closingSoonest: auction()),
      );

      expect(find.text('4 live'), findsOneWidget);
      expect(find.text('THE BID ROOM'), findsOneWidget);
    });

    testWidgets('an empty room still shows a door', (tester) async {
      // A door that disappears when the room is empty is a door nobody
      // discovers.
      await pump(tester, BidRoomEntryCard(liveCount: 0, onTap: () {}));

      expect(find.textContaining('Be the first'), findsOneWidget);
      expect(find.text('0 live'), findsNothing);
    });

    testWidgets('tickers the auction closing next', (tester) async {
      await pump(
        tester,
        BidRoomEntryCard(
          liveCount: 1,
          onTap: () {},
          closingSoonest: auction(currentBid: 85, bidCount: 12),
        ),
      );

      expect(find.text('Signed university rugby ball'), findsOneWidget);
      expect(find.text('£85'), findsOneWidget);
      expect(find.text('12 bids'), findsOneWidget);
    });

    testWidgets('opens the room on tap', (tester) async {
      var taps = 0;
      await pump(tester, BidRoomEntryCard(liveCount: 2, onTap: () => taps++));

      await tester.tap(find.byType(BidRoomEntryCard));
      expect(taps, 1);
    });

    testWidgets('fits a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pump(
        tester,
        BidRoomEntryCard(
          liveCount: 12,
          onTap: () {},
          closingSoonest: auction(currentBid: 1850, bidCount: 40),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('a row in the room', () {
    testWidgets('leads with the price it stands at', (tester) async {
      await pump(
        tester,
        AuctionRow(
          auction: auction(currentBid: 85, bidCount: 12),
          onTap: () {},
          now: now,
        ),
      );

      expect(find.text('NOW AT'), findsOneWidget);
      expect(find.text('£85'), findsOneWidget);
      expect(find.text('12 bids · Amina K'), findsOneWidget);
    });

    testWidgets('an auction with no bids invites one', (tester) async {
      // An empty floor that just shows £12 reads as a listing. Saying the
      // opening price takes it is what makes it an auction.
      await pump(
        tester,
        AuctionRow(auction: auction(), onTap: () {}, now: now),
      );

      expect(find.text('OPENING AT'), findsOneWidget);
      expect(find.textContaining('£12 takes it'), findsOneWidget);
    });

    testWidgets('the last two minutes explain the moving clock', (
      tester,
    ) async {
      // A closing time that jumps forward with no explanation looks like a bug.
      await pump(
        tester,
        AuctionRow(
          auction: auction(currentBid: 85, left: const Duration(seconds: 90)),
          onTap: () {},
          now: now,
        ),
      );

      expect(find.textContaining('adds two minutes'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });

    testWidgets('says when you are leading', (tester) async {
      await pump(
        tester,
        AuctionRow(
          auction: auction(currentBid: 32, currentBidderId: 'ben'),
          standing: AuctionStanding.leading,
          onTap: () {},
          now: now,
        ),
      );

      expect(find.text("YOU'RE LEADING"), findsOneWidget);
    });

    testWidgets('and when you have been beaten', (tester) async {
      await pump(
        tester,
        AuctionRow(
          auction: auction(currentBid: 46),
          standing: AuctionStanding.outbid,
          onTap: () {},
          now: now,
        ),
      );

      expect(find.text('OUTBID'), findsOneWidget);
    });

    testWidgets('a closing auction outranks a standing tag', (tester) async {
      // Two minutes left matters more than the fact you are winning.
      await pump(
        tester,
        AuctionRow(
          auction: auction(currentBid: 46, left: const Duration(seconds: 30)),
          standing: AuctionStanding.leading,
          onTap: () {},
          now: now,
        ),
      );

      expect(find.text("YOU'RE LEADING"), findsNothing);
      expect(find.textContaining('adds two minutes'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('the door when the query fails', () {
    testWidgets('still opens', (tester) async {
      // Found the hard way: with the auctions read denied, an entry that hid
      // on error made the whole feature silently cease to exist — no card, no
      // message, nothing to debug from the outside.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepositoryProvider<AuctionRepository>.value(
              value: _FailingAuctionRepository(),
              child: BidRoomEntry(onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BidRoomEntryCard), findsOneWidget);
      expect(find.textContaining('Be the first'), findsOneWidget);
    });

    testWidgets('but shows nothing while the first read is in flight', (
      tester,
    ) async {
      // A card that appears and then changes shape is worse than one that
      // arrives a frame late.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepositoryProvider<AuctionRepository>.value(
              value: _PendingAuctionRepository(),
              child: BidRoomEntry(onTap: () {}),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(BidRoomEntryCard), findsNothing);
    });
  });

  group('where you stand', () {
    final ben = auction(currentBid: 50, currentBidderId: 'ben');

    test('leading when the top bid is yours', () {
      expect(standingFor(ben, 'ben', const []), AuctionStanding.leading);
    });

    test('outbid when you bid and somebody went higher', () {
      final bid = Bid.fromMap('b1', const {
        'bidderId': 'chloe',
        'amount': 40,
        'status': 'outbid',
      });

      expect(standingFor(ben, 'chloe', [bid]), AuctionStanding.outbid);
    });

    test('nothing when you never bid', () {
      expect(standingFor(ben, 'chloe', const []), AuctionStanding.none);
    });

    test('selling beats everything — you cannot bid on your own', () {
      expect(standingFor(ben, 'amina', const []), AuctionStanding.selling);
    });
  });
}

/// Stands in for the auctions read being denied.
class _FailingAuctionRepository implements AuctionRepository {
  @override
  Stream<List<Auction>> watchLive({int limit = 30}) =>
      Stream.error(Exception('permission-denied'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A read that never answers — still connecting, not failed.
class _PendingAuctionRepository implements AuctionRepository {
  @override
  Stream<List<Auction>> watchLive({int limit = 30}) =>
      Stream.fromFuture(Completer<List<Auction>>().future);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
