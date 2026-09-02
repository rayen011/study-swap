import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/listing_options.dart';
import '../../../core/models/report.dart';

/// ReportRepository: Handles submitting user and listing reports to Firestore.
class ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  /// Submits a report. [targetId] can be a userId or listingId.
  Future<void> submitReport({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? additionalNote,
  }) async {
    final reporterId = _auth.currentUser?.uid;
    if (reporterId == null) throw Exception('Not authenticated');

    await _reports.add({
      'reporterId': reporterId,
      'targetId': targetId,
      'targetType': targetType.wire,
      'reason': reason,
      'additionalNote': additionalNote ?? '',
      'status': ReportStatus.pending.wire,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Streams all pending reports for moderators.
  ///
  /// Needs the composite index declared in `firestore.indexes.json`.
  Stream<List<Report>> getPendingReports() {
    return _reports
        .where('status', isEqualTo: ReportStatus.pending.wire)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Report.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Reads a single report.
  Future<Report?> getReport(String reportId) async {
    if (reportId.isEmpty) return null;
    final doc = await _reports.doc(reportId).get();
    return Report.fromDoc(doc);
  }

  /// Resolves a report with an action taken.
  Future<void> resolveReport({
    required String reportId,
    required ReportStatus status,
    String? actionTaken,
  }) {
    return _reports.doc(reportId).update({
      'status': status.wire,
      'actionTaken': actionTaken ?? 'No action taken',
      'resolvedAt': FieldValue.serverTimestamp(),
      'moderatorId': _auth.currentUser?.uid,
    });
  }

  /// Action: Hide a listing.
  Future<void> hideListing(String listingId) {
    return _firestore.collection('listings').doc(listingId).update({
      'status': ListingStatus.hidden.wire,
    });
  }

  /// Action: Suspend a user.
  Future<void> suspendUser(String userId) {
    return _firestore.collection('users').doc(userId).update({
      'isSuspended': true,
      'suspendedAt': FieldValue.serverTimestamp(),
    });
  }
}
