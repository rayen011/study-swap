import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:studyswap/core/models/auction.dart';
import 'package:studyswap/features/auctions/data/auction_repository.dart';
import 'package:studyswap/features/auctions/logic/auction_cubit.dart';
import 'package:studyswap/features/auctions/logic/auction_state.dart';

class _MockAuctionRepository extends Mock implements AuctionRepository {}

void main() {
  late _MockAuctionRepository repository;

  final endsAt = DateTime(2026, 9, 4, 18);

  Auction auction({
    String id = 'a1',
    double? currentBid,
    String? currentBidderId,
    int bidCount = 0,
  }) => Auction.fromMap(id, {
    'listingId': 'listing-1',
    'listingTitle': 'Signed rugby ball',
    'listingImage': '',
    'sellerId': 'amina',
    'sellerName': 'Amina K',
    'startPrice': 20,
    'currentBid': ?currentBid,
    'currentBidderId': ?currentBidderId,
    'bidCount': bidCount,
    'status': 'live',
    'endsAt': Timestamp.fromDate(endsAt),
  });

  Bid bid(String bidderId, double amount) => Bid.fromMap('b-$bidderId', {
    'bidderId': bidderId,
    'bidderName': bidderId,
    'amount': amount,
    'stakeLocked': (amount / 10).ceil(),
    'status': 'active',
  });

  /// The cubits subscribe in their constructor body, so the emissions land a
  /// microtask later than the synchronous `act` call.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repository = _MockAuctionRepository();
    when(() => repository.watchBids(any())).thenAnswer((_) => Stream.value([]));
  });

  group('the room list', () {
    blocTest<AuctionListCubit, AuctionListState>(
      'shows the live floor',
      setUp: () => when(() => repository.watchLive()).thenAnswer(
        (_) => Stream.value([auction(), auction(id: 'a2')]),
      ),
      build: () => AuctionListCubit(repository),
      act: (cubit) async {
        cubit.watch();
        await settle();
      },
      expect: () => [
        const AuctionListLoading(),
        isA<AuctionListLoaded>().having((s) => s.auctions.length, 'count', 2),
      ],
    );

    blocTest<AuctionListCubit, AuctionListState>(
      'an empty floor is loaded, not an error',
      setUp: () => when(
        () => repository.watchLive(),
      ).thenAnswer((_) => Stream.value([])),
      build: () => AuctionListCubit(repository),
      act: (cubit) async {
        cubit.watch();
        await settle();
      },
      expect: () => [
        const AuctionListLoading(),
        isA<AuctionListLoaded>().having((s) => s.isEmpty, 'isEmpty', isTrue),
      ],
    );

    blocTest<AuctionListCubit, AuctionListState>(
      'surfaces a missing index rather than spinning forever',
      setUp: () => when(() => repository.watchLive()).thenAnswer(
        (_) => Stream.error(Exception('failed-precondition: needs an index')),
      ),
      build: () => AuctionListCubit(repository),
      act: (cubit) async {
        cubit.watch();
        await settle();
      },
      expect: () => [const AuctionListLoading(), isA<AuctionListError>()],
    );
  });

  group('one auction', () {
    blocTest<AuctionDetailCubit, AuctionDetailState>(
      'loads the auction and its history',
      setUp: () {
        when(
          () => repository.watchAuction('a1'),
        ).thenAnswer((_) => Stream.value(auction(currentBid: 50, bidCount: 1)));
        when(
          () => repository.watchBids('a1'),
        ).thenAnswer((_) => Stream.value([bid('ben', 50)]));
      },
      build: () => AuctionDetailCubit(repository, 'a1'),
      act: (cubit) async {
        cubit.watch();
        await settle();
      },
      expect: () => [
        isA<AuctionDetailLoaded>().having(
          (s) => s.auction.currentBid,
          'bid',
          50,
        ),
        isA<AuctionDetailLoaded>().having((s) => s.bids.length, 'history', 1),
      ],
    );

    blocTest<AuctionDetailCubit, AuctionDetailState>(
      'an auction that is not there reads as gone, not as loading',
      // Firestore emits a snapshot for a document that does not exist, so
      // without distinguishing the two the screen would spin forever.
      setUp: () => when(
        () => repository.watchAuction('nope'),
      ).thenAnswer((_) => Stream.value(null)),
      build: () => AuctionDetailCubit(repository, 'nope'),
      act: (cubit) async {
        cubit.watch();
        await settle();
      },
      expect: () => [const AuctionDetailMissing()],
    );

    blocTest<AuctionDetailCubit, AuctionDetailState>(
      'bid history failing does not take the auction down with it',
      // The countdown and the bid button matter more than the list.
      setUp: () {
        when(
          () => repository.watchAuction('a1'),
        ).thenAnswer((_) => Stream.value(auction()));
        when(
          () => repository.watchBids('a1'),
        ).thenAnswer((_) => Stream.error(Exception('permission-denied')));
      },
      build: () => AuctionDetailCubit(repository, 'a1'),
      act: (cubit) async {
        cubit.watch();
        await settle();
      },
      // One state, not two: the failing bids stream re-emits a state equal to
      // the one already held, and a Cubit drops a repeat of its current state.
      expect: () => [isA<AuctionDetailLoaded>()],
    );
  });

  group('placing a bid', () {
    void stubLoaded() {
      when(
        () => repository.watchAuction('a1'),
      ).thenAnswer((_) => Stream.value(auction(currentBid: 50)));
    }

    blocTest<AuctionDetailCubit, AuctionDetailState>(
      'reports what the server did with it',
      setUp: () {
        stubLoaded();
        when(
          () => repository.placeBid(auctionId: 'a1', amount: 60),
        ).thenAnswer(
          (_) async => BidPlaced(
            amount: 60,
            stakeLocked: 6,
            endsAt: endsAt,
            extended: false,
          ),
        );
      },
      build: () => AuctionDetailCubit(repository, 'a1'),
      act: (cubit) async {
        cubit.watch();
        await settle();
        await cubit.placeBid(60);
      },
      skip: 1,
      expect: () => [
        isA<AuctionDetailLoaded>().having(
          (s) => s.isBidding,
          'in flight',
          isTrue,
        ),
        isA<AuctionDetailLoaded>()
            .having((s) => s.isBidding, 'in flight', isFalse)
            .having((s) => s.lastBid?.amount, 'placed', 60)
            .having((s) => s.lastBid?.stakeLocked, 'held', 6),
      ],
    );

    blocTest<AuctionDetailCubit, AuctionDetailState>(
      'says a late bid moved the clock',
      // Otherwise a countdown that jumps forward on its own looks like a bug
      // rather than the anti-snipe rule working.
      setUp: () {
        stubLoaded();
        when(() => repository.placeBid(auctionId: 'a1', amount: 60)).thenAnswer(
          (_) async => BidPlaced(
            amount: 60,
            stakeLocked: 6,
            endsAt: endsAt,
            extended: true,
          ),
        );
      },
      build: () => AuctionDetailCubit(repository, 'a1'),
      act: (cubit) async {
        cubit.watch();
        await settle();
        await cubit.placeBid(60);
      },
      skip: 2,
      expect: () => [
        isA<AuctionDetailLoaded>().having(
          (s) => s.lastBid?.extended,
          'extended',
          isTrue,
        ),
      ],
    );

    blocTest<AuctionDetailCubit, AuctionDetailState>(
      "carries the server's refusal through word for word",
      // "The next bid has to be at least £105" tells a bidder what to do next
      // in a way no error code does.
      setUp: () {
        stubLoaded();
        when(() => repository.placeBid(auctionId: 'a1', amount: 51)).thenThrow(
          const BidRefused('The next bid has to be at least £53.'),
        );
      },
      build: () => AuctionDetailCubit(repository, 'a1'),
      act: (cubit) async {
        cubit.watch();
        await settle();
        await cubit.placeBid(51);
      },
      skip: 2,
      expect: () => [
        isA<AuctionDetailLoaded>()
            .having(
              (s) => s.refusal,
              'refusal',
              'The next bid has to be at least £53.',
            )
            .having((s) => s.isBidding, 'in flight', isFalse),
      ],
    );

    blocTest<AuctionDetailCubit, AuctionDetailState>(
      'turns an unexpected failure into something readable',
      setUp: () {
        stubLoaded();
        when(
          () => repository.placeBid(auctionId: 'a1', amount: 60),
        ).thenThrow(StateError('socket closed'));
      },
      build: () => AuctionDetailCubit(repository, 'a1'),
      act: (cubit) async {
        cubit.watch();
        await settle();
        await cubit.placeBid(60);
      },
      skip: 2,
      expect: () => [
        isA<AuctionDetailLoaded>().having(
          (s) => s.refusal,
          'refusal',
          isNot(contains('socket')),
        ),
      ],
    );

    test('a second bid while one is in flight is ignored', () async {
      // Two identical bids would be refused server-side anyway, but only after
      // locking the network for a round trip.
      stubLoaded();

      final gate = Completer<BidPlaced>();
      when(
        () => repository.placeBid(auctionId: 'a1', amount: 60),
      ).thenAnswer((_) => gate.future);

      final cubit = AuctionDetailCubit(repository, 'a1')..watch();
      await settle();

      final first = cubit.placeBid(60);
      await cubit.placeBid(60);

      gate.complete(
        BidPlaced(amount: 60, stakeLocked: 6, endsAt: endsAt, extended: false),
      );
      await first;

      verify(() => repository.placeBid(auctionId: 'a1', amount: 60)).called(1);
      await cubit.close();
    });
  });
}
