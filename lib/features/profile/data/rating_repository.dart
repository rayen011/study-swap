import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/review.dart';

/// RatingRepository: writes reviews and reads them back.
///
/// It no longer touches the reputation aggregate on the user document. The
/// client writes the review; `onReviewCreated` in functions/src/index.ts
/// recomputes `rating` and `ratingCount`, and `firestore.rules` denies those
/// fields to every client. Same for deal completion — the app flips the deal
/// message's status and `onDealCompleted` does the rest.
class RatingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  /// Submits a rating for a user.
  ///
  /// The document id is deterministic, and the rules allow create but never
  /// update — so a second review for the same deal fails rather than
  /// overwriting the first.
  Future<void> submitRating({
    required String toId,
    required double rating,
    String? comment,
    required String chatId,
  }) async {
    final fromId = _auth.currentUser?.uid;
    if (fromId == null) return;

    final ref = _reviews.doc(
      Review.idFor(chatId: chatId, fromId: fromId, toId: toId),
    );

    if ((await ref.get()).exists) {
      throw Exception('You have already rated this transaction.');
    }

    await ref.set({
      'fromId': fromId,
      'toId': toId,
      'rating': rating,
      'comment': comment ?? '',
      'chatId': chatId,
      'timestamp': FieldValue.serverTimestamp(),
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
}
