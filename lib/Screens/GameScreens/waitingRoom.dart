// Enhanced WaitingRoom with proper player color assignment

import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EnhancedWaitingRoom extends StatefulWidget {
  final String roomCode;

  const EnhancedWaitingRoom({super.key, required this.roomCode});

  @override
  State<EnhancedWaitingRoom> createState() => _EnhancedWaitingRoomState();
}

class _EnhancedWaitingRoomState extends State<EnhancedWaitingRoom> {
  bool _navigated = false;
  int _countdown = 0; // for countdown display

  void _startCountdown(Map<String, dynamic> roomData) {
    _initializeGameData(roomData).then((_) {
      print("Printing Room Dara${roomData}");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(roomCode: widget.roomCode),
        ),
      );
    });
  }

  Future<void> _initializeGameData(Map<String, dynamic> roomData) async {
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

    // Update game document with initial game state
    await FirebaseFirestore.instance
        .collection('games')
        .doc(widget.roomCode)
        .update({
      'boardState': boardMap, // flat map instead of 2D list
      'currentPlayer': 'white',
      'gameStatus': 'playing',
      'whiteTimeLeft': 600, // 10 minutes
      'blackTimeLeft': 600,
      'player1Color': 'white',
      'player2Color': 'black',
      'gameStarted': true,
      'lastUpdated': FieldValue.serverTimestamp(),
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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Waiting Room"),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(widget.roomCode)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(
                child: Text("Waiting for room to be created..."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final player1 = data['player1'];
          final player2 = data['player2'];
          final status = data['status'];

          final players = [player1, if (player2 != null) player2];

          if (status == 'ready' && !_navigated) {
            _startCountdown(data);
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Colors.lightBlue],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.games,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Chess Game",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Waiting for players...",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Room Code: ${widget.roomCode}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...players.asMap().entries.map((entry) {
                        final index = entry.key;
                        final player = entry.value;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                index == 0
                                    ? Icons.person
                                    : Icons.person_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Player ${index + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      index == 0 ? Colors.white : Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  index == 0 ? "WHITE" : "BLACK",
                                  style: TextStyle(
                                    color: index == 0
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      if (status == 'ready') ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          _countdown > 0
                              ? "Game starting in $_countdown..."
                              : "Starting game...",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ] else ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          "${players.length}/2 players joined",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
