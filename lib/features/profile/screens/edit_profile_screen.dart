import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../logic/profile_cubit.dart';
import '../logic/profile_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _uniController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded) {
      _nameController.text = profileState.user.fullName;
      _uniController.text = profileState.user.university;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _uniController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('EDIT PROFILE', style: AppTextStyles.heading2.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.solidBlack),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.limeGreen),
            );
            context.pop();
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Placeholder
              Center(
                child: Stack(
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppColors.borderGrey,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.solidBlack, width: 2),
                      ),
                      child: const Icon(Icons.person, size: 50, color: AppColors.textGrey),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.solidBlack, width: 1.5),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),
              AppSizes.gapHXL,

              CustomTextField(
                label: 'Full Name',
                hintText: 'Enter your full name',
                controller: _nameController,
                prefixIcon: Icons.person_outline,
              ),
              AppSizes.gapHLG,

              CustomTextField(
                label: 'University',
                hintText: 'e.g. University of Oxford',
                controller: _uniController,
                prefixIcon: Icons.school_outlined,
              ),
              AppSizes.gapHXXL,

              BlocBuilder<ProfileCubit, ProfileState>(
                builder: (context, state) {
                  return CustomButton(
                    text: state is ProfileLoading ? 'SAVING...' : 'SAVE CHANGES',
                    type: ButtonType.solid,
                    onPressed: state is ProfileLoading
                        ? null
                        : () {
                            context.read<ProfileCubit>().updateProfile(
                                  fullName: _nameController.text,
                                  university: _uniController.text,
                                );
                          },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
