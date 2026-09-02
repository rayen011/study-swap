import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/listing.dart';
import '../data/listing_repository.dart';
import 'listing_state.dart';

class ListingCubit extends Cubit<ListingState> {
  final ListingRepository _listingRepository;
  StreamSubscription<List<Listing>>? _listingsSubscription;

  ListingCubit(this._listingRepository) : super(ListingInitial());

  /// Fetches and listens to all marketplace listings.
  void fetchListings() {
    emit(ListingLoading());
    _listingsSubscription?.cancel();
    _listingsSubscription = _listingRepository.getListings().listen(
      (listings) => emit(ListingLoaded(listings)),
      onError: (Object error) => emit(ListingError(error.toString())),
    );
  }

  /// Creates a new listing.
  Future<void> createListing(ListingDraft draft) async {
    emit(ListingLoading());
    try {
      await _listingRepository.createListing(draft);
      emit(ListingOperationSuccess());
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
