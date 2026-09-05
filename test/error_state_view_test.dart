import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/theme/room_colors.dart';
import 'package:studyswap/core/widgets/error_state_view.dart';

/// The user-facing half of the error state. The developer detail block is
/// debug-only and shows in these tests too, which is why the assertions look
/// for the friendly message rather than the absence of the raw one.
void main() {
  Future<void> pump(WidgetTester tester, String error, {VoidCallback? retry}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorStateView(error: error, onRetry: retry),
        ),
      ),
    );
  }

  testWidgets('a missing index reads as a generic failure, not a stack trace', (
    tester,
  ) async {
    // This is the real message that put a wall of base64 on the feed.
    await pump(
      tester,
      '[cloud_firestore/failed-precondition] FAILED_PRECONDITION: The query '
      'requires an index. You can create it here: https://console.firebase'
      '.google.com/v1/r/project/studyswap-1bdf3/firestore/indexes?create_'
      'composite=ClBwcm9qZWN0cy9zdHVkeXN3YXAtMWJkZjMvZGF0YWJhc2Vz',
    );

    expect(find.text('Something went wrong on our end.'), findsOneWidget);
  });

  testWidgets('a permission failure says so plainly', (tester) async {
    await pump(
      tester,
      '[cloud_firestore/permission-denied] Missing or '
      'insufficient permissions.',
    );

    expect(find.text("You don't have access to this."), findsOneWidget);
  });

  testWidgets('an offline failure points at the connection', (tester) async {
    await pump(
      tester,
      '[cloud_firestore/unavailable] The service is '
      'currently unavailable.',
    );

    expect(
      find.text("Can't reach StudySwap. Check your connection."),
      findsOneWidget,
    );
  });

  testWidgets('an expired session tells the user to sign in', (tester) async {
    await pump(tester, 'UNAUTHENTICATED: request had invalid credentials');

    expect(find.text('Your session expired. Sign in again.'), findsOneWidget);
  });

  testWidgets('retry is offered only when there is something to retry', (
    tester,
  ) async {
    await pump(tester, 'boom');
    expect(find.text('Try again'), findsNothing);

    var retried = 0;
    await pump(tester, 'boom', retry: () => retried++);
    await tester.tap(find.text('Try again'));

    expect(retried, 1);
  });

  testWidgets('a very long failure does not overflow', (tester) async {
    await pump(tester, 'x' * 5000);

    // The raw block is height-capped and scrollable; nothing paints outside
    // its bounds, which is what the original bug did.
    expect(tester.takeException(), isNull);
  });

  group("on the Bid Room's dark ground", () {
    testWidgets('the message is legible rather than near-black on black', (
      tester,
    ) async {
      // An error nobody can read is the same as no error at all, which is the
      // exact failure this widget exists to prevent.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: ErrorStateView(error: 'permission-denied', onDark: true),
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.text("You don't have access to this."),
      );

      expect(text.style?.color, RoomColors.textPrimary);
    });

    testWidgets('the light default is unchanged', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorStateView(error: 'permission-denied')),
        ),
      );

      final text = tester.widget<Text>(
        find.text("You don't have access to this."),
      );

      expect(text.style?.color, isNot(RoomColors.textPrimary));
    });
  });
}
