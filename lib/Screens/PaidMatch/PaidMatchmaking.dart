import 'dart:async';
import 'dart:math';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

class _PaidMatchmakingState extends State<PaidMatchmaking> with SingleTickerProviderStateMixin {
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
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
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
      final docRef = _firestore.collection('paid_matchmaking_queue').doc(currentUserId);
      await docRef.set({
        'uid': currentUserId,
        'eloRating': currentUserElo,
        'timestamp': FieldValue.serverTimestamp(),
        'time': widget.time,
        'amount': widget.amount,
      });
    }

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
      final now = DateTime.now();
      
      // Check if there are any other players in the queue
      bool foundSuitableOpponent = false;
      int availableOpponents = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String opponentId = data['uid'];
        final int opponentElo = data['eloRating'];
        final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
        final String opponentTime = data['time'];
        final String opponentAmount = data['amount'];

        if (opponentId == currentUserId) continue;
        if (opponentTime != widget.time || opponentAmount != widget.amount) continue;
        
        availableOpponents++;

        final waitingDuration = now.difference(timestamp.toDate()).inSeconds;
        final allowedRange = min(100 + (waitingDuration ~/ 30) * 25, 300);

        if ((opponentElo - currentUserElo).abs() <= allowedRange) {
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
    isSearching = false;
    await matchmakingListener?.cancel();
    
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
        .collection('paid_matchmaking_queue')
        .doc(currentUserId)
        .get();

    final opponentDoc = await _firestore
        .collection('paid_matchmaking_queue')
        .doc(opponentId)
        .get();

    if (!opponentDoc.exists) {
      if (mounted) {
        setState(() {
          _searchStatus = "Searching for opponent...";
          _searchSubStatus = "Please wait while we find a suitable match";
        });
        _startMatchmaking(1);
      }
      return;
    }

    final currentUserTimestamp = currentUserDoc.data()?['timestamp'] as Timestamp;
    final opponentTimestamp = opponentDoc.data()?['timestamp'] as Timestamp;

    try {
      await _deductEntryFee(currentUserId);
      await _deductEntryFee(opponentId);
      
      // Show success message after entry fee deduction
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entry fee of ${widget.amount} deducted successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to process entry fee. Please try again.')),
        );
        Navigator.pop(context);
        return;
      }
    }

    String? gameId;

    if (currentUserTimestamp.compareTo(opponentTimestamp) < 0) {
      final gameDoc = await _firestore.collection('games').add({
        'player1': currentUserId,
        'player2': opponentId,
        'status': 'ready',
        'createdAt': FieldValue.serverTimestamp(),
        'time': widget.time,
        'amount': widget.amount,
      });
      gameId = gameDoc.id;
    } else {
      await _firestore.collection('paid_matchmaking_queue').doc(currentUserId).delete();
      await _firestore.collection('paid_matchmaking_queue').doc(opponentId).delete();
      
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
      }
    }

    if (gameId != null && mounted) {
      final roomData = {
        'player1': currentUserId,
        'player2': opponentId,
        'status': 'ready',
        'createdAt': FieldValue.serverTimestamp(),
      };
      _startCountdown(roomData, gameId);
    } else {
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

  Future<void> _initializeGameData(Map<String, dynamic> roomData, String roomCode) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isPlayer1 = roomData['player1'] == currentUser.uid;
    final playerColor = isPlayer1 ? 'white' : 'black';

    final initialBoardState = _createInitialBoardState();

    Map<String, dynamic> boardMap = {};
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = initialBoardState[row][col];
        if (piece != null) {
          boardMap['$row-$col'] = piece;
        }
      }
    }

    final timeInMinutes = int.parse(widget.time.split(' ')[0]);
    final timeInSeconds = timeInMinutes * 60;

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
      'amount': widget.amount,
    });
  }

  Future<void> _deductEntryFee(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final amountString = widget.amount.replaceAll('₹', '').trim();
    final finalAmount = double.parse(amountString);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final currentBalance = userDoc.data()?['Balance'] ?? 0.0;

      if (currentBalance < finalAmount) {
        throw Exception('Insufficient balance');
      }

      transaction.update(userRef, {
        'Balance': currentBalance - finalAmount,
      });
    });
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    _firestore.collection('paid_matchmaking_queue').doc(currentUserId).delete();
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchSubStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
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
                            "• Try a different amount (₹10, ₹20, ₹50)\n• Check back in a few minutes",
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
                  profile ?? 'assets/images/pawn_image.jpg',
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
                'assets/images/pawn_image.jpg',
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
    await _firestore.collection('paid_matchmaking_queue').doc(currentUserId).delete();
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
        _searchSubStatus = "Try again in a few minutes or try a different amount";
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
}
