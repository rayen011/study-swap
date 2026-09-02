import 'package:equatable/equatable.dart';

import 'firestore_parsing.dart';

/// A conversation as it appears in the messages list.
///
/// The message bodies live in a subcollection; this is just the metadata the
/// chat list renders from.
class ChatSummary extends Equatable {
  const ChatSummary({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.unreadCounts,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageAt,
  });

  final String id;

  /// Exactly two user ids, sorted — the chat id is their join.
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, int> unreadCounts;

  final String lastMessage;
  final String lastSenderId;

  /// Null while the server timestamp is still pending.
  final DateTime? lastMessageAt;

  factory ChatSummary.fromMap(String id, Map<String, dynamic> data) {
    return ChatSummary(
      id: id,
      participants: asStringList(data['participants']),
      participantNames: asStringMap(data['participantNames']),
      unreadCounts: asIntMap(data['unreadCount']),
      lastMessage: asString(data['lastMessage']),
      lastSenderId: asString(data['lastSenderId']),
      lastMessageAt: asDate(data['lastTimestamp']),
    );
  }

  /// The id of the person on the other side of the conversation.
  ///
  /// Falls back to [currentUserId] for a malformed chat document, which keeps
  /// the list rendering rather than throwing.
  String otherParticipantId(String currentUserId) {
    for (final id in participants) {
      if (id != currentUserId) return id;
    }
    return currentUserId;
  }

  /// The display name of the person on the other side.
  String otherParticipantName(String currentUserId) {
    final otherId = otherParticipantId(currentUserId);
    final name = participantNames[otherId];
    return (name == null || name.isEmpty) ? 'Student' : name;
  }

  /// How many messages [userId] hasn't read in this conversation.
  int unreadFor(String userId) => unreadCounts[userId] ?? 0;

  bool get hasMessages => lastMessage.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    participants,
    participantNames,
    unreadCounts,
    lastMessage,
    lastSenderId,
    lastMessageAt,
  ];
}
