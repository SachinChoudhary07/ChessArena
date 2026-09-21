import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Screens/PlayWithOnlineFriends/play_with_online_friend_provider.dart';

class ChallengeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Validates if a challenge is still valid (not expired and not already processed)
  static Future<ChallengeValidationResult> validateChallenge(String challengeId) async {
    try {
      debugPrint('Validating challenge: $challengeId');
      final challengeDoc = await _firestore.collection('challenges').doc(challengeId).get();

      if (!challengeDoc.exists) {
        debugPrint('Challenge not found: $challengeId');
        return ChallengeValidationResult(
          isValid: false,
          message: 'Challenge not found',
          challenge: null,
        );
      }

      final challenge = Challenge.fromMap(challengeDoc.data()!, challengeId);
      debugPrint('Challenge created at: ${challenge.createdAt}, expires at: ${challenge.expiresAt}, isExpired: ${challenge.isExpired}');

      // Check if challenge is expired
      if (challenge.isExpired) {
        debugPrint('Challenge is expired: $challengeId');
        // Update status to expired if not already
        if (challenge.status == 'pending') {
          await _firestore.collection('challenges').doc(challengeId).update({
            'status': 'expired',
            'expiredAt': FieldValue.serverTimestamp(),
          });
          debugPrint('Updated challenge status to expired: $challengeId');
        }

        return ChallengeValidationResult(
          isValid: false,
          message: 'Challenge has expired',
          challenge: challenge,
        );
      }

      // Check if challenge is already processed
      if (challenge.status != 'pending') {
        debugPrint('Challenge already processed: $challengeId, status: ${challenge.status}');
        return ChallengeValidationResult(
          isValid: false,
          message: 'Challenge has already been ${challenge.status}',
          challenge: challenge,
        );
      }

      debugPrint('Challenge is valid: $challengeId');
      return ChallengeValidationResult(
        isValid: true,
        message: 'Challenge is valid',
        challenge: challenge,
      );
    } catch (e) {
      debugPrint('Error validating challenge: $e');
      return ChallengeValidationResult(
        isValid: false,
        message: 'Error validating challenge',
        challenge: null,
      );
    }
  }

  /// Check if user has sufficient balance
  static Future<bool> _hasEnoughBalance(String userId, double amount) async {
    try {
      debugPrint('💰 ChallengeService: Checking balance for user $userId, amount: $amount');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentBalance = (userDoc.data()?['Balance'] ?? 0.0) as num;
      final hasEnough = currentBalance >= amount;
      debugPrint('💰 ChallengeService: User balance: $currentBalance, Required: $amount, Has enough: $hasEnough');
      return hasEnough;
    } catch (e) {
      debugPrint('❌ ChallengeService: Error checking balance: $e');
      return false;
    }
  }

  /// Generate room code for game
  static String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (index) => chars[(timestamp + index * 13) % chars.length],
    ).join();
  }

  /// Convert time control string to seconds
  static int _parseTimeToSeconds(String timeString) {
    final parts = timeString.trim().split(' ');
    if (parts.length != 2) return 300; // default 5 minutes

    final value = int.tryParse(parts[0]);
    if (value == null) return 300;

    if (parts[1].toLowerCase().contains('min')) {
      return value * 60;
    }
    return 300;
  }

  /// Accepts a challenge and creates a game
  static Future<ChallengeAcceptResult> acceptChallenge(String challengeId) async {
    try {
      final validation = await validateChallenge(challengeId);
      if (!validation.isValid) {
        return ChallengeAcceptResult(
          success: false,
          message: validation.message,
          roomCode: null,
        );
      }

      final challenge = validation.challenge!;
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return ChallengeAcceptResult(
          success: false,
          message: 'User not authenticated',
          roomCode: null,
        );
      }

      // Check if current user is the opponent
      if (currentUser.uid != challenge.opponentUid) {
        return ChallengeAcceptResult(
          success: false,
          message: 'You can only accept challenges sent to you',
          roomCode: null,
        );
      }

      // Check balance for both users
      final challengerHasBalance = await _hasEnoughBalance(challenge.challengerUid, challenge.amount.toDouble());
      final opponentHasBalance = await _hasEnoughBalance(challenge.opponentUid, challenge.amount.toDouble());

      if (!challengerHasBalance || !opponentHasBalance) {
        return ChallengeAcceptResult(
          success: false,
          message: 'Insufficient balance for one or both players',
          roomCode: null,
        );
      }

      // Deduct amount from both players
      await _firestore.collection('users').doc(challenge.challengerUid).update({
        'Balance': FieldValue.increment(-challenge.amount),
      });
      await _firestore.collection('users').doc(challenge.opponentUid).update({
        'Balance': FieldValue.increment(-challenge.amount),
      });

      debugPrint('💰 ChallengeService: Deducted ${challenge.amount} from both players');

      // Generate room code and create game
      final roomCode = _generateRoomCode();
      final gameData = {
        'roomCode': roomCode,
        'hostId': challenge.challengerUid,
        'player1': challenge.challengerUid,
        'player2': challenge.opponentUid,
        'status': 'ready',
        'createdAt': FieldValue.serverTimestamp(),
        'gameName': 'Challenge Game',
        'time': challenge.timeControl,
        'entryFee': challenge.amount.toDouble(),
        'challengeId': challengeId,
      };

      await _firestore.collection('games').doc(roomCode).set(gameData);
      debugPrint('🎮 ChallengeService: Created game with room code: $roomCode');

      // Update challenge status
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'gameRoomCode': roomCode,
      });

      // Send notification to challenger about acceptance
      await _sendAcceptanceNotification(challenge.challengerUid, challenge.opponentUid, roomCode);

      return ChallengeAcceptResult(
        success: true,
        message: 'Challenge accepted! Game created.',
        roomCode: roomCode,
      );
    } catch (e) {
      debugPrint('Error accepting challenge: $e');
      return ChallengeAcceptResult(
        success: false,
        message: 'Error accepting challenge',
        roomCode: null,
      );
    }
  }

  /// Rejects a challenge
  static Future<bool> rejectChallenge(String challengeId) async {
    try {
      final validation = await validateChallenge(challengeId);
      if (!validation.isValid) {
        return false;
      }

      final challenge = validation.challenge!;
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check if current user is the opponent
      if (currentUser.uid != challenge.opponentUid) {
        return false;
      }

      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to challenger about rejection
      await _sendRejectionNotification(challenge.challengerUid, challenge.opponentUid);

      return true;
    } catch (e) {
      debugPrint('Error rejecting challenge: $e');
      return false;
    }
  }

  /// Send notification to challenger about acceptance
  static Future<void> _sendAcceptanceNotification(String challengerUid, String opponentUid, String roomCode) async {
    try {
      // Get opponent name
      final opponentDoc = await _firestore.collection('users').doc(opponentUid).get();
      final opponentName = opponentDoc.data()?['username'] ?? 'A player';

      // Get challenger FCM token
      final challengerDoc = await _firestore.collection('users').doc(challengerUid).get();
      final token = challengerDoc.data()?['fcmToken'];
      if (token == null) return;

      // Send FCM notification (you'll need to implement this similar to the challenge notification)
      debugPrint('📱 ChallengeService: Sending acceptance notification to challenger');
      // TODO: Implement FCM notification for acceptance
    } catch (e) {
      debugPrint('Error sending acceptance notification: $e');
    }
  }

  /// Send notification to challenger about rejection
  static Future<void> _sendRejectionNotification(String challengerUid, String opponentUid) async {
    try {
      // Get opponent name
      final opponentDoc = await _firestore.collection('users').doc(opponentUid).get();
      final opponentName = opponentDoc.data()?['username'] ?? 'A player';

      // Get challenger FCM token
      final challengerDoc = await _firestore.collection('users').doc(challengerUid).get();
      final token = challengerDoc.data()?['fcmToken'];
      if (token == null) return;

      // Send FCM notification (you'll need to implement this similar to the challenge notification)
      debugPrint('📱 ChallengeService: Sending rejection notification to challenger');
      // Implement FCM notification for rejection
      
      
    } catch (e) {
      debugPrint('Error sending rejection notification: $e');
    }
  }
}

/// Result of challenge validation
class ChallengeValidationResult {
  final bool isValid;
  final String message;
  final Challenge? challenge;

  ChallengeValidationResult({
    required this.isValid,
    required this.message,
    this.challenge,
  });
}

/// Result of challenge acceptance
class ChallengeAcceptResult {
  final bool success;
  final String message;
  final String? roomCode;

  ChallengeAcceptResult({
    required this.success,
    required this.message,
    this.roomCode,
  });
}
