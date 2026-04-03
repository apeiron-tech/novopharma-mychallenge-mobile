import 'package:cloud_firestore/cloud_firestore.dart';

class PopupModel {
  final String id;
  final List<String> clientCategory;
  final DateTime createdAt;
  final String description;
  final int? displayDuration;
  final DateTime endDate;
  final String imageUrl;
  final String link;
  final DateTime startDate;
  final String status;
  final String title;
  final int order;
  final DateTime updatedAt;

  PopupModel({
    required this.id,
    required this.clientCategory,
    required this.createdAt,
    required this.description,
    this.displayDuration,
    required this.endDate,
    required this.imageUrl,
    required this.link,
    required this.startDate,
    required this.status,
    required this.title,
    this.order = 0,
    required this.updatedAt,
  });

  factory PopupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PopupModel(
      id: doc.id,
      clientCategory: List<String>.from(data['clientCategory'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      description: data['description'] ?? '',
      displayDuration: data['displayDuration'] as int?,
      endDate: (data['endDate'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] ?? '',
      link: data['link'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'inactive',
      title: data['title'] ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
