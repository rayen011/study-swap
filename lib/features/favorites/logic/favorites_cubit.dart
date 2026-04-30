import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/favorites_repository.dart';

abstract class FavoritesState {}
class FavoritesInitial extends FavoritesState {}
class FavoritesLoading extends FavoritesState {}
class FavoritesLoaded extends FavoritesState {
  final List<Map<String, dynamic>> favorites;
  FavoritesLoaded(this.favorites);
}
class FavoritesError extends FavoritesState {
  final String message;
  FavoritesError(this.message);
}

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoritesRepository _favoritesRepository;

  FavoritesCubit(this._favoritesRepository) : super(FavoritesInitial());

  void fetchFavorites() {
    emit(FavoritesLoading());
    _favoritesRepository.getFavorites().listen(
      (favorites) => emit(FavoritesLoaded(favorites)),
      onError: (e) => emit(FavoritesError(e.toString())),
    );
  }

  Future<void> toggleFavorite(Map<String, dynamic> listing) async {
    try {
      await _favoritesRepository.toggleFavorite(listing);
    } catch (e) {
      emit(FavoritesError(e.toString()));
    }
  }
}
