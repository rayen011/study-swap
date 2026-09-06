import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:studyswap/core/constants/listing_options.dart';
import 'package:studyswap/core/models/listing.dart';
import 'package:studyswap/features/listings/logic/listing_cubit.dart';
import 'package:studyswap/features/listings/logic/listing_state.dart';
import 'package:studyswap/features/listings/widgets/listing_owner_actions.dart';

class _MockListingCubit extends MockCubit<ListingState>
    implements ListingCubit {}

void main() {
  late _MockListingCubit cubit;

  // mocktail needs a real instance before `any()` can stand in for an enum.
  setUpAll(() => registerFallbackValue(ListingStatus.active));

  setUp(() {
    cubit = _MockListingCubit();
    when(() => cubit.state).thenReturn(ListingInitial());
  });

  Listing listing({
    String status = 'active',
    String saleMode = 'fixed',
    String? auctionId,
    List<String> images = const ['https://example.test/1.jpg'],
  }) => Listing.fromMap('l1', {
    'title': 'Campbell Biology, 12th Edition',
    'description': 'Light highlighting.',
    'price': 24.5,
    'category': 'textbooks',
    'condition': 'good',
    'userId': 'amina',
    'imageUrls': images,
    'status': status,
    'saleMode': saleMode,
    'auctionId': ?auctionId,
  });

  /// Opens the sheet the way a screen does, and settles its animation.
  Future<void> open(WidgetTester tester, Listing item) async {
    await tester.pumpWidget(
      BlocProvider<ListingCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showListingOwnerActions(context: context, listing: item),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('a listing you own', () {
    testWidgets('offers edit, reserve and delete', (tester) async {
      // Before this, the only action anywhere in the app was a delete button
      // on one tab. A seller who mistyped a price had to delete the listing
      // and re-upload the photos.
      await open(tester, listing());

      expect(find.text('Edit listing'), findsOneWidget);
      expect(find.text('Mark as reserved'), findsOneWidget);
      expect(find.text('Delete listing'), findsOneWidget);
    });

    testWidgets('offers to put a reserved one back on sale', (tester) async {
      await open(tester, listing(status: 'reserved'));

      expect(find.text('Put it back on sale'), findsOneWidget);
      expect(find.text('Mark as reserved'), findsNothing);
    });

    testWidgets('reserving asks the cubit for it', (tester) async {
      when(
        () => cubit.setStatus(any(), any()),
      ).thenAnswer((_) async {});

      await open(tester, listing());
      await tester.tap(find.text('Mark as reserved'));
      await tester.pumpAndSettle();

      verify(() => cubit.setStatus('l1', ListingStatus.reserved)).called(1);
    });

    testWidgets('says how many photos a delete takes with it', (tester) async {
      await open(tester, listing(images: const ['a.jpg', 'b.jpg']));

      expect(find.textContaining('2 photos'), findsOneWidget);
    });

    testWidgets('deleting asks first, and cancelling does nothing', (
      tester,
    ) async {
      await open(tester, listing());
      await tester.tap(find.text('Delete listing'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this listing?'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.deleteListing(any()));
    });

    testWidgets('confirming deletes it', (tester) async {
      when(() => cubit.deleteListing(any())).thenAnswer((_) async {});

      await open(tester, listing());
      await tester.tap(find.text('Delete listing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      verify(() => cubit.deleteListing('l1')).called(1);
    });
  });

  group('a listing that is up for bids', () {
    testWidgets('offers nothing, and says why', (tester) async {
      // Bidders staked credits against this title, photo and price. Changing
      // any of it underneath them is what an auction cannot allow — the rules
      // refuse the write, so the sheet should not offer it either.
      await open(tester, listing(saleMode: 'auction', auctionId: 'a1'));

      expect(find.text('Edit listing'), findsNothing);
      expect(find.text('Mark as reserved'), findsNothing);
      expect(find.text('Delete listing'), findsNothing);
      expect(find.textContaining('credits staked'), findsOneWidget);
    });
  });

  group('a listing that sold', () {
    testWidgets('cannot be edited or reserved, only explained', (tester) async {
      // `sold` is written by onDealCompleted; letting a seller edit around it
      // would make the listing and their deal count disagree.
      await open(tester, listing(status: 'sold'));

      expect(find.text('Edit listing'), findsNothing);
      expect(find.text('Mark as reserved'), findsNothing);
      expect(find.textContaining('sold'), findsWidgets);
    });

    testWidgets('can still be deleted', (tester) async {
      await open(tester, listing(status: 'sold'));

      expect(find.text('Delete listing'), findsOneWidget);
    });
  });
}
