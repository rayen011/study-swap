import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../data/report_repository.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic>? initialData;

  const ReportDetailsScreen({
    super.key,
    required this.reportId,
    this.initialData,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  Map<String, dynamic>? _reportData;
  Map<String, dynamic>? _targetData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      if (widget.initialData != null) {
        _reportData = widget.initialData;
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('reports')
            .doc(widget.reportId)
            .get();
        _reportData = doc.data();
        _reportData?['id'] = doc.id;
      }

      if (_reportData != null) {
        final targetId = _reportData!['targetId'];
        final targetType = _reportData!['targetType'];
        final collection = targetType == 'user' ? 'users' : 'listings';

        final targetDoc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(targetId)
            .get();
        _targetData = targetDoc.data();
        _targetData?['id'] = targetDoc.id;
      }
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _takeAction(String status, String actionTaken) async {
    final reportRepo = context.read<ReportRepository>();
    final targetId = _reportData!['targetId'];
    final targetType = _reportData!['targetType'];

    setState(() => _isLoading = true);

    try {
      if (actionTaken == 'Hide Listing' && targetType == 'listing') {
        await reportRepo.hideListing(targetId);
      } else if (actionTaken == 'Suspend User') {
        final userId = targetType == 'user'
            ? targetId
            : (_targetData?['userId'] ?? '');
        if (userId.isNotEmpty) {
          await reportRepo.suspendUser(userId);
        }
      }

      await reportRepo.resolveReport(
        reportId: widget.reportId,
        status: status,
        actionTaken: actionTaken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report resolved: $actionTaken'),
            backgroundColor: AppColors.limeGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _reportData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final type = _reportData?['targetType'] ?? 'Unknown';
    final reason = _reportData?['reason'] ?? 'No reason';
    final note = _reportData?['additionalNote'] ?? '';

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
              _buildInfoRow('Type', type.toUpperCase()),
              _buildInfoRow('Reason', reason),
              if (note.isNotEmpty) _buildInfoRow('Additional Note', note),
            ]),
            AppSizes.gapHLG,
            _buildSectionHeader('TARGET CONTEXT'),
            if (_targetData != null)
              _buildInfoCard([
                if (type == 'listing') ...[
                  _buildInfoRow('Title', _targetData!['title'] ?? 'N/A'),
                  _buildInfoRow('Price', '£${_targetData!['price']}'),
                  _buildInfoRow('Status', _targetData!['status'] ?? 'N/A'),
                  _buildInfoRow('Seller ID', _targetData!['userId'] ?? 'N/A'),
                ] else ...[
                  _buildInfoRow('Full Name', _targetData!['fullName'] ?? 'N/A'),
                  _buildInfoRow('Email', _targetData!['email'] ?? 'N/A'),
                  _buildInfoRow(
                    'University',
                    _targetData!['university'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Status',
                    _targetData!['isSuspended'] == true
                        ? 'SUSPENDED'
                        : 'ACTIVE',
                  ),
                ],
              ])
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
                  : () => _takeAction('dismissed', 'Dismissed - No violation'),
            ),
            AppSizes.gapHMD,
            if (type == 'listing')
              CustomButton(
                text: 'HIDE LISTING',
                type: ButtonType.solid,
                onPressed: _isLoading
                    ? null
                    : () => _takeAction('reviewed', 'Hide Listing'),
              ),
            if (type == 'listing') AppSizes.gapHMD,

            CustomButton(
              text: 'SUSPEND USER',
              type: ButtonType.solid,
              backgroundColor: Colors.red,
              onPressed: _isLoading
                  ? null
                  : () => _takeAction('reviewed', 'Suspend User'),
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
