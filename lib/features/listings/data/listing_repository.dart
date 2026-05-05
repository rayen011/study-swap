import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ListingRepository: Handles CRUD operations for Marketplace Listings in Firestore.
class ListingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a new listing in Firestore.
  Future<void> createListing({
    required String title,
    required String description,
    required double price,
    required String category,
    required String university,
    required String condition,
    String? imageUrl,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User must be logged in to create a listing');
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final sellerName = userDoc.data()?['fullName'] ?? 'Student';

    await _firestore.collection('listings').add({
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'university': university,
      'condition': condition,
      'userId': uid,
      'sellerName': sellerName,
      'imageUrl': imageUrl ?? '', // Placeholder logic
      'status': 'active', // active, reserved, sold
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the status of a listing.
  Future<void> updateListingStatus(String listingId, String status) async {
    await _firestore.collection('listings').doc(listingId).update({
      'status': status,
    });
  }

  /// Streams all listings from Firestore.
  Stream<List<Map<String, dynamic>>> getListings() {
    return _firestore.collection('listings').snapshots().map((snapshot) {
      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort manually in Dart to avoid "Index Required" errors
      docs.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Descending
      });
      return docs;
    });
  }

  /// Streams listings for a specific user.
  Stream<List<Map<String, dynamic>>> getUserListings() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('listings')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort manually in Dart to avoid needing a Firestore Composite Index
          docs.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending
          });

          return docs;
        });
  }

  /// Deletes a listing from Firestore.
  Future<void> deleteListing(String listingId) async {
    await _firestore.collection('listings').doc(listingId).delete();
  }

  /// Updates an existing listing.
  Future<void> updateListing(
    String listingId,
    Map<String, dynamic> updates,
  ) async {
    await _firestore.collection('listings').doc(listingId).update(updates);
  }
}
