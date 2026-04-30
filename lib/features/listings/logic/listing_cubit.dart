import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/listing_repository.dart';
import 'listing_state.dart';

class ListingCubit extends Cubit<ListingState> {
  final ListingRepository _listingRepository;
  StreamSubscription? _listingsSubscription;

  ListingCubit(this._listingRepository) : super(ListingInitial());

  /// Fetches and listens to all marketplace listings.
  void fetchListings() {
    emit(ListingLoading());
    _listingsSubscription?.cancel();
    _listingsSubscription = _listingRepository.getListings().listen(
      (listings) {
        emit(ListingLoaded(listings));
      },
      onError: (error) {
        emit(ListingError(error.toString()));
      },
    );
  }

  /// Creates a new listing.
  Future<void> createListing({
    required String title,
    required String description,
    required double price,
    required String category,
    required String university,
    String? imageUrl,
  }) async {
    emit(ListingLoading());
    try {
      await _listingRepository.createListing(
        title: title,
        description: description,
        price: price,
        category: category,
        university: university,
        imageUrl: imageUrl,
      );
      emit(ListingOperationSuccess());
      // After success, we can trigger a re-fetch if not using streams
    } catch (e) {
      emit(ListingError(e.toString()));
    }
  }

  /// Deletes a listing.
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
