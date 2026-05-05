import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

/// AuthCubit: Orchestrates the authentication logic between the UI and Repository.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(AuthInitial());

  /// Checks if there is a persistent session when the app starts.
  Future<void> checkAuthStatus() async {
    emit(AuthLoading());
    try {
      final isLoggedIn = await _authRepository.isUserLoggedIn();
      if (isLoggedIn) {
        final email = await _authRepository.getUserEmail();
        emit(Authenticated(email ?? 'User'));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }

  /// Handles user login.
  Future<void> login(String email, String password, {bool stayLoggedIn = true}) async {
    emit(AuthLoading());
    try {
      await _authRepository.login(email, password, stayLoggedIn: stayLoggedIn);
      emit(Authenticated(email));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated()); // Fallback to unauthenticated so user can try again
    }
  }

  /// Handles user registration.
  Future<void> signup(String name, String email, String password, {bool stayLoggedIn = true}) async {
    emit(AuthLoading());
    try {
      await _authRepository.signup(name, email, password, stayLoggedIn: stayLoggedIn);
      emit(Authenticated(email));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  /// Handles password reset requests.
  Future<void> forgotPassword(String email) async {
    if (email.isEmpty) {
      emit(const AuthError('Please enter your email to reset your password'));
      return;
    }

    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(email);
      emit(AuthResetPasswordSent());
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  /// Handles user logout.
  Future<void> logout() async {
    emit(AuthLoading());
    await _authRepository.logout();
    emit(Unauthenticated());
  }
}
