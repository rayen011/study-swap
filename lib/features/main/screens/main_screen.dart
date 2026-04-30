import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../chat/data/chat_repository.dart';

/// MainScreen: Wrapper for the Bottom Navigation Bar using StatefulShellRoute.
class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.solidBlack, width: 2)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_outlined, 'HOME'),
              _buildNavItem(1, Icons.list_alt_outlined, 'LISTINGS'),
              _buildSellButton(2),
              StreamBuilder<int>(
                stream: context.read<ChatRepository>().getTotalUnreadCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  String badgeText = '';
                  if (count > 0) {
                    badgeText = count > 4 ? '+4' : count.toString();
                  }
                  return _buildNavItem(
                    3,
                    Icons.chat_bubble_outline,
                    'CHAT',
                    badge: badgeText,
                  );
                },
              ),
              _buildNavItem(4, Icons.person_outline, 'PROFILE'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {String? badge}) {
    final isActive = navigationShell.currentIndex == index;

    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: isActive
                ? BoxDecoration(
                    color: const Color(0xFFE2E8F0), // Light blueish background
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.solidBlack, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.solidBlack,
                        offset: Offset(4, 4),
                      ),
                    ],
                  )
                : const BoxDecoration(
                    color: Colors.transparent,
                  ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: AppColors.primaryBlue,
                  size: 28,
                ),
                if (badge != null && badge.isNotEmpty)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.solidBlack, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodyMediumDark.copyWith(
              fontSize: 10,
              color: AppColors.primaryBlue,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellButton(int index) {
    return GestureDetector(
      onTap: () => _onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.solidBlack, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.solidBlack,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: AppColors.white, size: 32),
          ),
          const SizedBox(height: 4),
          Text(
            'SELL',
            style: AppTextStyles.bodyMediumDark.copyWith(
              fontSize: 10,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
