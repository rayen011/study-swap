import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../constants/credit_rules.dart';
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
    required this.credits,
    required this.creditsLocked,
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

  /// Bidding power earned from completed trades. Written only by Cloud
  /// Functions — see `functions/src/credits.ts` and [CreditRules].
  final int credits;

  /// The part of [credits] staked on bids that are still standing.
  final int creditsLocked;

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
      credits: asInt(data['credits']),
      creditsLocked: asInt(data['creditsLocked']),
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
    credits: 0,
    creditsLocked: 0,
    isSuspended: false,
    createdAt: null,
  );

  /// Rating rounded for display, e.g. "4.6".
  String get formattedRating => rating.toStringAsFixed(1);

  bool get hasUniversity => university.isNotEmpty && university != 'none';

  /// Credits free to stake on a new bid.
  ///
  /// Clamped at zero: a balance behind its locked total would only ever be a
  /// bug, and the profile should show 0 rather than a negative.
  int get availableCredits =>
      credits - creditsLocked < 0 ? 0 : credits - creditsLocked;

  /// The largest bid this member could place right now.
  int get maxBid => CreditRules.maxBidFor(availableCredits);

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
    credits,
    creditsLocked,
    isSuspended,
    createdAt,
  ];
}
