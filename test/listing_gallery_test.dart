import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/widgets/listing_gallery.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<String> urls, {
    GalleryIndicator indicator = GalleryIndicator.dots,
    PageController? controller,
    ValueChanged<int>? onPageChanged,
    VoidCallback? onCardTap,
    ScrollController? listController,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Mirrors the feed: a vertical list of tappable cards, each with a
          // horizontal gallery inside.
          body: ListView(
            controller: listController,
            children: [
              GestureDetector(
                onTap: onCardTap,
                child: SizedBox(
                  height: 150,
                  child: ListingGallery(
                    imageUrls: urls,
                    indicator: indicator,
                    controller: controller,
                    onPageChanged: onPageChanged,
                  ),
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
  }

  List<String> urls(int n) =>
      List.generate(n, (i) => 'https://example.test/$i.jpg');

  /// `pumpAndSettle` never returns here: CachedNetworkImage shows a spinning
  /// placeholder for a URL that will never resolve in a test, so the frame
  /// scheduler is never idle. Pump enough frames for the page animation and
  /// move on.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('how many photos there are', () {
    testWidgets('no photos renders a placeholder, not a page view', (
      tester,
    ) async {
      await pump(tester, const []);

      expect(find.byType(PageView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one photo skips the page view entirely', (tester) async {
      // Nothing to swipe to, and a feed of twenty idle PageViews is waste.
      await pump(tester, urls(1));

      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('two or more photos become swipeable', (tester) async {
      await pump(tester, urls(3));

      expect(find.byType(PageView), findsOneWidget);
    });
  });

  group('swiping', () {
    testWidgets('a horizontal drag moves to the next photo', (tester) async {
      var page = 0;
      await pump(tester, urls(3), onPageChanged: (i) => page = i);

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await settle(tester);

      expect(page, 1);
    });

    testWidgets('swiping does not fire the card tap', (tester) async {
      // The card opens the listing on tap; a swipe must not count as one.
      var taps = 0;
      await pump(tester, urls(3), onCardTap: () => taps++);

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await settle(tester);

      expect(taps, 0);
    });

    testWidgets('tapping the card still opens it', (tester) async {
      var taps = 0;
      await pump(tester, urls(3), onCardTap: () => taps++);

      await tester.tap(find.byType(PageView));
      await settle(tester);

      expect(taps, 1);
    });

    testWidgets('the vertical list still scrolls over a gallery', (
      tester,
    ) async {
      // The gallery claims horizontal drags only — the feed has to keep
      // scrolling when you swipe up across a card.
      //
      // Asserted on the list's offset rather than the card's position: a
      // scrolled-away card leaves the viewport and is disposed, so there is
      // no PageView left to measure.
      final listController = ScrollController();
      addTearDown(listController.dispose);

      await pump(tester, urls(3), listController: listController);
      expect(listController.offset, 0);

      await tester.drag(find.byType(PageView), const Offset(0, -300));
      await settle(tester);

      expect(listController.offset, greaterThan(0));
    });
  });

  group('indicators', () {
    testWidgets('dots show one per photo', (tester) async {
      await pump(tester, urls(4));

      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });

    testWidgets('the counter reads current of total', (tester) async {
      await pump(tester, urls(5), indicator: GalleryIndicator.counter);

      expect(find.text('1 / 5'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await settle(tester);

      expect(find.text('2 / 5'), findsOneWidget);
    });

    testWidgets('none draws no indicator', (tester) async {
      await pump(tester, urls(3), indicator: GalleryIndicator.none);

      expect(find.byType(AnimatedContainer), findsNothing);
    });
  });

  group('an injected controller', () {
    testWidgets('drives the gallery from outside', (tester) async {
      // This is how the details screen's thumbnail strip works.
      final controller = PageController();
      addTearDown(controller.dispose);

      var page = 0;
      await pump(
        tester,
        urls(3),
        controller: controller,
        onPageChanged: (i) => page = i,
      );

      controller.jumpToPage(2);
      await settle(tester);

      expect(page, 2);
    });

    testWidgets('is not disposed by the gallery', (tester) async {
      // Ownership stays with the caller. If the gallery disposed an injected
      // controller, the details screen would throw when it disposed its own.
      // No addTearDown here — this test does the disposing itself.
      final controller = PageController();

      await pump(tester, urls(3), controller: controller);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Detached from the gone PageView, but still alive and disposable once.
      expect(controller.hasClients, isFalse);
      expect(controller.dispose, returnsNormally);
    });
  });
}
