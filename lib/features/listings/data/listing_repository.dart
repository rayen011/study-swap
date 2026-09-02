import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/listing_options.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_filter.dart';

/// ListingRepository: Handles CRUD operations for Marketplace Listings in Firestore.
class ListingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection('listings');

  /// Reserves a document id without writing anything.
  ///
  /// Photos upload to a Storage path keyed by the listing id, so the id has to
  /// exist before the document does.
  String newListingId() => _listings.doc().id;

  /// Creates a new listing in Firestore.
  ///
  /// Pass [listingId] to write to an id from [newListingId]; omit it and one
  /// is generated here.
  Future<void> createListing(ListingDraft draft, {String? listingId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User must be logged in to create a listing');
    }

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final sellerName = userDoc.data()?['fullName'] as String? ?? 'Student';

    final ref = listingId == null ? _listings.doc() : _listings.doc(listingId);

    await ref.set({
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

  /// How many listings one page of the feed holds.
  static const int pageSize = 20;

  /// Streams the marketplace feed for [filter], capped at [limit] documents.
  ///
  /// Pagination works by growing the window rather than by cursor. A cursor
  /// would mean one subscription per page and merging their emissions by hand;
  /// re-subscribing with a larger limit keeps the feed a single live query, and
  /// Firestore serves the already-seen documents from cache. The cost is one
  /// re-read of the window each time the user loads more, which at a 20-item
  /// page is a fair trade for live updates.
  Stream<List<Listing>> watchFeed({
    required ListingFilter filter,
    int limit = pageSize,
  }) {
    // Only active listings reach the feed. Sold, reserved and moderator-hidden
    // ones are excluded by the server rather than downloaded and discarded.
    Query<Map<String, dynamic>> query = _listings.where(
      'status',
      isEqualTo: ListingStatus.active.wire,
    );

    if (filter.category != null) {
      query = query.where('category', isEqualTo: filter.category!.wire);
    }
    if (filter.condition != null) {
      query = query.where('condition', isEqualTo: filter.condition!.wire);
    }

    return query
        .orderBy(filter.sort.field, descending: filter.sort.descending)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Listing.fromMap(doc.id, doc.data()))
              .toList(),
        );
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

  /// Deletes a listing.
  ///
  /// The photos go too, but not from here — `onListingDeleted` clears the
  /// Storage folder. Server-side cleanup survives the app being killed
  /// mid-delete, and means the client doesn't have to track how many images a
  /// listing had just to remove them.
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
