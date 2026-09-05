import 'package:flutter/material.dart';

import '../constants/credit_rules.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_text_styles.dart';

/// The member's credit balance, on their own profile.
///
/// Deliberately the one dark surface in a light app. Credits belong to the
/// bidding side of StudySwap, and giving them their own inverted palette here
/// is what makes that side feel like a different room rather than another tab.
///
/// Tapping it explains where the number came from — a balance nobody can
/// account for is just a number.
class CreditsCard extends StatelessWidget {
  const CreditsCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final locked = user.creditsLocked;

    return Semantics(
      button: true,
      label: '${user.credits} credits. How credits work.',
      child: GestureDetector(
        onTap: () => showCreditsExplainer(context),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.solidBlack,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.solidBlack, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.limeGreen, offset: Offset(3, 3)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CREDITS',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.limeGreen,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user.credits}',
                      style: AppTextStyles.heading1.copyWith(
                        color: AppColors.white,
                        fontSize: 30,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locked > 0
                          ? '$locked staked · ${user.availableCredits} free'
                          : 'Earned by trading. Never for sale.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.borderGrey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              AppSizes.gapWSm,
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.limeGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.question_mark_rounded,
                  size: 14,
                  color: AppColors.solidBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the sheet explaining how credits are earned and what they are for.
Future<void> showCreditsExplainer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // The shell route's bottom bar lives on the branch navigator, so a sheet
    // opened there is drawn *under* it. Credits belong to the bidding side of
    // the app, which is meant to take the whole screen when you are in it.
    useRootNavigator: true,
    backgroundColor: AppColors.solidBlack,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CreditsExplainer(),
  );
}

class _CreditsExplainer extends StatelessWidget {
  const _CreditsExplainer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSizes.gapHMD,
            Text(
              'How credits work',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.white,
                fontSize: 22,
              ),
            ),
            AppSizes.gapHSm,
            Text(
              'Credits are earned by completing real trades — not bought, not '
              'handed out daily. They are what a bid will cost you once the '
              'bidding room opens, which is what stops anyone bidding a number '
              'they could never back.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.borderGrey,
                height: 1.5,
              ),
            ),
            AppSizes.gapHLG,
            const _SectionLabel('EARNING THEM'),
            AppSizes.gapHSm,
            for (final earning in CreditRules.earnings)
              _EarningRow(earning: earning),
            AppSizes.gapHLG,
            const _SectionLabel('SPENDING THEM'),
            AppSizes.gapHSm,
            Text(
              'Bidding will not spend credits, it will hold them. A bid locks '
              '${CreditRules.stakePercent}% of itself until you are outbid or '
              'the item is yours. Your ceiling is your free balance times '
              '${CreditRules.bidMultiplier}, up to '
              '£${_grouped(CreditRules.maxBid)}.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.borderGrey,
                height: 1.5,
              ),
            ),
            AppSizes.gapHMD,
            Container(
              padding: const EdgeInsets.all(AppSizes.sm + 2),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textGrey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Credits have no monetary value. They cannot be bought, sold '
                'or withdrawn.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.borderGrey,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thousands separators, so a four-figure ceiling doesn't read as "2000".
String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.limeGreen,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.earning});

  final CreditEarning earning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              earning.label,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
            ),
          ),
          AppSizes.gapWSm,
          Text(
            '+${earning.amount}',
            style: AppTextStyles.buttonText.copyWith(
              color: AppColors.limeGreen,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
