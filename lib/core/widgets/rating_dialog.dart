import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class RatingDialog extends StatefulWidget {
  final String title;
  final Function(int rating, String comment) onSubmitted;

  const RatingDialog({
    super.key,
    required this.title,
    required this.onSubmitted,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.solidBlack, width: 2),
      ),
      title: Text('Rate your trade', style: AppTextStyles.heading2.copyWith(fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How was your experience with the trade of:', style: AppTextStyles.bodyMedium),
          Text(widget.title, style: AppTextStyles.bodyMediumDark.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => setState(() => _rating = index + 1),
              );
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.solidBlack),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.solidBlack),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('SKIP', style: TextStyle(color: AppColors.textGrey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.solidBlack, width: 1.5),
            ),
          ),
          onPressed: _rating == 0
              ? null
              : () {
                  widget.onSubmitted(_rating, _commentController.text);
                  Navigator.pop(context);
                },
          child: const Text('SUBMIT'),
        ),
      ],
    );
  }
}
