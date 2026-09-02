import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'firestore_parsing.dart';

/// A StudySwap member.
///
/// Note what is *not* here: a moderator flag. The `role` field on the document
/// is client-written and therefore not an authorization signal — moderator
/// status comes from the auth token's custom claim, via
/// `AuthRepository.isModerator()`.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.university,
    required this.rating,
    required this.ratingCount,
    required this.dealCount,
    required this.title,
    required this.isSuspended,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String university;

  /// Mean rating out of 5. Zero when nobody has rated them yet.
  final double rating;
  final int ratingCount;
  final int dealCount;

  /// Reputation title derived from [dealCount] — see
  /// `RatingRepository.getTitleForDeals`.
  final String title;

  final bool isSuspended;
  final DateTime? createdAt;

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      fullName: asString(data['fullName'], fallback: 'Student'),
      email: asString(data['email']),
      university: asString(data['university'], fallback: 'none'),
      rating: asDouble(data['rating']),
      ratingCount: asInt(data['ratingCount']),
      dealCount: asInt(data['dealCount']),
      title: asString(data['title'], fallback: 'Freshman Trader'),
      isSuspended: asBool(data['isSuspended']),
      createdAt: asDate(data['createdAt']),
    );
  }

  /// Builds an [AppUser] from a document, or null if the document is empty.
  static AppUser? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data == null ? null : AppUser.fromMap(doc.id, data);
  }

  /// A placeholder for a profile that hasn't loaded yet.
  static const AppUser empty = AppUser(
    id: '',
    fullName: 'Student',
    email: '',
    university: 'none',
    rating: 0,
    ratingCount: 0,
    dealCount: 0,
    title: 'Freshman Trader',
    isSuspended: false,
    createdAt: null,
  );

  /// Rating rounded for display, e.g. "4.6".
  String get formattedRating => rating.toStringAsFixed(1);

  bool get hasUniversity => university.isNotEmpty && university != 'none';

  @override
  List<Object?> get props => [
    id,
    fullName,
    email,
    university,
    rating,
    ratingCount,
    dealCount,
    title,
    isSuspended,
    createdAt,
  ];
}
