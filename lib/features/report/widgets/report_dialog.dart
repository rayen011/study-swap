import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/report_repository.dart';

enum ReportTargetType { user, listing }

/// Shows a bottom-sheet report dialog.
/// Call via [ReportDialog.show].
class ReportDialog extends StatefulWidget {
  final String targetId;
  final ReportTargetType targetType;
  final String targetName;

  const ReportDialog({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.targetName,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required ReportTargetType targetType,
    required String targetName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportDialog(
        targetId: targetId,
        targetType: targetType,
        targetName: targetName,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  static const _userReasons = [
    'Scam / Fraud',
    'Fake Profile',
    'Harassment or Abuse',
    'Inappropriate Content',
    'Spam',
    'Other',
  ];

  static const _listingReasons = [
    'Fake or Misleading Listing',
    'Prohibited Item',
    'Price Gouging',
    'Already Sold / Duplicate',
    'Spam',
    'Other',
  ];

  String? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;

  List<String> get _reasons => widget.targetType == ReportTargetType.user
      ? _userReasons
      : _listingReasons;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _submitting = true);

    try {
      await ReportRepository().submitReport(
        targetId: widget.targetId,
        targetType: widget.targetType == ReportTargetType.user
            ? 'user'
            : 'listing',
        reason: _selectedReason!,
        additionalNote: _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text("Report submitted. We'll review it shortly."),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.targetType == ReportTargetType.user;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.solidBlack,
              blurRadius: 0,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.borderGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.solidBlack,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isUser
                              ? Icons.person_off_outlined
                              : Icons.flag_outlined,
                          color: Colors.red.shade700,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUser ? 'Report User' : 'Report Listing',
                              style: AppTextStyles.heading2.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              widget.targetName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "What's the issue?",
                    style: AppTextStyles.bodyMediumDark.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reason chips
                  ..._reasons.map((reason) {
                    final isSelected = _selectedReason == reason;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedReason = reason),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.red.shade50
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.red.shade700
                                : AppColors.borderGrey,
                            width: isSelected ? 2 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.red.shade100,
                                    offset: const Offset(2, 2),
                                  ),
                                ]
                              : const [
                                  BoxShadow(
                                    color: AppColors.solidBlack,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isSelected
                                  ? Colors.red.shade700
                                  : AppColors.textGrey,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              reason,
                              style: AppTextStyles.bodyMediumDark.copyWith(
                                color: isSelected
                                    ? Colors.red.shade700
                                    : AppColors.solidBlack,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Optional note
                  Text(
                    'Additional details (optional)',
                    style: AppTextStyles.bodyMediumDark.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: InputDecoration(
                      hintText: 'Describe what happened...',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderGrey,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.solidBlack,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE6C200)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Color(0xFF856404),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'False reports may result in account restrictions. Reports are anonymous.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF856404),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selectedReason == null || _submitting)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedReason == null
                            ? AppColors.borderGrey
                            : Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: AppColors.solidBlack,
                            width: 2,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'SUBMIT REPORT',
                              style: AppTextStyles.buttonTextWhite.copyWith(
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
