import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/listing.dart';
import '../data/favorites_repository.dart';

abstract class FavoritesState extends Equatable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {}

class FavoritesLoading extends FavoritesState {}

class FavoritesLoaded extends FavoritesState {
  final List<Listing> favorites;
  const FavoritesLoaded(this.favorites);

  @override
  List<Object?> get props => [favorites];
}

class FavoritesError extends FavoritesState {
  final String message;
  const FavoritesError(this.message);

  @override
  List<Object?> get props => [message];
}

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoritesRepository _favoritesRepository;
  StreamSubscription<List<Listing>>? _subscription;

  FavoritesCubit(this._favoritesRepository) : super(FavoritesInitial());

  void fetchFavorites() {
    emit(FavoritesLoading());
    _subscription?.cancel();
    _subscription = _favoritesRepository.getFavorites().listen(
      (favorites) => emit(FavoritesLoaded(favorites)),
      onError: (Object e) => emit(FavoritesError(e.toString())),
    );
  }

  Future<void> toggleFavorite(Listing listing) async {
    try {
      await _favoritesRepository.toggleFavorite(listing);
    } catch (e) {
      emit(FavoritesError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
