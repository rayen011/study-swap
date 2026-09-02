import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/listing_options.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/screens/chat_details_screen.dart';
import '../../favorites/logic/favorites_cubit.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../listings/data/listing_repository.dart';
import '../../profile/data/user_repository.dart';
import '../../../core/animations/app_animations.dart';
import '../../../core/widgets/user_title_badge.dart';
import '../../report/widgets/report_dialog.dart';

/// ItemDetailsScreen: Displays full details of a listing.
class ItemDetailsScreen extends StatefulWidget {
  final Listing listing;

  const ItemDetailsScreen({super.key, required this.listing});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  bool _isCreatingChat = false;
  AppUser? _sellerData;

  @override
  void initState() {
    super.initState();
    _fetchSellerData();
  }

  Future<void> _fetchSellerData() async {
    final userRepository = context.read<UserRepository>();
    try {
      final seller = await userRepository.getUser(widget.listing.userId);
      if (mounted) setState(() => _sellerData = seller);
    } catch (_) {
      // The seller card falls back to the name stored on the listing.
    }
  }

  Future<void> _showSafetyPopup(Listing listing) async {
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
              _initiateDeal(listing);
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

  Future<void> _initiateDeal(Listing listing) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final sellerId = listing.userId;
    final sellerName = _sellerData?.fullName ?? listing.sellerName;
    final chatRepo = context.read<ChatRepository>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isCreatingChat = true);

    try {
      final chatId = await chatRepo.getOrCreateChat(sellerId, sellerName);

      // Don't stack a second request on top of one the seller hasn't
      // answered yet — just take the buyer back to the conversation.
      final alreadyOpen = await chatRepo.hasOpenDeal(chatId, listing.id);
      if (!alreadyOpen) {
        await chatRepo.sendDealRequest(chatId, sellerId, listing);
      }

      if (mounted) {
        if (alreadyOpen) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('You already have an open deal on this item.'),
            ),
          );
        }
        context.push(
          '/chat-details',
          extra: ChatDetailsArgs(
            chatId: chatId,
            receiverName: sellerName,
            receiverId: sellerId,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isCreatingChat = false);
    }
  }

  Color _getStatusColor(ListingStatus status) => switch (status) {
    ListingStatus.active => Colors.green,
    ListingStatus.reserved => Colors.orange,
    ListingStatus.sold => Colors.red,
    ListingStatus.hidden => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final listingId = widget.listing.id;

    return StreamBuilder<Listing?>(
      // The listing is watched live so status changes — reserved, sold —
      // land on this screen while it is open.
      stream: context.read<ListingRepository>().watchListing(listingId),
      initialData: widget.listing,
      builder: (context, snapshot) {
        final l = snapshot.data ?? widget.listing;

        final description = l.description.isEmpty
            ? 'No description provided.'
            : l.description;
        final seller = _sellerData;
        final sellerUni = seller?.hasUniversity == true
            ? seller!.university
            : (l.university.isEmpty ? 'None' : l.university);
        final sellerName = seller?.fullName ?? l.sellerName;

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
                              color: _getStatusColor(l.status),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.solidBlack,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              l.status.label.toUpperCase(),
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
                              onTap: () {
                                final currentUid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                // Owners can't report their own listing.
                                if (l.isOwnedBy(currentUid)) return;
                                ReportDialog.show(
                                  ctx,
                                  targetId: l.id,
                                  targetType: ReportTargetType.listing,
                                  targetName: l.title,
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
                          _buildTag(l.categoryLabel, true),
                          AppSizes.gapWSm,
                          _buildTag(sellerUni, false),
                        ],
                      ),
                      AppSizes.gapHLG,
                      Text(l.title, style: AppTextStyles.heading1),
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
                              l.formattedPrice,
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
                                final currentUserId =
                                    FirebaseAuth.instance.currentUser?.uid;
                                final isMine = l.isOwnedBy(currentUserId);
                                final isSold = l.status == ListingStatus.sold;

                                final label = _isCreatingChat
                                    ? 'PREPARING DEAL...'
                                    : isMine
                                    ? 'YOUR LISTING'
                                    : isSold
                                    ? 'ITEM SOLD'
                                    : l.status.acceptsDeals
                                    ? 'REQUEST TO BUY'
                                    : 'CONTACT SELLER';

                                return CustomButton(
                                  text: label,
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
                                              : isSold
                                              ? Icons.block
                                              : Icons.handshake_outlined,
                                          color: AppColors.white,
                                          size: 20,
                                        ),
                                  onPressed: _isCreatingChat || isSold || isMine
                                      ? null
                                      : () => l.status.acceptsDeals
                                            ? _showSafetyPopup(l)
                                            : _initiateDeal(l),
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
                              title: (seller ?? AppUser.empty).title,
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
                                          (seller ?? AppUser.empty).formattedRating,
                                          style: AppTextStyles.bodyMediumDark,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${(seller ?? AppUser.empty).ratingCount} Reviews',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${(seller ?? AppUser.empty).dealCount}',
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
