import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MatchMakingScreen extends StatefulWidget {
  final String time;

  const MatchMakingScreen({
    super.key,
    required this.time,
  });

  @override
  State<MatchMakingScreen> createState() => _MatchMakingScreenState();
}

class _MatchMakingScreenState extends State<MatchMakingScreen>
    with SingleTickerProviderStateMixin {
  bool isSearching = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String currentUserId;
  String? profile;
  String? currentUserName;
  late int currentUserElo;

  StreamSubscription? matchmakingListener;
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;

  // New variables for user-friendly messaging
  String _searchStatus = "Searching for opponent...";
  String _searchSubStatus = "Please wait while we find a suitable match";
  bool _showNoPlayersMessage = false;
  int _waitingTimeSeconds = 0;
  Timer? _waitingTimer;
  bool _isAutoCancelling = false;
  int _autoCancelCountdown = 6;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeUserData();
    _startWaitingTimer();
  }

  void _initializeAnimation() {
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _searchAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeInCirc,
      ),
    );

    _searchAnimationController.repeat(reverse: true);
  }

  Future<void> _initializeUserData() async {
    currentUserId = _auth.currentUser!.uid;
    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() ?? {};

    setState(() {
      profile = userData['profileImage']?.toString();
      currentUserElo = userData['eloRating']?.round() ?? 0;
      currentUserName = userData['username']?.toString();
    });

    _startMatchmaking(0);
  }

  Future<void> _startMatchmaking(int retryCount) async {
    if (retryCount == 0) {
      print("🎮 MatchMaking: Starting matchmaking process first time");
      final docRef =
          _firestore.collection('matchmaking_queue').doc(currentUserId);
      await docRef.set({
        'uid': currentUserId,
        'eloRating': currentUserElo,
        'timestamp': FieldValue.serverTimestamp(),
        'match_time': widget.time,
      });
      print("🎮 MatchMaking: Added to queue - UserID: $currentUserId");
    } else {
      print("🎮 MatchMaking: Starting matchmaking process second time");
    }

    matchmakingListener = _firestore
        .collection('matchmaking_queue')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) async {
      print(
          "🎮 MatchMaking: Queue updated - ${snapshot.docs.length} players in queue");
      final now = DateTime.now();
      
      // Check if there are any other players in the queue
      bool foundSuitableOpponent = false;
      int availableOpponents = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String opponentId = data['uid'];
        final int opponentElo = data['eloRating'];
        final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
        final String matchTime = data['match_time'] ?? '10';

        if (opponentId == currentUserId) continue;
        
        availableOpponents++;

        final waitingDuration = now.difference(timestamp.toDate()).inSeconds;
        final allowedRange = min(100 + (waitingDuration ~/ 30) * 25, 300);

        print(
            "🎮 MatchMaking: Checking opponent - ID: $opponentId, ELO: $opponentElo");
        print(
            "🎮 MatchMaking: Wait time: ${waitingDuration}s, Allowed ELO range: ±$allowedRange");

        if ((opponentElo - currentUserElo).abs() <= allowedRange &&
            matchTime == widget.time) {
          print("🎮 MatchMaking: Match found! Opponent ID: $opponentId");
          foundSuitableOpponent = true;
          await _createGameRoom(opponentId);
          break;
        }
      }
      
      // Update status based on available opponents
      if (mounted) {
        if (availableOpponents == 0) {
          setState(() {
            _searchStatus = "Searching for opponent...";
            _searchSubStatus = "You're the first player! Waiting for others to join...";
          });
        } else if (!foundSuitableOpponent && availableOpponents > 0) {
          setState(() {
            _searchStatus = "Players available but not suitable";
            _searchSubStatus = "Found $availableOpponents players, but none match your skill level.";
          });
        }
      }
    });
  }

  Future<void> _createGameRoom(String opponentId) async {
    print("🎮 GameRoom: Starting room creation with opponent: $opponentId");
    await matchmakingListener?.cancel();
    print("🎮 GameRoom: Matchmaking listener cancelled");
    
    // Reset search status when match is found
    if (mounted) {
      setState(() {
        _searchStatus = "Match found!";
        _searchSubStatus = "Setting up your game...";
        _showNoPlayersMessage = false;
        _isAutoCancelling = false;
      });
    }

    // Cancel any ongoing auto-cancellation
    _countdownTimer?.cancel();

    final currentUserDoc = await _firestore
        .collection('matchmaking_queue')
        .doc(currentUserId)
        .get();

    final opponentDoc =
        await _firestore.collection('matchmaking_queue').doc(opponentId).get();

    print("🎮 GameRoom: Current User Document Details:");
    print(currentUserDoc.data());
    print("🎮 GameRoom: Opponent Document Details:");
    print(opponentDoc.data());

    if (!opponentDoc.exists) {
      print(
          "❌ GameRoom: One of the players is no longer in the queue. Aborting and restarting search.");
      if (mounted) {
        setState(() {
          _searchStatus = "Searching for opponent...";
          _searchSubStatus = "Please wait while we find a suitable match";
        });
        _startMatchmaking(1);
      }
      return;
    }

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
          .collection('matchmaking_queue')
          .doc(currentUserId)
          .delete();
      await _firestore.collection('matchmaking_queue').doc(opponentId).delete();
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

  void _startWaitingTimer() {
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitingTimeSeconds++;
        });
        _updateSearchStatus();
      }
    });
  }

  void _updateSearchStatus() {
    if (_waitingTimeSeconds >= 30 && !_showNoPlayersMessage) {
      setState(() {
        _searchStatus = "Still searching...";
        _searchSubStatus = "We're expanding our search to find you a match";
      });
    }

    if (_waitingTimeSeconds >= 60 && !_showNoPlayersMessage) {
      setState(() {
        _searchStatus = "No players available right now";
        _searchSubStatus = "Try again in a few minutes or try a different time format";
        _showNoPlayersMessage = true;
      });

      // Automatically cancel after showing no players message
      _autoCancelAfterDelay();
    }
  }

  void _autoCancelAfterDelay() async {
    _isAutoCancelling = true;
    _autoCancelCountdown = 6;

    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isAutoCancelling) {
        setState(() {
          _autoCancelCountdown--;
        });

        if (_autoCancelCountdown <= 0) {
          timer.cancel();
          _handleCancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    matchmakingListener?.cancel();
    _waitingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  Text(
                    _searchStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchSubStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  if (_showNoPlayersMessage) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        border: Border.all(color: Colors.orange, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Suggestions:",
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "• Try a different time format (1 min, 5 min, 10 min)\n• Check back in a few minutes",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          if (_isAutoCancelling) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                border: Border.all(color: Colors.red, width: 1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Returning to dashboard in $_autoCancelCountdown seconds",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerCard(
                  currentUserName ?? AppConstants.you,
                  profile ?? AppConstants.defaultProfileImage,
                ),
                Text(
                  "VS",
                  style: TextStyle(
                    color: ColorResources.secondaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                _buildSearchingCard(),
              ],
            ),
            const Spacer(),
            _buildCancelButton(),
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
            border: Border.all(color: ColorResources.secondaryColor, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: CachedNetworkImage(
              imageUrl: imagePath,
              fit: BoxFit.cover,
              placeholder: (context, url) => Image.asset(
                AppConstants.defaultProfileImage,
                fit: BoxFit.cover,
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: ColorResources.secondaryColor,
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
            border: Border.all(color: ColorResources.secondaryColor, width: 3),
            borderRadius: BorderRadius.circular(12),
            // color: Colors.purple.shade800,
          ),
          child: AnimatedBuilder(
            animation: _searchAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _searchAnimation.value,
                child: Icon(
                  Icons.search,
                  color: ColorResources.secondaryColor,
                  size: 45,
                ),
              );
            },
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

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: ElevatedButton.icon(
        onPressed: _handleManualCancel,
        icon: const Icon(Icons.close),
        label: const Text(AppConstants.cancel),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.orange, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCancel() async {
    await _firestore
        .collection('matchmaking_queue')
        .doc(currentUserId)
        .delete();
    await matchmakingListener?.cancel();
    _waitingTimer?.cancel();
    _countdownTimer?.cancel();
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleManualCancel() async {
    // Reset auto-cancellation flag to prevent automatic cancellation
    _isAutoCancelling = false;
    _countdownTimer?.cancel();
    await _handleCancel();
  }
}
