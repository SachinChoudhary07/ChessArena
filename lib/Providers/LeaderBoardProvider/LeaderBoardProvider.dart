import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderBoardProvider with ChangeNotifier {
  List<Map<String, dynamic>> _leaderboard = [];
  String _errorMessage = '';

  List<Map<String, dynamic>> get leaderboard => _leaderboard;

  String get errorMessage => _errorMessage;

  bool isLoading = false;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  Future<void> fetchLeaderboard() async {
    setLoading(true);
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      _leaderboard = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'profilePictureUrl': data['profileImage'] ?? '',
          'name': data['username'] ?? 'Unknown',
          'elo': data['eloRating'] ?? 0,
          'points': data['ranking'] ?? 0,
        };
      }).toList();
      _errorMessage = '';
      _leaderboard.sort((a, b) => (b['elo'] as int).compareTo(a['elo'] as int));
      setLoading(false);
    } catch (e) {
      _errorMessage = 'Error fetching leaderboard: $e';
      setLoading(false);
    }
    notifyListeners();
  }
}
