import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/report.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../listings/data/listing_repository.dart';
import '../../profile/data/user_repository.dart';
import '../data/report_repository.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;

  /// Passed through from the queue so the screen renders immediately instead
  /// of flashing a spinner for a document the previous screen already has.
  final Report? initialReport;

  const ReportDetailsScreen({
    super.key,
    required this.reportId,
    this.initialReport,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  Report? _report;

  /// Whichever of the two the report points at; the other stays null.
  AppUser? _targetUser;
  Listing? _targetListing;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final reportRepository = context.read<ReportRepository>();
    final userRepository = context.read<UserRepository>();
    final listingRepository = context.read<ListingRepository>();

    try {
      final report = _report ?? await reportRepository.getReport(widget.reportId);
      if (report == null) return;

      AppUser? user;
      Listing? listing;
      if (report.targetType.isUser) {
        user = await userRepository.getUser(report.targetId);
      } else {
        listing = await listingRepository.getListing(report.targetId);
      }

      if (!mounted) return;
      setState(() {
        _report = report;
        _targetUser = user;
        _targetListing = listing;
      });
    } catch (_) {
      // Leaves the screen on whatever it already had; the target section
      // renders its "no longer exists" state.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _takeAction(ReportStatus status, String actionTaken) async {
    final report = _report;
    if (report == null) return;

    final reportRepository = context.read<ReportRepository>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    try {
      if (actionTaken == 'Hide Listing' && !report.targetType.isUser) {
        await reportRepository.hideListing(report.targetId);
      } else if (actionTaken == 'Suspend User') {
        // For a listing report, the user to suspend is the listing's owner.
        final userId = report.targetType.isUser
            ? report.targetId
            : (_targetListing?.userId ?? '');
        if (userId.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Cannot suspend: the listing owner is unknown.'),
              backgroundColor: Colors.red,
            ),
          );
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        await reportRepository.suspendUser(userId);
      }

      await reportRepository.resolveReport(
        reportId: widget.reportId,
        status: status,
        actionTaken: actionTaken,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Report resolved: $actionTaken'),
            backgroundColor: AppColors.limeGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: const Text('Review Report'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.solidBlack),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text('This report no longer exists.',
                  style: AppTextStyles.bodyMediumDark),
        ),
      );
    }

    final isListing = !report.targetType.isUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Review Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.solidBlack),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('REPORT INFO'),
            _buildInfoCard([
              _buildInfoRow('Type', report.targetType.label.toUpperCase()),
              _buildInfoRow('Reason', report.reason),
              if (report.hasNote)
                _buildInfoRow('Additional Note', report.additionalNote),
            ]),
            AppSizes.gapHLG,
            _buildSectionHeader('TARGET CONTEXT'),
            if (_targetListing != null)
              _buildInfoCard([
                _buildInfoRow('Title', _targetListing!.title),
                _buildInfoRow('Price', _targetListing!.formattedPrice),
                _buildInfoRow('Status', _targetListing!.status.label),
                _buildInfoRow('Seller ID', _targetListing!.userId),
              ])
            else if (_targetUser != null)
              _buildInfoCard([
                _buildInfoRow('Full Name', _targetUser!.fullName),
                _buildInfoRow('Email', _targetUser!.email),
                _buildInfoRow('University', _targetUser!.university),
                _buildInfoRow(
                  'Status',
                  _targetUser!.isSuspended ? 'SUSPENDED' : 'ACTIVE',
                ),
              ])
            else if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              const Text(
                'Target data no longer exists.',
                style: TextStyle(color: Colors.red),
              ),

            AppSizes.gapHXXL,
            _buildSectionHeader('MODERATOR ACTIONS'),
            AppSizes.gapHMD,

            CustomButton(
              text: 'DISMISS REPORT',
              type: ButtonType.outline,
              onPressed: _isLoading
                  ? null
                  : () => _takeAction(
                      ReportStatus.dismissed, 'Dismissed - No violation'),
            ),
            AppSizes.gapHMD,
            if (isListing) ...[
              CustomButton(
                text: 'HIDE LISTING',
                type: ButtonType.solid,
                onPressed: _isLoading
                    ? null
                    : () =>
                        _takeAction(ReportStatus.reviewed, 'Hide Listing'),
              ),
              AppSizes.gapHMD,
            ],

            CustomButton(
              text: 'SUSPEND USER',
              type: ButtonType.solid,
              backgroundColor: Colors.red,
              onPressed: _isLoading
                  ? null
                  : () =>
                      _takeAction(ReportStatus.reviewed, 'Suspend User'),
            ),

            AppSizes.gapHXXL,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title,
        style: AppTextStyles.bodyMediumDark.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.solidBlack, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMediumDark),
          ),
        ],
      ),
    );
  }
}
