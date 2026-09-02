import 'package:equatable/equatable.dart';

import 'firestore_parsing.dart';

/// A rating one member left another after a completed deal.
///
/// The document id is deterministic — `review_<chatId>_<fromId>_<toId>` — which
/// is what lets `firestore.rules` enforce one review per deal per direction.
class Review extends Equatable {
  const Review({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.rating,
    required this.comment,
    required this.chatId,
    required this.createdAt,
  });

  final String id;
  final String fromId;
  final String toId;

  /// 1 to 5.
  final double rating;
  final String comment;
  final String chatId;

  /// Null while the server timestamp is still pending.
  final DateTime? createdAt;

  factory Review.fromMap(String id, Map<String, dynamic> data) {
    return Review(
      id: id,
      fromId: asString(data['fromId']),
      toId: asString(data['toId']),
      rating: asDouble(data['rating']),
      comment: asString(data['comment']),
      chatId: asString(data['chatId']),
      createdAt: asDate(data['timestamp']),
    );
  }

  /// The id a review must be stored under. Mirrors `firestore.rules`.
  static String idFor({
    required String chatId,
    required String fromId,
    required String toId,
  }) => 'review_${chatId}_${fromId}_$toId';

  /// Filled stars to draw, 0 to 5.
  int get stars => rating.round().clamp(0, 5);

  bool get hasComment => comment.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    fromId,
    toId,
    rating,
    comment,
    chatId,
    createdAt,
  ];
}
