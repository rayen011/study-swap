import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/screens/landing_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/main/screens/main_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/item_details_screen.dart';
import '../../features/auctions/screens/auction_details_screen.dart';
import '../../features/auctions/screens/bid_room_screen.dart';
import '../../features/listings/screens/listings_screen.dart';
import '../../features/sell/screens/sell_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/chat/screens/chat_details_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/report/screens/moderation_queue_screen.dart';
import '../../features/report/screens/report_details_screen.dart';
import '../../features/auth/logic/auth_cubit.dart';
import '../../features/auth/logic/auth_state.dart';
import '../animations/app_animations.dart';
import '../models/listing.dart';
import '../models/report.dart';

/// AppRouter: Centralized routing configuration using GoRouter.
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellHome',
  );
  static final _shellNavigatorListingsKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellListings',
  );
  static final _shellNavigatorSellKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellSell',
  );
  static final _shellNavigatorChatKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellChat',
  );
  static final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(
    debugLabel: 'shellProfile',
  );

  /// Reachable without a session. Everything else redirects to `/login`.
  static const Set<String> _publicRoutes = {'/', '/login', '/signup'};

  static const String _splash = '/splash';

  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      initialLocation: _splash,
      navigatorKey: _rootNavigatorKey,
      refreshListenable: GoRouterRefreshStream(authCubit.stream),
      redirect: (context, state) {
        final authState = authCubit.state;
        final location = state.matchedLocation;

        // AuthInitial means Firebase hasn't finished restoring the session
        // yet. Hold on the splash rather than flashing the landing page.
        // AuthLoading is a sign-in already in progress and must NOT land here,
        // or the user gets bounced off the form mid-login.
        if (authState is AuthInitial) {
          return location == _splash ? null : _splash;
        }

        final isAuth = authState is Authenticated;
        final isPublic = _publicRoutes.contains(location);

        if (!isAuth) {
          // Leaving the splash with no session means a first run: send them
          // to the onboarding flow, not straight to the login form.
          if (location == _splash) return '/';
          // A deep link or hot restart onto a protected route lands here.
          return isPublic ? null : '/login';
        }

        if (isPublic || location == _splash) return '/home';

        return null;
      },
      routes: [
        GoRoute(
          path: _splash,
          builder: (context, state) => const SplashScreen(),
        ),
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
            final listing = state.extra as Listing;
            return _buildTransitionPage(
              child: ItemDetailsScreen(listing: listing),
              state: state,
              transitionType: 'scale',
            );
          },
        ),
        // The Bid Room lives on the root navigator on purpose: a route inside
        // the shell keeps the bottom bar, and the bar is what makes it feel
        // like a sixth tab instead of somewhere you went.
        GoRoute(
          path: '/bid-room',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _buildTransitionPage(
            child: const BidRoomScreen(),
            state: state,
            transitionType: 'slideUp',
          ),
          routes: [
            GoRoute(
              path: ':auctionId',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) => _buildTransitionPage(
                child: AuctionDetailsScreen(
                  auctionId: state.pathParameters['auctionId']!,
                ),
                state: state,
              ),
            ),
          ],
        ),
        // Editing reuses the sell form rather than a second screen that would
        // drift from it.
        GoRoute(
          path: '/edit-listing',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _buildTransitionPage(
            child: SellScreen(existing: state.extra as Listing),
            state: state,
            transitionType: 'slideUp',
          ),
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
            final args = state.extra as ChatDetailsArgs;
            return _buildTransitionPage(
              child: ChatDetailsScreen(
                chatId: args.chatId,
                receiverName: args.receiverName,
                receiverId: args.receiverId,
              ),
              state: state,
              transitionType: 'slideUp',
            );
          },
        ),
        GoRoute(
          path: '/moderation',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const ModerationQueueScreen(),
        ),
        GoRoute(
          path: '/moderation/report/:id',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final reportId = state.pathParameters['id']!;
            return ReportDetailsScreen(
              reportId: reportId,
              initialReport: state.extra as Report?,
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
            return PageTransitions.scale(
              context,
              animation,
              secondaryAnimation,
              child,
            );
          case 'slideUp':
            return PageTransitions.slideUp(
              context,
              animation,
              secondaryAnimation,
              child,
            );
          default:
            return PageTransitions.slideFade(
              context,
              animation,
              secondaryAnimation,
              child,
            );
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
