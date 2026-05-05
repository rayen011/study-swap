import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AuthRepository: Handles the data layer for authentication.
/// Now uses Firebase Auth and Firestore for persistence.
class AuthRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userEmailKey = 'user_email';

  /// Checks if the user is currently logged in (based on persistence).
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Gets the persisted user email.
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Simulates a login process and persists the session if stayLoggedIn is true.
  Future<void> login(
    String email,
    String password, {
    bool stayLoggedIn = true,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check for suspension
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      if (userDoc.data()?['isSuspended'] == true) {
        await _auth.signOut();
        throw Exception(
          'Your account has been suspended for violating campus guidelines.',
        );
      }

      if (stayLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_userEmailKey, email);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  /// Checks if the current user is a moderator.
  Future<bool> isModerator() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['role'] == 'moderator';
  }

  /// Simulates a signup process and persists the session if stayLoggedIn is true.
  Future<void> signup(
    String name,
    String email,
    String password, {
    bool stayLoggedIn = true,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create user document in Firestore
      await _firestore.collection('users').doc(uid).set({
        'fullName': name,
        'email': email,
        'university': 'none',
        'rating': 0.0,
        'ratingCount': 0,
        'dealCount': 0,
        'title': 'Freshman Trader',
        'role': 'user', // Default role
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (stayLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_userEmailKey, email);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Signup failed');
    } catch (e) {
      throw Exception('An unexpected error occurred during signup');
    }
  }

  /// Updates the user's profile information in Firestore.
  Future<void> updateUserProfile({String? fullName, String? university}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');

    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['fullName'] = fullName;
    if (university != null) updates['university'] = university;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  /// Gets the current user's data from Firestore.
  Future<Map<String, dynamic>?> getUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Sends a password reset email to the specified user.
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Password reset failed');
    } catch (e) {
      throw Exception('An unexpected error occurred during password reset');
    }
  }

  /// Logs the user out and clears the persistent session.
  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userEmailKey);
  }
}
