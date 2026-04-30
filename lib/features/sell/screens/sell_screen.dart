import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
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
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _selectedCategory = 'TEXTBOOKS';
  String _selectedCondition = 'Like New';

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListingCubit, ListingState>(
      listener: (context, state) {
        if (state is ListingOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing posted successfully!'), backgroundColor: AppColors.limeGreen),
          );
          // Clear form
          _titleController.clear();
          _priceController.clear();
          _descController.clear();
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
              Text('STUDYSWAP', style: AppTextStyles.buttonText.copyWith(color: AppColors.primaryBlue)),
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
              child: const Icon(Icons.notifications_none, color: AppColors.solidBlack, size: 20),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHAT ARE YOU\nSELLING?', style: AppTextStyles.heading1),
              AppSizes.gapHSm,
              Text('Provide details about your item to help other students find it easily on campus.', style: AppTextStyles.bodyMediumDark),
              
              AppSizes.gapHLG,
              
              // Photos section
              _buildLabel('PHOTOS * (OPTIONAL FOR NOW)'),
              AppSizes.gapHSm,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryBlue, width: 2, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryBlue, size: 32),
                    AppSizes.gapHSm,
                    Text('ADD COVER PHOTO', style: AppTextStyles.bodyMediumDark.copyWith(color: AppColors.primaryBlue, fontSize: 12)),
                  ],
                ),
              ),
              
              AppSizes.gapHLG,
              
              // Title
              _buildLabel('TITLE *'),
              AppSizes.gapHSm,
              _buildInputBox('e.g., Campbell Biology 12th Edition', _titleController),
              
              AppSizes.gapHLG,
              
              // Category
              _buildLabel('CATEGORY *'),
              AppSizes.gapHSm,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCategoryPill('TEXTBOOKS'),
                  _buildCategoryPill('ELECTRONICS'),
                  _buildCategoryPill('HOUSING'),
                  _buildCategoryPill('OTHER'),
                ],
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
                      child: TextField(
                        controller: _priceController,
                        style: AppTextStyles.heading2.copyWith(color: AppColors.textGrey),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.solidBlack, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCondition,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.solidBlack),
                    style: AppTextStyles.bodyMediumDark,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCondition = newValue;
                        });
                      }
                    },
                    items: <String>['Like New', 'Good', 'Fair', 'Poor']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
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
                child: TextField(
                  controller: _descController,
                  maxLines: null,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'Describe the item, note any highlighting or wear...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              
              AppSizes.gapHLG,
              
              // Marketplace Network
              BlocBuilder<ProfileCubit, ProfileState>(
                builder: (context, state) {
                  String uni = 'none';
                  if (state is ProfileLoaded) {
                    uni = state.userData['university'] ?? 'none';
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4D6),
                      border: Border.all(color: AppColors.solidBlack, width: 2),
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
                          child: const Icon(Icons.school, color: AppColors.white),
                        ),
                        AppSizes.gapWSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MARKETPLACE NETWORK', style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 10)),
                              Text(uni, style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 16)),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.limeGreen,
                                  border: Border.all(color: AppColors.solidBlack),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified, size: 10),
                                    const SizedBox(width: 4),
                                    Text('Verified Student Location', style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 10)),
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
              const Text('----------------------------------------', style: TextStyle(letterSpacing: 2, color: AppColors.solidBlack)),
              AppSizes.gapHXL,
              
              // Action Buttons
              CustomButton(
                text: 'SAVE DRAFT',
                type: ButtonType.outline,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved locally')));
                },
              ),
              AppSizes.gapHMD,
              BlocBuilder<ListingCubit, ListingState>(
                builder: (context, state) {
                  return CustomButton(
                    text: state is ListingLoading ? 'POSTING...' : 'POST LISTING',
                    type: ButtonType.solid,
                    onPressed: state is ListingLoading
                        ? null
                        : () {
                            final profileState = context.read<ProfileCubit>().state;
                            String uni = 'none';
                            if (profileState is ProfileLoaded) {
                              uni = profileState.userData['university'] ?? 'none';
                            }

                            if (_titleController.text.isEmpty || _priceController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill all required fields (*)'), backgroundColor: Colors.red),
                              );
                              return;
                            }

                            context.read<ListingCubit>().createListing(
                                  title: _titleController.text,
                                  description: _descController.text,
                                  price: double.tryParse(_priceController.text) ?? 0.0,
                                  category: _selectedCategory,
                                  university: uni,
                                );
                          },
                  );
                },
              ),
              AppSizes.gapHXL,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 12),
    );
  }

  Widget _buildInputBox(String hint, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.solidBlack, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        style: AppTextStyles.bodyMediumDark,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          hintStyle: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String label) {
    final isActive = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
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
          label,
          style: AppTextStyles.bodyMediumDark.copyWith(
            color: isActive ? AppColors.white : AppColors.solidBlack,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
