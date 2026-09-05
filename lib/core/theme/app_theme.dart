import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// The app's Material theme.
///
/// `AppColors` stays the source of truth for the palette; this turns it into a
/// [ThemeData] so Material's own widgets — dialogs, snackbars, sliders, tab
/// bars, bottom sheets, buttons — stop rendering in default Material purple and
/// pick up the app's colours instead. Before this, `ColorScheme.fromSeed` was
/// configured and then ignored by everything.
class AppTheme {
  AppTheme._();

  static ColorScheme get _colorScheme => ColorScheme.fromSeed(
    seedColor: AppColors.primaryBlue,
    primary: AppColors.primaryBlue,
    onPrimary: AppColors.white,
    surface: AppColors.cardBackground,
    onSurface: AppColors.textDark,
    error: AppColors.errorRed,
    onError: AppColors.white,
  );

  /// The neo-brutalist border used on cards, chips and inputs.
  static const BorderSide hardBorder = BorderSide(
    color: AppColors.solidBlack,
    width: 2,
  );

  static ThemeData get light {
    final colors = _colorScheme;
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,

      // Flat surfaces: depth comes from the offset black shadows the widgets
      // draw themselves, not from Material elevation.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.solidBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading2.copyWith(fontSize: 20),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.heading2.copyWith(fontSize: 18),
        contentTextStyle: AppTextStyles.bodyMediumDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: hardBorder,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Floating so it clears the bottom navigation bar.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.solidBlack,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        hintStyle: AppTextStyles.bodyMedium,
        errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed),
        border: _inputBorder(AppColors.borderGrey),
        enabledBorder: _inputBorder(AppColors.borderGrey),
        focusedBorder: _inputBorder(AppColors.primaryBlue, width: 1.5),
        errorBorder: _inputBorder(AppColors.errorRed),
        focusedErrorBorder: _inputBorder(AppColors.errorRed, width: 1.5),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: AppColors.textGrey,
        indicatorColor: AppColors.primaryBlue,
        labelStyle: AppTextStyles.buttonText.copyWith(fontSize: 12),
        dividerColor: Colors.transparent,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryBlue,
        inactiveTrackColor: AppColors.borderGrey,
        thumbColor: AppColors.solidBlack,
        overlayColor: AppColors.primaryBlue.withValues(alpha: 0.1),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderGrey,
        space: 1,
        thickness: 1,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryBlue
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.solidBlack, width: 2),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.solidBlack, width: 1.5),
          ),
          textStyle: AppTextStyles.buttonTextWhite,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.solidBlack, width: 1.5),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primaryBlue,
        textColor: AppColors.textDark,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Decoration for a field that draws its own container.
  ///
  /// Several fields — the search bar, the message composer, the sell form —
  /// sit inside a hand-drawn bordered `Container` and want no chrome of their
  /// own. Setting `border: InputBorder.none` is not enough: `enabledBorder`
  /// and `focusedBorder` take precedence over `border`, so the theme's
  /// rounded outline gets painted *inside* the container, giving a box in a
  /// box. Every border slot has to be cleared explicitly, and the fill turned
  /// off.
  ///
  /// [hideErrorText] suppresses the inline message for fields that render
  /// their validation error below the container instead.
  static InputDecoration bareInput({
    String? hintText,
    TextStyle? hintStyle,
    bool isDense = false,
    bool hideErrorText = false,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      isDense: isDense,
      counterText: counterText,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      errorStyle: hideErrorText
          ? const TextStyle(height: 0, fontSize: 0)
          : null,
    );
  }
}
