import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/credit_rules.dart';

/// AuthRepository: owns the session.
///
/// Firebase Auth is the single source of truth for whether somebody is signed
/// in — [authStateChanges] is what the app listens to. SharedPreferences holds
/// exactly one thing: whether the last sign-in asked to stay logged in.
class AuthRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _stayLoggedInKey = 'stay_logged_in';

  /// Emits on sign-in and sign-out, and once on startup when Firebase has
  /// finished restoring any persisted session.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Called once before the app starts listening to [authStateChanges].
  ///
  /// Firebase persists a session on this device whether or not the user asked
  /// it to, so honouring "stay logged in" means dropping the restored session
  /// on the next launch when they opted out.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final stayLoggedIn = prefs.getBool(_stayLoggedInKey) ?? true;

    if (!stayLoggedIn && _auth.currentUser != null) {
      await _auth.signOut();
    }
  }

  Future<void> _rememberChoice(bool stayLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stayLoggedInKey, stayLoggedIn);
  }

  /// Signs in with email and password.
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

      // Belt and braces: `firestore.rules` blocks a suspended account's
      // writes, but signing them straight back out is the honest UX.
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

      await _rememberChoice(stayLoggedIn);
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

  /// Registers a new account and creates its user document.
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

      // Create user document in Firestore. The shape here is pinned by
      // `firestore.rules` — reputation fields must start at zero.
      await _firestore.collection('users').doc(uid).set({
        'fullName': name,
        'email': email,
        'university': 'none',
        'rating': 0.0,
        'ratingCount': 0,
        'dealCount': 0,
        'title': 'Freshman Trader',
        // Pinned to this exact value by `firestore.rules`; every later change
        // comes from a Cloud Function.
        'credits': CreditRules.startingBalance,
        'creditsLocked': 0,
        // Descriptive only — authorization comes from the auth claim read by
        // [isModerator]. The rules pin this field to 'user' for every client.
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _rememberChoice(stayLoggedIn);
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

  /// Logs the user out.
  Future<void> logout() async {
    await _auth.signOut();
    // Next launch should default to staying signed in again.
    await _rememberChoice(true);
  }
}
