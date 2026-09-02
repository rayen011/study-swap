import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
