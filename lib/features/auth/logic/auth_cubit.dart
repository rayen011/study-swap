import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import 'auth_state.dart';

/// AuthCubit: Orchestrates the authentication logic between the UI and Repository.
///
/// The source of truth is Firebase's own `authStateChanges` stream, not a flag
/// in local storage. The cubit stays in [AuthInitial] until that stream has
/// spoken once — the router shows a splash for exactly that window, which is
/// why [AuthInitial] and [AuthLoading] have to stay distinct states.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _subscription;

  /// True while login / signup / logout is running. Those flows emit their own
  /// outcome, so stream events during them are ignored — otherwise a
  /// suspended account would flash Authenticated before being signed out.
  bool _authInFlight = false;

  AuthCubit(this._authRepository) : super(AuthInitial());

  /// Starts listening for the session. Called once at app startup.
  Future<void> start() async {
    // Honour "stay logged in" before anyone observes the restored session.
    try {
      await _authRepository.restoreSession();
    } catch (_) {
      // A storage failure shouldn't strand the app on the splash screen.
    }

    _subscription?.cancel();
    _subscription = _authRepository.authStateChanges().listen(
      _onAuthStateChanged,
      onError: (Object _) {
        if (!_authInFlight) emit(Unauthenticated());
      },
    );
  }

  void _onAuthStateChanged(User? user) {
    if (_authInFlight) return;
    emit(
      user == null ? Unauthenticated() : Authenticated(user.email ?? 'User'),
    );
  }

  /// Handles user login.
  Future<void> login(
    String email,
    String password, {
    bool stayLoggedIn = true,
  }) async {
    _authInFlight = true;
    emit(AuthLoading());
    try {
      await _authRepository.login(email, password, stayLoggedIn: stayLoggedIn);
      emit(Authenticated(email));
    } catch (e) {
      emit(AuthError(_readable(e)));
      emit(Unauthenticated());
    } finally {
      _authInFlight = false;
    }
  }

  /// Handles user registration.
  Future<void> signup(
    String name,
    String email,
    String password, {
    bool stayLoggedIn = true,
  }) async {
    _authInFlight = true;
    emit(AuthLoading());
    try {
      await _authRepository.signup(
        name,
        email,
        password,
        stayLoggedIn: stayLoggedIn,
      );
      emit(Authenticated(email));
    } catch (e) {
      emit(AuthError(_readable(e)));
      emit(Unauthenticated());
    } finally {
      _authInFlight = false;
    }
  }

  /// Handles password reset requests.
  Future<void> forgotPassword(String email) async {
    if (email.trim().isEmpty) {
      emit(const AuthError('Enter your email first, then tap Forgot password'));
      emit(Unauthenticated());
      return;
    }

    _authInFlight = true;
    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(email.trim());
      emit(AuthResetPasswordSent());
    } catch (e) {
      emit(AuthError(_readable(e)));
    } finally {
      _authInFlight = false;
      emit(Unauthenticated());
    }
  }

  /// Handles user logout.
  Future<void> logout() async {
    _authInFlight = true;
    emit(AuthLoading());
    try {
      await _authRepository.logout();
    } finally {
      _authInFlight = false;
      emit(Unauthenticated());
    }
  }

  /// Strips the `Exception: ` prefix Dart adds, which was being shown to users
  /// verbatim in the error SnackBar.
  static String _readable(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
