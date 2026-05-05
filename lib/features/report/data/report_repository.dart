import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ReportRepository: Handles submitting user and listing reports to Firestore.
class ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submits a report. [targetId] can be a userId or listingId.
  /// [targetType] is either 'user' or 'listing'.
  Future<void> submitReport({
    required String targetId,
    required String targetType,
    required String reason,
    String? additionalNote,
  }) async {
    final reporterId = _auth.currentUser?.uid;
    if (reporterId == null) throw Exception('Not authenticated');

    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'targetId': targetId,
      'targetType': targetType,  // 'user' | 'listing'
      'reason': reason,
      'additionalNote': additionalNote ?? '',
      'status': 'pending',       // pending | reviewed | dismissed
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Streams all pending reports for moderators.
  Stream<List<Map<String, dynamic>>> getPendingReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Resolves a report with an action taken.
  Future<void> resolveReport({
    required String reportId,
    required String status, // reviewed | dismissed
    String? actionTaken,
  }) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': status,
      'actionTaken': actionTaken ?? 'No action taken',
      'resolvedAt': FieldValue.serverTimestamp(),
      'moderatorId': _auth.currentUser?.uid,
    });
  }

  /// Action: Hide a listing.
  Future<void> hideListing(String listingId) async {
    await _firestore.collection('listings').doc(listingId).update({
      'status': 'hidden',
    });
  }

  /// Action: Suspend a user.
  Future<void> suspendUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isSuspended': true,
      'suspendedAt': FieldValue.serverTimestamp(),
    });
  }
}
