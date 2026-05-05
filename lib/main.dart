import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/logic/auth_cubit.dart';
import 'features/listings/data/listing_repository.dart';
import 'features/listings/logic/listing_cubit.dart';
import 'features/listings/logic/my_listings_cubit.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/logic/chat_cubit.dart';
import 'features/favorites/data/favorites_repository.dart';
import 'features/favorites/logic/favorites_cubit.dart';
import 'features/profile/logic/profile_cubit.dart';
import 'features/profile/data/rating_repository.dart';
import 'features/report/data/report_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final authRepository = AuthRepository();
  final listingRepository = ListingRepository();
  final chatRepository = ChatRepository();
  final favoritesRepository = FavoritesRepository();
  final ratingRepository = RatingRepository();
  final reportRepository = ReportRepository();
  
  runApp(MyApp(
    authRepository: authRepository,
    listingRepository: listingRepository,
    chatRepository: chatRepository,
    favoritesRepository: favoritesRepository,
    ratingRepository: ratingRepository,
    reportRepository: reportRepository,
  ));
}

class MyApp extends StatefulWidget {
  final AuthRepository authRepository;
  final ListingRepository listingRepository;
  final ChatRepository chatRepository;
  final FavoritesRepository favoritesRepository;
  final RatingRepository ratingRepository;
  final ReportRepository reportRepository;
  
  const MyApp({
    super.key, 
    required this.authRepository,
    required this.listingRepository,
    required this.chatRepository,
    required this.favoritesRepository,
    required this.ratingRepository,
    required this.reportRepository,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthCubit _authCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(widget.authRepository);
    _authCubit.checkAuthStatus();
    _router = AppRouter.createRouter(_authCubit);
  }

  @override
  void dispose() {
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.authRepository),
        RepositoryProvider.value(value: widget.listingRepository),
        RepositoryProvider.value(value: widget.chatRepository),
        RepositoryProvider.value(value: widget.favoritesRepository),
        RepositoryProvider.value(value: widget.ratingRepository),
        RepositoryProvider.value(value: widget.reportRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authCubit),
          BlocProvider(create: (context) => ListingCubit(widget.listingRepository)),
          BlocProvider(create: (context) => MyListingsCubit(widget.listingRepository)),
          BlocProvider(create: (context) => ProfileCubit(widget.authRepository)),
          BlocProvider(create: (context) => ChatCubit(widget.chatRepository)),
          BlocProvider(create: (context) => MessageCubit(
            widget.chatRepository, 
            widget.ratingRepository,
          )),
          BlocProvider(create: (context) => FavoritesCubit(widget.favoritesRepository)),
        ],
        child: MaterialApp.router(
          title: 'StudySwap',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
            useMaterial3: true,
            textTheme: GoogleFonts.interTextTheme(),
          ),
          routerConfig: _router,
        ),
      ),
    );
  }
}
