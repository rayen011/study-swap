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
      // 1. Add the review to 'reviews' collection
      final reviewRef = _firestore.collection('reviews').doc();
      transaction.set(reviewRef, {
        'fromId': fromId,
        'toId': toId,
        'rating': rating,
        'comment': comment ?? '',
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update the target user's rating stats
      final userRef = _firestore.collection('users').doc(toId);
      final userDoc = await transaction.get(userRef);
      
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
      // 1. Update deal status in chat message
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);
      
      transaction.update(messageRef, {
        'dealData.status': 'completed',
      });

      // 2. Update listing status to 'sold'
      final listingRef = _firestore.collection('listings').doc(itemId);
      transaction.update(listingRef, {
        'status': 'sold',
      });

      // 3. Update Seller stats
      await _updateUserDealStats(transaction, sellerId);
      
      // 4. Update Buyer stats
      await _updateUserDealStats(transaction, buyerId);
    });
  }

  Future<void> _updateUserDealStats(Transaction transaction, String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await transaction.get(userRef);
    
    if (userDoc.exists) {
      final currentDeals = (userDoc.data()?['dealCount'] as num? ?? 0).toInt();
      final newDeals = currentDeals + 1;
      
      transaction.update(userRef, {
        'dealCount': newDeals,
        'title': getTitleForDeals(newDeals),
      });
    }
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
