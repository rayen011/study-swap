import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/listing.dart';
import '../data/listing_repository.dart';
import 'listing_state.dart';

/// MyListingsCubit: Manages the user's personal listings independently.
class MyListingsCubit extends Cubit<ListingState> {
  final ListingRepository _listingRepository;
  StreamSubscription<List<Listing>>? _subscription;

  MyListingsCubit(this._listingRepository) : super(ListingInitial());

  void fetchUserListings() {
    emit(ListingLoading());
    _subscription?.cancel();
    _subscription = _listingRepository.getUserListings().listen(
      (listings) => emit(ListingLoaded(listings)),
      onError: (Object e) => emit(ListingError(e.toString())),
    );
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
    _subscription?.cancel();
    return super.close();
  }
}
