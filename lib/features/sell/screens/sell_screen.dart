import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/auction_rules.dart';
import '../../../core/constants/listing_options.dart';
import '../../../core/models/auction.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/listing_image.dart';
import '../../listings/data/image_repository.dart';
import '../../listings/logic/listing_cubit.dart';
import '../../listings/logic/listing_state.dart';
import '../../profile/logic/profile_cubit.dart';
import '../../profile/logic/profile_state.dart';
import '../widgets/sale_mode_picker.dart';

/// The form for posting a listing, and for editing one already posted.
///
/// One form rather than two. An edit screen that duplicated this would drift
/// from it — different validators, a category the sell form can write and the
/// edit form can't — and the bug that would surface is a listing you can post
/// but never correct.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key, this.existing});

  /// The listing being edited, or null when posting a new one.
  final Listing? existing;

  bool get isEditing => existing != null;

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _reserveController = TextEditingController();
  ListingCategory _selectedCategory = ListingCategory.textbooks;
  ListingCondition _selectedCondition = ListingCondition.likeNew;

  SaleMode _saleMode = SaleMode.fixed;
  int _durationHours = AuctionRules.durations[1].hours;
  bool _hasReserve = false;

  /// Photos chosen but not yet uploaded. They upload when the listing is
  /// posted, so abandoning the form costs nothing in Storage.
  final List<XFile> _images = [];

  /// Photos already in Cloud Storage, when editing. Removing one here drops
  /// it from the listing; the file itself is cleaned up with the listing.
  final List<String> _keptImageUrls = [];

  bool _picking = false;

  /// How many photos the listing would end up with.
  int get _photoCount => _keptImageUrls.length + _images.length;

  @override
  void initState() {
    super.initState();
    // A saved draft belongs to a new listing. Restoring it over the thing
    // somebody is editing would quietly replace their listing with a draft
    // they abandoned last week.
    if (widget.isEditing) {
      _prefillFrom(widget.existing!);
    } else {
      _loadDraft();
    }
  }

  void _prefillFrom(Listing listing) {
    _titleController.text = listing.title;
    _descController.text = listing.description;
    _priceController.text = listing.price.toStringAsFixed(2);
    _selectedCategory = listing.category ?? ListingCategory.other;
    _selectedCondition = listing.condition ?? ListingCondition.good;
    _keptImageUrls.addAll(listing.imageUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _reserveController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _titleController.text = prefs.getString('draft_title') ?? '';
      _priceController.text = prefs.getString('draft_price') ?? '';
      _descController.text = prefs.getString('draft_desc') ?? '';
      _selectedCategory =
          ListingCategory.tryParse(prefs.getString('draft_category')) ??
          ListingCategory.textbooks;
      _selectedCondition =
          ListingCondition.tryParse(prefs.getString('draft_condition')) ??
          ListingCondition.likeNew;
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_title', _titleController.text);
    await prefs.setString('draft_price', _priceController.text);
    await prefs.setString('draft_desc', _descController.text);
    await prefs.setString('draft_category', _selectedCategory.wire);
    await prefs.setString('draft_condition', _selectedCondition.wire);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved locally'),
          backgroundColor: AppColors.primaryBlue,
        ),
      );
    }
  }

  Future<void> _addPhotos(ImageSource source) async {
    if (_picking) return;
    final remaining = ImageRepository.maxImages - _images.length;
    if (remaining <= 0) return;

    setState(() => _picking = true);
    final imageRepository = context.read<ImageRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = source == ImageSource.camera
          ? [
              ?await imageRepository.pickFromCamera(),
            ]
          : await imageRepository.pickFromGallery(remainingSlots: remaining);

      if (picked.isNotEmpty && mounted) {
        setState(() => _images.addAll(picked.take(remaining)));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open photos: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addPhotos(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addPhotos(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the highlighted fields and try again'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final profileState = context.read<ProfileCubit>().state;
    final uni = profileState is ProfileLoaded
        ? profileState.user.university
        : 'none';

    // Validated above, so the parse can't fail here.
    final price = double.parse(_priceController.text.trim());

    if (widget.isEditing) {
      context.read<ListingCubit>().editListing(
        widget.existing!.id,
        ListingDraft(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          price: price,
          category: _selectedCategory,
          condition: _selectedCondition,
          university: widget.existing!.university,
          imageUrls: List.of(_keptImageUrls),
        ),
        newImages: List.of(_images),
      );
      return;
    }

    context.read<ListingCubit>().createListing(
      ListingDraft(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        price: price,
        category: _selectedCategory,
        condition: _selectedCondition,
        university: uni,
      ),
      images: List.of(_images),
      auction: _saleMode.isAuction
          ? AuctionSetup(
              // Bids are whole pounds, so an opening price of £12.50 would
              // make the first legal bid £13 and the stated price a lie.
              startPrice: price.ceil(),
              durationHours: _durationHours,
              reservePrice: _reserve,
            )
          : null,
    );
  }

  /// The reserve as a whole number, or null when there isn't one.
  int? get _reserve {
    if (!_saleMode.isAuction || !_hasReserve) return null;
    return int.tryParse(_reserveController.text.trim());
  }

  /// Validated here as well as on the server, because a seller finding out
  /// their reserve was impossible *after* the photos uploaded is a bad way to
  /// learn it.
  String? _validateReserve(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter a reserve, or turn it off';

    final reserve = int.tryParse(text);
    if (reserve == null) return 'Whole pounds only';
    if (reserve > AuctionRules.maxStartPrice) {
      return 'Nobody could bid that high — £${AuctionRules.maxStartPrice} is the ceiling';
    }

    final opening = double.tryParse(_priceController.text.trim());
    if (opening != null && reserve < opening.ceil()) {
      return 'A reserve under the opening price would never stop anything';
    }
    return null;
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_title');
    await prefs.remove('draft_price');
    await prefs.remove('draft_desc');
    await prefs.remove('draft_category');
    await prefs.remove('draft_condition');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListingCubit, ListingState>(
      listener: (context, state) {
        if (state is ListingOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEditing ? 'Changes saved' : 'Listing posted!',
              ),
              backgroundColor: AppColors.limeGreen,
            ),
          );

          // An edit is finished when it's saved. Leaving somebody on a form
          // with nothing left to do is how you get a second accidental save.
          if (widget.isEditing) {
            if (context.canPop()) context.pop();
            return;
          }

          // Clear form and draft
          _titleController.clear();
          _priceController.clear();
          _descController.clear();
          setState(_images.clear);
          _clearDraft();
          // Navigate to home or listings
        } else if (state is ListingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
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
              Text(
                'STUDYSWAP',
                style: AppTextStyles.buttonText.copyWith(
                  color: AppColors.primaryBlue,
                ),
              ),
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
              child: const Icon(
                Icons.notifications_none,
                color: AppColors.solidBlack,
                size: 20,
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing
                      ? 'EDIT YOUR\nLISTING'
                      : 'WHAT ARE YOU\nSELLING?',
                  style: AppTextStyles.heading1,
                ),
                AppSizes.gapHSm,
                Text(
                  widget.isEditing
                      ? 'Anything here can change while nobody has bid on it.'
                      : 'Provide details about your item to help other '
                            'students find it easily on campus.',
                  style: AppTextStyles.bodyMediumDark,
                ),

                AppSizes.gapHLG,

                // Photos section
                _buildLabel(
                  'PHOTOS ($_photoCount/${ImageRepository.maxImages})',
                ),
                AppSizes.gapHSm,
                _buildPhotoPicker(),

                AppSizes.gapHLG,

                // Title
                _buildLabel('TITLE *'),
                AppSizes.gapHSm,
                _buildInputBox(
                  'e.g., Campbell Biology 12th Edition',
                  _titleController,
                  validator: Validators.listingTitle,
                  textInputAction: TextInputAction.next,
                ),

                AppSizes.gapHLG,

                // Category
                _buildLabel('CATEGORY *'),
                AppSizes.gapHSm,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ListingCategory.values
                      .map(_buildCategoryPill)
                      .toList(),
                ),

                AppSizes.gapHLG,

                // How it's being sold. Above the price on purpose: it
                // changes what the price field means.
                //
                // Not offered when editing: moving a posted listing into the
                // room opens a floor with a closing time and a reserve, which
                // is a different act from correcting a typo.
                if (!widget.isEditing) ...[
                  _buildLabel('HOW ARE YOU SELLING IT?'),
                  AppSizes.gapHSm,
                  SaleModePicker(
                    mode: _saleMode,
                    onChanged: (mode) => setState(() => _saleMode = mode),
                  ),

                  AppSizes.gapHLG,
                ],

                _buildLabel(
                  _saleMode.isAuction ? 'OPENING PRICE *' : 'PRICE *',
                ),
                AppSizes.gapHSm,
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.solidBlack, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('£', style: AppTextStyles.heading2),
                      AppSizes.gapWSm,
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.textGrey,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: Validators.price,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: AppTheme.bareInput(
                            hintText: '0.00',
                            hideErrorText: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_saleMode.isAuction) ...[
                  AppSizes.gapHSm,
                  Text(
                    'Open low. Something nobody bids on tells you nothing; '
                    'something six people fight over tells you what it is '
                    'worth.',
                    style: AppTextStyles.bodySmall.copyWith(height: 1.45),
                  ),

                  AppSizes.gapHLG,

                  _buildLabel('HOW LONG'),
                  AppSizes.gapHSm,
                  DurationPicker(
                    hours: _durationHours,
                    onChanged: (hours) =>
                        setState(() => _durationHours = hours),
                  ),

                  AppSizes.gapHLG,

                  Row(
                    children: [
                      Expanded(child: _buildLabel('SET A RESERVE')),
                      Switch(
                        value: _hasReserve,
                        activeThumbColor: AppColors.white,
                        activeTrackColor: AppColors.primaryBlue,
                        onChanged: (on) => setState(() => _hasReserve = on),
                      ),
                    ],
                  ),
                  if (_hasReserve) ...[
                    AppSizes.gapHSm,
                    _buildInputBox(
                      'Minimum you would accept',
                      _reserveController,
                      validator: _validateReserve,
                    ),
                  ],
                  AppSizes.gapHSm,
                  ReserveNote(reserve: _hasReserve ? _reserve : null),
                ],

                AppSizes.gapHLG,

                // Condition
                _buildLabel('CONDITION'),
                AppSizes.gapHSm,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.solidBlack, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ListingCondition>(
                      value: _selectedCondition,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.solidBlack,
                      ),
                      style: AppTextStyles.bodyMediumDark,
                      onChanged: (ListingCondition? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCondition = newValue;
                          });
                        }
                      },
                      items: ListingCondition.values
                          .map<DropdownMenuItem<ListingCondition>>((value) {
                            return DropdownMenuItem<ListingCondition>(
                              value: value,
                              child: Text(value.label),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),

                AppSizes.gapHLG,

                // Description
                _buildLabel('DESCRIPTION'),
                AppSizes.gapHSm,
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.solidBlack, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextFormField(
                    controller: _descController,
                    maxLines: null,
                    maxLength: Validators.maxDescriptionLength,
                    style: AppTextStyles.bodyMedium,
                    validator: Validators.description,
                    decoration: AppTheme.bareInput(
                      hintText:
                          'Describe the item, note any highlighting or wear...',
                      counterText: '',
                    ),
                  ),
                ),

                AppSizes.gapHLG,

                // Marketplace Network
                BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, state) {
                    final uni = state is ProfileLoaded
                        ? state.user.university
                        : 'none';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4D6),
                        border: Border.all(
                          color: AppColors.solidBlack,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.solidBlack,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.school,
                              color: AppColors.white,
                            ),
                          ),
                          AppSizes.gapWSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MARKETPLACE NETWORK',
                                  style: AppTextStyles.bodyMediumDark.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  uni,
                                  style: AppTextStyles.bodyMediumDark.copyWith(
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.limeGreen,
                                    border: Border.all(
                                      color: AppColors.solidBlack,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified, size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified Student Location',
                                        style: AppTextStyles.bodyMediumDark
                                            .copyWith(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                AppSizes.gapHXL,
                const Text(
                  '----------------------------------------',
                  style: TextStyle(
                    letterSpacing: 2,
                    color: AppColors.solidBlack,
                  ),
                ),
                AppSizes.gapHXL,

                // Action Buttons
                if (!widget.isEditing) ...[
                  CustomButton(
                    text: 'SAVE DRAFT',
                    type: ButtonType.outline,
                    onPressed: _saveDraft,
                  ),
                  AppSizes.gapHMD,
                ],
                BlocBuilder<ListingCubit, ListingState>(
                  builder: (context, state) {
                    final busy =
                        state is ListingLoading || state is ListingUploading;

                    final label = state is ListingUploading
                        ? 'UPLOADING ${(state.progress * 100).round()}%'
                        : busy
                        ? (widget.isEditing ? 'SAVING...' : 'POSTING...')
                        : (widget.isEditing ? 'SAVE CHANGES' : 'POST LISTING');

                    return CustomButton(
                      text: label,
                      type: ButtonType.solid,
                      leadingWidget: busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : null,
                      onPressed: busy ? null : _submit,
                    );
                  },
                ),
                AppSizes.gapHXL,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The photo strip: a tile per chosen image plus an add button, capped at
  /// [ImageRepository.maxImages].
  Widget _buildPhotoPicker() {
    final canAddMore = _photoCount < ImageRepository.maxImages;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photoCount + (canAddMore ? 1 : 0),
        separatorBuilder: (_, _) => AppSizes.gapWSm,
        itemBuilder: (context, index) {
          if (index < _keptImageUrls.length) {
            return _buildKeptPhotoTile(index);
          }
          final picked = index - _keptImageUrls.length;
          if (picked == _images.length) return _buildAddPhotoTile();
          return _buildPhotoTile(picked);
        },
      ),
    );
  }

  Widget _buildAddPhotoTile() {
    return GestureDetector(
      onTap: _picking ? null : _showPhotoSourceSheet,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryBlue, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_picking)
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryBlue,
                ),
              )
            else
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primaryBlue,
                size: 28,
              ),
            AppSizes.gapHSm,
            Text(
              _images.isEmpty ? 'ADD PHOTO' : 'ADD MORE',
              style: AppTextStyles.bodyMediumDark.copyWith(
                color: AppColors.primaryBlue,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A photo already uploaded. Same chrome as a freshly picked one, so the
  /// strip reads as one row rather than two kinds of thing.
  Widget _buildKeptPhotoTile(int index) {
    return _photoFrame(
      isCover: index == 0,
      onRemove: () => setState(() => _keptImageUrls.removeAt(index)),
      child: ListingImage(url: _keptImageUrls[index]),
    );
  }

  Widget _buildPhotoTile(int index) {
    return _photoFrame(
      isCover: _keptImageUrls.isEmpty && index == 0,
      onRemove: () => setState(() => _images.removeAt(index)),
      child: Image.file(
        File(_images[index].path),
        fit: BoxFit.cover,
        width: 96,
        height: 96,
      ),
    );
  }

  Widget _photoFrame({
    required bool isCover,
    required VoidCallback onRemove,
    required Widget child,
  }) {
    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.solidBlack, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: child,
          ),
        ),
        // The first photo is what every card in the app shows.
        if (isCover)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.limeGreen,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.solidBlack),
              ),
              child: Text(
                'COVER',
                style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 8),
              ),
            ),
          ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.solidBlack,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 13,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 12),
    );
  }

  Widget _buildInputBox(
    String hint,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
  }) {
    // The bordered container is the field's visual chrome, so the error text
    // has to sit outside it rather than inside the box.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.solidBlack, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: controller,
            style: AppTextStyles.bodyMediumDark,
            validator: validator,
            textInputAction: textInputAction,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: AppTheme.bareInput(
              hintText: hint,
              hintStyle: AppTextStyles.bodyMedium,
              hideErrorText: true,
            ),
          ),
        ),
        _buildFieldError(controller, validator),
      ],
    );
  }

  /// Renders the validator's message under the bordered box.
  Widget _buildFieldError(
    TextEditingController controller,
    String? Function(String?)? validator,
  ) {
    if (validator == null) return const SizedBox.shrink();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final error = validator(value.text);
        if (error == null || value.text.isEmpty) {
          return const SizedBox(height: 4);
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            error,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed),
          ),
        );
      },
    );
  }

  Widget _buildCategoryPill(ListingCategory category) {
    final isActive = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBlue : AppColors.white,
          border: Border.all(color: AppColors.solidBlack, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category.label.toUpperCase(),
          style: AppTextStyles.bodyMediumDark.copyWith(
            color: isActive ? AppColors.white : AppColors.solidBlack,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
