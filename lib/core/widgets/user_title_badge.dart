import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class UserTitleBadge extends StatelessWidget {
  final String title;
  final bool isCompact;

  const UserTitleBadge({
    super.key,
    required this.title,
    this.isCompact = false,
  });

  /// Deliberately dark, saturated inks: the badge sits on a tinted wash of the
  /// same hue, so the colour has to carry contrast against near-white.
  Color _getTitleColor() {
    switch (title) {
      case 'Campus Pro':
        return const Color(0xFFB3261E); // deep red
      case 'Deal Maker':
        return const Color(0xFFB25E00); // burnt orange
      case 'Trade Regular':
        return const Color(0xFF8A6100); // dark amber
      case 'Campus Seller':
        return AppColors.primaryBlue;
      case 'Freshman Trader':
        return const Color(0xFF2C6A45); // forest green
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTitleColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.solidBlack,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        title.toUpperCase(),
        style:
            (isCompact ? AppTextStyles.bodySmall : AppTextStyles.bodyMediumDark)
                .copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 11 : 12,
                ),
      ),
    );
  }
}
