import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/listing.dart';
import '../../../core/models/listing_filter.dart';
import '../data/image_repository.dart';
import '../data/listing_repository.dart';
import 'listing_state.dart';

class ListingCubit extends Cubit<ListingState> {
  final ListingRepository _listingRepository;
  final ImageRepository _imageRepository;
  StreamSubscription<List<Listing>>? _listingsSubscription;

  ListingFilter _filter = const ListingFilter();
  int _limit = ListingRepository.pageSize;

  ListingCubit(this._listingRepository, this._imageRepository)
    : super(ListingInitial());

  ListingFilter get filter => _filter;

  /// Subscribes to the marketplace feed. Safe to call again — the previous
  /// subscription is replaced.
  void fetchListings() => _subscribe(reset: true);

  /// Applies a new filter.
  ///
  /// Only re-issues the Firestore query when the server-side half of the
  /// filter changed. Typing in the search box or dragging the price slider
  /// leaves the loaded window alone — the screen re-runs its own client-side
  /// narrowing over the same data, which is the whole point of debouncing.
  void applyFilter(ListingFilter next) {
    final needsRequery = next.queryKey != _filter.queryKey;
    _filter = next;
    if (needsRequery) _subscribe(reset: true);
  }

  /// Grows the window by one page.
  void loadMore() {
    final current = state;
    if (current is! ListingLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    _limit += ListingRepository.pageSize;
    _subscribe(reset: false);
  }

  void _subscribe({required bool reset}) {
    if (reset) {
      _limit = ListingRepository.pageSize;
      emit(ListingLoading());
    }

    _listingsSubscription?.cancel();
    _listingsSubscription = _listingRepository
        .watchFeed(filter: _filter, limit: _limit)
        .listen(
          (listings) => emit(
            ListingLoaded(listings, hasMore: listings.length >= _limit),
          ),
          onError: (Object error) => emit(ListingError(error.toString())),
        );
  }

  /// Creates a new listing, uploading its photos first.
  ///
  /// The document id is reserved up front so the images can be stored under a
  /// path the listing will own. If the upload fails the document is never
  /// written, so a listing can't end up pointing at photos that don't exist.
  Future<void> createListing(
    ListingDraft draft, {
    List<XFile> images = const [],
  }) async {
    emit(images.isEmpty ? ListingLoading() : const ListingUploading(0));
    try {
      final listingId = _listingRepository.newListingId();

      final urls = await _imageRepository.uploadListingImages(
        listingId: listingId,
        files: images,
        onProgress: (progress) {
          if (!isClosed) emit(ListingUploading(progress));
        },
      );

      await _listingRepository.createListing(
        draft.withImageUrls(urls),
        listingId: listingId,
      );
      emit(ListingOperationSuccess());
      // Posting replaced the feed state; put the feed back.
      _subscribe(reset: true);
    } catch (e) {
      emit(ListingError(e.toString()));
    }
  }

  /// Deletes a listing. Its photos are removed by onListingDeleted.
  Future<void> deleteListing(String listingId) async {
    try {
      await _listingRepository.deleteListing(listingId);
    } catch (e) {
      emit(ListingError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _listingsSubscription?.cancel();
    return super.close();
  }
}
