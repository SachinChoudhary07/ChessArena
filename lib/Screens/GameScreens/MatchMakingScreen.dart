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
  DateTime? _matchmakingStartTime;
  Timer? _phaseCheckTimer;
  bool _isInPhase2 = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeUserData();
    _startWaitingTimer();
  }

  void _initializeAnimation() {
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _searchAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeInOut,
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

  void _startPhaseCheckTimer() {
    _phaseCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _matchmakingStartTime != null) {
        final elapsedSeconds =
            DateTime.now().difference(_matchmakingStartTime!).inSeconds;

        // Check if we need to switch to phase 2
        if (elapsedSeconds >= 15 && !_isInPhase2) {
          print(
              "🎮 MatchMaking: Timer forcing phase 2 check at ${elapsedSeconds}s");
          _isInPhase2 = true;

          // Force a queue check by fetching the current queue
          _firestore
              .collection('matchmaking_queue')
              .orderBy('timestamp')
              .get()
              .then((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              print(
                  "🎮 MatchMaking: Forcing queue re-evaluation with ${snapshot.docs.length} players");

              // Manually trigger the matchmaking logic
              _checkQueueForMatches(snapshot.docs);
            }
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkQueueForMatches(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final now = DateTime.now();
    bool foundSuitableOpponent = false;
    int availableOpponents = 0;

    for (var doc in docs) {
      final data = doc.data();
      final String opponentId = data['uid'];
      final int opponentElo = data['eloRating'];
      final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
      final String matchTime = data['match_time'] ?? '10';

      if (opponentId == currentUserId) continue;

      availableOpponents++;

      // Time-based matching logic
      bool isMatch = false;

      // Calculate actual time elapsed since matchmaking started
      final matchmakingElapsedSeconds = _matchmakingStartTime != null
          ? now.difference(_matchmakingStartTime!).inSeconds
          : 0;

      if (matchmakingElapsedSeconds < 15) {
        // Phase 1: First 15 seconds - ELO-based matching
        final waitingDuration = now.difference(timestamp.toDate()).inSeconds;
        final allowedRange = min(100 + (waitingDuration ~/ 30) * 25, 300);

        print(
            "🎮 MatchMaking: Phase 1 (ELO-based) - Elapsed: ${matchmakingElapsedSeconds}s - Checking opponent - ID: $opponentId, ELO: $opponentElo");
        print(
            "🎮 MatchMaking: Wait time: ${waitingDuration}s, Allowed ELO range: ±$allowedRange");

        if ((opponentElo - currentUserElo).abs() <= allowedRange &&
            matchTime == widget.time) {
          isMatch = true;
        }
      } else {
        // Phase 2: After 15 seconds - Match with any player with same time
        print(
            "🎮 MatchMaking: Phase 2 (Any player) - Elapsed: ${matchmakingElapsedSeconds}s - Checking opponent - ID: $opponentId, ELO: $opponentElo");

        if (matchTime == widget.time) {
          isMatch = true;
        }
      }

      if (isMatch) {
        print("🎮 MatchMaking: Match found! Opponent ID: $opponentId");
        foundSuitableOpponent = true;

        // Add a small random delay to prevent simultaneous game room creation
        final randomDelay = Random().nextInt(300) + 100; // 100-400ms delay
        print(
            "🎮 MatchMaking: Adding ${randomDelay}ms delay before creating game room");
        await Future.delayed(Duration(milliseconds: randomDelay));

        await _createGameRoom(opponentId);
        break;
      }
    }

    // Update status based on available opponents and current phase
    if (mounted) {
      if (availableOpponents == 0) {
        setState(() {
          _searchStatus = "Searching for opponent...";
          _searchSubStatus =
              "You're the first player! Waiting for others to join...";
        });
      } else if (!foundSuitableOpponent && availableOpponents > 0) {
        // Calculate actual time elapsed since matchmaking started for status
        final matchmakingElapsedSeconds = _matchmakingStartTime != null
            ? now.difference(_matchmakingStartTime!).inSeconds
            : 0;

        if (matchmakingElapsedSeconds < 15) {
          setState(() {
            _searchStatus = "Searching for opponent...";
            _searchSubStatus =
                "Found $availableOpponents players, searching for skill-matched opponent...";
          });
        } else {
          setState(() {
            _searchStatus = "Broadening search...";
            _searchSubStatus =
                "Searching among all available players with same time format...";
          });
        }
      }
    }
  }

  Future<void> _startMatchmaking(int retryCount) async {
    if (retryCount == 0) {
      print("🎮 MatchMaking: Starting matchmaking process first time");
      _matchmakingStartTime = DateTime.now(); // Set matchmaking start time
      _isInPhase2 = false; // Reset phase flag
      _startPhaseCheckTimer(); // Start the periodic phase check timer
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
      _matchmakingStartTime = DateTime.now(); // Reset start time for retry
      _isInPhase2 = false; // Reset phase flag
      _startPhaseCheckTimer(); // Start the periodic phase check timer
    }

    matchmakingListener = _firestore
        .collection('matchmaking_queue')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) async {
      print(
          "🎮 MatchMaking: Queue updated - ${snapshot.docs.length} players in queue");

      await _checkQueueForMatches(snapshot.docs);
    });
  }

  Future<void> _createGameRoom(String opponentId) async {
    print("🎮 GameRoom: Starting room creation with opponent: $opponentId");
    await matchmakingListener?.cancel();
    _phaseCheckTimer?.cancel(); // Cancel the phase check timer
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

    if (!opponentDoc.exists || !currentUserDoc.exists) {
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

    final currentUserData = currentUserDoc.data();
    final opponentData = opponentDoc.data();

    if (currentUserData == null || opponentData == null) {
      print("❌ GameRoom: Player data is null. Aborting and restarting search.");
      if (mounted) {
        setState(() {
          _searchStatus = "Searching for opponent...";
          _searchSubStatus = "Please wait while we find a suitable match";
        });
        _startMatchmaking(1);
      }
      return;
    }

    final currentUserTimestamp = currentUserData['timestamp'] as Timestamp;
    final opponentTimestamp = opponentData['timestamp'] as Timestamp;

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
      print(
          "🎮 GameRoom: Opponent should create game, removing from queue and waiting");
      await _firestore
          .collection('matchmaking_queue')
          .doc(currentUserId)
          .delete();
      await _firestore.collection('matchmaking_queue').doc(opponentId).delete();
      print("🎮 GameRoom: Both players removed from queue");

      print("🎮 GameRoom: Waiting for opponent to create game");
      await Future.delayed(const Duration(milliseconds: 1000));

      // Try multiple times to find the game
      int attempts = 0;
      const maxAttempts = 10;

      while (attempts < maxAttempts && gameId == null) {
        attempts++;
        print("🎮 GameRoom: Attempt $attempts to find game");

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
          print(
              "🎮 GameRoom: Found game with ID: $gameId on attempt $attempts");
          break;
        } else {
          print("🎮 GameRoom: Game not found on attempt $attempts, waiting...");
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (gameId == null) {
        print("❌ GameRoom: Failed to find game after $maxAttempts attempts");
        // Try to restart matchmaking if game not found
        if (mounted) {
          setState(() {
            _searchStatus = "Connection issue, restarting search...";
            _searchSubStatus = "Please wait while we reconnect you";
          });
          await Future.delayed(const Duration(milliseconds: 1000));
          _startMatchmaking(1);
        }
        return;
      }
    }

    if (mounted) {
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
    // Only show "no players available" message after both phases have been attempted
    final matchmakingElapsedSeconds = _matchmakingStartTime != null
        ? DateTime.now().difference(_matchmakingStartTime!).inSeconds
        : 0;

    if (matchmakingElapsedSeconds >= 45 && !_showNoPlayersMessage) {
      setState(() {
        _searchStatus = "No players available right now";
        _searchSubStatus =
            "Try again in a few minutes or try a different time format";
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
    _phaseCheckTimer?.cancel(); // Cancel the new timer
    super.dispose();
  }

  String _formatWaitTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final ratingLabel =
        currentUserName != null ? '${currentUserElo} rating' : 'Loading…';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finding a game'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: ColorResources.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ColorResources.divider),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ColorResources.elevatedSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ColorResources.divider),
                      ),
                      child: Text(
                        '${widget.time}  •  Rated',
                        style: const TextStyle(
                          color: ColorResources.accentSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPlayerCard(
                            currentUserName ?? AppConstants.you,
                            profile ?? AppConstants.defaultProfileImage,
                            ratingLabel,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Text(
                                _formatWaitTime(_waitingTimeSeconds),
                                style: const TextStyle(
                                  color: ColorResources.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'VS',
                                style: TextStyle(
                                  color: ColorResources.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _buildSearchingCard()),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ColorResources.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchSubStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ColorResources.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showNoPlayersMessage) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ColorResources.elevatedSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ColorResources.warning),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: ColorResources.warning,
                        size: 22,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No one in this queue right now',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ColorResources.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Try another time control, or come back in a few minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ColorResources.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (_isAutoCancelling) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Returning home in $_autoCancelCountdown seconds',
                          style: const TextStyle(
                            color: ColorResources.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const Spacer(),
              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(String label, String imagePath, String subtitle) {
    return Column(
      children: [
        Container(
          height: 88,
          width: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ColorResources.primary, width: 2.5),
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: imagePath,
              fit: BoxFit.cover,
              placeholder: (context, url) => Image.asset(
                AppConstants.defaultProfileImage,
                fit: BoxFit.cover,
              ),
              errorWidget: (context, url, error) => Image.asset(
                AppConstants.defaultProfileImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ColorResources.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ColorResources.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingCard() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _searchAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _searchAnimation.value,
              child: child,
            );
          },
          child: Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorResources.elevatedSurface,
              border: Border.all(color: ColorResources.divider, width: 2),
            ),
            child: const Icon(
              Icons.person_search_outlined,
              color: ColorResources.accentSoft,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Opponent',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ColorResources.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Searching…',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ColorResources.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _handleManualCancel,
        child: const Text('Cancel search'),
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
    _phaseCheckTimer?.cancel(); // Cancel the new timer

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
