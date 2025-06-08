// TournamentWaitingRoom with proper player color assignment

import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TournamentWaitingRoom extends StatefulWidget {
  final String roomCode;

  final String tournamentId;
  final String player1;
  final String player2;

  const TournamentWaitingRoom({
    super.key,
    required this.roomCode,
    required this.tournamentId,
    required this.player1,
    required this.player2,
  });

  @override
  State<TournamentWaitingRoom> createState() => _TournamentWaitingRoomState();
}

class _TournamentWaitingRoomState extends State<TournamentWaitingRoom> {
  final bool _navigated = false;
  final int _countdown = 0; // for countdown display

  @override
  void initState() {
    super.initState();
    initOnline();
  }

  initOnline() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('matches')
        .doc(widget.roomCode);

    //check if the current user is in the match
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      if (currentUser.uid == widget.player1) {
        await docRef.update({'isPlayer1Present': true});
      } else {
        await docRef.update({'isPlayer2Present': true});
      }
    }
  }

  void _startCountdown(Map<String, dynamic> roomData) {
    _initializeGameData(roomData).then((_) {
      Future.delayed(const Duration(seconds: 3));
      pushReplacement(
          context,
          GameScreen(
            roomCode: widget.roomCode,
            tournamentId: widget.tournamentId,
          ));
    });
  }

  int parseTimeToSeconds(String? timeString) {
    if (timeString == null) return 300; // default 5 minutes

    final parts = timeString.trim().split(' ');
    if (parts.length != 2) return 300;

    final value = int.tryParse(parts[0]);
    if (value == null) return 300;

    // Convert to seconds
    if (parts[1].toLowerCase().contains('min')) {
      print(
          "🎮 WaitingRoom: Converting time limit $timeString to ${value * 60} seconds");
      return value * 60;
    }
    return 300; // default if parsing fails
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

    // Get time from room data
    final gameTimeSeconds = parseTimeToSeconds(roomData['time'] as String?);
    print(
        "🎮 WaitingRoom: Setting game time to $gameTimeSeconds seconds from ${roomData['time']}");

    // Update game document with initial game state
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('matches')
        .doc(widget.roomCode)
        .update({
      'boardState': boardMap,
      'currentPlayer': 'white',
      'gameStatus': 'playing',
      'whiteTimeLeft': gameTimeSeconds,
      'blackTimeLeft': gameTimeSeconds,
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
    return WillPopScope(
      // Prevent back button navigation
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              false, // This removes the back button from AppBar
          title: const Text("Waiting Room"),
          backgroundColor: ColorResources.primaryColor,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('matches')
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
            final gameName = data['gameName'];
            final isPlayer1Present = data['isPlayer1Present'] ?? false;
            final isPlayer2Present = data['isPlayer2Present'] ?? false;
            print("isPlayer1Present: $isPlayer1Present");
            print("isPlayer2Present: $isPlayer2Present");
            print("player1: $player1");
            print("player2: $player2");
            print("status: $status");
            print("gameName: $gameName");
            print("roomCode: ${widget.roomCode}");
            print("tournamentId: ${widget.tournamentId}");
            print("navigated: $_navigated");
            final players = [player1, if (player2 != null) player2];

            if (isPlayer1Present && isPlayer2Present && !_navigated) {
              _startCountdown(data);
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ColorResources.primaryColor,
                    ColorResources.secondaryColor
                  ],
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
                          "Waiting for player...",
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
                            border:
                                Border.all(color: ColorResources.primaryColor),
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Room Code: ${widget.roomCode}",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: ColorResources.secondaryColor),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...players.asMap().entries.map((entry) {
                          final index = entry.key;
                          final playerName = index == 0
                              ? (widget.player1 ?? 'Player 1')
                              : (widget.player2 ?? 'Player 2'); // ✅
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: ColorResources.secondaryColor,
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
                                  playerName,
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
                                    color: index == 0
                                        ? Colors.white
                                        : Colors.black,
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
                          const SizedBox(height: 10),
                          Text(
                            _countdown > 0
                                ? "Game is starting in some time ..."
                                : "Starting game...",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ColorResources.secondaryColor,
                            ),
                          ),
                        ] else ...[
                          const Loader(),
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
      ),
    );
  }
}
