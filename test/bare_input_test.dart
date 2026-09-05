import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/core/theme/app_theme.dart';

/// Regression tests for the box-in-a-box.
///
/// `InputDecorationTheme` sets `enabledBorder` and `focusedBorder`, and those
/// take precedence over `border`. A field that only said
/// `border: InputBorder.none` still got the theme's rounded outline and fill
/// painted inside its own hand-drawn container.
void main() {
  /// Renders a field the way the sell form does: inside a bordered container.
  Future<void> pumpInContainer(WidgetTester tester, InputDecoration d) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(decoration: d),
          ),
        ),
      ),
    );
  }

  InputDecoration effective(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField)).decoration!;
  }

  testWidgets('bareInput clears every border slot, not just border', (
    tester,
  ) async {
    await pumpInContainer(tester, AppTheme.bareInput(hintText: 'Title'));
    final d = effective(tester);

    // All five have to be none. Clearing only `border` was the bug.
    expect(d.border, InputBorder.none);
    expect(d.enabledBorder, InputBorder.none);
    expect(d.focusedBorder, InputBorder.none);
    expect(d.errorBorder, InputBorder.none);
    expect(d.focusedErrorBorder, InputBorder.none);
  });

  testWidgets('bareInput turns the theme fill off', (tester) async {
    // The theme fills with AppColors.background; inside an already-filled
    // container that reads as a second, inset box.
    await pumpInContainer(tester, AppTheme.bareInput());

    expect(effective(tester).filled, isFalse);
  });

  testWidgets('the theme still styles ordinary fields', (tester) async {
    // The opt-out must not become the default — login and signup rely on the
    // theme drawing their outline.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TextField()),
      ),
    );

    final theme = Theme.of(
      tester.element(find.byType(TextField)),
    ).inputDecorationTheme;

    expect(theme.filled, isTrue);
    expect(theme.enabledBorder, isA<OutlineInputBorder>());
  });

  testWidgets('hideErrorText collapses the inline message', (tester) async {
    // The sell form renders its validation error below the container, so the
    // inline one would double up.
    await pumpInContainer(
      tester,
      AppTheme.bareInput(hintText: 'Price', hideErrorText: true),
    );

    expect(effective(tester).errorStyle?.fontSize, 0);
  });

  testWidgets('errors stay visible by default', (tester) async {
    await pumpInContainer(tester, AppTheme.bareInput(hintText: 'Message'));

    expect(effective(tester).errorStyle, isNull);
  });
}
