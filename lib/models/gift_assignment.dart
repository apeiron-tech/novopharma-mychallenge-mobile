import 'package:cloud_firestore/cloud_firestore.dart';

class GiftAssignment {
  final String id;
  final int assignedStock;
  final String assigneeId;
  final String assigneeNameSnapshot;
  final String assigneeType;
  final String description;
  final String giftId;
  final String giftTitleSnapshot;
  final int initialStock;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GiftAssignment({
    required this.id,
    required this.assignedStock,
    required this.assigneeId,
    required this.assigneeNameSnapshot,
    required this.assigneeType,
    required this.description,
    required this.giftId,
    required this.giftTitleSnapshot,
    required this.initialStock,
    this.createdAt,
    this.updatedAt,
  });

  factory GiftAssignment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GiftAssignment(
      id: doc.id,
      assignedStock: data['assignedStock'] ?? 0,
      assigneeId: data['assigneeId'] ?? '',
      assigneeNameSnapshot: data['assigneeNameSnapshot'] ?? '',
      assigneeType: data['assigneeType'] ?? '',
      description: data['description'] ?? '',
      giftId: data['giftId'] ?? '',
      giftTitleSnapshot: data['giftTitleSnapshot'] ?? '',
      initialStock: data['initialStock'] ?? 0,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
