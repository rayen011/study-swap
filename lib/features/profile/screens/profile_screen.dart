import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/logic/auth_cubit.dart';
import '../../auth/logic/auth_state.dart';
import '../../listings/logic/my_listings_cubit.dart';
import '../../listings/logic/listing_state.dart';
import '../logic/profile_cubit.dart';
import '../logic/profile_state.dart';
import '../../../core/widgets/user_title_badge.dart';

/// ProfileScreen: Dynamic profile with listings grid, rating history, and stats.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<ProfileCubit>().loadProfile();
    context.read<MyListingsCubit>().fetchUserListings();
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _reviewsLoading = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('toId', isEqualTo: uid)
          .get();

      final reviews = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      reviews.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _reviewsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) context.go('/login');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.borderGrey,
                child: Icon(Icons.person, size: 14, color: AppColors.textGrey),
              ),
              AppSizes.gapWSm,
              Text('STUDYSWAP',
                  style: AppTextStyles.buttonText
                      .copyWith(color: AppColors.primaryBlue)),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.limeGreen,
                border: Border.all(color: AppColors.solidBlack),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_none,
                  color: AppColors.solidBlack, size: 20),
            ),
          ],
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, profileState) {
            String name = 'STUDENT';
            String university = 'NONE';
            double rating = 0.0;
            int ratingCount = 0;
            int dealCount = 0;
            String title = 'Freshman Trader';
            DateTime? joinDate;

            if (profileState is ProfileLoaded) {
              name = profileState.userData['fullName']?.toUpperCase() ?? 'STUDENT';
              university = profileState.userData['university'] ?? 'none';
              rating = (profileState.userData['rating'] as num? ?? 0.0).toDouble();
              ratingCount = (profileState.userData['ratingCount'] as num? ?? 0).toInt();
              dealCount = (profileState.userData['dealCount'] as num? ?? 0).toInt();
              title = profileState.userData['title'] ?? 'Freshman Trader';
              final ts = profileState.userData['createdAt'];
              if (ts is Timestamp) joinDate = ts.toDate();
            }

            return BlocBuilder<MyListingsCubit, ListingState>(
              builder: (context, listingState) {
                final allListings = listingState is ListingLoaded
                    ? listingState.listings
                    : <Map<String, dynamic>>[];
                final activeListings = allListings
                    .where((l) => l['status'] != 'sold')
                    .toList();
                final soldListings = allListings
                    .where((l) => l['status'] == 'sold')
                    .toList();

                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSizes.gapHLG,
                            _buildProfileCard(
                                name, university, rating, ratingCount,
                                dealCount, title, joinDate),
                            AppSizes.gapHLG,
                            _buildStatsRow(
                                activeListings.length, soldListings.length,
                                rating, ratingCount),
                            AppSizes.gapHLG,
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primaryBlue,
                          unselectedLabelColor: AppColors.textGrey,
                          indicatorColor: AppColors.primaryBlue,
                          indicatorWeight: 3,
                          labelStyle: AppTextStyles.buttonText.copyWith(fontSize: 12),
                          tabs: [
                            Tab(text: 'ACTIVE (${activeListings.length})'),
                            Tab(text: 'SOLD (${soldListings.length})'),
                            Tab(text: 'REVIEWS (${_reviews.length})'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListingsGrid(activeListings, isLoading: listingState is ListingLoading),
                      _buildListingsGrid(soldListings, isSold: true, isLoading: listingState is ListingLoading),
                      _buildReviewsList(),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── Profile Card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(String name, String university, double rating,
      int ratingCount, int dealCount, String title, DateTime? joinDate) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 64, left: 16, right: 16, bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.solidBlack, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
            ],
          ),
          child: Column(
            children: [
              Text(
                name.contains(' ') ? name.replaceFirst(' ', '\n') : name,
                style: AppTextStyles.heading1,
                textAlign: TextAlign.center,
              ),
              AppSizes.gapHSm,
              // University badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.solidBlack, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined,
                        color: AppColors.primaryBlue, size: 14),
                    const SizedBox(width: 6),
                    Text(university,
                        style: AppTextStyles.bodyMediumDark
                            .copyWith(color: AppColors.primaryBlue, fontSize: 12)),
                  ],
                ),
              ),
              AppSizes.gapHSm,
              UserTitleBadge(title: title),
              AppSizes.gapHSm,
              // Join date
              if (joinDate != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: AppColors.textGrey),
                    const SizedBox(width: 4),
                    Text(
                      'Joined ${DateFormat('MMMM yyyy').format(joinDate)}',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              AppSizes.gapHLG,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/edit-profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(
                        color: AppColors.solidBlack, width: 1.5),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('EDIT PROFILE',
                      style: AppTextStyles.buttonTextWhite),
                ),
              ),
              AppSizes.gapHSm,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.read<AuthCubit>().logout(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text('LOG OUT',
                      style: AppTextStyles.buttonText
                          .copyWith(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
        // Overlapping Avatar
        Positioned(
          top: -40,
          child: Column(
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.solidBlack, width: 2),
                ),
                child:
                    const Icon(Icons.person, size: 40, color: AppColors.textGrey),
              ),
              Transform.translate(
                offset: const Offset(0, -10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C7500),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.solidBlack, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified,
                          color: AppColors.white, size: 10),
                      const SizedBox(width: 4),
                      Text('Verified\nStudent',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.white, fontSize: 8),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(
      int activeCount, int soldCount, double rating, int ratingCount) {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard(
                '$activeCount', 'Active\nListings', AppColors.primaryBlue,
                Icons.storefront_outlined)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                '$soldCount', 'Items\nSold', AppColors.limeGreen,
                Icons.handshake_outlined, dark: true)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                rating.toStringAsFixed(1), '$ratingCount Reviews',
                AppColors.primaryYellow, Icons.star_rounded, dark: true)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color, IconData icon,
      {bool dark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.solidBlack, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.solidBlack, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.solidBlack, width: 1.5),
            ),
            child: Icon(icon,
                color: dark ? AppColors.solidBlack : AppColors.white, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.heading2.copyWith(fontSize: 20),
              textAlign: TextAlign.center),
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontSize: 10, height: 1.2),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Listings Grid ─────────────────────────────────────────────────────────

  Widget _buildListingsGrid(List<Map<String, dynamic>> listings,
      {bool isSold = false, bool isLoading = false}) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSold ? Icons.check_circle_outline : Icons.storefront_outlined,
              size: 48,
              color: AppColors.borderGrey,
            ),
            const SizedBox(height: 12),
            Text(
              isSold ? 'No sold items yet' : 'No active listings',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) =>
          _buildListingCard(listings[index], isSold: isSold),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing,
      {bool isSold = false}) {
    final title = listing['title'] ?? 'Item';
    final price = listing['price'];
    final category = listing['category'] ?? '';
    final imageUrl = listing['imageUrl'] ?? '';
    final status = listing['status'] ?? 'active';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'sold':
        statusColor = Colors.red;
        statusLabel = 'SOLD';
        break;
      case 'reserved':
        statusColor = Colors.orange;
        statusLabel = 'RESERVED';
        break;
      default:
        statusColor = Colors.green;
        statusLabel = 'ACTIVE';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.solidBlack, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.solidBlack, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => _placeholderImage())
                      : _placeholderImage(),
                  // Status badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: AppColors.solidBlack, width: 1),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('£${price?.toStringAsFixed(2) ?? '0.00'}',
                        style: AppTextStyles.heading2.copyWith(fontSize: 14,
                            color: AppColors.primaryBlue)),
                    Text(category,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 32, color: AppColors.borderGrey),
      ),
    );
  }

  // ── Reviews List ──────────────────────────────────────────────────────────

  Widget _buildReviewsList() {
    if (_reviewsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_outline, size: 48, color: AppColors.borderGrey),
            const SizedBox(height: 12),
            Text('No reviews yet', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) => _buildReviewCard(_reviews[index]),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num? ?? 0).toInt();
    final comment = review['comment'] ?? '';
    final ts = review['timestamp'] as Timestamp?;
    final date = ts != null
        ? DateFormat('dd MMM yyyy').format(ts.toDate())
        : 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.solidBlack, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.solidBlack, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 18,
                    color: AppColors.primaryYellow,
                  ),
                ),
              ),
              Text(date,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 10)),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ── Pinned Tab Bar Delegate ───────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.borderGrey),
          tabBar,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
