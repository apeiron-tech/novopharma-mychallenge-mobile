import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getLeaderboard([
    String? currentUserId,
  ]) async {
    print('🏆 [LEADERBOARD] ===== Starting Leaderboard Fetch =====');

    String connectedUserCategory = 'Pharmacie';
    if (currentUserId != null) {
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      if (currentUserDoc.exists) {
        String currPharmacyId = currentUserDoc.data()?['pharmacyId'] ?? '';
        if (currPharmacyId.isNotEmpty) {
          final currPharmacyDoc = await _firestore
              .collection('pharmacies')
              .doc(currPharmacyId)
              .get();
          if (currPharmacyDoc.exists) {
            String cat = currPharmacyDoc.data()?['clientCategory'] ?? '';
            if (cat != 'Pharmacie' && cat != '') {
              connectedUserCategory = cat; // E.g., 'Para-Pharmacie'
            }
          }
        }
      }
    }

    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .orderBy('points', descending: true)
          .get();

      print(
        '🏆 [LEADERBOARD] ===== Users Snapshot: ${usersSnapshot.docs.length} =====',
      );
      final List<Map<String, dynamic>> leaderboard = [];
      int rank = 1;

      // Roles to exclude from the leaderboard
      final excludedRoles = ['preparateur_manager', 'mystery', 'admin'];

      // Batch check pharmacy IDs
      Set<String> thisBatchPharmacyIds = {};
      for (var userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final String role = data['role'] as String? ?? '';

        // Skip excluded roles
        if (excludedRoles.contains(role)) continue;

        final String pharmacyId = data['pharmacyId'] as String? ?? '';
        if (pharmacyId.isNotEmpty) {
          thisBatchPharmacyIds.add(pharmacyId);
        }
      }

      Map<String, String> pharmacyCategoryMap = {};
      if (thisBatchPharmacyIds.isNotEmpty) {
        final pharmIdsList = thisBatchPharmacyIds.toList();
        for (int j = 0; j < pharmIdsList.length; j += 10) {
          final pharmBatch = pharmIdsList.skip(j).take(10).toList();
          final pharmSnapshot = await _firestore
              .collection('pharmacies')
              .where(FieldPath.documentId, whereIn: pharmBatch)
              .get();
          for (var pDoc in pharmSnapshot.docs) {
            pharmacyCategoryMap[pDoc.id] =
                pDoc.data()['clientCategory'] as String? ?? '';
          }
        }
      }

      for (var userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final String role = data['role'] as String? ?? '';

        // Skip excluded roles
        if (excludedRoles.contains(role)) continue;

        final uId = userDoc.id;
        final points = data['points'] is num
            ? (data['points'] as num).toDouble()
            : 0.0;
        final String pharmacyId = data['pharmacyId'] as String? ?? '';

        String userCategory = 'Pharmacie';
        if (pharmacyId.isNotEmpty) {
          String cat = pharmacyCategoryMap[pharmacyId] ?? '';
          if (cat != 'Pharmacie' && cat != '') {
            userCategory = cat; // E.g., 'Para-Pharmacie'
          }
        }

        if (connectedUserCategory == userCategory) {
          leaderboard.add({
            'rank': rank,
            'userId': uId,
            'name': data['name'] ?? 'Unknown',
            'avatarUrl': data['avatarUrl'] ?? '',
            'points': points.toInt(),
          });
          rank++;
        }
      }

      return leaderboard;
    } catch (e) {
      print('❌ [LEADERBOARD] Error: $e');
      return [];
    }
  }

  // Define clearCache purely to prevent external compilation errors if called elsewhere
  static void clearCache([String? period]) {}
}
