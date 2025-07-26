import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/gameProvider/GameProvider.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Widgets/GameEndDialog.dart';

// -------------------------------------------------------------------------
// Friend request status enumeration (top-level)
// -------------------------------------------------------------------------

enum FriendStatus { none, pending, requestReceived, friends }

// screens/game_screen.dart
class GameScreen extends StatefulWidget {
  final String roomCode;
  final String? tournamentId; // Optional tournament ID

  const GameScreen({
    super.key,
    required this.roomCode,
    this.tournamentId, // Add optional parameter
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ChessGameProvider _gameProvider;
  final bool _isInitialized = false;
  bool _isShowingPromotionDialog = false;
  DocumentSnapshot? _latestGameSnapshot;

  // ---------------------------------------------------------
  // Friend request variables
  // ---------------------------------------------------------
  FriendStatus _friendStatus = FriendStatus.none;
  StreamSubscription<DocumentSnapshot>? _friendSubscription;
  String? _opponentUID;
  final bool _showFriendBanner = false;

  @override
  void initState() {
    super.initState();
    print("🎮 GameScreen: Initializing game screen");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  @override
  void dispose() {
    print("🎮 GameScreen: Disposing game screen");
    // Cancel friend request listener
    _friendSubscription?.cancel();
    // _gameProvider.dispose();
    super.dispose();
  }

  String? player1Name;
  String? player2Name;
  String? gameName = '';
  String? player1Image;
  String? player2Image;
  num player1Elo = 0.0;
  num player2Elo = 0.0;

  Future<void> _initializeGame() async {
    print("🎮 GameScreen: Starting game initialization");
    _gameProvider = Provider.of<ChessGameProvider>(context, listen: false);
    _gameProvider.initializeBoard();

    _gameProvider.setLoading(true);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      print("🎮 GameScreen: Fetching game data for room ${widget.roomCode}");
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      final gameDoc = await gameCollection.doc(widget.roomCode).get();

      if (gameDoc.exists) {
        final data = gameDoc.data() as Map<String, dynamic>;
        print("🎮 GameScreen: Game data fetched successfully");

        final player1UID = data['player1'];
        final player2UID = data['player2'];
        print("🎮 GameScreen: Player1: $player1UID, Player2: $player2UID");

        final player1Snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(player1UID)
            .get();
        final player2Snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(player2UID)
            .get();

        player1Name = player1Snapshot.data()?['username'] ?? 'Player 1';
        player2Name = player2Snapshot.data()?['username'] ?? 'Player 2';
        gameName = data['gameName'] ?? 'Chess Match';
        print("🎮 GameScreen: Players loaded - $player1Name vs $player2Name");

        player1Image = player1Snapshot.data()?['profileImage'] ?? '';
        player2Image = player2Snapshot.data()?['profileImage'] ?? '';
        player1Elo = player1Snapshot.data()?['eloRating'] ?? 0;
        player2Elo = player2Snapshot.data()?['eloRating'] ?? 0;

        // Store opponent UID for friend logic
        _opponentUID =
            (player1UID == currentUser.uid) ? player2UID : player1UID;

        // Start listening for friend request / friendship status
        _listenToFriendStatus();

        // Check if already friends
        _checkExistingFriendship();

        PieceColor playerColor;
        if (player1UID == currentUser.uid) {
          playerColor = data['player1Color'] == 'white'
              ? PieceColor.white
              : PieceColor.black;
          print(
              "🎮 GameScreen: Current user is Player 1 with color: $playerColor");
        } else {
          playerColor = data['player2Color'] == 'white'
              ? PieceColor.white
              : PieceColor.black;
          print(
              "🎮 GameScreen: Current user is Player 2 with color: $playerColor");
        }

        _gameProvider.initializeGame(
          widget.roomCode,
          currentUser.uid,
          playerColor,
          tournamentId: widget.tournamentId,
          round: data['round'] as int?,
          matchNumber: data['matchNumber'] as int?,
        );
        print("🎮 GameScreen: Game initialized successfully");
      } else {
        print("❌ GameScreen: Game document not found!");
      }
    } else {
      print("❌ GameScreen: No authenticated user found!");
    }
  }

  String _getOpponentName() {
    final myColor =
        Provider.of<ChessGameProvider>(context, listen: false).playerColor;
    return myColor == PieceColor.white
        ? (player2Name ?? 'Opponent')
        : (player1Name ?? 'Opponent');
  }

  Future<bool> _onBackPressed() async {
    return false;
  }

  Future<void> _handlePlayerExit() async {
    print("🎮 GameScreen: Processing player exit");
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final gameDocRef =
        FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    final snapshot = await gameDocRef.get();
    if (!snapshot.exists) {
      print("❌ GameScreen: Game document not found during exit");
      return;
    }

    final data = snapshot.data()!;
    final player1UID = data['player1'];
    final player2UID = data['player2'];

    final opponentUID =
        (player1UID == currentUser.uid) ? player2UID : player1UID;

    print("🎮 GameScreen: Updating game status to resignation");
    await gameDocRef.update({
      'gameStatus': 'resignation',
      'winner': opponentUID,
      'endedBy': currentUser.uid,
      'endReason': 'Player Resign',
    });

    print("🎮 GameScreen: Player exit processed successfully");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You left the game. ${_getOpponentName()} wins!')),
    );
  }

  // void handleGameStatus(String status) {
  //   switch (status) {
  //     case 'win':
  //       statusText = 'You Win!';
  //       statusColor = Colors.green;
  //       break;
  //
  //     case 'lose':
  //       statusText = 'You Lost!';
  //       statusColor = Colors.red;
  //       break;
  //
  //     case 'draw':
  //       statusText = 'It\'s a Draw!';
  //       statusColor = Colors.grey;
  //       break;
  //
  //     case 'resignation':
  //       final currentUser = FirebaseAuth.instance.currentUser;
  //       final winnerId = gameProvider.winner;
  //       final youWon = winnerId == currentUser?.uid;
  //
  //       statusText = youWon
  //           ? 'You Win! Your opponent left the game.'
  //           : 'You Lost! You left the game.';
  //       statusColor = youWon ? Colors.green : Colors.red;
  //       break;
  //
  //     default:
  //       statusText = 'Game Over';
  //       statusColor = Colors.black;
  //   }
  //
  //   notifyListeners(); // if inside ChangeNotifier
  // }

  // ---------------------------------------------------------
  // Friend request Firestore helpers
  // ---------------------------------------------------------

  String _combinedFriendDocId(String uidA, String uidB) {
    // Ensure consistent docId irrespective of order
    return (uidA.compareTo(uidB) < 0) ? '${uidA}_$uidB' : '${uidB}_$uidA';
  }

  void _listenToFriendStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);
    _friendSubscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (!snapshot.exists) {
        // Only set to none if not already friends
        if (_friendStatus != FriendStatus.friends) {
          setState(() {
            _friendStatus = FriendStatus.none;
          });
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status']; // 'pending', 'accepted', 'rejected'
      final requester = data['requester'];

      if (status == 'accepted') {
        setState(() {
          _friendStatus = FriendStatus.friends;
        });
      } else if (status == 'pending') {
        if (requester == currentUser.uid) {
          setState(() {
            _friendStatus = FriendStatus.pending;
          });
        } else {
          // Current user received a request
          setState(() {
            _friendStatus = FriendStatus.requestReceived;
          });
        }
      } else if (status == 'rejected') {
        // Treat rejection same as no request so users can send again
        setState(() {
          _friendStatus = FriendStatus.none;
        });
      } else {
        setState(() {
          _friendStatus = FriendStatus.none;
        });
      }
    });
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(docId)
        .set({
      'requester': currentUser.uid,
      'addressee': _opponentUID,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _acceptFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);
    final batch = FirebaseFirestore.instance.batch();

    // Update request status
    final reqRef =
        FirebaseFirestore.instance.collection('friend_requests').doc(docId);
    batch.update(reqRef,
        {'status': 'accepted', 'respondedAt': FieldValue.serverTimestamp()});

    // Add each other to friends subcollection
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final oppRef =
        FirebaseFirestore.instance.collection('users').doc(_opponentUID!);

    batch.set(userRef.collection('friends').doc(_opponentUID!), {
      'uid': _opponentUID,
      'since': FieldValue.serverTimestamp(),
    });

    batch.set(oppRef.collection('friends').doc(currentUser.uid), {
      'uid': currentUser.uid,
      'since': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> _rejectFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final docId = _combinedFriendDocId(currentUser.uid, _opponentUID!);

    // Delete the request document so that a new request can be sent later
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(docId)
        .delete();

    if (mounted) {
      setState(() {
        _friendStatus = FriendStatus.none;
      });
    }
  }

  // ---------------------------------------------------------
  // Initial check: are we already friends?
  // ---------------------------------------------------------

  Future<void> _checkExistingFriendship() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _opponentUID == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .doc(_opponentUID!)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _friendStatus = FriendStatus.friends;
      });
    }
  }

  // ---------------------------------------------------------
  // UI helpers for friend request action row & banner
  // ---------------------------------------------------------

  Widget _buildActionRow() {
    // Only show friend actions for opponent info (top)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.chat),
            color: Colors.grey,
            onPressed: () {
              // Future chat implementation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat feature coming soon!')),
              );
            },
          ),
          const SizedBox(width: 4),
          ..._friendActionIcons(),
        ],
      ),
    );
  }

  List<Widget> _friendActionIcons() {
    switch (_friendStatus) {
      case FriendStatus.none:
        return [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _sendFriendRequest,
          ),
        ];
      case FriendStatus.pending:
        return [
          IconButton(
            icon: Icon(
              Icons.hourglass_bottom_sharp,
              color: ColorResources.secondaryColor,
            ),
            onPressed: null,
          ),
        ];
      case FriendStatus.friends:
        return [
          const IconButton(
            icon: Icon(
              Icons.people,
              color: Colors.green,
            ),
            color: Colors.green,
            onPressed: null,
          ),
        ];
      case FriendStatus.requestReceived:
        return [
          IconButton(
            icon: const Icon(Icons.check),
            color: Colors.green,
            onPressed: _acceptFriendRequest,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: Colors.red,
            onPressed: _rejectFriendRequest,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        // backgroundColor: Colors.brown.shade100,
        appBar: AppBar(
          // backgroundColor: Colors.transparent,
          centerTitle: true,
          title: const Text(
            AppConstants.appName,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // We'll get move counts from the latest snapshot
                final snapshot = _latestGameSnapshot;
                int moveCountWhite = 0;
                int moveCountBlack = 0;
                if (snapshot != null && snapshot.data() != null) {
                  final data = snapshot.data() as Map<String, dynamic>;
                  moveCountWhite = (data['moveCountWhite'] ?? 0) as int;
                  moveCountBlack = (data['moveCountBlack'] ?? 0) as int;
                }
                _showGameMenu(context,
                    moveCountWhite: moveCountWhite,
                    moveCountBlack: moveCountBlack);
              },
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _getGameStream(),
          builder: (context, snapshot) {
            // Store the latest snapshot for use in the menu
            _latestGameSnapshot = snapshot.data;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              _handleDrawOffer(data);
            }

            return Consumer<ChessGameProvider>(
              builder: (context, gameProvider, child) {
                if (gameProvider.isLoading) {
                  return const Loader();
                }

                // Show promotion dialog if needed
                if (gameProvider.isPromotionPending &&
                    !_isShowingPromotionDialog) {
                  _isShowingPromotionDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showPromotionDialog(gameProvider);
                  });
                }

                return Column(
                  children: [
                    _buildPlayerInfo(
                      isOpponent: true,
                      timeLeft: gameProvider.playerColor == PieceColor.white
                          ? gameProvider.blackTimeLeft
                          : gameProvider.whiteTimeLeft,
                      isActive: !gameProvider.isMyTurn,
                    ),

                    _buildActionRow(),

                    // Chess board
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: _buildChessBoard(gameProvider),
                        ),
                      ),
                    ),

                    // Current player info and timer
                    _buildPlayerInfo(
                      isOpponent: false,
                      timeLeft: gameProvider.playerColor == PieceColor.white
                          ? gameProvider.whiteTimeLeft
                          : gameProvider.blackTimeLeft,
                      isActive: gameProvider.isMyTurn,
                    ),
                    _buildGameStatus(gameProvider),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Stream<DocumentSnapshot> _getGameStream() {
    CollectionReference<Map<String, dynamic>> gameCollection;
    if (widget.tournamentId != null) {
      gameCollection = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId!)
          .collection('matches');
    } else {
      gameCollection = FirebaseFirestore.instance.collection('games');
    }

    return gameCollection.doc(widget.roomCode).snapshots();
  }

  bool _isShowingDrawOfferDialog = false;

  void _handleDrawOffer(Map<String, dynamic> data) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final drawOfferedBy = data['drawOfferedBy'];
    final drawAcceptedBy = data['drawAcceptedBy'];

    // Check if a draw offer was made by the opponent
    if (drawOfferedBy != null &&
        drawOfferedBy != currentUser.uid &&
        !_isShowingDrawOfferDialog &&
        drawAcceptedBy == null) {
      _isShowingDrawOfferDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDrawOfferDialog();
      });
    }

    // Check if draw was accepted
    if (drawAcceptedBy != null && data['gameStatus'] == 'draw') {
      // Game ended in draw, show game end dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showGameEndDialog(
              _gameProvider, false); // Draw is neither win nor loss
        }
      });
    }

    // Reset draw offer dialog flag if draw offer was cleared
    if (drawOfferedBy == null) {
      _isShowingDrawOfferDialog = false;
    }
  }

  Widget _buildPlayerInfo({
    required bool isOpponent,
    required int timeLeft,
    required bool isActive,
  }) {
    final gameProvider = Provider.of<ChessGameProvider>(context, listen: false);
    final isWhitePlayer = gameProvider.playerColor == PieceColor.white;

    final playerName = isOpponent
        ? (isWhitePlayer
            ? (player2Name ?? 'Opponent')
            : (player1Name ?? 'Opponent'))
        : (isWhitePlayer ? (player1Name ?? 'You') : (player2Name ?? 'You'));

    final playerElo = isOpponent
        ? (isWhitePlayer ? (player2Elo ?? 0) : (player1Elo ?? 0))
        : (isWhitePlayer ? (player1Elo ?? 0) : (player2Elo ?? 0));

    final playerImage = isOpponent
        ? (isWhitePlayer ? (player2Image ?? '') : (player1Image ?? ''))
        : (isWhitePlayer ? (player1Image ?? '') : (player2Image ?? ''));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        // border: Border.all(
        //   color: isActive ? Colors.green : Colors.grey,
        //   width: 2,
        // ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.green : Colors.grey,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: playerImage,
                fit: BoxFit.cover,
                placeholder: (context, url) => Image.asset(
                  'assets/white_peice/White_King.png',
                  fit: BoxFit.cover,
                ),
                errorWidget: (context, url, error) => const Icon(Icons.person),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ELO: ${playerElo.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: timeLeft < 60 ? Colors.red : Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ColorResources.secondaryColor)),
            child: Text(
              gameProvider.formatTime(timeLeft),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChessBoard(ChessGameProvider gameProvider) {
    final board = gameProvider.board;
    if (board.length != 8 || board.any((row) => row.length != 8)) {
      return const Center(child: CircularProgressIndicator());
    }

    // Determine if the board needs to be flipped so that the current
    // player always sees their own pieces at the bottom of the screen.
    final shouldFlipBoard = gameProvider.playerColor == PieceColor.black;

    const String lightWoodAsset = 'assets/wood_light.jpg';
    const String darkWoodAsset = 'assets/wood_dark.png';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF8B4513), width: 4),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          // UI coordinates drawn by GridView
          final uiRow = index ~/ 8;
          final uiCol = index % 8;

          // Convert to actual board coordinates depending on orientation
          final row = shouldFlipBoard ? 7 - uiRow : uiRow;
          final col = shouldFlipBoard ? 7 - uiCol : uiCol;

          final position = ChessPosition(row, col);
          final piece = board[row][col];
          final isSelected = gameProvider.selectedPosition == position;
          final isPossibleMove = gameProvider.possibleMoves.contains(position);
          final isWhiteSquare = (row + col) % 2 == 0;

          final isKingInCheckSquare = gameProvider.kingInCheck != null &&
              gameProvider.kingInCheck == position;

          final String squareAsset =
              isWhiteSquare ? lightWoodAsset : darkWoodAsset;

          return GestureDetector(
            onTap: () => gameProvider.onSquareTapped(row, col),
            child: Stack(
              children: [
                // The wood texture background
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(squareAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Overlay for king in check
                if (isKingInCheckSquare)
                  Container(
                    color: const Color.fromARGB(
                        180, 187, 87, 87), // semi-transparent red
                  ),
                // Overlay for possible move (only if not king in check)
                if (isPossibleMove && !isKingInCheckSquare)
                  Container(
                    color: const Color.fromARGB(
                        120, 124, 179, 66), // semi-transparent green
                  ),
                // The piece or possible move indicator
                Center(
                  child: piece != null
                      ? _buildPieceWidget(piece)
                      : isPossibleMove
                          ? Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPieceWidget(ChessPiece piece) {
    final imagePath = _getPieceImagePath(piece);
    return Image.asset(
      imagePath,
      fit: BoxFit.contain,
      width: 40,
      height: 40,
    );
  }

  String _getPieceImagePath(ChessPiece piece) {
    final colorPrefix = piece.color == PieceColor.white ? 'White' : 'Black';
    final pieceType = piece.type.toString().split('.').last;
    return 'assets/${piece.color == PieceColor.white ? 'white_peice' : 'black_peice'}/'
        '${colorPrefix}_${pieceType[0].toUpperCase()}${pieceType.substring(1)}.png';
  }

  Widget _buildGameStatus(ChessGameProvider gameProvider) {
    String statusText = '';
    Color statusColor = Colors.blue;

    final currentUser = FirebaseAuth.instance.currentUser;
    final winnerColor = gameProvider.winner;
    final playerColor = gameProvider.playerColor.toString().split('.').last;
    final youWon = winnerColor == playerColor;
    final isGameOver =
        gameProvider.gameStatus != null && gameProvider.gameStatus != 'playing';

    if (!isGameOver) {
      statusText = gameProvider.isMyTurn ? 'Your Turn' : 'Opponent\'s Turn';
      statusColor = gameProvider.isMyTurn ? Colors.green : Colors.orange;
    } else {
      switch (gameProvider.gameStatus) {
        case 'checkmate':
          statusText = youWon ? 'Checkmate! You Win!' : 'Checkmate! You Lose!';
          statusColor = youWon ? Colors.green : Colors.red;
          break;

        case 'stalemate':
        case 'draw':
          statusText = 'Draw!';
          statusColor = Colors.grey;
          break;

        case 'resignation':
          statusText = youWon
              ? 'You Win! Your opponent left the game.'
              : 'You Lost! You left the game.';
          statusColor = youWon ? Colors.green : Colors.red;
          break;

        case 'timeout':
          statusText =
              youWon ? 'You Win! Opponent timed out.' : 'You Lost! Time\'s up.';
          statusColor = youWon ? Colors.green : Colors.red;
          break;
      }

      // ✅ Show dialog instead of automatic navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showGameEndDialog(gameProvider, youWon);
        }
      });
      // // Add navigation delay when game ends
      // Future.delayed(const Duration(seconds: 2), () {
      //   if (mounted) {
      //     Navigator.of(context).pushAndRemoveUntil(
      //         MaterialPageRoute(builder: (context) => BottomNavBar()),
      //         (route) => false); // Navigate to dashboard and clear stack
      //   }
      // });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        border: Border(top: BorderSide(color: statusColor, width: 2)),
      ),
      child: Text(
        statusText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

// Add this new method for the game end dialog
  void _showGameEndDialog(ChessGameProvider gameProvider, bool youWon) {
    // Prevent multiple dialogs
    if (_isShowingGameEndDialog) return;
    _isShowingGameEndDialog = true;

    showDialog(
      context: context,
      barrierDismissible: false, // Must tap OK to dismiss
      builder: (BuildContext context) {
        return GameEndDialog(
          gameProvider: gameProvider,
          youWon: youWon,
          player1Name: player1Name ?? 'Player 1',
          player2Name: player2Name ?? 'Player 2',
          roomCode: widget.roomCode,
          onOkPressed: () {
            Navigator.of(context).pop(); // Close dialog
            // Clean up game state
            final provider =
                Provider.of<ChessGameProvider>(context, listen: false);
            provider.resetGameState();
            // Navigate to home
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const BottomNavBar()),
              (route) => false,
            );
          },
        );
      },
    );
  }

// Add this flag to prevent multiple dialogs
  bool _isShowingGameEndDialog = false;

  void _showGameMenu(BuildContext context,
      {required int moveCountWhite, required int moveCountBlack}) {
    print("🎮 GameScreen: Opening game menu");
    final bool canAbort = moveCountWhite == 0 || moveCountBlack == 0;
    final bool canResign = moveCountWhite > 0 && moveCountBlack > 0;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canAbort)
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Abort'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmAbort();
                  },
                ),
              if (canResign)
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Resign'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmResign();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.handshake),
                title: const Text('Offer Draw'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDraw();
                },
              ),
              // ListTile(
              //   leading: const Icon(Icons.exit_to_app),
              //   title: const Text('Leave Game'),
              //   onTap: () {
              //     Navigator.pop(context);
              //     _confirmLeaveGame();
              //   },
              // ),
            ],
          ),
        );
      },
    );
  }

  void _confirmResign() {
    print("🎮 GameScreen: Showing resign confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resign Game'),
          content: const Text('Are you sure you want to resign?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print("🎮 GameScreen: Player confirmed resignation");
                _gameProvider.resignGame();
              },
              child: const Text('Resign'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDraw() {
    print("🎮 GameScreen: Showing draw offer confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Offer Draw'),
          content: const Text('Do you want to offer a draw to your opponent?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print("🎮 GameScreen: Player confirmed draw offer");
                _offerDraw();
              },
              child: const Text('Offer Draw'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _offerDraw() async {
    print("🎮 GameScreen: Offering draw to opponent");
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Update game document to indicate draw offer
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      await gameCollection.doc(widget.roomCode).update({
        'drawOfferedBy': currentUser.uid,
        'drawOfferedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw offer sent to opponent'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print("❌ GameScreen: Error offering draw: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send draw offer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDrawOfferDialog() {
    print("🎮 GameScreen: Showing draw offer dialog");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Draw Offer'),
          content:
              Text('${_getOpponentName()} has offered a draw. Do you accept?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectDraw();
              },
              child: const Text('Reject'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptDraw();
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptDraw() async {
    print("🎮 GameScreen: Accepting draw offer");
    try {
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      await gameCollection.doc(widget.roomCode).update({
        'gameStatus': 'draw',
        'winner': null,
        'drawAcceptedBy': FirebaseAuth.instance.currentUser?.uid,
        'drawAcceptedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw accepted! Game ended in a draw.'),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (e) {
      print("❌ GameScreen: Error accepting draw: $e");
    } finally {
      _isShowingDrawOfferDialog = false;
    }
  }

  Future<void> _rejectDraw() async {
    print("🎮 GameScreen: Rejecting draw offer");
    try {
      CollectionReference<Map<String, dynamic>> gameCollection;
      if (widget.tournamentId != null) {
        gameCollection = FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId!)
            .collection('matches');
      } else {
        gameCollection = FirebaseFirestore.instance.collection('games');
      }

      await gameCollection.doc(widget.roomCode).update({
        'drawOfferedBy': null,
        'drawOfferedAt': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw offer rejected. Game continues.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print("❌ GameScreen: Error rejecting draw: $e");
    } finally {
      _isShowingDrawOfferDialog = false;
    }
  }

  // void _confirmLeaveGame() {
  //   print("🎮 GameScreen: Showing leave game confirmation dialog");
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Leave Game'),
  //         content: Text(
  //             "If you leave, your opponent (${_getOpponentName()}) will win the match.\nAre you sure you want to exit?"),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               print(
  //                   "🎮 GameScreen: Player confirmed leave , that will going to call resign");
  //               _gameProvider.resignGame();
  //             },
  //             child: const Text('Yes, Exit'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _showPromotionDialog(ChessGameProvider gameProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final pieceColor = gameProvider.playerColor;
        return AlertDialog(
          title: const Text('Choose Promotion Piece'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPromotionPiece(PieceType.queen, pieceColor!, gameProvider),
              _buildPromotionPiece(PieceType.rook, pieceColor, gameProvider),
              _buildPromotionPiece(PieceType.bishop, pieceColor, gameProvider),
              _buildPromotionPiece(PieceType.knight, pieceColor, gameProvider),
            ],
          ),
        );
      },
    ).then((_) {
      _isShowingPromotionDialog = false;
    });
  }

  Widget _buildPromotionPiece(
    PieceType type,
    PieceColor color,
    ChessGameProvider gameProvider,
  ) {
    final imagePath = _getPieceImagePath(ChessPiece(type: type, color: color));
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        gameProvider.handlePromotion(type);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown),
          color: Colors.white,
        ),
        child: Center(
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            width: 40,
            height: 40,
          ),
        ),
      ),
    );
  }

  void _confirmAbort() {
    print("🎮 GameScreen: Showing abort confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Abort Game'),
          content: const Text('Are you sure you want to abort the game?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print("🎮 GameScreen: Player confirmed abort");
                // Implement abort logic here (e.g., update Firestore, end game as aborted)
                _gameProvider.abortGame();
              },
              child: const Text('Abort'),
            ),
          ],
        );
      },
    );
  }
}

