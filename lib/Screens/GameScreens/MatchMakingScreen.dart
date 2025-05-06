import 'dart:async';
import 'dart:math';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Screens/GameScreens/gamescreen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MatchMakingScreen extends StatefulWidget {
  const MatchMakingScreen({super.key});

  @override
  State<MatchMakingScreen> createState() => _MatchMakingScreenState();
}

class _MatchMakingScreenState extends State<MatchMakingScreen> {
  bool isSearching = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String currentUserId;
  late String profile;
  late int currentUserElo;

  StreamSubscription? matchmakingListener;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() {
    currentUserId = _auth.currentUser!.uid;
    profile = _auth.currentUser?.photoURL ??
        'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT9nPR4_CyTE4xJdV3eDJ3P4rDGs8uvpTEW-qK_-WzU6xfjqg1I1CeyCcPOHztCFtwfbrc&usqp=CAU';
    // Replace this with your actual way to get user Elo
    currentUserElo = 1400;
    _startMatchmaking();
  }

  Future<void> _startMatchmaking() async {
    final docRef =
        _firestore.collection('matchmaking_queue').doc(currentUserId);
    await docRef.set({
      'uid': currentUserId,
      'elo': currentUserElo,
      'timestamp': FieldValue.serverTimestamp(),
    });

    matchmakingListener = _firestore
        .collection('matchmaking_queue')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) async {
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String opponentId = data['uid'];
        final int opponentElo = data['elo'];
        final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();

        if (opponentId == currentUserId) continue;

        final waitingDuration = now.difference(timestamp.toDate()).inSeconds;

        // Gradual Elo widening: +25 every 30 seconds, capped at ±300
        final allowedRange = min(100 + (waitingDuration ~/ 30) * 25, 300);

        if ((opponentElo - currentUserElo).abs() <= allowedRange) {
          await _createGameRoom(opponentId);
          break;
        }
      }
    });
  }

  Future<void> _createGameRoom(String opponentId) async {
    // Stop listening to queue
    await matchmakingListener?.cancel();

    // Remove both users from queue
    await _firestore
        .collection('matchmaking_queue')
        .doc(currentUserId)
        .delete();
    await _firestore.collection('matchmaking_queue').doc(opponentId).delete();

    // Create new game room
    final gameDoc = await _firestore.collection('games').add({
      'player1': currentUserId,
      'player2': opponentId,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Navigate to chess game page
    if (mounted) {
      // Navigator.pushReplacementNamed(context, '/chess_game', arguments: {
      //   'gameId': gameDoc.id,
      //   'playerId': currentUserId,
      // });
      pushReplacement(
          context,
          ChessGameScreen(
            gameId: gameDoc.id,
            playerId: currentUserId,
          ));
    }
  }

  @override
  void dispose() {
    _firestore.collection('matchmaking_queue').doc(currentUserId).delete();
    matchmakingListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),
            const Text(
              AppConstants.waitingText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerCard(AppConstants.you, profile),
                const Text(
                  "VS",
                  style: TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                _buildSearchingCard(),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _firestore
                      .collection('matchmaking_queue')
                      .doc(currentUserId)
                      .delete();
                  await matchmakingListener?.cancel();

                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.close),
                label: const Text(AppConstants.cancel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.orange, width: 1.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(String label, String imagePath) {
    return Column(
      children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.orange, width: 3),
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: NetworkImage(imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingCard() {
    return Column(
      children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.purple, width: 3),
            borderRadius: BorderRadius.circular(12),
            color: Colors.purple.shade800,
          ),
          child: const Icon(
            Icons.search,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Searching...",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
