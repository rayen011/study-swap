import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:studyswap/features/auth/data/auth_repository.dart';
import 'package:studyswap/features/auth/logic/auth_cubit.dart';
import 'package:studyswap/features/auth/logic/auth_state.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

void main() {
  late _MockAuthRepository auth;
  late StreamController<User?> authState;

  User user(String email) {
    final u = _MockUser();
    when(() => u.email).thenReturn(email);
    return u;
  }

  setUp(() {
    auth = _MockAuthRepository();
    authState = StreamController<User?>.broadcast();

    when(() => auth.restoreSession()).thenAnswer((_) async {});
    when(() => auth.authStateChanges()).thenAnswer((_) => authState.stream);
  });

  tearDown(() => authState.close());

  AuthCubit build() => AuthCubit(auth);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('start', () {
    test('stays in AuthInitial until the stream speaks', () async {
      // The router shows the splash for exactly this window. If start() emitted
      // AuthLoading instead, the splash would also cover in-flight sign-ins.
      final cubit = build();
      await cubit.start();

      expect(cubit.state, isA<AuthInitial>());
      await cubit.close();
    });

    blocTest<AuthCubit, AuthState>(
      'honours "stay logged in" before anyone observes the session',
      build: build,
      act: (cubit) => cubit.start(),
      verify: (_) => verify(() => auth.restoreSession()).called(1),
    );

    blocTest<AuthCubit, AuthState>(
      'emits Authenticated when Firebase restores a session',
      build: build,
      act: (cubit) async {
        await cubit.start();
        authState.add(user('a@uni.edu'));
      },
      expect: () => [
        isA<Authenticated>().having((s) => s.email, 'email', 'a@uni.edu'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Unauthenticated when there is no session',
      build: build,
      act: (cubit) async {
        await cubit.start();
        authState.add(null);
      },
      expect: () => [isA<Unauthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'recovers from a stream error instead of hanging on the splash',
      build: build,
      act: (cubit) async {
        await cubit.start();
        authState.addError(Exception('token revoked'));
      },
      expect: () => [isA<Unauthenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'a failed restoreSession does not strand the app in AuthInitial',
      setUp: () => when(
        () => auth.restoreSession(),
      ).thenThrow(Exception('storage unavailable')),
      build: build,
      act: (cubit) async {
        await cubit.start();
        authState.add(null);
      },
      expect: () => [isA<Unauthenticated>()],
    );
  });

  group('login', () {
    blocTest<AuthCubit, AuthState>(
      'emits loading then authenticated',
      setUp: () => when(
        () =>
            auth.login(any(), any(), stayLoggedIn: any(named: 'stayLoggedIn')),
      ).thenAnswer((_) async {}),
      build: build,
      act: (cubit) => cubit.login('a@uni.edu', 'hunter22'),
      expect: () => [isA<AuthLoading>(), isA<Authenticated>()],
    );

    blocTest<AuthCubit, AuthState>(
      'strips the Exception prefix users were being shown',
      setUp: () => when(
        () =>
            auth.login(any(), any(), stayLoggedIn: any(named: 'stayLoggedIn')),
      ).thenThrow(Exception('The password is invalid.')),
      build: build,
      act: (cubit) => cubit.login('a@uni.edu', 'wrong'),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          'The password is invalid.',
        ),
        isA<Unauthenticated>(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'ignores stream events while a sign-in is in flight',
      setUp: () =>
          when(
            () => auth.login(
              any(),
              any(),
              stayLoggedIn: any(named: 'stayLoggedIn'),
            ),
          ).thenAnswer((_) async {
            // A suspended account signs in, then gets signed straight back out.
            // Without the in-flight guard the user would see Authenticated flash
            // and the router would bounce them to /home and back.
            authState.add(user('suspended@uni.edu'));
            await settle();
            throw Exception('Your account has been suspended.');
          }),
      build: build,
      act: (cubit) async {
        await cubit.start();
        await cubit.login('suspended@uni.edu', 'hunter22');
      },
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
        isA<Unauthenticated>(),
      ],
    );
  });

  group('forgotPassword', () {
    blocTest<AuthCubit, AuthState>(
      'refuses an empty email without calling the repository',
      build: build,
      act: (cubit) => cubit.forgotPassword('   '),
      expect: () => [isA<AuthError>(), isA<Unauthenticated>()],
      verify: (_) => verifyNever(() => auth.resetPassword(any())),
    );

    blocTest<AuthCubit, AuthState>(
      'confirms when the email is sent',
      setUp: () =>
          when(() => auth.resetPassword(any())).thenAnswer((_) async {}),
      build: build,
      act: (cubit) => cubit.forgotPassword('  a@uni.edu  '),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthResetPasswordSent>(),
        isA<Unauthenticated>(),
      ],
      // Trimmed before it reaches Firebase.
      verify: (_) => verify(() => auth.resetPassword('a@uni.edu')).called(1),
    );
  });

  group('logout', () {
    blocTest<AuthCubit, AuthState>(
      'ends unauthenticated even if sign-out throws',
      setUp: () => when(() => auth.logout()).thenThrow(Exception('offline')),
      build: build,
      act: (cubit) => cubit.logout().catchError((_) {}),
      expect: () => [isA<AuthLoading>(), isA<Unauthenticated>()],
    );
  });
}
