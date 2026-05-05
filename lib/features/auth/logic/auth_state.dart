import 'package:equatable/equatable.dart';

/// AuthState: Represents the different states of the authentication flow.
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state when the app starts.
class AuthInitial extends AuthState {}

/// State when checking for an existing session.
class AuthLoading extends AuthState {}

/// State when the user is successfully authenticated.
class Authenticated extends AuthState {
  final String email;
  const Authenticated(this.email);

  @override
  List<Object?> get props => [email];
}

/// State when the user is not logged in.
class Unauthenticated extends AuthState {}

/// State when a password reset email has been sent successfully.
class AuthResetPasswordSent extends AuthState {}

/// State when an error occurs during login/signup.
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
