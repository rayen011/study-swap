import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/user_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final UserRepository _userRepository;

  ProfileCubit(this._userRepository) : super(ProfileInitial());

  /// Fetches the current user's profile data.
  Future<void> loadProfile() async {
    emit(ProfileLoading());
    try {
      final user = await _userRepository.getCurrentUser();
      if (user != null) {
        emit(ProfileLoaded(user));
      } else {
        emit(const ProfileError('Failed to load profile data'));
      }
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  /// Updates the user's profile information.
  Future<void> updateProfile({String? fullName, String? university}) async {
    emit(ProfileLoading());
    try {
      await _userRepository.updateProfile(
        fullName: fullName,
        university: university,
      );
      emit(ProfileUpdateSuccess());
      // Refresh data
      await loadProfile();
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
