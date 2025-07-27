import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../Firebase/get_server_key.dart';
import 'dart:convert'; // Added for jsonEncode

/// Simple representation of a friend
class FriendInfo {
  final String uid;
  final String name;

  FriendInfo({required this.uid, required this.name});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendInfo && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}

/// Simple representation of a challenge (dummy for history)
class ChallengeHistoryItem {
  final String opponentName;
  final String timeControl;
  final int amount;
  final DateTime date;
  final String result; // win / loss / pending

  ChallengeHistoryItem({
    required this.opponentName,
    required this.timeControl,
    required this.amount,
    required this.date,
    required this.result,
  });
}

class PlayWithOnlineFriendProvider with ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Friend list state
  // ---------------------------------------------------------------------------
  List<FriendInfo> _friends = [];
  bool _isFetchingFriends = false;

  List<FriendInfo> get friends => _friends;
  bool get isFetchingFriends => _isFetchingFriends;

  // Currently selected values
  FriendInfo? _selectedFriend;
  String _selectedTime = '5 min';
  int _selectedAmount = 0;

  FriendInfo? get selectedFriend => _selectedFriend;
  String get selectedTime => _selectedTime;
  int get selectedAmount => _selectedAmount;

  void setSelectedFriend(FriendInfo? friend) {
    _selectedFriend = friend;
    notifyListeners();
  }

  void setSelectedTime(String time) {
    _selectedTime = time;
    notifyListeners();
  }

  void setSelectedAmount(int amount) {
    _selectedAmount = amount;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Challenge sending state
  // ---------------------------------------------------------------------------
  bool _isSendingChallenge = false;
  bool get isSendingChallenge => _isSendingChallenge;

  Future<void> fetchFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _isFetchingFriends = true;
    notifyListeners();

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('friends').get();

      // Fetch usernames for each friend UID
      final List<FriendInfo> loaded = [];
      for (final doc in snap.docs) {
        final uid = doc.id;
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final username = userDoc.data()?['username'] ?? 'Friend';
          loaded.add(FriendInfo(uid: uid, name: username));
        } catch (_) {
          loaded.add(FriendInfo(uid: uid, name: 'Friend'));
        }
      }

      _friends = loaded;
    } catch (e) {
      debugPrint('Error fetching friends: $e');
    }

    _isFetchingFriends = false;
    notifyListeners();
  }

  Future<void> sendChallenge() async {
    if (_selectedFriend == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _isSendingChallenge = true;
    notifyListeners();

    try {
      // For simplicity, write to a top-level collection "challenges"
      await FirebaseFirestore.instance.collection('challenges').add({
        'challenger': currentUser.uid,
        'opponent': _selectedFriend!.uid,
        'timeControl': _selectedTime,
        'amount': _selectedAmount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send push notification to opponent
      await _sendChallengeNotification(currentUser.uid, _selectedFriend!.uid);
    } catch (e) {
      debugPrint('Error sending challenge: $e');
    }

    _isSendingChallenge = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Challenge history (dummy for now)
  // ---------------------------------------------------------------------------
  final List<ChallengeHistoryItem> _history = [
    ChallengeHistoryItem(
      opponentName: 'Alice',
      timeControl: '5 min',
      amount: 10,
      date: DateTime.now().subtract(const Duration(days: 1)),
      result: 'win',
    ),
    ChallengeHistoryItem(
      opponentName: 'Bob',
      timeControl: '10 min',
      amount: 20,
      date: DateTime.now().subtract(const Duration(days: 3)),
      result: 'loss',
    ),
    ChallengeHistoryItem(
      opponentName: 'Charlie',
      timeControl: '3 min',
      amount: 0,
      date: DateTime.now().subtract(const Duration(days: 7)),
      result: 'pending',
    ),
  ];

  List<ChallengeHistoryItem> get history => _history;

  // ---------------------------------------------------------------------------
  // Push notification via FCM HTTP v1 legacy API
  // ---------------------------------------------------------------------------

  static const String _projectId = 'chess4cash-37f67';
  static const String _fcmEndpoint = 'https://fcm.googleapis.com/v1/projects/chess4cash-37f67/messages:send';

  Future<void> _sendChallengeNotification(String challengerUid, String opponentUid) async {
    try {
      // Obtain OAuth2 token via service account
      final accessToken = await generateFcmAccessToken();

      // Fetch challenger name
      final challengerDoc = await FirebaseFirestore.instance.collection('users').doc(challengerUid).get();
      final challengerName = challengerDoc.data()?['username'] ?? 'A player';

      // Fetch opponent FCM token
      final opponentDoc = await FirebaseFirestore.instance.collection('users').doc(opponentUid).get();
      final token = opponentDoc.data()?['fcmToken'];
      if (token == null) return;

      final payload = {
        "message": {
          "token": token,
          "notification": {"title": "New Chess Challenge!", "body": "$challengerName challenged you to a $_selectedTime game${_selectedAmount > 0 ? ' for ₹$_selectedAmount' : ''}."},
          "android": {
            "notification": {
              "icon": "ic_launcher", // ensure exists in drawable
              "color": "#e3ac3b",
              "tag": "challenge_$challengerUid" // collapse duplicates
            }
          },
          "data": {"type": "challenge", "challengerUid": challengerUid}
        }
      };

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      debugPrint('FCM response status: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error sending FCM notification: $e');
    }
  }
}