// models/chess_piece.dart
class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  // Convert to map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'color': color.toString().split('.').last,
      'hasMoved': hasMoved,
    };
  }

  // Create from map for Firebase
  static ChessPiece? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return ChessPiece(
      type: PieceType.values
          .firstWhere((e) => e.toString().split('.').last == map['type']),
      color: PieceColor.values
          .firstWhere((e) => e.toString().split('.').last == map['color']),
      hasMoved: map['hasMoved'] ?? false,
    );
  }

  ChessPiece copyWith({bool? hasMoved}) {
    return ChessPiece(
      type: type,
      color: color,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }
}

enum PieceType { king, queen, rook, bishop, knight, pawn }

enum PieceColor { white, black }

// models/chess_position.dart
class ChessPosition {
  final int row;
  final int col;

  const ChessPosition(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChessPosition && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  bool isValid() {
    return row >= 0 && row < 8 && col >= 0 && col < 8;
  }

  Map<String, dynamic> toMap() {
    return {'row': row, 'col': col};
  }

  static ChessPosition fromMap(Map<String, dynamic> map) {
    return ChessPosition(map['row'], map['col']);
  }
}

// models/chess_move.dart
class ChessMove {
  final ChessPosition from;
  final ChessPosition to;
  final ChessPiece piece;
  final ChessPiece? capturedPiece;
  final DateTime timestamp;
  final String playerId;

  ChessMove({
    required this.from,
    required this.to,
    required this.piece,
    this.capturedPiece,
    required this.timestamp,
    required this.playerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'from': from.toMap(),
      'to': to.toMap(),
      'piece': piece.toMap(),
      'capturedPiece': capturedPiece?.toMap(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'playerId': playerId,
    };
  }

  static ChessMove fromMap(Map<String, dynamic> map) {
    return ChessMove(
      from: ChessPosition.fromMap(map['from']),
      to: ChessPosition.fromMap(map['to']),
      piece: ChessPiece.fromMap(map['piece'])!,
      capturedPiece: ChessPiece.fromMap(map['capturedPiece']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      playerId: map['playerId'],
    );
  }
}
