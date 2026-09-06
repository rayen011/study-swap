import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/app_user.dart';
import '../data/user_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final UserRepository _userRepository;
  StreamSubscription<AppUser?>? _subscription;

  ProfileCubit(this._userRepository) : super(ProfileInitial());

  /// Loads the profile and then keeps it live.
  ///
  /// Watching, not fetching once. Every server-owned field on this document —
  /// credits, rating, dealCount, title — is written by a Cloud Function
  /// *after* the app has loaded it, so a one-shot read shows a number that was
  /// true when the screen opened and is wrong the moment a deal completes. The
  /// balance in the Bid Room's header was already live; this is the profile
  /// catching up with it.
  Future<void> watchProfile() async {
    emit(ProfileLoading());

    try {
      // Once, up front: rebuilds the document if it has gone missing, which a
      // stream alone would never do.
      final user = await _userRepository.ensureProfile();
      if (user == null) {
        emit(const ProfileError('Failed to load profile data'));
        return;
      }

      emit(ProfileLoaded(user));

      await _subscription?.cancel();
      _subscription = _userRepository.watchUser(user.id).listen(
        (live) {
          if (live != null) emit(ProfileLoaded(live));
        },
        // The profile is already on screen; losing the live updates is
        // not a reason to replace it with an error.
        onError: (Object _) {},
      );
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  /// Fetches the current user's profile, rebuilding it if it has gone missing.
  ///
  /// A signed-in account with no profile document used to dead-end here — see
  /// `UserRepository.ensureProfile` for how that state arises.
  Future<void> loadProfile() async {
    emit(ProfileLoading());
    try {
      final user = await _userRepository.ensureProfile();
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

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
