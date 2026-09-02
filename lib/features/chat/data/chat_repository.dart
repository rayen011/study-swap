import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/chat_summary.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/message.dart';

/// ChatRepository: Handles real-time messaging and chat management in Firestore.
class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> _messagesOf(String chatId) =>
      _chats.doc(chatId).collection('messages');

  /// Streams all chats where the current user is a participant.
  Stream<List<ChatSummary>> getChats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ChatSummary.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// How many messages of a conversation to keep live.
  ///
  /// Chats are read newest-first, so this is the recent tail. A long-running
  /// conversation would otherwise stream its entire history on every open.
  static const int messageWindow = 100;

  /// Streams the most recent messages for a specific chat, newest first.
  Stream<List<Message>> getMessages(String chatId) {
    return _messagesOf(chatId)
        .orderBy('timestamp', descending: true)
        .limit(messageWindow)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Message.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Sends a message and updates the last message in the chat metadata.
  Future<void> sendMessage(
    String chatId,
    String receiverId,
    String text,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final timestamp = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    batch.set(_messagesOf(chatId).doc(), {
      'senderId': uid,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
    });

    batch.update(_chats.doc(chatId), {
      'lastMessage': text,
      'lastTimestamp': timestamp,
      'lastSenderId': uid,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Sends a deal request (special message type).
  Future<void> sendDealRequest(
    String chatId,
    String receiverId,
    Listing listing,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final timestamp = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    batch.set(_messagesOf(chatId).doc(), {
      'senderId': uid,
      'receiverId': receiverId,
      'type': 'deal',
      'text': 'Deal Request for ${listing.title}',
      'timestamp': timestamp,
      'dealData': {
        'itemId': listing.id,
        'title': listing.title,
        'price': listing.price,
        'status': DealStatus.pending.wire,
        'buyerId': uid,
        'sellerId': listing.userId,
        'createdAt': timestamp,
      },
    });

    batch.update(_chats.doc(chatId), {
      'lastMessage': '🤝 New Deal Request: ${listing.title}',
      'lastTimestamp': timestamp,
      'lastSenderId': uid,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Whether this user already has an open deal on [listingId] in this chat.
  ///
  /// Guards against firing off a second request every time the buy button is
  /// tapped.
  Future<bool> hasOpenDeal(String chatId, String listingId) async {
    final open = await _messagesOf(chatId)
        .where('type', isEqualTo: 'deal')
        .where('dealData.itemId', isEqualTo: listingId)
        .get();

    return open.docs.any((doc) {
      final status = DealStatus.fromWire(
        (doc.data()['dealData'] as Map?)?['status'],
      );
      return status == DealStatus.pending || status == DealStatus.accepted;
    });
  }

  /// Updates the status of a deal message.
  Future<void> updateDealStatus(
    String chatId,
    String messageId,
    DealStatus newStatus,
  ) {
    return _messagesOf(
      chatId,
    ).doc(messageId).update({'dealData.status': newStatus.wire});
  }

  /// Resets the unread count for the current user in a specific chat.
  ///
  /// Callers decide when this is worth doing — see `_markRead` in
  /// ChatDetailsScreen, which only calls it for a genuinely new inbound
  /// message rather than on every snapshot.
  Future<void> markAsRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _chats.doc(chatId).update({'unreadCount.$uid': 0});
  }

  /// Streams the total unread message count for the current user.
  Stream<int> getTotalUnreadCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _chats.where('participants', arrayContains: uid).snapshots().map((
      snap,
    ) {
      var total = 0;
      for (final doc in snap.docs) {
        total += ChatSummary.fromMap(doc.id, doc.data()).unreadFor(uid);
      }
      return total;
    });
  }

  /// Creates a chat between two users if it doesn't exist.
  /// Returns the chatId.
  Future<String> getOrCreateChat(
    String otherUserId,
    String otherUserName,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    // A consistent id regardless of who starts the chat. `firestore.rules`
    // requires the document id to be exactly this join.
    final participants = [uid, otherUserId]..sort();
    final chatId = participants.join('_');

    final chatDoc = await _chats.doc(chatId).get();
    if (chatDoc.exists) return chatId;

    final currentUserDoc = await _firestore.collection('users').doc(uid).get();
    final currentUserName =
        currentUserDoc.data()?['fullName'] as String? ?? 'Student';

    await _chats.doc(chatId).set({
      'participants': participants,
      'participantNames': {uid: currentUserName, otherUserId: otherUserName},
      'unreadCount': {uid: 0, otherUserId: 0},
      'lastMessage': '',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return chatId;
  }
}
