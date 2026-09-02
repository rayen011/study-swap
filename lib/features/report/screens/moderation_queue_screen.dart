import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/report.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/report_repository.dart';

class ModerationQueueScreen extends StatelessWidget {
  const ModerationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportRepo = context.read<ReportRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Moderation Queue', style: AppTextStyles.heading2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.solidBlack),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<List<Report>>(
        stream: reportRepo.getPendingReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: AppColors.limeGreen),
                  AppSizes.gapHMD,
                  Text('All caught up!', style: AppTextStyles.heading2),
                  Text('No pending reports to review.', style: AppTextStyles.bodyMedium),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, index) => AppSizes.gapHMD,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(context, report);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Report report) {
    final createdAt = report.createdAt;
    final dateStr = createdAt == null
        ? ''
        : DateFormat('MMM d, HH:mm').format(createdAt);

    return GestureDetector(
      onTap: () =>
          context.push('/moderation/report/${report.id}', extra: report),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.solidBlack, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.targetType.isUser
                        ? const Color(0xFFE0E7FF)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.solidBlack, width: 1),
                  ),
                  child: Text(
                    report.targetType.label.toUpperCase(),
                    style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(dateStr, style: AppTextStyles.bodySmall),
              ],
            ),
            AppSizes.gapHMD,
            Text(report.reason,
                style: AppTextStyles.heading2.copyWith(fontSize: 16)),
            if (report.hasNote) ...[
              AppSizes.gapHSm,
              Text(
                report.additionalNote,
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            AppSizes.gapHMD,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'REVIEW DETAILS',
                  style: AppTextStyles.bodyMediumDark.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primaryBlue, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
