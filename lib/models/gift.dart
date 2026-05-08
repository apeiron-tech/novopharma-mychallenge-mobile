import 'package:cloud_firestore/cloud_firestore.dart';

class Gift {
  final String id;
  final List<String> clientCategory;
  final String description;
  final String imageUrl;
  final int initialStock;
  final List<String> listProducts;
  final List<String> productCategory;
  final List<String> productMarque;
  final String status;
  final int stock;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Gift({
    required this.id,
    required this.clientCategory,
    required this.description,
    required this.imageUrl,
    required this.initialStock,
    required this.listProducts,
    required this.productCategory,
    required this.productMarque,
    required this.status,
    required this.stock,
    required this.title,
    this.createdAt,
    this.updatedAt,
  });

  factory Gift.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Gift(
      id: doc.id,
      clientCategory: List<String>.from(data['clientCategory'] ?? []),
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      initialStock: data['initialStock'] ?? 0,
      listProducts: List<String>.from(data['listProducts'] ?? []),
      productCategory: List<String>.from(data['productCategory'] ?? []),
      productMarque: List<String>.from(data['productMarque'] ?? []),
      status: data['status'] ?? '',
      stock: data['stock'] ?? 0,
      title: data['title'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
