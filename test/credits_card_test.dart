import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/constants/credit_rules.dart';
import 'package:studyswap/core/models/app_user.dart';
import 'package:studyswap/core/widgets/credits_card.dart';

void main() {
  AppUser member({int credits = 0, int creditsLocked = 0}) => AppUser(
    id: 'u1',
    fullName: 'Amina Khan',
    email: 'amina@uni.ac.uk',
    university: 'Oxford',
    rating: 4.8,
    ratingCount: 12,
    dealCount: 17,
    title: 'Deal Maker',
    credits: credits,
    creditsLocked: creditsLocked,
    isSuspended: false,
    createdAt: null,
  );

  Future<void> pump(WidgetTester tester, AppUser user) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CreditsCard(user: user)),
      ),
    );
  }

  group('the balance', () {
    testWidgets('shows the credits earned', (tester) async {
      await pump(tester, member(credits: 185));

      expect(find.text('185'), findsOneWidget);
    });

    testWidgets('says where they came from when nothing is staked', (
      tester,
    ) async {
      await pump(tester, member(credits: 185));

      expect(find.textContaining('Earned by trading'), findsOneWidget);
    });

    testWidgets('shows what is staked and what is left when a bid stands', (
      tester,
    ) async {
      // The free balance is what decides the next bid, so it has to be the
      // number on the card — not the total, which is bigger and misleading.
      await pump(tester, member(credits: 185, creditsLocked: 60));

      expect(find.textContaining('60 staked'), findsOneWidget);
      expect(find.textContaining('125 free'), findsOneWidget);
    });
  });

  group('the explainer', () {
    testWidgets('opens on tap', (tester) async {
      await pump(tester, member(credits: 185));

      await tester.tap(find.byType(CreditsCard));
      await tester.pumpAndSettle();

      expect(find.text('How credits work'), findsOneWidget);
    });

    testWidgets('lists every way of earning, with its amount', (tester) async {
      await pump(tester, member(credits: 50));
      await tester.tap(find.byType(CreditsCard));
      await tester.pumpAndSettle();

      for (final earning in CreditRules.earnings) {
        expect(find.text(earning.label), findsOneWidget);
        expect(find.text('+${earning.amount}'), findsWidgets);
      }
    });

    testWidgets('groups the thousands in the ceiling', (tester) async {
      // "up to £2000" reads as a serial number, not an amount.
      await pump(tester, member(credits: 50));
      await tester.tap(find.byType(CreditsCard));
      await tester.pumpAndSettle();

      expect(find.textContaining('£2,000'), findsOneWidget);
    });

    testWidgets('states plainly that credits are not money', (tester) async {
      // Not decoration: a fake currency that looks purchasable is the thing
      // that turns an auction feature into a payments product under review.
      await pump(tester, member(credits: 50));
      await tester.tap(find.byType(CreditsCard));
      await tester.pumpAndSettle();

      expect(find.textContaining('no monetary value'), findsOneWidget);
      expect(find.textContaining('cannot be bought'), findsOneWidget);
    });
  });

  testWidgets('fits a narrow phone without overflowing', (tester) async {
    // The profile screen has overflowed under a tight parent before; this card
    // sits in the same column.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, member(credits: 1240, creditsLocked: 320));

    expect(tester.takeException(), isNull);
  });
}
