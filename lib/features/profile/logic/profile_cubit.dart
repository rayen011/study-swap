import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/data/auth_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepository _authRepository;

  ProfileCubit(this._authRepository) : super(ProfileInitial());

  /// Fetches the current user's profile data.
  Future<void> loadProfile() async {
    emit(ProfileLoading());
    try {
      final userData = await _authRepository.getUserData();
      if (userData != null) {
        emit(ProfileLoaded(userData));
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
      await _authRepository.updateUserProfile(
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
