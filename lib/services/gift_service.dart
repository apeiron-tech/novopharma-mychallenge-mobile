import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/gift.dart';
import 'package:novopharma/models/gift_assignment.dart';

class GiftService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<GiftAssignment>> getAssignmentsForPharmacy(
    String pharmacyId,
  ) async {
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

  Future<List<GiftAssignment>> getAssignmentsForDermoOrPharmacy({
    required String pharmacyId,
    required String dermoId,
  }) async {
    try {
      final pharmSnap = await _db
          .collection('giftAssignments')
          .where('assigneeId', isEqualTo: pharmacyId)
          .get();

      final dermoSnap = await _db
          .collection('giftAssignments')
          .where('assigneeId', isEqualTo: dermoId)
          .get();

      final List<GiftAssignment> list = [];
      list.addAll(pharmSnap.docs.map((doc) => GiftAssignment.fromFirestore(doc)));
      list.addAll(dermoSnap.docs.map((doc) => GiftAssignment.fromFirestore(doc)));

      return list.where((assignment) => assignment.assignedStock > 0).toList();
    } catch (e) {
      print('Error getting gift assignments for dermo/pharmacy: $e');
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
    List<String>? saleIds,
    required String giftId,
    required String pharmacyId,
    required int quantity,
    String? clientNom,
    String? clientPrenom,
    String? clientPhone,
    required String userId,
    String? pointOfSale,
    String? assignmentId,
    String? visitId,
  }) async {
    final operationRef = _db.collection('giftOperations').doc();

    await _db.runTransaction((transaction) async {
      List<DocumentSnapshot> freshAssignments = [];
      int totalAvailable = 0;

      if (assignmentId != null) {
        final freshDoc = await transaction.get(
          _db.collection('giftAssignments').doc(assignmentId),
        );
        if (freshDoc.exists) {
          freshAssignments.add(freshDoc);
          totalAvailable += (freshDoc.get('assignedStock') as int);
        }
      }

      if (freshAssignments.isEmpty) {
        var assignmentsSnapshot = await _db
            .collection('giftAssignments')
            .where('assigneeId', isEqualTo: pharmacyId)
            .where('giftId', isEqualTo: giftId)
            .get();

        if (assignmentsSnapshot.docs.isEmpty) {
          assignmentsSnapshot = await _db
              .collection('giftAssignments')
              .where('assigneeId', isEqualTo: userId)
              .where('giftId', isEqualTo: giftId)
              .get();
        }

        List<DocumentSnapshot> assignments = assignmentsSnapshot.docs;
        assignments.sort((a, b) {
          Timestamp t1 = a.get('createdAt') ?? Timestamp.now();
          Timestamp t2 = b.get('createdAt') ?? Timestamp.now();
          return t1.compareTo(t2);
        });

        List<String> assignmentIds = assignments.map((d) => d.id).toList();
        for (String id in assignmentIds) {
          final freshDoc = await transaction.get(
            _db.collection('giftAssignments').doc(id),
          );
          freshAssignments.add(freshDoc);
          totalAvailable += (freshDoc.get('assignedStock') as int);
        }
      }

      if (totalAvailable < quantity) {
        throw Exception("Not enough total stock!");
      }

      int remainingToDeduct = quantity;
      for (var doc in freshAssignments) {
        if (remainingToDeduct <= 0) break;
        int currentStock = doc.get('assignedStock') as int;
        if (currentStock <= 0) continue;

        int toDeduct = remainingToDeduct > currentStock
            ? currentStock
            : remainingToDeduct;
        transaction.update(doc.reference, {
          'assignedStock': currentStock - toDeduct,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        remainingToDeduct -= toDeduct;
      }

      transaction.set(operationRef, {
        'saleId': saleId,
        'saleIds': saleIds ?? [saleId],
        'giftId': giftId,
        'pharmacyId': pharmacyId,
        'quantity': quantity,
        'clientNom': clientNom,
        'clientPrenom': clientPrenom,
        'clientPhone': clientPhone,
        'userId': userId,
        'pointOfSale': pointOfSale,
        'createdAt': FieldValue.serverTimestamp(),
        if (visitId != null) 'visitId': visitId,
      });
    });
  }

  Future<Map<String, dynamic>?> getGiftOperationBySaleId(String saleId) async {
    try {
      var snapshot = await _db
          .collection('giftOperations')
          .where('saleIds', arrayContains: saleId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return data;
      }

      snapshot = await _db
          .collection('giftOperations')
          .where('saleId', isEqualTo: saleId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting gift operation: $e');
      return null;
    }
  }
}
