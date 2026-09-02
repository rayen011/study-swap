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

  /// Firestore's cap on values in a single `whereIn` clause.
  static const int _whereInChunkSize = 30;

  /// Streams the list of favorite listings for the current user.
  ///
  /// Only the listing id is stored on the favourite, so the listings are read
  /// live — a favourited item shows its current price and status rather than
  /// whatever it cost when it was saved.
  ///
  /// The reads are batched with `whereIn` in chunks of 30: 20 favourites cost
  /// one query instead of twenty, and the chunks run concurrently.
  Stream<List<Listing>> getFavorites() {
    final favorites = _favorites;
    if (favorites == null) return Stream.value(const []);

    return favorites
        .orderBy('favoritedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((doc) => doc.id).toList();
          if (ids.isEmpty) return const <Listing>[];

          final chunks = <List<String>>[
            for (var i = 0; i < ids.length; i += _whereInChunkSize)
              ids.sublist(
                i,
                (i + _whereInChunkSize).clamp(0, ids.length),
              ),
          ];

          final results = await Future.wait(
            chunks.map(
              (chunk) => _firestore
                  .collection('listings')
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get(),
            ),
          );

          // whereIn doesn't preserve order, so index by id and rebuild in the
          // order the favourites were saved.
          final byId = {
            for (final snap in results)
              for (final doc in snap.docs)
                doc.id: Listing.fromMap(doc.id, doc.data()),
          };

          // Listings deleted since they were favourited simply drop out.
          return [for (final id in ids) ?byId[id]];
        });
  }

  /// Checks if a specific listing is favorited.
  Stream<bool> isFavorited(String listingId) {
    final favorites = _favorites;
    if (favorites == null || listingId.isEmpty) return Stream.value(false);

    return favorites.doc(listingId).snapshots().map((doc) => doc.exists);
  }
}
