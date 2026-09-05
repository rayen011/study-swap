import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/features/profile/screens/profile_screen.dart';

/// Regression tests for the profile tab overflow.
///
/// A real device handed the empty state 2 logical pixels of height and the
/// plain `Center(Column(...))` overflowed by 79, painting the yellow-and-black
/// stripes over the tab. These pump the same widget at hostile heights.
void main() {
  Future<void> pumpAt(WidgetTester tester, double height) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 392.7,
              height: height,
              child: const ProfileEmptyTab(
                icon: Icons.storefront_outlined,
                message: 'No active listings',
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('survives the 2px height that caused the overflow', (
    tester,
  ) async {
    await pumpAt(tester, 2.1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives zero height', (tester) async {
    await pumpAt(tester, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders normally when there is room', (tester) async {
    await pumpAt(tester, 600);

    expect(tester.takeException(), isNull);
    expect(find.text('No active listings'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });

  testWidgets('centres its content when there is room', (tester) async {
    await pumpAt(tester, 600);

    // Vertically centred means the icon sits well below the top edge.
    final icon = tester.getCenter(find.byIcon(Icons.storefront_outlined));
    expect(icon.dy, greaterThan(200));
  });
}
