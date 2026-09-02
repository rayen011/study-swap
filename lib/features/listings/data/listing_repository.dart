import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/listing_options.dart';
import '../../../core/models/listing.dart';

/// ListingRepository: Handles CRUD operations for Marketplace Listings in Firestore.
class ListingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection('listings');

  /// Creates a new listing in Firestore.
  Future<void> createListing(ListingDraft draft) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User must be logged in to create a listing');
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final sellerName = userDoc.data()?['fullName'] as String? ?? 'Student';

    await _listings.add({
      ...draft.toMap(),
      'userId': uid,
      'sellerName': sellerName,
      'status': ListingStatus.active.wire,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the status of a listing.
  Future<void> updateListingStatus(String listingId, ListingStatus status) {
    return _listings.doc(listingId).update({'status': status.wire});
  }

  /// Streams all listings from Firestore, newest first.
  Stream<List<Listing>> getListings() {
    return _listings.snapshots().map(_toSortedListings);
  }

  /// Streams listings for the signed-in user, newest first.
  Stream<List<Listing>> getUserListings() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return _listings
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(_toSortedListings);
  }

  /// Streams a single listing, so a details screen sees status changes live.
  ///
  /// Emits null if the listing is deleted while being viewed.
  Stream<Listing?> watchListing(String listingId) {
    if (listingId.isEmpty) return Stream.value(null);
    return _listings.doc(listingId).snapshots().map(Listing.fromDoc);
  }

  /// Reads a single listing once.
  Future<Listing?> getListing(String listingId) async {
    if (listingId.isEmpty) return null;
    final doc = await _listings.doc(listingId).get();
    return Listing.fromDoc(doc);
  }

  /// Deletes a listing from Firestore.
  Future<void> deleteListing(String listingId) {
    return _listings.doc(listingId).delete();
  }

  /// Updates an existing listing.
  Future<void> updateListing(String listingId, Map<String, dynamic> updates) {
    return _listings.doc(listingId).update(updates);
  }

  /// Sorted in Dart rather than by Firestore, which would need a composite
  /// index per query shape. Revisit when the feed moves to server-side
  /// filtering and pagination.
  List<Listing> _toSortedListings(QuerySnapshot<Map<String, dynamic>> snap) {
    final listings = snap.docs
        .map((doc) => Listing.fromMap(doc.id, doc.data()))
        .toList();

    listings.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      // A pending server timestamp sorts to the top: it was just written.
      if (aTime == null) return bTime == null ? 0 : -1;
      if (bTime == null) return 1;
      return bTime.compareTo(aTime);
    });

    return listings;
  }
}
