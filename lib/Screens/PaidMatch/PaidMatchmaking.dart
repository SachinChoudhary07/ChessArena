import 'dart:async';
import 'dart:math';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaidMatchmaking extends StatefulWidget {
  final String time;
  final String amount;

  const PaidMatchmaking({
    super.key,
    required this.time,
    required this.amount,
  });

  @override
  State<PaidMatchmaking> createState() => _PaidMatchmakingState();
}

class _PaidMatchmakingState extends State<PaidMatchmaking> {
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
    print("🎮 MatchMaking: Screen Initialized");
    init();
  }

  init() {
    currentUserId = _auth.currentUser!.uid;
    profile = _auth.currentUser?.photoURL ??
        'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT9nPR4_CyTE4xJdV3eDJ3P4rDGs8uvpTEW-qK_-WzU6xfjqg1I1CeyCcPOHztCFtwfbrc&usqp=CAU';
    currentUserElo = 1400;
    print(
        "🎮 MatchMaking: Init - UserID: $currentUserId, ELO: $currentUserElo");
    _startMatchmaking();
  }

  Future<void> _startMatchmaking() async {
    print("🎮 MatchMaking: Starting matchmaking process");
    final docRef =
        _firestore.collection('paid_matchmaking_queue').doc(currentUserId);
    await docRef.set({
      'uid': currentUserId,
      'elo': currentUserElo,
      'timestamp': FieldValue.serverTimestamp(),
      'time': widget.time,
      'amount': widget.amount,
    });
    print("🎮 MatchMaking: Added to queue - UserID: $currentUserId");

    // Start timeout timer
    Timer(const Duration(minutes: 2), () {
      if (mounted && isSearching) {
        _handleNoOpponentFound();
      }
    });

    matchmakingListener = _firestore
        .collection('paid_matchmaking_queue')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) async {
      print(
          "🎮 MatchMaking: Queue updated - ${snapshot.docs.length} players in queue");
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String opponentId = data['uid'];
        final int opponentElo = data['elo'];
        final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
        final String opponentTime = data['time'];
        final String opponentAmount = data['amount'];

        if (opponentId == currentUserId) continue;
        if (opponentTime != widget.time || opponentAmount != widget.amount)
          continue;

        final waitingDuration = now.difference(timestamp.toDate()).inSeconds;
        final allowedRange = min(100 + (waitingDuration ~/ 30) * 25, 300);

        print(
            "🎮 MatchMaking: Checking opponent - ID: $opponentId, ELO: $opponentElo");
        print(
            "🎮 MatchMaking: Wait time: ${waitingDuration}s, Allowed ELO range: ±$allowedRange");

        if ((opponentElo - currentUserElo).abs() <= allowedRange) {
          print("🎮 MatchMaking: Match found! Opponent ID: $opponentId");
          await _createGameRoom(opponentId);
          break;
        }
      }
    });
  }

  void _handleNoOpponentFound() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No opponent found. Please try again later.'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _createGameRoom(String opponentId) async {
    print("🎮 GameRoom: Starting room creation with opponent: $opponentId");
    isSearching = false;
    await matchmakingListener?.cancel();
    print("🎮 GameRoom: Matchmaking listener cancelled");

    // Deduct entry fee from both players
    try {
      await _deductEntryFee(currentUserId);
      await _deductEntryFee(opponentId);
    } catch (e) {
      print("❌ GameRoom: Failed to deduct entry fee - $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to process entry fee. Please try again.')),
        );
        Navigator.pop(context);
        return;
      }
    }

    final currentUserDoc = await _firestore
        .collection('paid_matchmaking_queue')
        .doc(currentUserId)
        .get();

    final opponentDoc = await _firestore
        .collection('paid_matchmaking_queue')
        .doc(opponentId)
        .get();

    final currentUserTimestamp =
        currentUserDoc.data()?['timestamp'] as Timestamp;
    final opponentTimestamp = opponentDoc.data()?['timestamp'] as Timestamp;

    print(
        "🎮 GameRoom: Current user wait time: ${DateTime.now().difference(currentUserTimestamp.toDate()).inSeconds}s");
    print(
        "🎮 GameRoom: Opponent wait time: ${DateTime.now().difference(opponentTimestamp.toDate()).inSeconds}s");

    String? gameId;

    if (currentUserTimestamp.compareTo(opponentTimestamp) < 0) {
      print("🎮 GameRoom: Current user creating game (waited longer)");
      final gameDoc = await _firestore.collection('games').add({
        'player1': currentUserId,
        'player2': opponentId,
        'status': 'ready',
        'createdAt': FieldValue.serverTimestamp(),
        'time': widget.time, // Using widget.time instead of timeLimit
      });
      gameId = gameDoc.id;
      print("🎮 GameRoom: Game created with ID: $gameId");
    } else {
      await _firestore
          .collection('paid_matchmaking_queue')
          .doc(currentUserId)
          .delete();
      await _firestore
          .collection('paid_matchmaking_queue')
          .doc(opponentId)
          .delete();
      print("🎮 GameRoom: Both players removed from queue");
      print("🎮 GameRoom: Waiting for opponent to create game");
      await Future.delayed(const Duration(milliseconds: 500));

      final querySnapshot = await _firestore
          .collection('games')
          .where('player2', isEqualTo: currentUserId)
          .where('player1', isEqualTo: opponentId)
          .where('status', isEqualTo: 'ready')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        gameId = querySnapshot.docs.first.id;
        print("🎮 GameRoom: Found and joining game with ID: $gameId");
      } else {
        print("❌ GameRoom: Failed to find game to join");
      }
    }

    if (gameId != null && mounted) {
      print("🎮 GameRoom: Navigating to game screen with ID: $gameId");

      final roomData = {
        'player1': currentUserId,
        'player2': opponentId,
        'status': 'ready',
        'createdAt': FieldValue.serverTimestamp(),
      };
      _startCountdown(roomData, gameId);
    } else {
      print("❌ GameRoom: Failed to create/join game");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to create/join game. Please try again.')),
        );
      }
    }
  }

  void _startCountdown(Map<String, dynamic> roomData, String roomCode) {
    _initializeGameData(roomData, roomCode).then((_) {
      Future.delayed(const Duration(seconds: 3));
      pushReplacement(
          context,
          GameScreen(
            roomCode: roomCode,
          ));
    });
  }

  List<List<Map<String, dynamic>?>> _createInitialBoardState() {
    final board = List.generate(
        8, (row) => List.generate(8, (col) => null as Map<String, dynamic>?));

    // Black pieces
    board[0][0] = {'type': 'rook', 'color': 'black', 'hasMoved': false};
    board[0][1] = {'type': 'knight', 'color': 'black', 'hasMoved': false};
    board[0][2] = {'type': 'bishop', 'color': 'black', 'hasMoved': false};
    board[0][3] = {'type': 'queen', 'color': 'black', 'hasMoved': false};
    board[0][4] = {'type': 'king', 'color': 'black', 'hasMoved': false};
    board[0][5] = {'type': 'bishop', 'color': 'black', 'hasMoved': false};
    board[0][6] = {'type': 'knight', 'color': 'black', 'hasMoved': false};
    board[0][7] = {'type': 'rook', 'color': 'black', 'hasMoved': false};

    for (int col = 0; col < 8; col++) {
      board[1][col] = {'type': 'pawn', 'color': 'black', 'hasMoved': false};
    }

    // White pieces
    for (int col = 0; col < 8; col++) {
      board[6][col] = {'type': 'pawn', 'color': 'white', 'hasMoved': false};
    }

    board[7][0] = {'type': 'rook', 'color': 'white', 'hasMoved': false};
    board[7][1] = {'type': 'knight', 'color': 'white', 'hasMoved': false};
    board[7][2] = {'type': 'bishop', 'color': 'white', 'hasMoved': false};
    board[7][3] = {'type': 'queen', 'color': 'white', 'hasMoved': false};
    board[7][4] = {'type': 'king', 'color': 'white', 'hasMoved': false};
    board[7][5] = {'type': 'bishop', 'color': 'white', 'hasMoved': false};
    board[7][6] = {'type': 'knight', 'color': 'white', 'hasMoved': false};
    board[7][7] = {'type': 'rook', 'color': 'white', 'hasMoved': false};

    return board;
  }

  Future<void> _initializeGameData(
      Map<String, dynamic> roomData, String roomCode) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Determine player colors
    final isPlayer1 = roomData['player1'] == currentUser.uid;
    final playerColor = isPlayer1 ? 'white' : 'black';

    // Setup initial board state
    final initialBoardState = _createInitialBoardState();

    // Convert 2D board to flat map (Firestore-compatible)
    Map<String, dynamic> boardMap = {};
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = initialBoardState[row][col];
        if (piece != null) {
          boardMap['$row-$col'] = piece;
        }
      }
    }

    // Parse time string to seconds
    final timeInMinutes = int.parse(widget.time.split(' ')[0]);
    final timeInSeconds = timeInMinutes * 60;

    // Update game document with initial game state
    await FirebaseFirestore.instance.collection('games').doc(roomCode).update({
      'boardState': boardMap,
      'currentPlayer': 'white',
      'gameStatus': 'playing',
      'whiteTimeLeft': timeInSeconds,
      'blackTimeLeft': timeInSeconds,
      'player1Color': 'white',
      'player2Color': 'black',
      'gameStarted': true,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deductEntryFee(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final amount = double.parse(widget.amount);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final currentBalance = userDoc.data()?['balance'] ?? 0.0;

      if (currentBalance < amount) {
        throw Exception('Insufficient balance');
      }

      transaction.update(userRef, {
        'balance': currentBalance - amount,
      });
    });
  }

  @override
  void dispose() {
    // print("🎮 MatchMaking: Disposing screen - cleaning up");
    _firestore.collection('paid_matchmaking_queue').doc(currentUserId).delete();
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
                      .collection('paid_matchmaking_queue')
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
