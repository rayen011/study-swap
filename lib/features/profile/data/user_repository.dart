import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/credit_rules.dart';
import '../../../core/models/app_user.dart';

/// UserRepository: reads and writes member profiles.
///
/// Split out from `AuthRepository`, which now only owns the session. Screens
/// that need somebody else's profile — a seller card, a chat header, a report
/// target — go through here instead of reaching for Firestore themselves.
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Reads any member's profile. Returns null if the document is missing.
  Future<AppUser?> getUser(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _users.doc(uid).get();
    return AppUser.fromDoc(doc);
  }

  /// Reads the signed-in user's profile.
  Future<AppUser?> getCurrentUser() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future.value(null);
    return getUser(uid);
  }

  /// Returns the signed-in user's profile, creating it if it has gone missing.
  ///
  /// Signup writes the Auth account and the profile document separately, so a
  /// crash or a dropped connection between them leaves an account that can
  /// sign in but has no profile — and every screen that reads it dead-ends
  /// with no way out through the UI. Deleting the collection by hand produces
  /// the same state.
  ///
  /// The shape here has to match what `firestore.rules` accepts on create:
  /// reputation starts at zero, credits at the fixed opening balance, and the
  /// role is always `user`.
  Future<AppUser?> ensureProfile() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;

    final existing = await getUser(authUser.uid);
    if (existing != null) return existing;

    final rebuilt = {
      'fullName': authUser.displayName?.trim().isNotEmpty == true
          ? authUser.displayName!.trim()
          : _nameFromEmail(authUser.email),
      'email': authUser.email ?? '',
      'university': 'none',
      'rating': 0.0,
      'ratingCount': 0,
      'dealCount': 0,
      'title': 'Freshman Trader',
      'credits': CreditRules.startingBalance,
      'creditsLocked': 0,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _users.doc(authUser.uid).set(rebuilt);
    return getUser(authUser.uid);
  }

  /// A readable fallback name when Auth has no display name — better than
  /// showing the raw email or a blank profile.
  static String _nameFromEmail(String? email) {
    final local = (email ?? '').split('@').first.trim();
    if (local.isEmpty) return 'Student';
    return local[0].toUpperCase() + local.substring(1);
  }

  /// Streams a member's profile, for screens that should reflect live changes.
  Stream<AppUser?> watchUser(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _users.doc(uid).snapshots().map(AppUser.fromDoc);
  }

  /// Updates the signed-in user's editable profile fields.
  ///
  /// Only `fullName` and `university` are writable — everything else on the
  /// document is either derived or privileged, and `firestore.rules` rejects
  /// any other field from a client.
  Future<void> updateProfile({String? fullName, String? university}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');

    final updates = <String, dynamic>{};
    if (fullName != null) updates['fullName'] = fullName.trim();
    if (university != null) updates['university'] = university.trim();
    if (updates.isEmpty) return;

    await _users.doc(uid).update(updates);
  }
}
