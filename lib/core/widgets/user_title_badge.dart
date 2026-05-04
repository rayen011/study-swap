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

  Color _getTitleColor() {
    switch (title) {
      case 'Campus Pro':
        return Colors.redAccent;
      case 'Deal Maker':
        return Colors.orangeAccent;
      case 'Trade Regular':
        return Colors.amber;
      case 'Campus Seller':
        return AppColors.primaryBlue;
      case 'Freshman Trader':
        return Colors.greenAccent;
      default:
        return const Color.fromARGB(255, 255, 255, 255);
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
        color: color.withOpacity(0.1),
        border: Border.all(
          color: const Color.fromARGB(255, 241, 241, 241),
          width: 2,
        ),
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
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontWeight: FontWeight.w900,
                  fontSize: isCompact ? 10 : 12,
                ),
      ),
    );
  }
}
