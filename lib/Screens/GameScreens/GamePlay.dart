import 'package:chess_cash/Providers/gameProvider/GameProvider.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Widgets/GameEndDialog.dart';

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
  bool _isInitialized = false;
  bool _isShowingPromotionDialog = false;

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
    // _gameProvider.dispose();
    super.dispose();
  }

  String? player1Name;
  String? player2Name;
  String? gameName = '';

  Future<void> _initializeGame() async {
    print("🎮 GameScreen: Starting game initialization");
    _gameProvider = Provider.of<ChessGameProvider>(context, listen: false);
    _gameProvider.initializeBoard();

    _gameProvider.setLoading(true);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      print("🎮 GameScreen: Fetching game data for room ${widget.roomCode}");
      final gameDoc = await FirebaseFirestore.instance
          .collection(widget.tournamentId != null
              ? 'tournaments/${widget.tournamentId}/matches' // Tournament match path
              : 'games') // Regular game path
          .doc(widget.roomCode)
          .get();

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
    print("🎮 GameScreen: Back button pressed, showing confirmation dialog");
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Match?"),
        content: Text(
          "If you leave, your opponent (${_getOpponentName()}) will win the match.\nAre you sure you want to exit?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Exit"),
          ),
        ],
      ),
    );

    if (result == true) {
      print("🎮 GameScreen: User confirmed exit, handling player exit");
      await _handlePlayerExit();
      return true;
    }

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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$gameName - ${widget.roomCode}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showGameMenu(context),
            ),
          ],
        ),
        body: Consumer<ChessGameProvider>(
          builder: (context, gameProvider, child) {
            if (gameProvider.isLoading) {
              return Loader();
            }

            // Show promotion dialog if needed
            if (gameProvider.isPromotionPending && !_isShowingPromotionDialog) {
              _isShowingPromotionDialog = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showPromotionDialog(gameProvider);
              });
            }

            return Column(
              children: [
                // Opponent info and timer
                _buildPlayerInfo(
                  isOpponent: true,
                  timeLeft: gameProvider.playerColor == PieceColor.white
                      ? gameProvider.blackTimeLeft
                      : gameProvider.whiteTimeLeft,
                  isActive: !gameProvider.isMyTurn,
                ),

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

                // Game status
                _buildGameStatus(gameProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerInfo({
    required bool isOpponent,
    required int timeLeft,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isOpponent
                ? (Provider.of<ChessGameProvider>(context, listen: false)
                            .playerColor ==
                        PieceColor.white
                    ? (player2Name ?? 'Opponent')
                    : (player1Name ?? 'Opponent'))
                : (Provider.of<ChessGameProvider>(context, listen: false)
                            .playerColor ==
                        PieceColor.white
                    ? (player1Name ?? 'You')
                    : (player2Name ?? 'You')),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: timeLeft < 60 ? Colors.red : Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              Provider.of<ChessGameProvider>(context, listen: false)
                  .formatTime(timeLeft),
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

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown, width: 4),
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

          return GestureDetector(
            onTap: () => gameProvider.onSquareTapped(row, col),
            child: Container(
              decoration: BoxDecoration(
                color:
                    _getSquareColor(isWhiteSquare, isSelected, isPossibleMove),
                border: isPossibleMove
                    ? Border.all(color: Colors.yellow, width: 3)
                    : null,
              ),
              child: Center(
                child: piece != null
                    ? _buildPieceWidget(piece)
                    : isPossibleMove
                        ? Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.yellow,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getSquareColor(
      bool isWhiteSquare, bool isSelected, bool isPossibleMove) {
    if (isSelected) return Colors.blue;
    if (isPossibleMove) return Colors.green;
    return isWhiteSquare ? Colors.white : Colors.brown[300]!;
  }

  Widget _buildPieceWidget(ChessPiece piece) {
    final pieceSymbol = _getPieceSymbol(piece);
    return Text(
      pieceSymbol,
      style: TextStyle(
        fontSize: 32,
        color: piece.color == PieceColor.white ? Colors.white : Colors.black,
        shadows: piece.color == PieceColor.white
            ? [const Shadow(color: Colors.black, blurRadius: 2)]
            : [const Shadow(color: Colors.white, blurRadius: 2)],
      ),
    );
  }

  String _getPieceSymbol(ChessPiece piece) {
    final isWhite = piece.color == PieceColor.white;
    switch (piece.type) {
      case PieceType.king:
        return isWhite ? '♔' : '♚';
      case PieceType.queen:
        return isWhite ? '♕' : '♛';
      case PieceType.rook:
        return isWhite ? '♖' : '♜';
      case PieceType.bishop:
        return isWhite ? '♗' : '♝';
      case PieceType.knight:
        return isWhite ? '♘' : '♞';
      case PieceType.pawn:
        return isWhite ? '♙' : '♟';
    }
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
              MaterialPageRoute(builder: (context) => BottomNavBar()),
              (route) => false,
            );
          },
        );
      },
    );
  }

// Add this flag to prevent multiple dialogs
  bool _isShowingGameEndDialog = false;

  void _showGameMenu(BuildContext context) {
    print("🎮 GameScreen: Opening game menu");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Resign'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmResign();
                },
              ),
              // ListTile(
              //   leading: const Icon(Icons.handshake),
              //   title: const Text('Offer Draw'),
              //   onTap: () {
              //     Navigator.pop(context);
              //     _confirmDraw();
              //   },
              // ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Leave Game'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLeaveGame();
                },
              ),
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
          content: const Text('Do you want to offer a draw?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                print("🎮 GameScreen: Player confirmed draw offer");
                _gameProvider.offerDraw();
              },
              child: const Text('Offer Draw'),
            ),
          ],
        );
      },
    );
  }

  void _confirmLeaveGame() {
    print("🎮 GameScreen: Showing leave game confirmation dialog");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Game'),
          content: Text(
              "If you leave, your opponent (${_getOpponentName()}) will win the match.\nAre you sure you want to exit?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                print(
                    "🎮 GameScreen: Player confirmed leave , that will going to call resign");
                _gameProvider.resignGame();
              },
              child: const Text('Yes, Exit'),
            ),
          ],
        );
      },
    );
  }

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
          child: Text(
            _getPieceSymbol(ChessPiece(type: type, color: color)),
            style: TextStyle(
              fontSize: 32,
              color: color == PieceColor.white ? Colors.white : Colors.black,
              shadows: color == PieceColor.white
                  ? [const Shadow(color: Colors.black, blurRadius: 2)]
                  : [const Shadow(color: Colors.white, blurRadius: 2)],
            ),
          ),
        ),
      ),
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
