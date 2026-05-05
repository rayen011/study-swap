import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/data/chat_repository.dart';
import '../../favorites/logic/favorites_cubit.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../../core/animations/app_animations.dart';
import '../../../core/widgets/user_title_badge.dart';
import '../../report/widgets/report_dialog.dart';

/// ItemDetailsScreen: Displays full details of a listing.
class ItemDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> listing;

  const ItemDetailsScreen({super.key, required this.listing});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  bool _isCreatingChat = false;
  Map<String, dynamic>? _sellerData;

  @override
  void initState() {
    super.initState();
    _fetchSellerData();
  }

  Future<void> _fetchSellerData() async {
    try {
      final sellerId = widget.listing['userId'];
      if (sellerId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .get();
        if (mounted) {
          setState(() {
            _sellerData = doc.data();
          });
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _showSafetyPopup() async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.solidBlack, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Safe Trade Tips',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSafetyTip(
              Icons.people,
              'Meet in a public place (e.g., Campus Library)',
            ),
            const SizedBox(height: 12),
            _buildSafetyTip(
              Icons.search,
              'Check the item thoroughly before paying',
            ),
            const SizedBox(height: 12),
            _buildSafetyTip(
              Icons.money_off,
              'Avoid advance payments/bank transfers',
            ),
            const SizedBox(height: 12),
            _buildSafetyTip(
              Icons.verified_user,
              'Keep communication within StudySwap',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textGrey),
            ),
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
            onPressed: () {
              Navigator.pop(ctx);
              _initiateDeal();
            },
            child: const Text('I UNDERSTAND'),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _initiateDeal() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final sellerId = widget.listing['userId'];
    final sellerName = _sellerData?['fullName'] ?? 'Student';

    if (currentUserId == null) return;

    setState(() => _isCreatingChat = true);

    try {
      final chatRepo = context.read<ChatRepository>();
      final chatId = await chatRepo.getOrCreateChat(sellerId, sellerName);

      // Send Deal Request message
      await chatRepo.sendDealRequest(chatId, sellerId, widget.listing);

      if (mounted) {
        context.push(
          '/chat-details',
          extra: {
            'chatId': chatId,
            'receiverName': sellerName,
            'receiverId': sellerId,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingChat = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'reserved':
        return Colors.orange;
      case 'sold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingId = widget.listing['id'] ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .snapshots(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data() as Map<String, dynamic>?;
        // Merge the document ID back into the live data so Favorites works
        final l = liveData != null
            ? {...liveData, 'id': listingId}
            : widget.listing;

        final title = l['title'] ?? 'No Title';
        final price = l['price']?.toString() ?? '0.00';
        final description = l['description'] ?? 'No description provided.';
        final category = l['category'] ?? 'General';

        final sellerUni =
            _sellerData?['university'] ?? l['university'] ?? 'None';
        final sellerName = _sellerData?['fullName'] ?? 'Loading...';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 300,
                      width: double.infinity,
                      color: const Color(0xFF6B8E9B),
                      child: const Center(
                        child: Icon(
                          Icons.book,
                          size: 100,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.solidBlack,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      right: 16,
                      child: Row(
                        children: [
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(l['status'] ?? 'active'),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.solidBlack,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              (l['status'] ?? 'active').toUpperCase(),
                              style: AppTextStyles.bodyMediumDark.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 3-dot report menu
                          Builder(
                            builder: (ctx) => GestureDetector(
                              onTap: () async {
                                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                                final isOwner = currentUid == l['userId'];
                                if (isOwner) return; // owners can't report own listing
                                ReportDialog.show(
                                  ctx,
                                  targetId: l['id'] ?? '',
                                  targetType: ReportTargetType.listing,
                                  targetName: l['title'] ?? 'Listing',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.more_vert,
                                  color: AppColors.solidBlack,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildTag(category, true),
                          AppSizes.gapWSm,
                          _buildTag(sellerUni, false),
                        ],
                      ),
                      AppSizes.gapHLG,
                      Text(title, style: AppTextStyles.heading1),
                      AppSizes.gapHSm,
                      Text(
                        'Campus Pickup • $sellerUni',
                        style: AppTextStyles.bodyMediumDark,
                      ),
                      AppSizes.gapHLG,
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C7500),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.solidBlack,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.solidBlack,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '£$price',
                              style: AppTextStyles.heading2.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSizes.gapHLG,
                      Row(
                        children: [
                          _buildThumbnail(isActive: true),
                          AppSizes.gapWSm,
                          _buildThumbnail(),
                          AppSizes.gapWSm,
                          _buildThumbnail(),
                          AppSizes.gapWSm,
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '+2 More',
                                style: AppTextStyles.bodyMediumDark.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSizes.gapHXL,
                      Text(
                        'Description',
                        style: AppTextStyles.heading2.copyWith(fontSize: 20),
                      ),
                      AppSizes.gapHMD,
                      Text(
                        description,
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          height: 1.6,
                        ),
                      ),
                      AppSizes.gapHXL,
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                final isMine = currentUserId == l['userId'];

                                return CustomButton(
                                  text: _isCreatingChat
                                      ? 'PREPARING DEAL...'
                                      : (isMine
                                          ? 'YOUR LISTING'
                                          : (l['status'] == 'sold'
                                              ? 'ITEM SOLD'
                                              : (l['status'] == 'active'
                                                  ? 'REQUEST TO BUY'
                                                  : 'CONTACT SELLER'))),
                                  type: ButtonType.solid,
                                  leadingWidget: _isCreatingChat
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          isMine
                                              ? Icons.person
                                              : (l['status'] == 'sold'
                                                  ? Icons.block
                                                  : Icons.handshake_outlined),
                                          color: AppColors.white,
                                          size: 20,
                                        ),
                                  onPressed: _isCreatingChat ||
                                          l['status'] == 'sold' ||
                                          isMine
                                      ? null
                                      : (l['status'] == 'active'
                                          ? _showSafetyPopup
                                          : _initiateDeal),
                                );
                              },
                            ),
                          ),
                          AppSizes.gapWMD,
                          StreamBuilder<bool>(
                            stream: context
                                .read<FavoritesRepository>()
                                .isFavorited(listingId),
                            builder: (context, snapshot) {
                              final isFav = snapshot.data ?? false;
                              return ScaleAnimation(
                                onTap: () => context
                                    .read<FavoritesCubit>()
                                    .toggleFavorite(l),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isFav
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isFav
                                          ? Colors.red
                                          : AppColors.borderGrey,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: PopAnimation(
                                    isTriggered: isFav,
                                    child: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFav
                                          ? Colors.red
                                          : AppColors.solidBlack,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      AppSizes.gapHXL,
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.borderGrey),
                        ),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.borderGrey,
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: AppColors.textGrey,
                              ),
                            ),
                            AppSizes.gapHMD,
                            Text(
                              sellerName,
                              style: AppTextStyles.heading2.copyWith(
                                fontSize: 20,
                              ),
                            ),
                            AppSizes.gapHSm,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.primaryBlue,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified Student',
                                    style: AppTextStyles.bodyMediumDark
                                        .copyWith(
                                          color: AppColors.primaryBlue,
                                          fontSize: 12,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            AppSizes.gapHSm,
                            UserTitleBadge(
                              title: _sellerData?['title'] ?? 'Freshman Trader',
                              isCompact: true,
                            ),
                            AppSizes.gapHSm,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school, size: 14),
                                  const SizedBox(width: 8),
                                  Text(
                                    sellerUni,
                                    style: AppTextStyles.bodyMediumDark
                                        .copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            AppSizes.gapHLG,
                            const Divider(),
                            AppSizes.gapHLG,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.star, size: 16, color: AppColors.primaryYellow),
                                        const SizedBox(width: 4),
                                        Text(
                                          (_sellerData?['rating'] as num? ?? 0.0).toStringAsFixed(1),
                                          style: AppTextStyles.bodyMediumDark,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${_sellerData?['ratingCount'] ?? 0} Reviews',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_sellerData?['dealCount'] ?? 0}',
                                      style: AppTextStyles.bodyMediumDark,
                                    ),
                                    Text(
                                      'Swaps Done',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AppSizes.gapHXL,
                      Text(
                        'Meetup Location',
                        style: AppTextStyles.heading2.copyWith(fontSize: 20),
                      ),
                      AppSizes.gapHMD,
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDECDA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppColors.primaryBlue,
                                size: 32,
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Near Engineering Library',
                                  style: AppTextStyles.bodyMediumDark.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AppSizes.gapHXL,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFE0E7FF) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMediumDark.copyWith(
          color: isPrimary ? AppColors.primaryBlue : AppColors.textDark,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildThumbnail({bool isActive = false}) {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF6B8E9B),
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(color: AppColors.primaryBlue, width: 2)
            : null,
      ),
    );
  }
}
