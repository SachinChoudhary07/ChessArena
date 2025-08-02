import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../Firebase/get_server_key.dart';
import 'dart:convert'; // Added for jsonEncode

/// Model representing a chess challenge
class Challenge {
  final String id;
  final String challengerUid;
  final String opponentUid;
  final String timeControl;
  final int amount;
  final String status; // 'pending', 'accepted', 'rejected', 'expired'
  final DateTime createdAt;
  final DateTime expiresAt;

  Challenge({
    required this.id,
    required this.challengerUid,
    required this.opponentUid,
    required this.timeControl,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Challenge.fromMap(Map<String, dynamic> map, String id) {
    DateTime createdAt;
    if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    // Calculate expiration time (2 minutes from creation)
    final expiresAt = createdAt.add(const Duration(minutes: 2));

    return Challenge(
      id: id,
      challengerUid: map['challenger'] ?? '',
      opponentUid: map['opponent'] ?? '',
      timeControl: map['timeControl'] ?? '',
      amount: map['amount'] ?? 0,
      status: map['status'] ?? 'pending',
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'challenger': challengerUid,
        'opponent': opponentUid,
        'timeControl': timeControl,
        'amount': amount,
        'status': status,
        'createdAt': createdAt,
      };

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

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
  final String id;
  final String opponentName;
  final String timeControl;
  final int amount;
  final DateTime date;
  final String result; // win / loss / pending
  final String status; // 'accepted', 'rejected', 'expired'
  final bool isChallenger;
  final String? gameRoomCode;

  ChallengeHistoryItem({
    required this.id,
    required this.opponentName,
    required this.timeControl,
    required this.amount,
    required this.date,
    required this.result,
    required this.status,
    required this.isChallenger,
    this.gameRoomCode,
  });
}

class ChallengeSendResult {
  final bool success;
  final String message;
  final String? roomCode;
  final String? challengeId;

  ChallengeSendResult({
    required this.success,
    required this.message,
    this.roomCode,
    this.challengeId,
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

  Future<ChallengeSendResult> sendChallenge() async {
    if (_selectedFriend == null) {
      return ChallengeSendResult(
        success: false,
        message: 'Please select a friend',
        roomCode: null,
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return ChallengeSendResult(
        success: false,
        message: 'User not authenticated',
        roomCode: null,
      );
    }

    _isSendingChallenge = true;
    notifyListeners();

    try {
      // Check if user has sufficient balance for the challenge amount
      if (_selectedAmount > 0) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final currentBalance = (userDoc.data()?['Balance'] ?? 0.0) as num;

        if (currentBalance < _selectedAmount) {
          debugPrint('❌ Insufficient balance: $currentBalance < $_selectedAmount');
          _isSendingChallenge = false;
          notifyListeners();
          return ChallengeSendResult(
            success: false,
            message: 'Insufficient balance to send challenge',
            roomCode: null,
          );
        }
      }

      // Generate room code for the challenge
      final roomCode = _generateRoomCode();

      // Create challenge document and get the ID
      final challengeRef = await FirebaseFirestore.instance.collection('challenges').add({
        'challenger': currentUser.uid,
        'opponent': _selectedFriend!.uid,
        'timeControl': _selectedTime,
        'amount': _selectedAmount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'roomCode': roomCode, // Add room code to challenge
      });

      // Send push notification to opponent with challenge ID
      await _sendChallengeNotification(currentUser.uid, _selectedFriend!.uid, challengeRef.id);

      _isSendingChallenge = false;
      notifyListeners();

      return ChallengeSendResult(
        success: true,
        message: 'Challenge sent successfully!',
        roomCode: roomCode,
        challengeId: challengeRef.id,
      );
    } catch (e) {
      debugPrint('Error sending challenge: $e');
      _isSendingChallenge = false;
      notifyListeners();
      return ChallengeSendResult(
        success: false,
        message: 'Error sending challenge',
        roomCode: null,
      );
    }
  }

  /// Generate room code for challenge
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (index) => chars[(timestamp + index * 13) % chars.length],
    ).join();
  }

  // ---------------------------------------------------------------------------
  // Challenge history (real data from Firestore)
  // ---------------------------------------------------------------------------
  List<ChallengeHistoryItem> _history = [];
  bool _isLoadingHistory = false;

  List<ChallengeHistoryItem> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;

  Future<void> fetchChallengeHistory() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      // Fetch challenges where current user is either challenger or opponent
      final challengesQuery = await FirebaseFirestore.instance.collection('challenges').where('status', whereIn: ['accepted', 'rejected', 'expired']).get();

      final List<ChallengeHistoryItem> loadedHistory = [];

      for (final doc in challengesQuery.docs) {
        final data = doc.data();
        final challengerUid = data['challenger'] as String;
        final opponentUid = data['opponent'] as String;
        final status = data['status'] as String;
        final timeControl = data['timeControl'] as String;
        final amount = data['amount'] as int;
        final createdAt = data['createdAt'] as Timestamp;
        final gameRoomCode = data['gameRoomCode'] as String?;

        // Only include challenges where current user participated
        if (challengerUid == currentUser.uid || opponentUid == currentUser.uid) {
          // Determine if current user is challenger or opponent
          final isChallenger = challengerUid == currentUser.uid;
          final otherUserUid = isChallenger ? opponentUid : challengerUid;

          // Fetch other user's name
          final otherUserDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserUid).get();
          final otherUserName = otherUserDoc.data()?['username'] ?? 'Unknown Player';

          // Determine result based on status and user role
          String result;
          if (status == 'accepted') {
            // Check if there's a game result
            if (gameRoomCode != null) {
              // Try to find game result in gamehistory
              final gameHistoryDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('gamehistory').doc(gameRoomCode).get();

              if (gameHistoryDoc.exists) {
                final gameResult = gameHistoryDoc.data()?['result'] as String?;
                if (gameResult == 'win') {
                  result = 'win';
                } else if (gameResult == 'loss') {
                  result = 'loss';
                } else {
                  result = 'accepted'; // Game accepted but no result yet
                }
              } else {
                result = 'accepted'; // Game accepted but no result yet
              }
            } else {
              result = 'accepted';
            }
          } else if (status == 'rejected') {
            result = 'rejected';
          } else if (status == 'expired') {
            result = 'expired';
          } else {
            result = 'pending';
          }

          loadedHistory.add(ChallengeHistoryItem(
            id: doc.id,
            opponentName: otherUserName,
            timeControl: timeControl,
            amount: amount,
            date: createdAt.toDate(),
            result: result,
            status: status,
            isChallenger: isChallenger,
            gameRoomCode: gameRoomCode,
          ));
        }
      }

      // Sort by date (newest first)
      loadedHistory.sort((a, b) => b.date.compareTo(a.date));

      _history = loadedHistory;
    } catch (e) {
      debugPrint('Error fetching challenge history: $e');
    }

    _isLoadingHistory = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Push notification via FCM HTTP v1 legacy API
  // ---------------------------------------------------------------------------

  static const String _projectId = 'chess4cash-37f67';
  static const String _fcmEndpoint = 'https://fcm.googleapis.com/v1/projects/chess4cash-37f67/messages:send';

  Future<void> _sendChallengeNotification(String challengerUid, String opponentUid, String challengeId) async {
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
          "data": {"type": "challenge", "challengerUid": challengerUid, "challengeId": challengeId}
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
