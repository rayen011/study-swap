import 'package:equatable/equatable.dart';

import '../../../core/models/listing.dart';

abstract class ListingState extends Equatable {
  const ListingState();

  @override
  List<Object?> get props => [];
}

class ListingInitial extends ListingState {}

class ListingLoading extends ListingState {}

class ListingLoaded extends ListingState {
  final List<Listing> listings;
  const ListingLoaded(this.listings);

  @override
  List<Object?> get props => [listings];
}

class ListingError extends ListingState {
  final String message;
  const ListingError(this.message);

  @override
  List<Object?> get props => [message];
}

class ListingOperationSuccess extends ListingState {}
