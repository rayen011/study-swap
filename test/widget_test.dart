import 'package:flutter_test/flutter_test.dart';
import 'package:studyswap/main.dart';
import 'package:studyswap/features/auth/data/auth_repository.dart';
import 'package:studyswap/features/listings/data/listing_repository.dart';
import 'package:studyswap/features/chat/data/chat_repository.dart';
import 'package:studyswap/features/favorites/data/favorites_repository.dart';
import 'package:studyswap/features/profile/data/rating_repository.dart';

void main() {
  testWidgets('App should load', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      authRepository: AuthRepository(),
      listingRepository: ListingRepository(),
      chatRepository: ChatRepository(),
      favoritesRepository: FavoritesRepository(),
      ratingRepository: RatingRepository(),
    ));

    // Verify that the app starts (e.g., checking if it doesn't crash)
    expect(find.byType(MyApp), findsOneWidget);
  });
}
