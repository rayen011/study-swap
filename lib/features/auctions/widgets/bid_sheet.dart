import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/credit_rules.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/auction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/room_colors.dart';

/// Opens the bid sheet and returns the amount the bidder settled on, or null.
///
/// Returning the amount rather than placing the bid itself keeps this a form:
/// the cubit owns the call, the sheet owns the number.
Future<int?> showBidSheet({
  required BuildContext context,
  required Auction auction,
  required AppUser bidder,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: RoomColors.ground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      // Lift the sheet above the keyboard rather than letting it cover the
      // one field on it.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _BidSheet(auction: auction, bidder: bidder),
    ),
  );
}

class _BidSheet extends StatefulWidget {
  const _BidSheet({required this.auction, required this.bidder});

  final Auction auction;
  final AppUser bidder;

  @override
  State<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<_BidSheet> {
  late final TextEditingController _controller;
  late int _amount;

  int get _minimum => widget.auction.minimumBid;
  int get _ceiling => widget.bidder.maxBid;

  @override
  void initState() {
    super.initState();
    _amount = _minimum;
    _controller = TextEditingController(text: '$_amount');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setAmount(int value) {
    setState(() => _amount = value);
    _controller.text = '$value';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  /// Four one-tap amounts, starting at the cheapest legal bid.
  ///
  /// The minimum is first so nobody has to work out five percent in their
  /// head, and anything past the ceiling is dropped rather than shown and
  /// refused.
  List<int> get _shortcuts {
    final steps = <int>{
      _minimum,
      (_minimum * 1.1).ceil(),
      (_minimum * 1.35).ceil(),
      (_minimum * 2).ceil(),
    };
    return steps.where((step) => step <= _ceiling).take(4).toList();
  }

  bool get _isValid => _amount >= _minimum && _amount <= _ceiling;

  @override
  Widget build(BuildContext context) {
    final stake = CreditRules.stakeFor(_amount);
    final free = widget.bidder.availableCredits;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RoomColors.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSizes.gapHMD,
            Text(
              'Your bid',
              style: AppTextStyles.heading2.copyWith(
                fontSize: 22,
                color: RoomColors.textPrimary,
              ),
            ),
            AppSizes.gapHMD,

            _AmountField(
              controller: _controller,
              onChanged: (value) =>
                  setState(() => _amount = int.tryParse(value) ?? 0),
            ),
            AppSizes.gapHMD,

            Row(
              children: [
                for (final step in _shortcuts) ...[
                  Expanded(
                    child: _Shortcut(
                      amount: step,
                      isMinimum: step == _minimum,
                      isSelected: step == _amount,
                      onTap: () => _setAmount(step),
                    ),
                  ),
                  if (step != _shortcuts.last) const SizedBox(width: 8),
                ],
              ],
            ),
            AppSizes.gapHMD,

            _CostPanel(
              stake: stake,
              free: free,
              ceiling: _ceiling,
              amount: _amount,
            ),
            AppSizes.gapHMD,

            // The consequence of winning, before the button rather than after.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: RoomColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Win and this opens a chat with ${widget.auction.sellerName} '
                    'with the deal already agreed at your price. Don\'t turn up '
                    'and the $stake credits go to them.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: RoomColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            AppSizes.gapHMD,

            _BidButton(
              amount: _amount,
              enabled: _isValid,
              onPressed: () => Navigator.of(context).pop(_amount),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: RoomColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '£',
            style: AppTextStyles.heading1.copyWith(
              fontSize: 28,
              color: RoomColors.textTertiary,
            ),
          ),
          IntrinsicWidth(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              textAlign: TextAlign.left,
              keyboardType: TextInputType.number,
              // Whole pounds only — the server refuses pennies, so the
              // keyboard should not offer them.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              cursorColor: RoomColors.accent,
              style: AppTextStyles.heading1.copyWith(
                fontSize: 48,
                color: RoomColors.textPrimary,
                height: 1.1,
              ),
              decoration: AppTheme.bareInput(isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.amount,
    required this.isMinimum,
    required this.isSelected,
    required this.onTap,
  });

  final int amount;
  final bool isMinimum;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? RoomColors.accent : RoomColors.line,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '£$amount',
              style: AppTextStyles.buttonText.copyWith(
                fontSize: 14,
                color: isSelected
                    ? RoomColors.accent
                    : RoomColors.textSecondary,
              ),
            ),
            if (isMinimum)
              Text(
                'min',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  color: RoomColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the bid costs to hold, and what is left afterwards.
///
/// The ceiling is stated with the reason under it, so a low one reads as
/// something you can raise by trading rather than an arbitrary punishment.
class _CostPanel extends StatelessWidget {
  const _CostPanel({
    required this.stake,
    required this.free,
    required this.ceiling,
    required this.amount,
  });

  final int stake;
  final int free;
  final int ceiling;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final overCeiling = amount > ceiling;
    final fraction = ceiling == 0 ? 0.0 : (amount / ceiling).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RoomColors.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Line(label: 'Holds', value: '$stake credits'),
          const SizedBox(height: 10),
          _Line(
            label: 'Free afterwards',
            value: '${(free - stake).clamp(0, free)} of $free',
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: RoomColors.line),
          const SizedBox(height: 10),
          _Line(
            label: 'Your ceiling',
            value: '£$ceiling',
            emphasis: overCeiling ? RoomColors.warning : null,
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: RoomColors.line,
              valueColor: AlwaysStoppedAnimation(
                overCeiling ? RoomColors.warning : RoomColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              overCeiling
                  ? 'Over your ceiling. Complete more deals to raise it.'
                  : 'Earned by trading. Trade more, bid higher.',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11,
                color: overCeiling
                    ? RoomColors.warning
                    : RoomColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.emphasis});

  final String label;
  final String value;
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 13,
            color: RoomColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.buttonText.copyWith(
            fontSize: 14,
            color: emphasis ?? RoomColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BidButton extends StatelessWidget {
  const _BidButton({
    required this.amount,
    required this.enabled,
    required this.onPressed,
  });

  final int amount;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: enabled ? RoomColors.accent : RoomColors.line,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'BID £$amount',
          textAlign: TextAlign.center,
          style: AppTextStyles.buttonText.copyWith(
            fontSize: 16,
            color: enabled ? AppColors.solidBlack : RoomColors.muted,
          ),
        ),
      ),
    );
  }
}
