import 'package:cloud_firestore/cloud_firestore.dart';

class Challenge {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> clientCategory;
  final List<String> productIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.clientCategory,
    required this.productIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Challenge.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Challenge(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      status: data['status'] ?? 'active',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientCategory: List<String>.from(data['clientCategory'] ?? []),
      productIds: List<String>.from(data['productIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
