import 'package:equatable/equatable.dart';

import 'firestore_parsing.dart';

/// Where a deal request has got to.
enum DealStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  completed('completed');

  const DealStatus(this.wire);

  /// The value persisted in Firestore.
  final String wire;

  static DealStatus fromWire(Object? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return DealStatus.pending;
  }
}

/// The deal attached to a deal-request message.
class DealRequest extends Equatable {
  const DealRequest({
    required this.itemId,
    required this.title,
    required this.price,
    required this.status,
    required this.buyerId,
    required this.sellerId,
  });

  final String itemId;
  final String title;
  final double price;
  final DealStatus status;
  final String buyerId;
  final String sellerId;

  factory DealRequest.fromMap(Map<String, dynamic> data) {
    return DealRequest(
      itemId: asString(data['itemId']),
      title: asString(data['title'], fallback: 'Item'),
      price: asDouble(data['price']),
      status: DealStatus.fromWire(data['status']),
      buyerId: asString(data['buyerId']),
      // Older documents wrote the seller under both keys.
      sellerId: asString(
        data['sellerId'],
        fallback: asString(data['listingOwnerId']),
      ),
    );
  }

  String get formattedPrice => '£${price.toStringAsFixed(2)}';

  bool isSeller(String uid) => uid == sellerId;
  bool isBuyer(String uid) => uid == buyerId;

  @override
  List<Object?> get props => [itemId, title, price, status, buyerId, sellerId];
}

/// A single chat message — either plain text or a deal request.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.sentAt,
    required this.deal,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String text;

  /// Null while the server timestamp is still pending.
  final DateTime? sentAt;

  /// Non-null when this message carries a deal request.
  final DealRequest? deal;

  factory Message.fromMap(String id, Map<String, dynamic> data) {
    final dealData = data['type'] == 'deal' ? asMap(data['dealData']) : null;
    return Message(
      id: id,
      senderId: asString(data['senderId']),
      receiverId: asString(data['receiverId']),
      text: asString(data['text']),
      sentAt: asDate(data['timestamp']),
      deal: dealData == null ? null : DealRequest.fromMap(dealData),
    );
  }

  bool get isDeal => deal != null;

  bool isFrom(String uid) => senderId == uid;

  @override
  List<Object?> get props => [id, senderId, receiverId, text, sentAt, deal];
}
