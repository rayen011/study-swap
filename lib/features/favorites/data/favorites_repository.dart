import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Toggles the favorite status of a listing.
  Future<void> toggleFavorite(Map<String, dynamic> listing) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    final listingId = listing['id'];
    final favoriteRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(listingId);

    final doc = await favoriteRef.get();

    if (doc.exists) {
      await favoriteRef.delete();
    } else {
      await favoriteRef.set({
        ...listing,
        'favoritedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Streams the list of favorite listings for the current user.
  /// Fetches live data from the 'listings' collection to avoid stale data.
  Stream<List<Map<String, dynamic>>> getFavorites() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('favoritedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> results = [];
      for (var favDoc in snapshot.docs) {
        final listingId = favDoc.id;
        final listingDoc = await _firestore.collection('listings').doc(listingId).get();
        if (listingDoc.exists) {
          final data = listingDoc.data()!;
          data['id'] = listingDoc.id;
          results.add(data);
        }
      }
      return results;
    });
  }

  /// Checks if a specific listing is favorited.
  Stream<bool> isFavorited(String listingId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(listingId)
        .snapshots()
        .map((doc) => doc.exists);
  }
}
