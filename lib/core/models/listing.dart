import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../constants/listing_options.dart';
import 'firestore_parsing.dart';

/// A marketplace listing.
class Listing extends Equatable {
  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.condition,
    required this.university,
    required this.userId,
    required this.sellerName,
    required this.imageUrls,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final double price;

  /// Null when the stored value doesn't match any known category.
  final ListingCategory? category;

  /// Null when the stored value doesn't match any known condition.
  final ListingCondition? condition;

  final String university;
  final String userId;
  final String sellerName;

  /// Download URLs in display order; the first is the cover image.
  final List<String> imageUrls;

  final ListingStatus status;

  /// Null while the server timestamp is still pending on a just-written doc.
  final DateTime? createdAt;

  factory Listing.fromMap(String id, Map<String, dynamic> data) {
    return Listing(
      id: id,
      title: asString(data['title'], fallback: 'Untitled listing'),
      description: asString(data['description']),
      price: asDouble(data['price']),
      category: ListingCategory.tryParse(data['category']),
      condition: ListingCondition.tryParse(data['condition']),
      university: asString(data['university']),
      userId: asString(data['userId']),
      sellerName: asString(data['sellerName'], fallback: 'Student'),
      imageUrls: _readImageUrls(data),
      status: ListingStatus.fromWire(data['status']),
      createdAt: asDate(data['createdAt']),
    );
  }

  /// Builds a [Listing] from a document, or null if the document is empty.
  static Listing? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data == null ? null : Listing.fromMap(doc.id, data);
  }

  /// Reads the image list, falling back to the single `imageUrl` field that
  /// listings written before multi-image support still carry.
  static List<String> _readImageUrls(Map<String, dynamic> data) {
    final urls = asStringList(
      data['imageUrls'],
    ).where((url) => url.isNotEmpty).toList();
    if (urls.isNotEmpty) return urls;

    final legacy = asString(data['imageUrl']);
    return legacy.isEmpty ? const [] : [legacy];
  }

  bool get hasImages => imageUrls.isNotEmpty;

  /// The image to show on a card, or null when the listing has no photos.
  String? get coverImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  /// The label to render for the category, never blank.
  String get categoryLabel => (category ?? ListingCategory.other).label;

  /// The label to render for the condition, blank when unknown.
  String get conditionLabel => condition?.label ?? '';

  /// Price formatted for display. Currency is hardcoded to GBP for now, in
  /// line with the rest of the app.
  String get formattedPrice => '£${price.toStringAsFixed(2)}';

  bool isOwnedBy(String? uid) => uid != null && uid == userId;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    price,
    category,
    condition,
    university,
    userId,
    sellerName,
    imageUrls,
    status,
    createdAt,
  ];
}

/// The fields a user supplies when posting a listing.
///
/// Separate from [Listing] because the server owns the rest: the document id,
/// the seller's name, the initial status and `createdAt`.
class ListingDraft {
  const ListingDraft({
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.condition,
    required this.university,
    this.imageUrls = const [],
  });

  final String title;
  final String description;
  final double price;
  final ListingCategory category;
  final ListingCondition condition;
  final String university;
  final List<String> imageUrls;

  /// The document body, minus the fields the repository fills in.
  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'price': price,
    'category': category.wire,
    'condition': condition.wire,
    'university': university,
    'imageUrls': imageUrls,
  };

  /// Returns a copy carrying the URLs produced by the image upload, which
  /// only exist after the files have been sent to Cloud Storage.
  ListingDraft withImageUrls(List<String> urls) => ListingDraft(
    title: title,
    description: description,
    price: price,
    category: category,
    condition: condition,
    university: university,
    imageUrls: urls,
  );
}
