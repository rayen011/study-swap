import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:studyswap/core/models/app_user.dart';
import 'package:studyswap/features/profile/data/user_repository.dart';
import 'package:studyswap/features/profile/logic/profile_cubit.dart';
import 'package:studyswap/features/profile/logic/profile_state.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// Regression tests for the signed-in-but-profile-less dead end.
///
/// Signup writes the Auth account and the Firestore profile separately, so a
/// failure between them leaves an account that can sign in and has nowhere to
/// go. Deleting the users collection by hand produces the same state.
void main() {
  late _MockUserRepository users;

  const profile = AppUser(
    id: 'u1',
    fullName: 'Amina Khan',
    email: 'amina@uni.ac.uk',
    university: 'Oxford',
    rating: 0,
    ratingCount: 0,
    dealCount: 0,
    title: 'Freshman Trader',
    credits: 50,
    creditsLocked: 0,
    isSuspended: false,
    createdAt: null,
  );

  setUp(() => users = _MockUserRepository());

  blocTest<ProfileCubit, ProfileState>(
    'rebuilds a missing profile rather than dead-ending',
    setUp: () =>
        when(() => users.ensureProfile()).thenAnswer((_) async => profile),
    build: () => ProfileCubit(users),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [
      isA<ProfileLoading>(),
      isA<ProfileLoaded>().having((s) => s.user.id, 'user', 'u1'),
    ],
    // The read-only getCurrentUser would have returned null and stuck.
    verify: (_) {
      verify(() => users.ensureProfile()).called(1);
      verifyNever(() => users.getCurrentUser());
    },
  );

  blocTest<ProfileCubit, ProfileState>(
    'still errors when there is no signed-in user at all',
    setUp: () =>
        when(() => users.ensureProfile()).thenAnswer((_) async => null),
    build: () => ProfileCubit(users),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [isA<ProfileLoading>(), isA<ProfileError>()],
  );

  blocTest<ProfileCubit, ProfileState>(
    'surfaces a write failure instead of hanging on the spinner',
    setUp: () => when(
      () => users.ensureProfile(),
    ).thenThrow(Exception('permission-denied')),
    build: () => ProfileCubit(users),
    act: (cubit) => cubit.loadProfile(),
    expect: () => [isA<ProfileLoading>(), isA<ProfileError>()],
  );
}
