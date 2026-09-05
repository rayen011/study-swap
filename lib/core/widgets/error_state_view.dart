import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_text_styles.dart';
import '../theme/room_colors.dart';

/// The empty state for a screen whose data failed to load.
///
/// Exists because the raw failure was being rendered straight to the user —
/// a missing Firestore index put a wall of base64 on the marketplace feed,
/// which is a developer's problem shown in the user's app.
///
/// In debug builds the underlying message is still shown, indented and
/// scrollable, because that's the audience who can act on it.
///
/// Set [onDark] on the Bid Room's inverted surface. Without it the message
/// renders near-black on black and the debug panel is a white box in the
/// middle of a dark screen — an error nobody can read is the same as no
/// error at all, which is the exact failure this widget exists to prevent.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    this.onDark = false,
  });

  /// The raw failure. Only surfaced in debug builds.
  final String error;

  /// Shown as a "Try again" button when provided.
  final VoidCallback? onRetry;

  final IconData icon;

  /// Whether this sits on the Bid Room's dark ground.
  final bool onDark;

  /// Maps a failure to something a person can act on.
  ///
  /// Firestore's messages are written for developers — they name indexes,
  /// preconditions and RPC codes. These cover the cases a user can actually
  /// do something about; everything else gets the honest generic.
  String get _message {
    final lower = error.toLowerCase();

    if (lower.contains('permission-denied') ||
        lower.contains('permission_denied')) {
      return "You don't have access to this.";
    }
    if (lower.contains('unavailable') ||
        lower.contains('network') ||
        lower.contains('offline')) {
      return "Can't reach StudySwap. Check your connection.";
    }
    if (lower.contains('unauthenticated')) {
      return 'Your session expired. Sign in again.';
    }
    return "Something went wrong on our end.";
  }

  @override
  Widget build(BuildContext context) {
    final iconColour = onDark ? RoomColors.muted : AppColors.borderGrey;
    final textColour = onDark ? RoomColors.textPrimary : AppColors.textDark;
    final accent = onDark ? RoomColors.accent : AppColors.primaryBlue;
    final panel = onDark ? RoomColors.raised : AppColors.background;
    final panelBorder = onDark ? RoomColors.line : AppColors.borderGrey;
    final panelText = onDark ? RoomColors.textSecondary : AppColors.textGrey;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColour),
            AppSizes.gapHMD,
            Text(
              _message,
              style: AppTextStyles.bodyMediumDark.copyWith(
                fontSize: 15,
                color: textColour,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              AppSizes.gapHMD,
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                ),
              ),
            ],
            // Developer detail, debug builds only.
            if (kDebugMode) ...[
              AppSizes.gapHLG,
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: panelBorder),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    error,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: panelText,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
