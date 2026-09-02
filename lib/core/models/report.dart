import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'firestore_parsing.dart';

/// What a report is about.
enum ReportTargetType {
  user('user'),
  listing('listing')
  ;

  const ReportTargetType(this.wire);

  /// The value persisted in Firestore.
  final String wire;

  static ReportTargetType fromWire(Object? value) =>
      value == ReportTargetType.user.wire
      ? ReportTargetType.user
      : ReportTargetType.listing;

  bool get isUser => this == ReportTargetType.user;

  String get label => isUser ? 'User' : 'Listing';
}

/// Where a report is in the moderation queue.
enum ReportStatus {
  pending('pending'),
  reviewed('reviewed'),
  dismissed('dismissed')
  ;

  const ReportStatus(this.wire);

  /// The value persisted in Firestore.
  final String wire;

  static ReportStatus fromWire(Object? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return ReportStatus.pending;
  }
}

/// A user- or listing-report awaiting moderation.
class Report extends Equatable {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetId,
    required this.targetType,
    required this.reason,
    required this.additionalNote,
    required this.status,
    required this.createdAt,
    required this.actionTaken,
    required this.moderatorId,
    required this.resolvedAt,
  });

  final String id;
  final String reporterId;
  final String targetId;
  final ReportTargetType targetType;
  final String reason;
  final String additionalNote;
  final ReportStatus status;

  /// Null while the server timestamp is still pending.
  final DateTime? createdAt;

  /// Set once a moderator resolves the report.
  final String actionTaken;
  final String moderatorId;
  final DateTime? resolvedAt;

  factory Report.fromMap(String id, Map<String, dynamic> data) {
    return Report(
      id: id,
      reporterId: asString(data['reporterId']),
      targetId: asString(data['targetId']),
      targetType: ReportTargetType.fromWire(data['targetType']),
      reason: asString(data['reason'], fallback: 'No reason given'),
      additionalNote: asString(data['additionalNote']),
      status: ReportStatus.fromWire(data['status']),
      createdAt: asDate(data['createdAt']),
      actionTaken: asString(data['actionTaken']),
      moderatorId: asString(data['moderatorId']),
      resolvedAt: asDate(data['resolvedAt']),
    );
  }

  /// Builds a [Report] from a document, or null if the document is empty.
  static Report? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data == null ? null : Report.fromMap(doc.id, data);
  }

  bool get hasNote => additionalNote.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    reporterId,
    targetId,
    targetType,
    reason,
    additionalNote,
    status,
    createdAt,
    actionTaken,
    moderatorId,
    resolvedAt,
  ];
}
