import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChallengeExpirationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _expirationTimer;

  /// Start the background timer to check for expired challenges
  static void startExpirationTimer() {
    // Check every 30 seconds for expired challenges
    _expirationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndExpireChallenges();
    });
  }

  /// Stop the background timer
  static void stopExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = null;
  }

  /// Check for pending challenges that have expired and update their status
  static Future<void> _checkAndExpireChallenges() async {
    try {
      final now = DateTime.now();
      final twoMinutesAgo = now.subtract(const Duration(minutes: 2));

      // Query for pending challenges created more than 2 minutes ago
      final expiredChallenges = await _firestore
          .collection('challenges')
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(twoMinutesAgo))
          .get();

      // Update all expired challenges
      final batch = _firestore.batch();
      for (final doc in expiredChallenges.docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
        });
      }

      if (expiredChallenges.docs.isNotEmpty) {
        await batch.commit();
        debugPrint('Expired ${expiredChallenges.docs.length} challenges');

        // Send notifications to challengers about expired challenges
        for (final doc in expiredChallenges.docs) {
          final data = doc.data();
          final challengerUid = data['challenger'];
          final opponentUid = data['opponent'];
          if (challengerUid != null) {
            await _sendExpirationNotification(challengerUid, opponentUid);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for expired challenges: $e');
    }
  }

  /// Send notification to challenger about expired challenge
  static Future<void> _sendExpirationNotification(
      String challengerUid, String opponentUid) async {
    try {
      // Get opponent name
      final opponentDoc =
          await _firestore.collection('users').doc(opponentUid).get();
      final opponentName = opponentDoc.data()?['username'] ?? 'A player';

      // Get challenger FCM token
      final challengerDoc =
          await _firestore.collection('users').doc(challengerUid).get();
      final token = challengerDoc.data()?['fcmToken'];
      if (token == null) return;

      // Send FCM notification (you'll need to implement this similar to the challenge notification)
      debugPrint(
          '📱 ChallengeExpirationService: Sending expiration notification to challenger');
      // TODO: Implement FCM notification for expiration
    } catch (e) {
      debugPrint('Error sending expiration notification: $e');
    }
  }

  /// Manually expire a specific challenge
  static Future<void> expireChallenge(String challengeId) async {
    try {
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error expiring challenge $challengeId: $e');
    }
  }
}
