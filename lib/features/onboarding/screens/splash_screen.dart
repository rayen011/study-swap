import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shown while Firebase restores the persisted session.
///
/// Without it the landing page flashes on every cold start before the router
/// learns the user is already signed in and redirects to the feed.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.solidBlack, width: 2),
                boxShadow: const [
                  BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
                ],
              ),
              child: const Icon(
                Icons.menu_book,
                color: AppColors.white,
                size: 40,
              ),
            ),
            AppSizes.gapHLG,
            Text(
              'StudySwap',
              style: AppTextStyles.heading2.copyWith(fontSize: 24),
            ),
            AppSizes.gapHXL,
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
