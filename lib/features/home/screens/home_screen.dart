import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../listings/logic/listing_cubit.dart';
import '../../listings/logic/listing_state.dart';
import '../../profile/logic/profile_cubit.dart';
import '../../../core/animations/app_animations.dart';

// ── Sort options ──────────────────────────────────────────────────────────────
enum SortOption { newest, cheapest, mostExpensive }

extension SortLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.newest:
        return 'Newest';
      case SortOption.cheapest:
        return 'Cheapest';
      case SortOption.mostExpensive:
        return 'Most Expensive';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.newest:
        return Icons.schedule;
      case SortOption.cheapest:
        return Icons.arrow_downward;
      case SortOption.mostExpensive:
        return Icons.arrow_upward;
    }
  }
}

// ── Condition options ─────────────────────────────────────────────────────────
const _conditions = ['All', 'New', 'Used'];

const _categories = [
  'All',
  'Textbooks',
  'Study Summaries',
  'Electronics',
  'Stationery',
  'Other',
];

/// HomeScreen: Marketplace feed with live search, filters, and sort.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Search & filter state ─────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';
  String _selectedCondition = 'All';
  RangeValues _priceRange = const RangeValues(0, 500);
  SortOption _sortOption = SortOption.newest;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    context.read<ListingCubit>().fetchListings();
    context.read<ProfileCubit>().loadProfile();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtering & sorting logic ─────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    var results = all.where((l) {
      // Only active listings
      if (l['status'] == 'sold') return false;

      // Title / category text search
      if (_query.isNotEmpty) {
        final title = (l['title'] ?? '').toString().toLowerCase();
        final cat = (l['category'] ?? '').toString().toLowerCase();
        if (!title.contains(_query) && !cat.contains(_query)) return false;
      }

      // Category filter
      if (_selectedCategory != 'All') {
        if ((l['category'] ?? '') != _selectedCategory) return false;
      }

      // Condition filter
      if (_selectedCondition != 'All') {
        if ((l['condition'] ?? '') != _selectedCondition) return false;
      }

      // Price range
      final price = (l['price'] as num? ?? 0).toDouble();
      if (price < _priceRange.start || price > _priceRange.end) return false;

      return true;
    }).toList();

    // Sort
    switch (_sortOption) {
      case SortOption.newest:
        results.sort((a, b) {
          final aT = a['createdAt'];
          final bT = b['createdAt'];
          if (aT == null || bT == null) return 0;
          return bT.compareTo(aT);
        });
        break;
      case SortOption.cheapest:
        results.sort((a, b) {
          final aP = (a['price'] as num? ?? 0).toDouble();
          final bP = (b['price'] as num? ?? 0).toDouble();
          return aP.compareTo(bP);
        });
        break;
      case SortOption.mostExpensive:
        results.sort((a, b) {
          final aP = (a['price'] as num? ?? 0).toDouble();
          final bP = (b['price'] as num? ?? 0).toDouble();
          return bP.compareTo(aP);
        });
        break;
    }

    return results;
  }

  bool get _hasActiveFilters =>
      _selectedCategory != 'All' ||
      _selectedCondition != 'All' ||
      _priceRange.start > 0 ||
      _priceRange.end < 500 ||
      _sortOption != SortOption.newest;

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedCondition = 'All';
      _priceRange = const RangeValues(0, 500);
      _sortOption = SortOption.newest;
    });
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
            Text('StudySwap',
                style: AppTextStyles.heading2.copyWith(fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none,
                color: AppColors.solidBlack),
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
                                color: AppColors.solidBlack, width: 1.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  color: AppColors.textDark, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search title or category...',
                                    hintStyle: AppTextStyles.bodyMedium,
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_query.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  child: const Icon(Icons.close,
                                      size: 18, color: AppColors.textGrey),
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
                                  offset: Offset(2, 2)),
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
                children: _categories.map((cat) {
                  final isActive = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                                    offset: Offset(2, 2))
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
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
                }).toList(),
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
                  final filtered = _applyFilters(state.listings);
                  return _buildResultsList(filtered, state.listings.length);
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
              Text('Sort by',
                  style: AppTextStyles.bodyMediumDark
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SortOption.values.map((opt) {
                      final isSelected = _sortOption == opt;
                      return GestureDetector(
                        onTap: () => setState(() => _sortOption = opt),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
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
                              Icon(opt.icon,
                                  size: 14,
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.solidBlack),
                              const SizedBox(width: 4),
                              Text(opt.label,
                                  style: AppTextStyles.bodyMediumDark
                                      .copyWith(
                                    fontSize: 12,
                                    color: isSelected
                                        ? AppColors.white
                                        : AppColors.solidBlack,
                                  )),
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
              Text('Condition',
                  style: AppTextStyles.bodyMediumDark
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              ..._conditions.map((c) {
                final isSelected = _selectedCondition == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCondition = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.limeGreen : AppColors.background,
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
                                  offset: Offset(2, 2))
                            ]
                          : null,
                    ),
                    child: Text(c,
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        )),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 14),

          // Price range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Price Range',
                  style: AppTextStyles.bodyMediumDark
                      .copyWith(fontWeight: FontWeight.w700)),
              Text(
                '£${_priceRange.start.toInt()} – £${_priceRange.end.toInt()}',
                style: AppTextStyles.bodyMediumDark.copyWith(
                    fontSize: 12, color: AppColors.primaryBlue),
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
                  enabledThumbRadius: 8),
            ),
            child: RangeSlider(
              values: _priceRange,
              min: 0,
              max: 500,
              divisions: 50,
              onChanged: (v) => setState(() => _priceRange = v),
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
                label: Text('Reset filters',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: Colors.red, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Results list ──────────────────────────────────────────────────────────

  Widget _buildResultsList(
      List<Map<String, dynamic>> filtered, int totalCount) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 56, color: AppColors.borderGrey),
            const SizedBox(height: 16),
            Text('No results found', style: AppTextStyles.heading2.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              _query.isNotEmpty || _hasActiveFilters
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
                style: AppTextStyles.bodyMediumDark
                    .copyWith(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              if (filtered.length < totalCount) ...[
                Text(
                  ' (filtered from $totalCount)',
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 11),
                ),
              ],
              const Spacer(),
              // Sort quick-switch
              GestureDetector(
                onTap: () {
                  final opts = SortOption.values;
                  final next =
                      opts[(opts.indexOf(_sortOption) + 1) % opts.length];
                  setState(() => _sortOption = next);
                },
                child: Row(
                  children: [
                    Icon(_sortOption.icon,
                        size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    Text(_sortOption.label,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 11, color: AppColors.primaryBlue)),
                    const Icon(Icons.swap_vert,
                        size: 14, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return FadeInSlide(
                delay: Duration(milliseconds: index * 60),
                child: _buildItemCard(context, filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
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
              BoxShadow(color: AppColors.solidBlack, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.solidBlack),
              const SizedBox(width: 8),
              Text('SELL ITEM',
                  style: AppTextStyles.buttonText.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Item card ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> listing) {
    final title = listing['title'] ?? 'No Title';
    final price = '£${listing['price'] ?? '0.00'}';
    final sellerName = listing['sellerName'] ?? 'Student';
    final category = listing['category'] ?? '';
    final condition = listing['condition'] ?? '';
    final university = listing['university'] ?? '';

    return GestureDetector(
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 150,
                width: double.infinity,
                color: const Color(0xFFE5E7EB),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.image,
                          size: 50, color: AppColors.textGrey),
                    ),
                    // Price badge
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.solidBlack,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(price,
                            style: AppTextStyles.bodyMediumDark.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                    // Condition badge
                    if (condition.isNotEmpty)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: condition == 'New'
                                ? AppColors.limeGreen
                                : const Color(0xFFFFE4D6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.solidBlack, width: 1),
                          ),
                          child: Text(condition,
                              style: AppTextStyles.bodyMediumDark
                                  .copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
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
                  Text(title,
                      style: AppTextStyles.bodyMediumDark
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (category.isNotEmpty) _buildTag(category, true),
                      if (university.isNotEmpty) _buildTag(university, false),
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
                      Text(sellerName,
                          style:
                              AppTextStyles.bodyMedium.copyWith(fontSize: 12)),
                      const Spacer(),
                      const Icon(Icons.verified,
                          color: AppColors.solidBlack, size: 16),
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
        color: isPrimary
            ? const Color(0xFFE0E7FF)
            : const Color(0xFFE5E7EB),
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
