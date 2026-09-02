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
  const ListingLoaded(
    this.listings, {
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<Listing> listings;

  /// True when the window filled to its limit, so there is probably another
  /// page behind it.
  final bool hasMore;

  /// True while a larger window is being fetched.
  final bool isLoadingMore;

  ListingLoaded copyWith({bool? isLoadingMore}) => ListingLoaded(
    listings,
    hasMore: hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [listings, hasMore, isLoadingMore];
}

class ListingError extends ListingState {
  final String message;
  const ListingError(this.message);

  @override
  List<Object?> get props => [message];
}

class ListingOperationSuccess extends ListingState {}

/// Emitted while a listing's photos upload, so the sell form can show real
/// progress instead of an indefinite spinner.
class ListingUploading extends ListingState {
  /// 0.0 to 1.0 across the whole batch.
  final double progress;
  const ListingUploading(this.progress);

  @override
  List<Object?> get props => [progress];
}
