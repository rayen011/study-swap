import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/logic/auth_cubit.dart';
import '../../auth/logic/auth_state.dart';
import '../logic/profile_cubit.dart';
import '../logic/profile_state.dart';

/// ProfileScreen: Displays user profile details and settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          context.go('/login');
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
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSizes.gapHLG, // Extra space for avatar overlap
              
              // Profile Card
              Stack(
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
                    child: BlocBuilder<ProfileCubit, ProfileState>(
                      builder: (context, state) {
                        String name = 'STUDENT';
                        String university = 'NONE';
                        
                        if (state is ProfileLoaded) {
                          name = state.userData['fullName']?.toUpperCase() ?? 'STUDENT';
                          university = state.userData['university'] ?? 'none';
                        }
                        
                        return Column(
                          children: [
                            Text(name.contains(' ') ? name.replaceFirst(' ', '\n') : name, 
                              style: AppTextStyles.heading1, textAlign: TextAlign.center),
                            AppSizes.gapHMD,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.solidBlack, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school_outlined, color: AppColors.primaryBlue, size: 16),
                                  const SizedBox(width: 8),
                                  Text(university, style: AppTextStyles.bodyMediumDark.copyWith(color: AppColors.primaryBlue), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                            AppSizes.gapHMD,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.solidBlack, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_border, size: 14),
                                  const SizedBox(width: 4),
                                  Text('4.8 (24 Reviews)', style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 10)),
                                ],
                              ),
                            ),
                            AppSizes.gapHSm,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.limeGreen,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.solidBlack, width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14),
                                  const SizedBox(width: 4),
                                  Text('15 Swaps Done', style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 10)),
                                ],
                              ),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  side: const BorderSide(color: AppColors.solidBlack, width: 1.5),
                                ),
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text('EDIT PROFILE', style: AppTextStyles.buttonTextWhite),
                              ),
                            ),
                          ],
                        );
                      },
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
                          child: const Icon(Icons.person, size: 40, color: AppColors.textGrey),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C7500), // Olive Green
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.solidBlack, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, color: AppColors.white, size: 10),
                                const SizedBox(width: 4),
                                Text('Verified\nStudent', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white, fontSize: 8), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              AppSizes.gapHXL,
              
              // Account & Settings
              Text('ACCOUNT & SETTINGS', style: AppTextStyles.heading2.copyWith(fontSize: 18)),
              const Divider(color: AppColors.solidBlack, thickness: 2),
              AppSizes.gapHMD,
              
              // Settings Grid
              Column(
                children: [
                  _buildSettingTile(Icons.payment, 'Payment\nMethods', 'Manage cards & payouts', AppColors.primaryBlue, AppColors.white),
                  AppSizes.gapHSm,
                  _buildSettingTile(Icons.security, 'Privacy &\nSecurity', 'Password & verification', AppColors.limeGreen, AppColors.solidBlack),
                  AppSizes.gapHSm,
                  Row(
                    children: [
                      Expanded(child: _buildSettingSquare(context, Icons.notifications_none, 'ALERTS', const Color(0xFFFFE4D6))),
                      AppSizes.gapWSm,
                      Expanded(child: _buildSettingSquare(context, Icons.help_outline, 'SUPPORT', const Color(0xFFE2E8F0))),
                    ],
                  ),
                  AppSizes.gapHSm,
                  Row(
                    children: [
                      Expanded(child: _buildSettingSquare(context, Icons.dark_mode_outlined, 'THEME', const Color(0xFF111111), isDark: true)),
                      AppSizes.gapWSm,
                      Expanded(
                        child: _buildSettingSquare(
                          context, 
                          Icons.logout, 
                          'LOG OUT', 
                          const Color(0xFFB91C1C), 
                          isDark: true,
                          onTap: () => context.read<AuthCubit>().logout(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              AppSizes.gapHXL,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, Color iconBgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.solidBlack, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.solidBlack, offset: Offset(2, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.solidBlack, width: 1.5),
            ),
            child: Icon(icon, color: iconColor),
          ),
          AppSizes.gapWMD,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyMediumDark.copyWith(fontSize: 16, height: 1.1)),
              Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSquare(BuildContext context, IconData icon, String title, Color bgColor, {bool isDark = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.solidBlack, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.solidBlack, offset: Offset(2, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.solidBlack, width: 1.5),
              ),
              child: Icon(icon, color: isDark ? AppColors.white : AppColors.solidBlack),
            ),
            AppSizes.gapHMD,
            Text(title, style: AppTextStyles.buttonText.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
