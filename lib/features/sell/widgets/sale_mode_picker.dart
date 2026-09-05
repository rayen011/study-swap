import 'package:flutter/material.dart';

import '../../../core/constants/auction_rules.dart';
import '../../../core/constants/listing_options.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/room_colors.dart';

/// Fixed price, or let the room decide.
///
/// The auction card is black with a lime offset shadow — the same anatomy as
/// the door in the feed and the credits card on the profile. Picking it should
/// feel like choosing the other place, not ticking a checkbox.
class SaleModePicker extends StatelessWidget {
  const SaleModePicker({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final SaleMode mode;
  final ValueChanged<SaleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight, not CrossAxisAlignment.stretch: the picker sits in a
    // scroll view, where stretch asks a Row for infinite height and takes the
    // whole form's layout down with it — silently, with a blank screen and no
    // red error box to explain it.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ModeCard(
              icon: Icons.sell_outlined,
              title: 'Fixed price',
              blurb: 'You name it, someone pays it.',
              selected: mode == SaleMode.fixed,
              dark: false,
              onTap: () => onChanged(SaleMode.fixed),
            ),
          ),
          AppSizes.gapWSm,
          Expanded(
            child: _ModeCard(
              icon: Icons.gavel_rounded,
              title: 'Let the room decide',
              blurb: 'Bidders find the price for you.',
              selected: mode == SaleMode.auction,
              dark: true,
              onTap: () => onChanged(SaleMode.auction),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String blurb;
  final bool selected;

  /// The auction card inverts when chosen — it belongs to the room.
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inverted = dark && selected;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: inverted ? RoomColors.ground : AppColors.white,
            border: Border.all(
              color: selected ? AppColors.solidBlack : AppColors.borderGrey,
              width: selected ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: inverted
                          ? RoomColors.accent
                          : AppColors.solidBlack,
                      offset: const Offset(3, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: inverted
                    ? RoomColors.accent
                    : selected
                    ? AppColors.solidBlack
                    : AppColors.textGrey,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: AppTextStyles.buttonText.copyWith(
                  fontSize: 14,
                  color: inverted ? AppColors.white : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blurb,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  height: 1.4,
                  color: inverted
                      ? RoomColors.textSecondary
                      : AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three lengths a floor can run for.
class DurationPicker extends StatelessWidget {
  const DurationPicker({
    super.key,
    required this.hours,
    required this.onChanged,
  });

  final int hours;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in AuctionRules.durations) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.hours),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: option.hours == hours
                      ? AppColors.primaryBlue
                      : AppColors.white,
                  border: Border.all(
                    color: option.hours == hours
                        ? AppColors.primaryBlue
                        : AppColors.borderGrey,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.buttonText.copyWith(
                    fontSize: 13,
                    color: option.hours == hours
                        ? AppColors.white
                        : AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ),
          if (option != AuctionRules.durations.last) AppSizes.gapWSm,
        ],
      ],
    );
  }
}

/// Explains what a hidden reserve actually hides.
///
/// Worth saying in full: "hidden reserve" sounds like the number is secret
/// *and* its existence is. Bidders are told there is one, because an auction
/// that quietly refuses to sell is a worse experience than one that says why.
class ReserveNote extends StatelessWidget {
  const ReserveNote({super.key, required this.reserve});

  final int? reserve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 15,
              color: AppColors.primaryBlue,
            ),
          ),
          AppSizes.gapWSm,
          Expanded(
            child: Text(
              reserve == null
                  ? 'Without a reserve, the highest bid wins whatever it is.'
                  : 'Bidders are told a reserve exists — never what it is. '
                        'Below £$reserve nothing sells and every bidder gets '
                        'their credits back.',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11,
                height: 1.45,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
