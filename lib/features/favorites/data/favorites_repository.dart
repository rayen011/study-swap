import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/listing.dart';

class FavoritesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get _favorites {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('favorites');
  }

  /// Toggles the favorite status of a listing.
  Future<void> toggleFavorite(Listing listing) async {
    final favorites = _favorites;
    if (favorites == null) throw Exception('User not logged in');

    final ref = favorites.doc(listing.id);
    final doc = await ref.get();

    if (doc.exists) {
      await ref.delete();
    } else {
      // Only the pointer is stored; the listing itself is read live so a
      // favourite never shows a stale price.
      await ref.set({
        'listingId': listing.id,
        'favoritedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Streams the list of favorite listings for the current user.
  ///
  /// Each favourite is re-read from `listings` so the card reflects the
  /// current price and status. That's one read per favourite per change —
  /// batching it is tracked as a follow-up.
  Stream<List<Listing>> getFavorites() {
    final favorites = _favorites;
    if (favorites == null) return Stream.value(const []);

    return favorites
        .orderBy('favoritedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final listings = <Listing>[];
          for (final favDoc in snapshot.docs) {
            final listingDoc = await _firestore
                .collection('listings')
                .doc(favDoc.id)
                .get();
            final listing = Listing.fromDoc(listingDoc);
            // Skip listings deleted since they were favourited.
            if (listing != null) listings.add(listing);
          }
          return listings;
        });
  }

  /// Checks if a specific listing is favorited.
  Stream<bool> isFavorited(String listingId) {
    final favorites = _favorites;
    if (favorites == null || listingId.isEmpty) return Stream.value(false);

    return favorites.doc(listingId).snapshots().map((doc) => doc.exists);
  }
}
