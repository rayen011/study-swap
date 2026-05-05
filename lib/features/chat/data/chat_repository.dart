import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ChatRepository: Handles real-time messaging and chat management in Firestore.
class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Streams all chats where the current user is a participant.
  Stream<List<Map<String, dynamic>>> getChats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Streams messages for a specific chat.
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Sends a message and updates the last message in the chat metadata.
  Future<void> sendMessage(String chatId, String receiverId, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final timestamp = FieldValue.serverTimestamp();

    final batch = _firestore.batch();

    // 1. Add message to sub-collection
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    
    batch.set(messageRef, {
      'senderId': uid,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
    });

    // 2. Update chat metadata
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastTimestamp': timestamp,
      'lastSenderId': uid,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Sends a deal request (special message type).
  Future<void> sendDealRequest(String chatId, String receiverId, Map<String, dynamic> listing) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final timestamp = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final sellerId = listing['userId'];
    final buyerId = uid;

    batch.set(messageRef, {
      'senderId': uid,
      'receiverId': receiverId,
      'type': 'deal',
      'text': 'Deal Request for ${listing['title']}',
      'timestamp': timestamp,
      'dealData': {
        'itemId': listing['id'],
        'title': listing['title'],
        'price': listing['price'],
        'status': 'pending', // pending, accepted, declined, completed
        'buyerId': buyerId,
        'sellerId': sellerId,
        'listingOwnerId': sellerId,
        'createdAt': timestamp,
      },
    });

    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': '🤝 New Deal Request: ${listing['title']}',
      'lastTimestamp': timestamp,
      'lastSenderId': uid,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Updates the status of a deal message.
  Future<void> updateDealStatus(String chatId, String messageId, String newStatus) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'dealData.status': newStatus,
    });
  }

  /// Resets the unread count for the current user in a specific chat.
  Future<void> markAsRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$uid': 0,
    });
  }

  /// Streams the total unread message count for the current user.
  Stream<int> getTotalUnreadCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        final unreadCount = doc.data()['unreadCount'] as Map<String, dynamic>?;
        total += (unreadCount?[uid] as num? ?? 0).toInt();
      }
      return total;
    });
  }

  /// Creates a chat between two users if it doesn't exist.
  /// Returns the chatId.
  Future<String> getOrCreateChat(String otherUserId, String otherUserName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    // Generate a consistent ID regardless of who starts the chat
    final participants = [uid, otherUserId]..sort();
    final chatId = participants.join('_');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      // Get current user name for the other person to see
      final currentUserDoc = await _firestore.collection('users').doc(uid).get();
      final currentUserName = currentUserDoc.data()?['fullName'] ?? 'Student';

      await _firestore.collection('chats').doc(chatId).set({
        'participants': participants,
        'participantNames': {
          uid: currentUserName,
          otherUserId: otherUserName,
        },
        'unreadCount': {
          uid: 0,
          otherUserId: 0,
        },
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }
}
