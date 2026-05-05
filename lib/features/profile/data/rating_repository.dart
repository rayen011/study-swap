import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submits a rating for a user and updates their average rating.
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
      final reviewId = 'review_${chatId}_${fromId}_$toId';
      final reviewRef = _firestore.collection('reviews').doc(reviewId);
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
        final currentRating = (userDoc.data()?['rating'] as num? ?? 0.0).toDouble();
        final currentCount = (userDoc.data()?['ratingCount'] as num? ?? 0).toInt();
        
        final newCount = currentCount + 1;
        final newRating = ((currentRating * currentCount) + rating) / newCount;
        
        transaction.update(userRef, {
          'rating': newRating,
          'ratingCount': newCount,
        });
      }
    });
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
        'dealData.status': 'completed',
      });

      final listingRef = _firestore.collection('listings').doc(itemId);
      transaction.update(listingRef, {
        'status': 'sold',
      });

      if (sellerDoc.exists) {
        final currentDeals = (sellerDoc.data()?['dealCount'] as num? ?? 0).toInt();
        final newDeals = currentDeals + 1;
        transaction.update(sellerRef, {
          'dealCount': newDeals,
          'title': getTitleForDeals(newDeals),
        });
      }

      if (buyerDoc.exists) {
        final currentDeals = (buyerDoc.data()?['dealCount'] as num? ?? 0).toInt();
        final newDeals = currentDeals + 1;
        transaction.update(buyerRef, {
          'dealCount': newDeals,
          'title': getTitleForDeals(newDeals),
        });
      }
    });
  }

  /// Logic for User Titles based on deal count.
  String getTitleForDeals(int deals) {
    if (deals >= 31) return 'Campus Pro';
    if (deals >= 16) return 'Deal Maker';
    if (deals >= 8) return 'Trade Regular';
    if (deals >= 3) return 'Campus Seller';
    return 'Freshman Trader';
  }
}
