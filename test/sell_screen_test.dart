import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyswap/features/listings/logic/listing_cubit.dart';
import 'package:studyswap/features/listings/logic/listing_state.dart';
import 'package:studyswap/features/profile/logic/profile_cubit.dart';
import 'package:studyswap/features/profile/logic/profile_state.dart';
import 'package:studyswap/features/sell/screens/sell_screen.dart';

class _MockListingCubit extends MockCubit<ListingState>
    implements ListingCubit {}

class _MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

void main() {
  late _MockListingCubit listings;
  late _MockProfileCubit profile;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    listings = _MockListingCubit();
    profile = _MockProfileCubit();
    when(() => listings.state).thenReturn(ListingInitial());
    when(() => profile.state).thenReturn(ProfileInitial());
  });

  Future<void> pump(WidgetTester tester) {
    // Tall, because the form is long and a tap misses a widget below the
    // fold. Wider than a phone on purpose: the form has a pre-existing 16px
    // overflow at 393dp and under, which is a separate bug from anything
    // these tests are checking.
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ListingCubit>.value(value: listings),
          BlocProvider<ProfileCubit>.value(value: profile),
        ],
        child: const MaterialApp(home: SellScreen()),
      ),
    );
  }

  testWidgets('the form renders', (tester) async {
    // A regression test for a whole blank screen. The sale-mode picker asked
    // a Row for infinite height inside the form's scroll view, which killed
    // the subtree's layout — on a device that shows as an empty body with no
    // red error box and nothing in logcat, so nothing points at the cause.
    await pump(tester);
    await tester.pump();

    expect(find.textContaining('SELLING?'), findsOneWidget);
    expect(find.text('TITLE *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the auction settings appear only in auction mode', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('PRICE *'), findsOneWidget);
    expect(find.text('HOW LONG'), findsNothing);

    await tester.tap(find.text('Let the room decide'));
    await tester.pump();

    // The price field changes meaning, so it changes name.
    expect(find.text('OPENING PRICE *'), findsOneWidget);
    expect(find.text('HOW LONG'), findsOneWidget);
    expect(find.text('SET A RESERVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reserve field only appears once switched on', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Let the room decide'));
    await tester.pump();

    expect(find.textContaining('highest bid wins'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('Minimum you would accept'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
