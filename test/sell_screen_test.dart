import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyswap/core/models/listing.dart';
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

  Listing existing() => Listing.fromMap('l1', {
    'title': 'Campbell Biology, 12th Edition',
    'description': 'Light highlighting in chapter 3.',
    'price': 24.5,
    'category': 'textbooks',
    'condition': 'good',
    'university': 'Oxford',
    'userId': 'amina',
    'imageUrls': ['https://example.test/1.jpg', 'https://example.test/2.jpg'],
    'status': 'active',
  });

  Future<void> pump(WidgetTester tester, {Listing? editing}) {
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
        child: MaterialApp(home: SellScreen(existing: editing)),
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

  group('editing a listing already posted', () {
    testWidgets('opens filled in with what is there', (tester) async {
      // The alternative a seller had was deleting the listing and re-uploading
      // the photos to change a price.
      await pump(tester, editing: existing());
      await tester.pump();

      expect(find.textContaining('EDIT YOUR'), findsOneWidget);
      expect(find.text('Campbell Biology, 12th Edition'), findsOneWidget);
      expect(find.text('24.50'), findsOneWidget);
      expect(find.text('Light highlighting in chapter 3.'), findsOneWidget);
    });

    testWidgets('saves rather than posts', (tester) async {
      await pump(tester, editing: existing());
      await tester.pump();

      expect(find.text('SAVE CHANGES'), findsOneWidget);
      expect(find.text('POST LISTING'), findsNothing);
      // A draft belongs to something unposted.
      expect(find.text('SAVE DRAFT'), findsNothing);
    });

    testWidgets('does not offer to move it into the room', (tester) async {
      // Opening a floor sets a closing time and a reserve. That is a
      // different act from correcting a typo, and the rules refuse it as an
      // edit anyway.
      await pump(tester, editing: existing());
      await tester.pump();

      expect(find.text('HOW ARE YOU SELLING IT?'), findsNothing);
      expect(find.text('Let the room decide'), findsNothing);
    });

    testWidgets('shows the photos already uploaded, each removable', (
      tester,
    ) async {
      await pump(tester, editing: existing());
      await tester.pump();

      expect(find.text('PHOTOS (0/5)'), findsNothing);
      expect(find.byIcon(Icons.close), findsNWidgets(2));
    });

    testWidgets('never restores a saved draft over it', (tester) async {
      // A draft abandoned last week silently replacing a live listing is the
      // worst thing this screen could do.
      SharedPreferences.setMockInitialValues({
        'draft_title': 'Something else entirely',
        'draft_price': '999',
      });

      await pump(tester, editing: existing());
      await tester.pump();

      expect(find.text('Something else entirely'), findsNothing);
      expect(find.text('Campbell Biology, 12th Edition'), findsOneWidget);
    });
  });
}
