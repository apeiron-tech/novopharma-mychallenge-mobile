import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/gift.dart';
import 'package:novopharma/models/gift_assignment.dart';

class GiftService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<GiftAssignment>> getAssignmentsForPharmacy(String pharmacyId) async {
    try {
      final snapshot = await _db
          .collection('giftAssignments')
          .where('assigneeId', isEqualTo: pharmacyId)
          .get();
      
      return snapshot.docs
          .map((doc) => GiftAssignment.fromFirestore(doc))
          .where((assignment) => assignment.assignedStock > 0)
          .toList();
    } catch (e) {
      print('Error getting gift assignments: $e');
      return [];
    }
  }

  Future<Gift?> getGiftById(String id) async {
    try {
      final doc = await _db.collection('gifts').doc(id).get();
      if (doc.exists) {
        return Gift.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting gift: $e');
      return null;
    }
  }

  Future<void> saveGiftOperation({
    required String saleId,
    required String giftId,
    required String pharmacyId,
    required int quantity,
    String? clientNom,
    String? clientPrenom,
    String? clientPhone,
    required String userId,
    String? pointOfSale,
  }) async {
    final operationRef = _db.collection('giftOperations').doc();

    await _db.runTransaction((transaction) async {
      final assignmentsQuery = _db
          .collection('giftAssignments')
          .where('assigneeId', isEqualTo: pharmacyId)
          .where('giftId', isEqualTo: giftId);
      
      final assignmentsSnapshot = await assignmentsQuery.get();

      List<DocumentSnapshot> assignments = assignmentsSnapshot.docs;
      // Sort by createdAt ascending
      assignments.sort((a, b) {
        Timestamp t1 = a.get('createdAt') ?? Timestamp.now();
        Timestamp t2 = b.get('createdAt') ?? Timestamp.now();
        return t1.compareTo(t2);
      });

      int remainingToDeduct = quantity;
      int totalAvailable = 0;
      
      // We need to re-read each doc inside the transaction to be safe? 
      // Actually, if we use the snapshot docs, they might be stale if we don't use transaction.get.
      // But firestore transactions on collections are tricky.
      // Let's do it this way: fetch IDs first, then get each one via transaction.
      
      List<String> assignmentIds = assignments.map((d) => d.id).toList();
      List<DocumentSnapshot> freshAssignments = [];
      for (String id in assignmentIds) {
        final freshDoc = await transaction.get(_db.collection('giftAssignments').doc(id));
        freshAssignments.add(freshDoc);
        totalAvailable += (freshDoc.get('assignedStock') as int);
      }

      if (totalAvailable < quantity) {
        throw Exception("Not enough total stock!");
      }

      for (var doc in freshAssignments) {
        if (remainingToDeduct <= 0) break;
        int currentStock = doc.get('assignedStock') as int;
        if (currentStock <= 0) continue;

        int toDeduct = remainingToDeduct > currentStock ? currentStock : remainingToDeduct;
        transaction.update(doc.reference, {
          'assignedStock': currentStock - toDeduct,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        remainingToDeduct -= toDeduct;
      }

      transaction.set(operationRef, {
        'saleId': saleId,
        'giftId': giftId,
        'pharmacyId': pharmacyId,
        'quantity': quantity,
        'clientNom': clientNom,
        'clientPrenom': clientPrenom,
        'clientPhone': clientPhone,
        'userId': userId,
        'pointOfSale': pointOfSale,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Map<String, dynamic>?> getGiftOperationBySaleId(String saleId) async {
    try {
      final snapshot = await _db
          .collection('giftOperations')
          .where('saleId', isEqualTo: saleId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting gift operation: $e');
      return null;
    }
  }
}
