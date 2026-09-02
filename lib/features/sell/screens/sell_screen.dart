import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/listing_options.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../../listings/data/image_repository.dart';
import '../../listings/logic/listing_cubit.dart';
import '../../listings/logic/listing_state.dart';
import '../../profile/logic/profile_cubit.dart';
import '../../profile/logic/profile_state.dart';

/// SellScreen: The form for creating a new listing.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  ListingCategory _selectedCategory = ListingCategory.textbooks;
  ListingCondition _selectedCondition = ListingCondition.likeNew;

  /// Photos chosen but not yet uploaded. They upload when the listing is
  /// posted, so abandoning the form costs nothing in Storage.
  final List<XFile> _images = [];
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
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

    context.read<ListingCubit>().createListing(
      ListingDraft(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        // Validated above, so the parse can't fail here.
        price: double.parse(_priceController.text.trim()),
        category: _selectedCategory,
        condition: _selectedCondition,
        university: uni,
      ),
      images: List.of(_images),
    );
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
            const SnackBar(
              content: Text('Listing posted successfully!'),
              backgroundColor: AppColors.limeGreen,
            ),
          );
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
                Text('WHAT ARE YOU\nSELLING?', style: AppTextStyles.heading1),
                AppSizes.gapHSm,
                Text(
                  'Provide details about your item to help other students find it easily on campus.',
                  style: AppTextStyles.bodyMediumDark,
                ),

                AppSizes.gapHLG,

                // Photos section
                _buildLabel(
                  'PHOTOS (${_images.length}/${ImageRepository.maxImages})',
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

                // Price
                _buildLabel('PRICE *'),
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
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            errorStyle: TextStyle(height: 0, fontSize: 0),
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                    decoration: const InputDecoration(
                      hintText:
                          'Describe the item, note any highlighting or wear...',
                      border: InputBorder.none,
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
                CustomButton(
                  text: 'SAVE DRAFT',
                  type: ButtonType.outline,
                  onPressed: _saveDraft,
                ),
                AppSizes.gapHMD,
                BlocBuilder<ListingCubit, ListingState>(
                  builder: (context, state) {
                    final busy =
                        state is ListingLoading || state is ListingUploading;

                    final label = state is ListingUploading
                        ? 'UPLOADING ${(state.progress * 100).round()}%'
                        : busy
                        ? 'POSTING...'
                        : 'POST LISTING';

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
    final canAddMore = _images.length < ImageRepository.maxImages;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + (canAddMore ? 1 : 0),
        separatorBuilder: (_, _) => AppSizes.gapWSm,
        itemBuilder: (context, index) {
          if (index == _images.length) return _buildAddPhotoTile();
          return _buildPhotoTile(index);
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

  Widget _buildPhotoTile(int index) {
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
            child: Image.file(
              File(_images[index].path),
              fit: BoxFit.cover,
              width: 96,
              height: 96,
            ),
          ),
        ),
        // The first photo is what every card in the app shows.
        if (index == 0)
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
            onTap: () => setState(() => _images.removeAt(index)),
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
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: AppTextStyles.bodyMedium,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
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
