import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/features/auctions/widgets/countdown.dart';

void main() {
  group('how long is left', () {
    test('a week out, days and hours are enough', () {
      // A seconds counter on a seven-day auction is noise that also forces a
      // rebuild every second to change nothing.
      expect(
        formatCountdown(const Duration(days: 6, hours: 20, minutes: 30)),
        '6d 20h',
      );
    });

    test('within the day, hours and minutes', () {
      expect(
        formatCountdown(const Duration(hours: 5, minutes: 12, seconds: 40)),
        '5h 12m',
      );
    });

    test('within the hour, minutes and seconds', () {
      expect(
        formatCountdown(const Duration(minutes: 1, seconds: 48)),
        '1m 48s',
      );
    });

    test('in the last minute, just seconds', () {
      expect(formatCountdown(const Duration(seconds: 48)), '48s');
    });

    test('past the end it says so rather than counting backwards', () {
      expect(formatCountdown(Duration.zero), 'Closed');
      expect(formatCountdown(const Duration(seconds: -30)), 'Closed');
    });
  });

  group('how often it redraws', () {
    test('every second when seconds are on screen', () {
      expect(
        countdownTick(const Duration(minutes: 3)),
        const Duration(seconds: 1),
      );
    });

    test('every minute when they are not', () {
      // Twenty auctions in a list rebuilding every second, to change nothing.
      expect(
        countdownTick(const Duration(hours: 5)),
        const Duration(minutes: 1),
      );
      expect(
        countdownTick(const Duration(days: 2)),
        const Duration(minutes: 1),
      );
    });
  });

  group('the live countdown', () {
    Future<void> pump(WidgetTester tester, DateTime? endsAt, DateTime now) {
      return tester.pumpWidget(
        MaterialApp(
          home: Countdown(
            endsAt: endsAt,
            now: () => now,
            builder: (context, left) => Text(formatCountdown(left)),
          ),
        ),
      );
    }

    testWidgets('counts down as time passes', (tester) async {
      var now = DateTime(2026, 9, 4, 12);
      final endsAt = now.add(const Duration(seconds: 10));

      await tester.pumpWidget(
        MaterialApp(
          home: Countdown(
            endsAt: endsAt,
            now: () => now,
            builder: (context, left) => Text(formatCountdown(left)),
          ),
        ),
      );
      expect(find.text('10s'), findsOneWidget);

      // The widget re-reads its clock on each tick, so moving the clock and
      // firing the timer is what advances it.
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('7s'), findsOneWidget);

      // A live countdown always has a timer pending; unmount so the test ends
      // with none.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });

    testWidgets('stops at zero rather than going negative', (tester) async {
      final now = DateTime(2026, 9, 4, 12);
      await pump(tester, now.subtract(const Duration(minutes: 5)), now);

      expect(find.text('Closed'), findsOneWidget);
    });

    testWidgets('a missing end time reads as closed', (tester) async {
      await pump(tester, null, DateTime(2026, 9, 4, 12));

      expect(find.text('Closed'), findsOneWidget);
    });

    testWidgets('follows the end time when a late bid moves it', (
      tester,
    ) async {
      // The anti-snipe rule pushes the close out; a countdown still running to
      // the old time would hit zero while bidding is open.
      final now = DateTime(2026, 9, 4, 12);
      await pump(tester, now.add(const Duration(seconds: 30)), now);
      expect(find.text('30s'), findsOneWidget);

      await pump(tester, now.add(const Duration(minutes: 2)), now);
      expect(find.text('2m 0s'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });

    testWidgets('cancels its timer when it leaves the tree', (tester) async {
      // A list scrolls rows in and out constantly; a leaked timer per row
      // would keep firing setState on a dead element.
      final now = DateTime(2026, 9, 4, 12);
      await pump(tester, now.add(const Duration(seconds: 30)), now);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  });
}
