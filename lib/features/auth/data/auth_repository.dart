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
  ///
  /// The answer comes from a custom auth claim, not from the `role` field on
  /// the user document — that field is written by the client at signup, so
  /// trusting it would let anyone grant themselves moderator powers. The claim
  /// is set from a trusted environment (`setCustomUserClaims`) and is what
  /// `firestore.rules` actually enforces against.
  Future<bool> isModerator() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final token = await user.getIdTokenResult();
      return token.claims?['role'] == 'moderator';
    } catch (_) {
      return false;
    }
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
        // Descriptive only — authorization comes from the auth claim read by
        // [isModerator]. The rules pin this field to 'user' for every client.
        'role': 'user',
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

  // Profile reads and writes live in UserRepository — this class owns the
  // session only.

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
