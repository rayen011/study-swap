import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/animations/app_animations.dart';

/// LandingScreen: Displays the onboarding flow for new users.
/// Uses a PageView to swipe through different onboarding steps.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  void _skip() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar (Progress indicators and Skip/Back buttons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage == 0)
                    const SizedBox(width: 48) // Placeholder to balance SKIP text
                  else
                    TapBounce(
                      onTap: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.solidBlack, width: 2),
                        ),
                        child: const Icon(Icons.arrow_back, size: 20),
                      ),
                    ),
                  
                  // Page Indicators
                  Row(
                    children: [
                      _buildDot(0),
                      AppSizes.gapWSm,
                      _buildDot(1),
                      AppSizes.gapWSm,
                      _buildDot(2), // Included an extra dot just like the screenshot
                    ],
                  ),
                  
                  if (_currentPage == 0)
                    TapBounce(
                      onTap: _skip,
                      child: Text(
                        'SKIP',
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48), // Placeholder to balance Back button
                ],
              ),
            ),

            // Page View Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildPageContent(
                    title: 'Buy & sell\neasily',
                    subtitle: 'The student-only marketplace for everything you need for campus life.',
                    iconPlaceholder: Icons.storefront_outlined,
                    isFirstPage: true,
                  ),
                  _buildPageContent(
                    title: 'Only students,\nno scams',
                    subtitle: 'Verified university emails ensure a safe and trusted community for everyone.',
                    iconPlaceholder: Icons.shield_outlined,
                    isFirstPage: false,
                  ),
                ],
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: CustomButton(
                text: _currentPage == 0 ? 'NEXT' : 'Get Started',
                type: ButtonType.brutal,
                trailingIcon: _currentPage == 0 ? Icons.arrow_forward : null,
                onPressed: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Indicator dot widget
  Widget _buildDot(int index) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.solidBlack, width: isActive ? 0 : 2),
      ),
    );
  }

  // Individual page content layout
  Widget _buildPageContent({
    required String title,
    required String subtitle,
    required IconData iconPlaceholder,
    required bool isFirstPage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration Placeholder (Neubrutalism style container)
          Expanded(
            child: Center(
              child: FadeInSlide(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.solidBlack, width: 3),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.solidBlack,
                        offset: Offset(8, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    iconPlaceholder,
                    size: 100,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
          
          AppSizes.gapHLG,
          FadeInSlide(
            delay: const Duration(milliseconds: 200),
            child: Text(
              title,
              style: AppTextStyles.heading1,
              textAlign: TextAlign.center,
            ),
          ),
          AppSizes.gapHMD,
          FadeInSlide(
            delay: const Duration(milliseconds: 400),
            child: Text(
              subtitle,
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          AppSizes.gapHLG,
        ],
      ),
    );
  }
}
