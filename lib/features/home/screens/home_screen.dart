import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../listings/logic/listing_cubit.dart';
import '../../listings/logic/listing_state.dart';
import '../../profile/logic/profile_cubit.dart';
import '../../profile/logic/profile_state.dart';
import '../../../core/animations/app_animations.dart';

/// HomeScreen: The main marketplace feed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ListingCubit>().fetchListings();
    context.read<ProfileCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.solidBlack),
          onPressed: () {},
        ),
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: AppColors.primaryBlue),
            AppSizes.gapWSm,
            Text(
              'StudySwap',
              style: AppTextStyles.heading2.copyWith(fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.solidBlack,
            ),
            onPressed: () {},
          ),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.borderGrey,
            child: Icon(Icons.person, size: 16, color: AppColors.textGrey),
          ),
          AppSizes.gapWMD,
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            FadeInSlide(
              duration: const Duration(milliseconds: 500),
              child: Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find your next essential.',
                      style: AppTextStyles.bodyMediumDark,
                    ),
                    AppSizes.gapHSm,
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(
                          color: AppColors.solidBlack,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.textDark),
                          AppSizes.gapWSm,
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText:
                                    'Search textbooks, notes, electronics...',
                                hintStyle: AppTextStyles.bodyMedium,
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'Search',
                              style: AppTextStyles.bodyMediumDark.copyWith(
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Categories
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'Browse Categories',
                      style: AppTextStyles.bodyMediumDark,
                    ),
                  ),
                  AppSizes.gapHSm,
                  FadeInSlide(
                    delay: const Duration(milliseconds: 150),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryPill('All Items', true),
                          _buildCategoryPill('Textbooks', false),
                          _buildCategoryPill('Study Summaries', false),
                          _buildCategoryPill('Electronics', false),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Listings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: BlocBuilder<ListingCubit, ListingState>(
                builder: (context, state) {
                  if (state is ListingLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (state is ListingError) {
                    return Center(child: Text(state.message));
                  }

                  if (state is ListingLoaded) {
                    if (state.listings.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No listings found yet!'),
                        ),
                      );
                    }

                    return BlocBuilder<ProfileCubit, ProfileState>(
                      builder: (context, profileState) {
                        String userUni = 'none';
                        if (profileState is ProfileLoaded) {
                          userUni =
                              profileState.userData['university'] ?? 'none';
                        }

                        return Column(
                          children: state.listings.asMap().entries.map((entry) {
                            final index = entry.key;
                            final listing = entry.value;

                            return FadeInSlide(
                              delay: Duration(milliseconds: 200 + (index * 100)),
                              child: _buildItemCard(
                                context,
                                listing,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    return IdleBounce(
      child: ScaleAnimation(
        onTap: () => context.go('/sell'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.limeGreen,
            border: Border.all(color: AppColors.solidBlack, width: 2),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: AppColors.solidBlack,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.solidBlack),
              const SizedBox(width: 8),
              Text(
                'SELL ITEM',
                style: AppTextStyles.buttonText.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: isActive ? AppColors.solidBlack : AppColors.borderGrey,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMediumDark.copyWith(
          color: isActive ? AppColors.textDark : AppColors.textGrey,
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    Map<String, dynamic> listing,
  ) {
    final title = listing['title'] ?? 'No Title';
    final price = '£${listing['price'] ?? '0.00'}';
    final rating = '5.0'; // Placeholder
    final sellerName = listing['sellerName'] ?? 'Student';
    final listingUni = listing['university'] ?? 'none';

    // We don't need to recalculate tags here if we pass them, 
    // but for simplicity let's just use the listing data.
    final tags = [listingUni];
    if (listing['category'] != null) tags.add(listing['category']);

    return GestureDetector(
      onTap: () => context.push('/item-details', extra: listing),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.borderGrey, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Placeholder
            Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.image,
                      size: 50,
                      color: AppColors.textGrey,
                    ),
                  ),
                  if (listing['status'] != null && listing['status'] != 'active')
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: (listing['status'] == 'sold' ? Colors.black : Colors.orange).withOpacity(0.6),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.solidBlack, width: 1.5),
                            ),
                            child: Text(
                              listing['status'].toString().toUpperCase(),
                              style: AppTextStyles.bodyMediumDark.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderGrey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_border, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: AppTextStyles.bodyMediumDark.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderGrey),
                      ),
                      child: Text(price, style: AppTextStyles.bodyMediumDark),
                    ),
                  ),
                ],
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMediumDark),
                  AppSizes.gapHSm,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderGrey),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 12,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.borderGrey,
                        child: Icon(Icons.person, size: 12),
                      ),
                      AppSizes.gapWSm,
                      Text(sellerName, style: AppTextStyles.bodyMedium),
                      const Spacer(),
                      const Icon(
                        Icons.verified,
                        color: AppColors.solidBlack,
                        size: 16,
                      ),
                    ],
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
