import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../animations/app_animations.dart';

enum ButtonType { brutal, solid, outline }

/// CustomButton: A highly reusable button widget supporting multiple styles and animations.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final IconData? trailingIcon;
  final Widget? leadingWidget;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.solid,
    this.trailingIcon,
    this.leadingWidget,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingWidget != null) ...[
          Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: leadingWidget!,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: _getTextStyle().copyWith(
            color: textColor ?? (isDisabled ? _getTextStyle().color?.withValues(alpha: 0.5) : _getTextStyle().color),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(
            trailingIcon,
            color: _getIconColor().withValues(alpha: isDisabled ? 0.5 : 1.0),
            size: 20,
          ),
        ],
      ],
    );

    return TapBounce(
      onTap: isDisabled ? null : onPressed,
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        child: _buildButtonBody(buttonContent, isDisabled),
      ),
    );
  }

  Widget _buildButtonBody(Widget content, bool isDisabled) {
    switch (type) {
      case ButtonType.brutal:
        return Container(
          decoration: BoxDecoration(
            color: isDisabled ? AppColors.borderGrey : AppColors.limeGreen,
            border: Border.all(color: AppColors.solidBlack, width: 2.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDisabled
                ? null
                : const [
                    BoxShadow(
                      color: AppColors.solidBlack,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Center(child: content),
        );
      case ButtonType.solid:
        return Container(
          decoration: BoxDecoration(
            color: isDisabled 
              ? (backgroundColor?.withValues(alpha: 0.5) ?? AppColors.primaryBlue.withValues(alpha: 0.5)) 
              : (backgroundColor ?? AppColors.primaryBlue),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Center(child: content),
        );
      case ButtonType.outline:
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: isDisabled ? 0.5 : 1.0),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Center(child: content),
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (type) {
      case ButtonType.brutal:
        return AppTextStyles.buttonText;
      case ButtonType.solid:
        return AppTextStyles.buttonTextWhite;
      case ButtonType.outline:
        return AppTextStyles.buttonTextWhite.copyWith(
          color: AppColors.primaryBlue,
        );
    }
  }

  Color _getIconColor() {
    switch (type) {
      case ButtonType.brutal:
        return AppColors.solidBlack;
      case ButtonType.solid:
        return AppColors.white;
      case ButtonType.outline:
        return AppColors.primaryBlue;
    }
  }
}
