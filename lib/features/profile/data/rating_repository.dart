import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/listing_options.dart';
import '../../../core/models/message.dart';
import '../../../core/models/review.dart';

class RatingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  /// Submits a rating for a user and updates their average rating.
  ///
  /// The aggregate is still recomputed here rather than in a Cloud Function.
  /// `firestore.rules` bounds what this write may do — see the note in that
  /// file — but moving it server-side is the real fix.
  Future<void> submitRating({
    required String toId,
    required double rating,
    String? comment,
    required String chatId,
  }) async {
    final fromId = _auth.currentUser?.uid;
    if (fromId == null) return;

    await _firestore.runTransaction((transaction) async {
      // 1. Read user data first
      final userRef = _firestore.collection('users').doc(toId);
      final userDoc = await transaction.get(userRef);

      // 2. Perform writes
      final reviewRef = _reviews.doc(
        Review.idFor(chatId: chatId, fromId: fromId, toId: toId),
      );
      final reviewDoc = await transaction.get(reviewRef);

      if (reviewDoc.exists) {
        throw Exception('You have already rated this transaction.');
      }

      transaction.set(reviewRef, {
        'fromId': fromId,
        'toId': toId,
        'rating': rating,
        'comment': comment ?? '',
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (userDoc.exists) {
        final data = userDoc.data() ?? const <String, dynamic>{};
        final currentRating = (data['rating'] as num? ?? 0.0).toDouble();
        final currentCount = (data['ratingCount'] as num? ?? 0).toInt();

        final newCount = currentCount + 1;
        final newRating = ((currentRating * currentCount) + rating) / newCount;

        transaction.update(userRef, {
          'rating': newRating,
          'ratingCount': newCount,
        });
      }
    });
  }

  /// Whether the signed-in user has already reviewed their counterpart in
  /// this chat.
  Future<bool> hasRated({required String chatId, required String toId}) async {
    final fromId = _auth.currentUser?.uid;
    if (fromId == null) return false;

    final doc = await _reviews
        .doc(Review.idFor(chatId: chatId, fromId: fromId, toId: toId))
        .get();
    return doc.exists;
  }

  /// Every review written about [uid], newest first.
  Future<List<Review>> getReviewsFor(String uid) async {
    if (uid.isEmpty) return const [];

    final snap = await _reviews.where('toId', isEqualTo: uid).get();
    final reviews = snap.docs
        .map((doc) => Review.fromMap(doc.id, doc.data()))
        .toList();

    // Sorted in Dart so the query needs no composite index.
    reviews.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null) return bTime == null ? 0 : -1;
      if (bTime == null) return 1;
      return bTime.compareTo(aTime);
    });

    return reviews;
  }

  /// Completes a deal, increments deal counts, updates titles, and marks listing as sold.
  Future<void> completeDeal({
    required String chatId,
    required String messageId,
    required String itemId,
    required String buyerId,
    required String sellerId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. Perform all reads
      final sellerRef = _firestore.collection('users').doc(sellerId);
      final buyerRef = _firestore.collection('users').doc(buyerId);

      final sellerDoc = await transaction.get(sellerRef);
      final buyerDoc = await transaction.get(buyerRef);

      // 2. Perform all writes
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      transaction.update(messageRef, {
        'dealData.status': DealStatus.completed.wire,
      });

      transaction.update(_firestore.collection('listings').doc(itemId), {
        'status': ListingStatus.sold.wire,
      });

      for (final entry in {sellerRef: sellerDoc, buyerRef: buyerDoc}.entries) {
        final doc = entry.value;
        if (!doc.exists) continue;

        final current = (doc.data()?['dealCount'] as num? ?? 0).toInt();
        final updated = current + 1;
        transaction.update(entry.key, {
          'dealCount': updated,
          'title': getTitleForDeals(updated),
        });
      }
    });
  }

  /// Logic for User Titles based on deal count.
  ///
  /// Static so it can be unit-tested without constructing the repository (and
  /// therefore without an initialised Firebase app). The thresholds are
  /// mirrored in `firestore.rules` — change both together.
  static String getTitleForDeals(int deals) {
    if (deals >= 31) return 'Campus Pro';
    if (deals >= 16) return 'Deal Maker';
    if (deals >= 8) return 'Trade Regular';
    if (deals >= 3) return 'Campus Seller';
    return 'Freshman Trader';
  }
}
