import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'challenges';

  Stream<List<Challenge>> getActiveChallenges(String clientCategory) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .where('clientCategory', arrayContains: clientCategory)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => Challenge.fromFirestore(doc))
          .where((challenge) => challenge.endDate.isAfter(now))
          .toList();
    });
  }

  Future<Challenge?> getChallengeById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Challenge.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching challenge by id: $e');
      return null;
    }
  }
}
