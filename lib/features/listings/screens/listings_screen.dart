import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/listing_options.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/listing_gallery.dart';
import '../../../core/widgets/error_state_view.dart';
import '../logic/my_listings_cubit.dart';
import '../widgets/listing_owner_actions.dart';
import '../logic/listing_state.dart';
import '../../favorites/logic/favorites_cubit.dart';
import '../../../core/animations/app_animations.dart';

/// ListingsScreen: Displays the user's active listings and favorite items.
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  int _selectedSegment = 0; // 0 for Active, 1 for Past, 2 for Favorites

  @override
  void initState() {
    super.initState();
    context.read<MyListingsCubit>().fetchUserListings();
    context.read<FavoritesCubit>().fetchFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'COLLECTION',
          style: AppTextStyles.heading2.copyWith(fontSize: 20),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSegmentedControl(),
          Expanded(
            child: _selectedSegment == 0
                ? _buildMyListings(showSold: false)
                : _selectedSegment == 1
                ? _buildMyListings(showSold: true)
                : _buildFavorites(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.solidBlack, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          children: [
            _buildSegmentItem(0, 'ACTIVE'),
            _buildSegmentItem(1, 'PAST'),
            _buildSegmentItem(2, 'FAVORITES'),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final isActive = _selectedSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSegment = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyMediumDark.copyWith(
                color: isActive ? AppColors.white : AppColors.textDark,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyListings({required bool showSold}) {
    return BlocBuilder<MyListingsCubit, ListingState>(
      builder: (context, state) {
        if (state is ListingLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ListingError) {
          return ErrorStateView(
            error: state.message,
            onRetry: () => context.read<MyListingsCubit>().fetchUserListings(),
          );
        }
        if (state is ListingLoaded) {
          final listings = state.listings.where((l) {
            final isSold = l.status == ListingStatus.sold;
            return showSold ? isSold : !isSold;
          }).toList();

          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    showSold ? 'No past sales yet' : 'No active listings',
                    style: AppTextStyles.bodyMediumDark,
                  ),
                  if (!showSold) ...[
                    AppSizes.gapHMD,
                    _buildCreateListingCard(),
                  ],
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: showSold ? listings.length : listings.length + 1,
            itemBuilder: (context, index) {
              if (!showSold && index == listings.length) {
                return FadeInSlide(
                  delay: Duration(milliseconds: index * 100),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildCreateListingCard(),
                  ),
                );
              }
              final listing = listings[index];
              return FadeInSlide(
                delay: Duration(milliseconds: index * 100),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildListingCard(
                    listing: listing,
                    showDelete: !showSold,
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildFavorites() {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, state) {
        if (state is FavoritesLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is FavoritesError) {
          return ErrorStateView(
            error: state.message,
            onRetry: () => context.read<FavoritesCubit>().fetchFavorites(),
          );
        }
        if (state is FavoritesLoaded) {
          if (state.favorites.isEmpty) {
            return Center(
              child: Text(
                'No favorites added yet',
                style: AppTextStyles.bodyMediumDark,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.favorites.length,
            itemBuilder: (context, index) {
              final listing = state.favorites[index];
              return FadeInSlide(
                delay: Duration(milliseconds: index * 100),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildListingCard(
                    listing: listing,
                    showDelete: false,
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildListingCard({
    required Listing listing,
    bool showDelete = false,
  }) {
    final color = listing.category == ListingCategory.textbooks
        ? const Color(0xFFE2E8F0)
        : AppColors.limeGreen;
    final isSold = listing.status == ListingStatus.sold;

    return CardLift(
      onTap: isSold
          ? null
          : () => context.push('/item-details', extra: listing),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.solidBlack, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                border: const Border(
                  bottom: BorderSide(color: AppColors.solidBlack, width: 2),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: ListingGallery(
                      imageUrls: listing.imageUrls,
                      placeholderIconSize: 64,
                      placeholderColor: color,
                    ),
                  ),
                  if (listing.status != ListingStatus.active)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isSold ? Colors.black : Colors.orange)
                              .withValues(alpha: 0.6),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.solidBlack,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              listing.status.label.toUpperCase(),
                              style: AppTextStyles.bodyMediumDark.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        listing.categoryLabel.toUpperCase(),
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          color: AppColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4C7500),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.solidBlack,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        listing.formattedPrice,
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.title,
                          style: AppTextStyles.bodyMediumDark.copyWith(
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          listing.university,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // One entry point for everything a seller can do with it,
                  // rather than a delete button and no way to fix a typo.
                  if (showDelete)
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: 'Manage listing',
                      onPressed: () => showListingOwnerActions(
                        context: context,
                        listing: listing,
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

  Widget _buildCreateListingCard() {
    return GestureDetector(
      onTap: () => context.go('/sell'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4D6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.solidBlack, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.solidBlack, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.add_circle_outline, size: 32),
            AppSizes.gapHSm,
            Text(
              'Create New Listing',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
