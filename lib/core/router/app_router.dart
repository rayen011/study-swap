import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/screens/landing_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/main/screens/main_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/item_details_screen.dart';
import '../../features/listings/screens/listings_screen.dart';
import '../../features/sell/screens/sell_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/chat_details_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/auth/logic/auth_state.dart';
import '../animations/app_animations.dart';

/// AppRouter: Centralized routing configuration using GoRouter.
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
  static final _shellNavigatorListingsKey = GlobalKey<NavigatorState>(debugLabel: 'shellListings');
  static final _shellNavigatorSellKey = GlobalKey<NavigatorState>(debugLabel: 'shellSell');
  static final _shellNavigatorChatKey = GlobalKey<NavigatorState>(debugLabel: 'shellChat');
  static final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      initialLocation: '/',
      navigatorKey: _rootNavigatorKey,
      refreshListenable: GoRouterRefreshStream(authCubit.stream),
      redirect: (context, state) {
        final authState = authCubit.state;
        final bool isAuth = authState is Authenticated;
        final bool isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup' || state.matchedLocation == '/';

        if (!isAuth) {
          return null; // Let the user go to landing/login/signup
        }

        if (isLoggingIn) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LandingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/item-details',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final listing = state.extra as Map<String, dynamic>;
            return _buildTransitionPage(
              child: ItemDetailsScreen(listing: listing),
              state: state,
              transitionType: 'scale',
            );
          },
        ),
        GoRoute(
          path: '/edit-profile',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _buildTransitionPage(
            child: const EditProfileScreen(),
            state: state,
          ),
        ),
        GoRoute(
          path: '/chat-details',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return _buildTransitionPage(
              child: ChatDetailsScreen(
                chatId: extra['chatId'],
                receiverName: extra['receiverName'],
                receiverId: extra['receiverId'],
              ),
              state: state,
              transitionType: 'slideUp',
            );
          },
        ),
        
        // Stateful navigation shell for BottomNavigationBar
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainScreen(navigationShell: navigationShell);
          },
          branches: [
            // HOME
            StatefulShellBranch(
              navigatorKey: _shellNavigatorHomeKey,
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            // LISTINGS
            StatefulShellBranch(
              navigatorKey: _shellNavigatorListingsKey,
              routes: [
                GoRoute(
                  path: '/listings',
                  builder: (context, state) => const ListingsScreen(),
                ),
              ],
            ),
            // SELL
            StatefulShellBranch(
              navigatorKey: _shellNavigatorSellKey,
              routes: [
                GoRoute(
                  path: '/sell',
                  builder: (context, state) => const SellScreen(),
                ),
              ],
            ),
            // CHAT
            StatefulShellBranch(
              navigatorKey: _shellNavigatorChatKey,
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const ChatScreen(),
                ),
              ],
            ),
            // PROFILE
            StatefulShellBranch(
              navigatorKey: _shellNavigatorProfileKey,
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static CustomTransitionPage _buildTransitionPage({
    required Widget child,
    required GoRouterState state,
    String transitionType = 'slideFade',
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        switch (transitionType) {
          case 'scale':
            return PageTransitions.scale(context, animation, secondaryAnimation, child);
          case 'slideUp':
            return PageTransitions.slideUp(context, animation, secondaryAnimation, child);
          default:
            return PageTransitions.slideFade(context, animation, secondaryAnimation, child);
        }
      },
    );
  }
}

/// Helper class to convert a Stream into a Listenable for GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
