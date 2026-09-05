import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The Bid Room's palette: the app's own colours, inverted.
///
/// Nothing here is a new brand. The lime is [AppColors.limeGreen] and the red
/// is [AppColors.errorRed] — what changes is the ground they sit on. The room
/// is a full-screen route with the tab bar gone, and giving it a dark surface
/// is what makes bidding feel like somewhere you went rather than a sixth tab.
///
/// It also settles, deliberately and in one place, the dark-mode question the
/// rest of the app has been putting off: the neo-brutalist look is built on
/// black borders and hard black offset shadows, which vanish on a black
/// ground. In here the shadow becomes lime and the border becomes a light
/// hairline, and that swap is the answer.
class RoomColors {
  const RoomColors._();

  /// The ground. Matches the credits card on the profile exactly, which is
  /// what ties the door to the room behind it.
  static const Color ground = AppColors.solidBlack;

  /// One step up from the ground, for inset panels and thumbnails.
  static const Color raised = Color(0xFF141416);

  /// Hairline borders, where the light app would use a 2px black one.
  static const Color line = Color(0xFF2A2A2E);

  /// Filled placeholders and disabled marks.
  static const Color muted = Color(0xFF4B4B52);

  /// The accent, and the only bright colour in here.
  static const Color accent = AppColors.limeGreen;

  static const Color textPrimary = AppColors.white;

  /// Body copy on the dark ground. The app's borderGrey, which clears the
  /// contrast floor on black where its textGrey does not.
  static const Color textSecondary = AppColors.borderGrey;

  /// Labels and captions only — under 4.5:1 on this ground, so never body.
  static const Color textTertiary = AppColors.textGrey;

  /// Outbid, and nothing else. One red in the whole room.
  static const Color warning = AppColors.errorRed;

  /// Reserve marks, borrowed from the app's star colour.
  static const Color reserve = AppColors.primaryYellow;
}
