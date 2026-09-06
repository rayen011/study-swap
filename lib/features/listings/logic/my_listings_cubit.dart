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

  // Deleting lives on ListingCubit, which is what the owner-actions sheet
  // talks to. A second copy here would be a second place to keep in step for
  // no gain: this cubit watches a stream, so a delete made anywhere shows up
  // in the profile grid and the Collection tab on its own.

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
