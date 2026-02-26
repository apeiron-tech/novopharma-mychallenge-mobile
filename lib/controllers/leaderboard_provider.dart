import 'package:flutter/material.dart';
import 'package:novopharma/services/leaderboard_service.dart';

class LeaderboardProvider with ChangeNotifier {
  final LeaderboardService _leaderboardService = LeaderboardService();

  List<Map<String, dynamic>> _leaderboardData = [];
  List<Map<String, dynamic>> get leaderboardData => _leaderboardData;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  LeaderboardProvider();

  Future<void> fetchLeaderboard([String? currentUserId]) async {
    // Defer the state update to after the build phase
    Future.microtask(() {
      _isLoading = true;
      notifyListeners();
    });

    _leaderboardData = await _leaderboardService.getLeaderboard(currentUserId);

    _isLoading = false;
    notifyListeners();
  }
}
