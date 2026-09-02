import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/animations/app_animations.dart';
import '../../../core/constants/listing_options.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_filter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/listing_image.dart';
import '../../listings/logic/listing_cubit.dart';
import '../../listings/logic/listing_state.dart';
import '../../profile/logic/profile_cubit.dart';

extension _SortIcon on ListingSort {
  IconData get icon => switch (this) {
    ListingSort.newest => Icons.schedule,
    ListingSort.cheapest => Icons.arrow_downward,
    ListingSort.mostExpensive => Icons.arrow_upward,
  };
}

/// How long to wait after the last keystroke before re-filtering. Without it
/// the whole loaded window is re-filtered and re-sorted on every character.
const Duration _kSearchDebounce = Duration(milliseconds: 250);

/// HomeScreen: Marketplace feed with live search, filters, and sort.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Search & filter state ─────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  ListingFilter _filter = const ListingFilter();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    context.read<ListingCubit>().fetchListings();
    context.read<ProfileCubit>().loadProfile();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      _updateFilter(
        _filter.copyWith(
          query: _searchController.text.toLowerCase().trim(),
        ),
      );
    });
  }

  /// Loads the next page once the user is within one screen of the end.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 400) return;

    context.read<ListingCubit>().loadMore();
  }

  /// Single funnel for every filter change, so the cubit decides whether the
  /// Firestore query needs re-issuing.
  void _updateFilter(ListingFilter next) {
    if (next == _filter) return;
    setState(() => _filter = next);
    context.read<ListingCubit>().applyFilter(next);
  }

  // ── Client-side narrowing ─────────────────────────────────────────────────
  //
  // Status, category, condition and sort are already applied by the query.
  // What's left is the price range and the text search, which Firestore can't
  // combine with the chosen sort — see ListingFilter for why.
  List<Listing> _applyClientFilters(List<Listing> loaded) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return loaded.where((l) {
      // Your own listings belong in Collection, not the marketplace feed.
      if (l.isOwnedBy(currentUid)) return false;

      if (l.price < _filter.minPrice || l.price > _filter.maxPrice) {
        return false;
      }

      if (_filter.query.isNotEmpty) {
        final title = l.title.toLowerCase();
        final category = l.categoryLabel.toLowerCase();
        if (!title.contains(_filter.query) &&
            !category.contains(_filter.query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters => _filter.isActive;

  void _resetFilters() {
    _searchController.clear();
    _updateFilter(const ListingFilter());
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
      body: Column(
        children: [
          // ── Search bar + filter toggle ──────────────────────────────────
          FadeInSlide(
            duration: const Duration(milliseconds: 400),
            child: Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(
                              color: AppColors.solidBlack,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: AppColors.textDark,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search title or category...',
                                    hintStyle: AppTextStyles.bodyMedium,
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _updateFilter(
                                      _filter.copyWith(query: ''),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Filter toggle button
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showFilters = !_showFilters),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasActiveFilters
                                ? AppColors.primaryBlue
                                : AppColors.background,
                            border: Border.all(
                              color: _hasActiveFilters
                                  ? AppColors.primaryBlue
                                  : AppColors.solidBlack,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.solidBlack,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.tune,
                            color: _hasActiveFilters
                                ? AppColors.white
                                : AppColors.solidBlack,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Expandable filter panel ───────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _showFilters
                        ? _buildFilterPanel()
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // ── Category pills (always visible) ────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <ListingCategory?>[null, ...ListingCategory.values]
                    .map((
                      cat,
                    ) {
                      final isActive = _filter.category == cat;
                      return TapBounce(
                        onTap: () => _updateFilter(
                          _filter.copyWith(
                            category: cat,
                            clearCategory: cat == null,
                          ),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primaryBlue
                                : AppColors.white,
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primaryBlue
                                  : AppColors.borderGrey,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isActive
                                ? const [
                                    BoxShadow(
                                      color: AppColors.solidBlack,
                                      offset: Offset(2, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            cat?.label ?? 'All',
                            style: AppTextStyles.bodyMediumDark.copyWith(
                              color: isActive
                                  ? AppColors.white
                                  : AppColors.textGrey,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ),

          // ── Results ────────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<ListingCubit, ListingState>(
              builder: (context, state) {
                if (state is ListingLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ListingError) {
                  return Center(child: Text(state.message));
                }
                if (state is ListingLoaded) {
                  return _buildResultsList(
                    _applyClientFilters(state.listings),
                    state,
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── Filter panel ──────────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // Sort row
          Row(
            children: [
              Text(
                'Sort by',
                style: AppTextStyles.bodyMediumDark.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ListingSort.values.map((opt) {
                      final isSelected = _filter.sort == opt;
                      return GestureDetector(
                        onTap: () => _updateFilter(_filter.copyWith(sort: opt)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.solidBlack
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.solidBlack,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                opt.icon,
                                size: 14,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.solidBlack,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                opt.label,
                                style: AppTextStyles.bodyMediumDark.copyWith(
                                  fontSize: 12,
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.solidBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Condition row
          Row(
            children: [
              Text(
                'Condition',
                style: AppTextStyles.bodyMediumDark.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        <ListingCondition?>[
                          null,
                          ...ListingCondition.values,
                        ].map((c) {
                          final isSelected = _filter.condition == c;
                          return GestureDetector(
                            onTap: () => _updateFilter(
                              _filter.copyWith(
                                condition: c,
                                clearCondition: c == null,
                              ),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.limeGreen
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.solidBlack
                                      : AppColors.borderGrey,
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? const [
                                        BoxShadow(
                                          color: AppColors.solidBlack,
                                          offset: Offset(2, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                c?.label ?? 'All',
                                style: AppTextStyles.bodyMediumDark.copyWith(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Price range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Range',
                style: AppTextStyles.bodyMediumDark.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '£${_filter.minPrice.toInt()} – £${_filter.maxPrice.toInt()}',
                style: AppTextStyles.bodyMediumDark.copyWith(
                  fontSize: 12,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryBlue,
              inactiveTrackColor: AppColors.borderGrey,
              thumbColor: AppColors.solidBlack,
              overlayColor: AppColors.primaryBlue.withValues(alpha: 0.1),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
              ),
            ),
            child: RangeSlider(
              values: RangeValues(_filter.minPrice, _filter.maxPrice),
              min: 0,
              max: ListingFilter.maxPriceCeiling,
              divisions: 50,
              onChanged: (v) => _updateFilter(
                _filter.copyWith(minPrice: v.start, maxPrice: v.end),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Reset button
          if (_hasActiveFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                label: Text(
                  'Reset filters',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Results list ──────────────────────────────────────────────────────────

  Widget _buildResultsList(List<Listing> filtered, ListingLoaded state) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 56, color: AppColors.borderGrey),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters || _filter.query.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Be the first to list something!',
              style: AppTextStyles.bodyMedium,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset filters'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results count bar
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                style: AppTextStyles.bodyMediumDark.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // The price range and text search only narrow what's loaded, so
              // say so rather than implying it's the whole catalogue.
              if (filtered.length < state.listings.length) ...[
                Text(
                  ' of ${state.listings.length} loaded',
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 11),
                ),
              ],
              const Spacer(),
              // Sort quick-switch
              GestureDetector(
                onTap: () {
                  const opts = ListingSort.values;
                  final next =
                      opts[(opts.indexOf(_filter.sort) + 1) % opts.length];
                  _updateFilter(_filter.copyWith(sort: next));
                },
                child: Row(
                  children: [
                    Icon(
                      _filter.sort.icon,
                      size: 14,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _filter.sort.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 11,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const Icon(
                      Icons.swap_vert,
                      size: 14,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            // One extra row for the pagination footer.
            itemCount: filtered.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filtered.length) return _buildLoadMoreFooter(state);

              return FadeInSlide(
                // Stagger only the first page; later pages arrive mid-scroll
                // and a delay there just makes them feel laggy.
                delay: Duration(milliseconds: (index % 20) * 60),
                child: _buildItemCard(context, filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Sits under the last card. Loading happens on scroll, so this is feedback
  /// rather than a control — but it stays tappable in case the scroll listener
  /// hasn't fired.
  Widget _buildLoadMoreFooter(ListingLoaded state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: state.isLoadingMore
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryBlue,
                ),
              )
            : TextButton(
                onPressed: () => context.read<ListingCubit>().loadMore(),
                child: Text(
                  'Load more',
                  style: AppTextStyles.bodyMediumDark.copyWith(
                    color: AppColors.primaryBlue,
                    fontSize: 13,
                  ),
                ),
              ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return IdleBounce(
      child: TapBounce(
        onTap: () => context.go('/sell'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.limeGreen,
            border: Border.all(color: AppColors.solidBlack, width: 2),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: AppColors.solidBlack, offset: Offset(0, 4)),
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

  // ── Item card ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(BuildContext context, Listing listing) {
    final condition = listing.condition;

    return CardLift(
      onTap: () => context.push('/item-details', extra: listing),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.solidBlack, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: AppColors.solidBlack, offset: Offset(3, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ListingImage(
                      url: listing.coverImageUrl,
                      placeholderIconSize: 50,
                    ),
                    // Price badge
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.solidBlack,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          listing.formattedPrice,
                          style: AppTextStyles.bodyMediumDark.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    // Condition badge
                    if (condition != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: condition == ListingCondition.likeNew
                                ? AppColors.limeGreen
                                : const Color(0xFFFFE4D6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.solidBlack,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            condition.label,
                            style: AppTextStyles.bodyMediumDark.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: AppTextStyles.bodyMediumDark.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildTag(listing.categoryLabel, true),
                      if (listing.university.isNotEmpty)
                        _buildTag(listing.university, false),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.borderGrey,
                        child: Icon(Icons.person, size: 12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        listing.sellerName,
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                      ),
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

  Widget _buildTag(String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFE0E7FF) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
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
}
