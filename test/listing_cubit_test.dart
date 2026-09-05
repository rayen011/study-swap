import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:studyswap/core/constants/listing_options.dart';
import 'package:studyswap/core/models/listing.dart';
import 'package:studyswap/core/models/listing_filter.dart';
import 'package:studyswap/features/auctions/data/auction_repository.dart';
import 'package:studyswap/features/listings/data/image_repository.dart';
import 'package:studyswap/features/listings/data/listing_repository.dart';
import 'package:studyswap/features/listings/logic/listing_cubit.dart';
import 'package:studyswap/features/listings/logic/listing_state.dart';

class _MockListingRepository extends Mock implements ListingRepository {}

class _MockImageRepository extends Mock implements ImageRepository {}

class _MockAuctionRepository extends Mock implements AuctionRepository {}

Listing _listing(String id) => Listing.fromMap(id, {
  'title': 'Item $id',
  'price': 10,
  'userId': 'seller',
  'status': 'active',
});

List<Listing> _page(int count, {int from = 0}) =>
    List.generate(count, (i) => _listing('l${from + i}'));

void main() {
  late _MockListingRepository listings;
  late _MockImageRepository images;
  late _MockAuctionRepository auctions;

  setUpAll(() {
    registerFallbackValue(const ListingFilter());
    registerFallbackValue(
      const ListingDraft(
        title: '',
        description: '',
        price: 0,
        category: ListingCategory.other,
        condition: ListingCondition.good,
        university: '',
      ),
    );
  });

  setUp(() {
    listings = _MockListingRepository();
    images = _MockImageRepository();
    auctions = _MockAuctionRepository();
  });

  ListingCubit build() => ListingCubit(listings, images, auctions);

  /// Each call gets its own stream: `Stream.value` is single-subscription, so
  /// handing the same instance to two subscribes would throw on the second.
  void stubFeed(Stream<List<Listing>> Function() stream) {
    when(
      () => listings.watchFeed(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => stream());
  }

  /// Lets a pending stream emission land, so the cubit is in ListingLoaded
  /// before the next action runs.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('fetchListings', () {
    blocTest<ListingCubit, ListingState>(
      'emits loading then the first page',
      setUp: () => stubFeed(() => Stream.value(_page(3))),
      build: build,
      act: (cubit) => cubit.fetchListings(),
      expect: () => [
        isA<ListingLoading>(),
        isA<ListingLoaded>()
            .having((s) => s.listings.length, 'listings', 3)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<ListingCubit, ListingState>(
      'reports hasMore when the window comes back full',
      setUp: () =>
          stubFeed(() => Stream.value(_page(ListingRepository.pageSize))),
      build: build,
      act: (cubit) => cubit.fetchListings(),
      expect: () => [
        isA<ListingLoading>(),
        isA<ListingLoaded>().having((s) => s.hasMore, 'hasMore', true),
      ],
    );

    blocTest<ListingCubit, ListingState>(
      'surfaces a stream error',
      setUp: () => stubFeed(() => Stream.error(Exception('offline'))),
      build: build,
      act: (cubit) => cubit.fetchListings(),
      expect: () => [isA<ListingLoading>(), isA<ListingError>()],
    );
  });

  group('applyFilter', () {
    blocTest<ListingCubit, ListingState>(
      're-queries when the server-side half of the filter changes',
      setUp: () => stubFeed(() => Stream.value(_page(2))),
      build: build,
      act: (cubit) async {
        cubit.fetchListings();
        await settle();
        cubit.applyFilter(
          const ListingFilter(category: ListingCategory.textbooks),
        );
      },
      verify: (_) {
        // Once for the initial subscribe, once for the category change.
        verify(
          () => listings.watchFeed(
            filter: any(named: 'filter'),
            limit: any(named: 'limit'),
          ),
        ).called(2);
      },
    );

    blocTest<ListingCubit, ListingState>(
      'does not re-query when only the search text changes',
      setUp: () => stubFeed(() => Stream.value(_page(2))),
      build: build,
      act: (cubit) async {
        cubit.fetchListings();
        await settle();
        cubit.applyFilter(const ListingFilter(query: 'biology'));
        cubit.applyFilter(const ListingFilter(query: 'biolo'));
      },
      verify: (_) {
        // Typing must not refetch the window — that's the whole point of
        // debouncing and of ListingFilter.queryKey.
        verify(
          () => listings.watchFeed(
            filter: any(named: 'filter'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      },
    );

    blocTest<ListingCubit, ListingState>(
      'does not re-query when only the price range changes',
      setUp: () => stubFeed(() => Stream.value(_page(2))),
      build: build,
      act: (cubit) async {
        cubit.fetchListings();
        await settle();
        cubit.applyFilter(const ListingFilter(minPrice: 5, maxPrice: 50));
      },
      verify: (_) {
        verify(
          () => listings.watchFeed(
            filter: any(named: 'filter'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      },
    );
  });

  group('loadMore', () {
    blocTest<ListingCubit, ListingState>(
      'grows the window by one page',
      setUp: () =>
          stubFeed(() => Stream.value(_page(ListingRepository.pageSize))),
      build: build,
      act: (cubit) async {
        cubit.fetchListings();
        // loadMore only acts on a loaded state, so let the page land first.
        await settle();
        cubit.loadMore();
      },
      verify: (_) {
        verify(
          () => listings.watchFeed(
            filter: any(named: 'filter'),
            limit: ListingRepository.pageSize,
          ),
        ).called(1);
        verify(
          () => listings.watchFeed(
            filter: any(named: 'filter'),
            limit: ListingRepository.pageSize * 2,
          ),
        ).called(1);
      },
    );

    blocTest<ListingCubit, ListingState>(
      'does nothing when the last page was short',
      setUp: () => stubFeed(() => Stream.value(_page(3))),
      build: build,
      act: (cubit) async {
        cubit.fetchListings();
        // loadMore only acts on a loaded state, so let the page land first.
        await settle();
        cubit.loadMore();
      },
      verify: (_) {
        verify(
          () => listings.watchFeed(
            filter: any(named: 'filter'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      },
    );
  });

  group('createListing', () {
    const draft = ListingDraft(
      title: 'Campbell Biology',
      description: '',
      price: 24.5,
      category: ListingCategory.textbooks,
      condition: ListingCondition.good,
      university: 'Oxford',
    );

    blocTest<ListingCubit, ListingState>(
      'reserves an id, uploads, then writes the document',
      setUp: () {
        stubFeed(Stream<List<Listing>>.empty);
        when(() => listings.newListingId()).thenReturn('new-id');
        when(
          () => images.uploadListingImages(
            listingId: any(named: 'listingId'),
            files: any(named: 'files'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => ['https://a/0.jpg']);
        when(
          () =>
              listings.createListing(any(), listingId: any(named: 'listingId')),
        ).thenAnswer((_) async {});
      },
      build: build,
      act: (cubit) => cubit.createListing(draft),
      verify: (_) {
        // The images must be uploaded under the id the document will use,
        // otherwise the listing points at a path it doesn't own.
        verify(
          () => images.uploadListingImages(
            listingId: 'new-id',
            files: any(named: 'files'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        verify(
          () => listings.createListing(any(), listingId: 'new-id'),
        ).called(1);
      },
    );

    blocTest<ListingCubit, ListingState>(
      'never writes the document when the upload fails',
      setUp: () {
        when(() => listings.newListingId()).thenReturn('new-id');
        when(
          () => images.uploadListingImages(
            listingId: any(named: 'listingId'),
            files: any(named: 'files'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('storage unavailable'));
      },
      build: build,
      act: (cubit) => cubit.createListing(draft),
      expect: () => [isA<ListingLoading>(), isA<ListingError>()],
      verify: (_) {
        verifyNever(
          () =>
              listings.createListing(any(), listingId: any(named: 'listingId')),
        );
      },
    );
  });

  group('deleteListing', () {
    blocTest<ListingCubit, ListingState>(
      'surfaces a failure as an error state',
      setUp: () => when(
        () => listings.deleteListing(any()),
      ).thenThrow(Exception('permission denied')),
      build: build,
      act: (cubit) => cubit.deleteListing('l1'),
      expect: () => [isA<ListingError>()],
    );
  });
}
