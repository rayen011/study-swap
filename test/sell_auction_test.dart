import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/constants/listing_options.dart';
import 'package:studyswap/core/models/listing.dart';
import 'package:studyswap/features/sell/widgets/sale_mode_picker.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('choosing how to sell', () {
    testWidgets('offers both, fixed price by default', (tester) async {
      await pump(
        tester,
        SaleModePicker(mode: SaleMode.fixed, onChanged: (_) {}),
      );

      expect(find.text('Fixed price'), findsOneWidget);
      expect(find.text('Let the room decide'), findsOneWidget);
    });

    testWidgets('switching reports the new mode', (tester) async {
      SaleMode? picked;
      await pump(
        tester,
        SaleModePicker(mode: SaleMode.fixed, onChanged: (m) => picked = m),
      );

      await tester.tap(find.text('Let the room decide'));
      expect(picked, SaleMode.auction);
    });

    testWidgets('fits a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pump(
        tester,
        SaleModePicker(mode: SaleMode.auction, onChanged: (_) {}),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('how long the floor runs', () {
    testWidgets('offers the three the server accepts', (tester) async {
      // The server refuses anything else, so offering a fourth would be a
      // button that always fails.
      await pump(tester, DurationPicker(hours: 72, onChanged: (_) {}));

      expect(find.text('24 hours'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
    });

    testWidgets('reports the chosen length in hours', (tester) async {
      int? picked;
      await pump(
        tester,
        DurationPicker(hours: 72, onChanged: (h) => picked = h),
      );

      await tester.tap(find.text('7 days'));
      expect(picked, 168);
    });
  });

  group('what the reserve note says', () {
    testWidgets('with a reserve, that its existence is public', (tester) async {
      // "Hidden reserve" sounds like the fact of it is hidden too. It is not,
      // and an auction that quietly refuses to sell is worse than one that
      // says why.
      await pump(tester, const ReserveNote(reserve: 120));

      expect(find.textContaining('told a reserve exists'), findsOneWidget);
      expect(find.textContaining('never what it is'), findsOneWidget);
      expect(find.textContaining('£120'), findsOneWidget);
    });

    testWidgets('without one, that the top bid simply wins', (tester) async {
      await pump(tester, const ReserveNote(reserve: null));

      expect(find.textContaining('highest bid wins'), findsOneWidget);
    });
  });

  group('a listing that is up for bids', () {
    Listing listing({String? auctionId, String saleMode = 'fixed'}) =>
        Listing.fromMap('l1', {
          'title': 'Signed rugby ball',
          'price': 12,
          'userId': 'amina',
          'status': 'active',
          'saleMode': saleMode,
          'auctionId': ?auctionId,
        });

    test('needs both the mode and the floor to count as one', () {
      // A listing marked auction with no auction to open is a dead end: the
      // card would route to nothing.
      expect(listing(saleMode: 'auction').isAuction, isFalse);
      expect(listing(saleMode: 'auction', auctionId: 'a1').isAuction, isTrue);
    });

    test('a fixed-price listing never is, whatever else it carries', () {
      expect(listing(auctionId: 'a1').isAuction, isFalse);
    });

    test('a listing from before auctions existed reads as fixed', () {
      final old = Listing.fromMap('l0', const {'title': 'Old', 'price': 5});

      expect(old.saleMode, SaleMode.fixed);
      expect(old.isAuction, isFalse);
    });

    test('an unrecognised sale mode falls back to fixed, not auction', () {
      // Guessing auction would route the card at an auction that isn't there.
      final odd = Listing.fromMap('l2', const {'saleMode': 'sealed_bid'});

      expect(odd.saleMode, SaleMode.fixed);
    });
  });
}
