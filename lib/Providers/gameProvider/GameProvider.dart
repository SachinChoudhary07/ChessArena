import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../../Screens/GameScreens/GamePlay.dart';

class ChessGameProvider with ChangeNotifier {
  // Game state
  List<List<ChessPiece?>> _board = [];
  PieceColor _currentPlayer = PieceColor.white;
  List<ChessPosition> _possibleMoves = [];
  ChessPosition? _selectedPosition;
  String? _gameStatus; // 'playing', 'checkmate', 'stalemate', 'draw'
  String? _winner;

  // Room and player info
  late String _roomCode;
  late String _playerId;
  PieceColor? _playerColor;
  String? _opponentId;

  // Timers
  int _whiteTimeLeft = 600; // 10 minutes in seconds
  int _blackTimeLeft = 600;
  Timer? _gameTimer;
  DateTime? _lastMoveTime;

  bool isLoading = false;

  void setLoading(bool value) {
    // isLoading = value;
    // notifyListeners();
  }

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _gameSubscription;

  // Getters
  List<List<ChessPiece?>> get board => _board;

  PieceColor get currentPlayer => _currentPlayer;

  List<ChessPosition> get possibleMoves => _possibleMoves;

  ChessPosition? get selectedPosition => _selectedPosition;

  String? get gameStatus => _gameStatus;

  String? get winner => _winner;

  PieceColor? get playerColor => _playerColor;

  int get whiteTimeLeft => _whiteTimeLeft;

  int get blackTimeLeft => _blackTimeLeft;

  bool get isMyTurn => _currentPlayer == _playerColor;

  // Initialize the chess game
  void initializeGame(
      String roomCode, String playerId, PieceColor playerColor) {
    _roomCode = roomCode;
    _playerId = playerId;
    _playerColor = playerColor;
    // _initializeBoard();
    _listenToGameUpdates();
    _startTimer();
    notifyListeners();
  }

  // Initialize the chess board with starting positions
  void initializeBoard() {
    print("_InitializeBoard Called ---------------->>>>>>>>>>>>");
    _board = List.generate(8, (row) => List.generate(8, (col) => null));

    // Place pieces in starting positions
    _placePiece(
        0, 0, ChessPiece(type: PieceType.rook, color: PieceColor.black));
    _placePiece(
        0, 1, ChessPiece(type: PieceType.knight, color: PieceColor.black));
    _placePiece(
        0, 2, ChessPiece(type: PieceType.bishop, color: PieceColor.black));
    _placePiece(
        0, 3, ChessPiece(type: PieceType.queen, color: PieceColor.black));
    _placePiece(
        0, 4, ChessPiece(type: PieceType.king, color: PieceColor.black));
    _placePiece(
        0, 5, ChessPiece(type: PieceType.bishop, color: PieceColor.black));
    _placePiece(
        0, 6, ChessPiece(type: PieceType.knight, color: PieceColor.black));
    _placePiece(
        0, 7, ChessPiece(type: PieceType.rook, color: PieceColor.black));

    for (int col = 0; col < 8; col++) {
      _placePiece(
          1, col, ChessPiece(type: PieceType.pawn, color: PieceColor.black));
    }

    _placePiece(
        7, 0, ChessPiece(type: PieceType.rook, color: PieceColor.white));
    _placePiece(
        7, 1, ChessPiece(type: PieceType.knight, color: PieceColor.white));
    _placePiece(
        7, 2, ChessPiece(type: PieceType.bishop, color: PieceColor.white));
    _placePiece(
        7, 3, ChessPiece(type: PieceType.queen, color: PieceColor.white));
    _placePiece(
        7, 4, ChessPiece(type: PieceType.king, color: PieceColor.white));
    _placePiece(
        7, 5, ChessPiece(type: PieceType.bishop, color: PieceColor.white));
    _placePiece(
        7, 6, ChessPiece(type: PieceType.knight, color: PieceColor.white));
    _placePiece(
        7, 7, ChessPiece(type: PieceType.rook, color: PieceColor.white));

    for (int col = 0; col < 8; col++) {
      _placePiece(
          6, col, ChessPiece(type: PieceType.pawn, color: PieceColor.white));
    }
  }

  void _placePiece(int row, int col, ChessPiece piece) {
    _board[row][col] = piece;
  }

  // Listen to game updates from Firebase
  void _listenToGameUpdates() {
    _gameSubscription = _firestore
        .collection('games')
        .doc(_roomCode)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _updateGameFromFirestore(data);
      }
    });
  }

  // Update local game state from Firestore data
  void _updateGameFromFirestore(Map<String, dynamic> data) {
    if (data['boardState'] != null) {
      final boardData = data['boardState'] as Map<String, dynamic>;
      for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
          final key = '$row-$col';
          final pieceMap = boardData[key];
          if (pieceMap != null) {
            _board[row][col] = ChessPiece.fromMap(pieceMap);
          } else {
            _board[row][col] = null; // or some default empty piece
          }
        }
      }
    }

    // Update game state
    _currentPlayer =
        data['currentPlayer'] == 'white' ? PieceColor.white : PieceColor.black;
    _gameStatus = data['gameStatus'];
    _winner = data['winner'];
    _whiteTimeLeft = data['whiteTimeLeft'] ?? 600;
    _blackTimeLeft = data['blackTimeLeft'] ?? 600;

    // Update opponent info
    if (data['player1'] != _playerId) {
      _opponentId = data['player1'];
    } else {
      _opponentId = data['player2'];
    }

    notifyListeners();
  }

  // Start the game timer
  void _startTimer() {
    _gameTimer?.cancel();
    _lastMoveTime = DateTime.now();

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameStatus == 'playing') {
        if (_currentPlayer == PieceColor.white) {
          _whiteTimeLeft--;
          if (_whiteTimeLeft <= 0) {
            _endGame('black', 'timeout');
          }
        } else {
          _blackTimeLeft--;
          if (_blackTimeLeft <= 0) {
            _endGame('white', 'timeout');
          }
        }
        _updateTimersInFirestore();
        notifyListeners();
      }
    });
  }

  // Handle piece selection and moves
  void onSquareTapped(int row, int col) {
    if (!isMyTurn || _gameStatus != 'playing') return;

    final position = ChessPosition(row, col);
    final piece = _board[row][col];

    // If no piece is selected
    if (_selectedPosition == null) {
      if (piece != null && piece.color == _playerColor) {
        _selectedPosition = position;
        _possibleMoves = _calculatePossibleMoves(position);
        notifyListeners();
      }
    } else {
      // If same piece is tapped again, deselect
      if (_selectedPosition == position) {
        _selectedPosition = null;
        _possibleMoves = [];
        notifyListeners();
        return;
      }

      // If a valid move is selected
      if (_possibleMoves.contains(position)) {
        _makeMove(_selectedPosition!, position);
      } else if (piece != null && piece.color == _playerColor) {
        // Select a different piece
        _selectedPosition = position;
        _possibleMoves = _calculatePossibleMoves(position);
        notifyListeners();
      } else {
        // Invalid move, deselect
        _selectedPosition = null;
        _possibleMoves = [];
        notifyListeners();
      }
    }
  }

  // Calculate possible moves for a piece
  List<ChessPosition> _calculatePossibleMoves(ChessPosition position) {
    final piece = _board[position.row][position.col];
    if (piece == null) return [];

    List<ChessPosition> moves = [];

    switch (piece.type) {
      case PieceType.pawn:
        moves = _calculatePawnMoves(position, piece);
        break;
      case PieceType.rook:
        moves = _calculateRookMoves(position, piece);
        break;
      case PieceType.knight:
        moves = _calculateKnightMoves(position, piece);
        break;
      case PieceType.bishop:
        moves = _calculateBishopMoves(position, piece);
        break;
      case PieceType.queen:
        moves = _calculateQueenMoves(position, piece);
        break;
      case PieceType.king:
        moves = _calculateKingMoves(position, piece);
        break;
    }

    // Filter out moves that would put own king in check
    return moves
        .where((move) => !_wouldBeInCheckAfterMove(position, move))
        .toList();
  }

  // Calculate pawn moves
  List<ChessPosition> _calculatePawnMoves(
      ChessPosition position, ChessPiece piece) {
    List<ChessPosition> moves = [];
    final direction = piece.color == PieceColor.white ? -1 : 1;
    final startRow = piece.color == PieceColor.white ? 6 : 1;

    // Forward move
    final oneForward = ChessPosition(position.row + direction, position.col);
    if (oneForward.isValid() &&
        _board[oneForward.row][oneForward.col] == null) {
      moves.add(oneForward);

      // Two squares forward from starting position
      if (position.row == startRow) {
        final twoForward =
            ChessPosition(position.row + 2 * direction, position.col);
        if (twoForward.isValid() &&
            _board[twoForward.row][twoForward.col] == null) {
          moves.add(twoForward);
        }
      }
    }

    // Diagonal captures
    for (int colOffset in [-1, 1]) {
      final capturePos =
          ChessPosition(position.row + direction, position.col + colOffset);
      if (capturePos.isValid()) {
        final targetPiece = _board[capturePos.row][capturePos.col];
        if (targetPiece != null && targetPiece.color != piece.color) {
          moves.add(capturePos);
        }
      }
    }

    return moves;
  }

  // Calculate rook moves
  List<ChessPosition> _calculateRookMoves(
      ChessPosition position, ChessPiece piece) {
    List<ChessPosition> moves = [];

    // Horizontal and vertical directions
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];

    for (final direction in directions) {
      for (int i = 1; i < 8; i++) {
        final newRow = position.row + direction[0] * i;
        final newCol = position.col + direction[1] * i;
        final newPos = ChessPosition(newRow, newCol);

        if (!newPos.isValid()) break;

        final targetPiece = _board[newRow][newCol];
        if (targetPiece == null) {
          moves.add(newPos);
        } else {
          if (targetPiece.color != piece.color) {
            moves.add(newPos);
          }
          break; // Stop at any piece
        }
      }
    }

    return moves;
  }

  // Calculate knight moves
  List<ChessPosition> _calculateKnightMoves(
      ChessPosition position, ChessPiece piece) {
    List<ChessPosition> moves = [];

    final knightMoves = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1]
    ];

    for (final move in knightMoves) {
      final newPos =
          ChessPosition(position.row + move[0], position.col + move[1]);
      if (newPos.isValid()) {
        final targetPiece = _board[newPos.row][newPos.col];
        if (targetPiece == null || targetPiece.color != piece.color) {
          moves.add(newPos);
        }
      }
    }

    return moves;
  }

  // Calculate bishop moves
  List<ChessPosition> _calculateBishopMoves(
      ChessPosition position, ChessPiece piece) {
    List<ChessPosition> moves = [];

    // Diagonal directions
    final directions = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1]
    ];

    for (final direction in directions) {
      for (int i = 1; i < 8; i++) {
        final newRow = position.row + direction[0] * i;
        final newCol = position.col + direction[1] * i;
        final newPos = ChessPosition(newRow, newCol);

        if (!newPos.isValid()) break;

        final targetPiece = _board[newRow][newCol];
        if (targetPiece == null) {
          moves.add(newPos);
        } else {
          if (targetPiece.color != piece.color) {
            moves.add(newPos);
          }
          break;
        }
      }
    }

    return moves;
  }

  // Calculate queen moves (combination of rook and bishop)
  List<ChessPosition> _calculateQueenMoves(
      ChessPosition position, ChessPiece piece) {
    return [
      ..._calculateRookMoves(position, piece),
      ..._calculateBishopMoves(position, piece),
    ];
  }

  // Calculate king moves
  List<ChessPosition> _calculateKingMoves(
      ChessPosition position, ChessPiece piece) {
    List<ChessPosition> moves = [];

    for (int rowOffset = -1; rowOffset <= 1; rowOffset++) {
      for (int colOffset = -1; colOffset <= 1; colOffset++) {
        if (rowOffset == 0 && colOffset == 0) continue;

        final newPos =
            ChessPosition(position.row + rowOffset, position.col + colOffset);
        if (newPos.isValid()) {
          final targetPiece = _board[newPos.row][newPos.col];
          if (targetPiece == null || targetPiece.color != piece.color) {
            moves.add(newPos);
          }
        }
      }
    }

    return moves;
  }

  // Check if a move would result in own king being in check
  bool _wouldBeInCheckAfterMove(ChessPosition from, ChessPosition to) {
    // Make temporary move
    final originalPiece = _board[to.row][to.col];
    final movingPiece = _board[from.row][from.col];

    _board[to.row][to.col] = movingPiece;
    _board[from.row][from.col] = null;

    // Check if king is in check
    final isInCheck = _isKingInCheck(movingPiece!.color);

    // Restore original position
    _board[from.row][from.col] = movingPiece;
    _board[to.row][to.col] = originalPiece;

    return isInCheck;
  }

  // Check if a king is in check
  bool _isKingInCheck(PieceColor kingColor) {
    // Find king position
    ChessPosition? kingPosition;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.color == kingColor) {
          kingPosition = ChessPosition(row, col);
          break;
        }
      }
      if (kingPosition != null) break;
    }

    if (kingPosition == null) return false;

    // Check if any opponent piece can attack the king
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece != null && piece.color != kingColor) {
          final attacks =
              _calculateAttackSquares(ChessPosition(row, col), piece);
          if (attacks.contains(kingPosition)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  // Calculate squares that a piece attacks (similar to possible moves but ignores check)
  List<ChessPosition> _calculateAttackSquares(
      ChessPosition position, ChessPiece piece) {
    // Similar to _calculatePossibleMoves but without the check validation
    // This is used internally for check detection
    switch (piece.type) {
      case PieceType.pawn:
        return _calculatePawnAttacks(position, piece);
      case PieceType.rook:
        return _calculateRookMoves(position, piece);
      case PieceType.knight:
        return _calculateKnightMoves(position, piece);
      case PieceType.bishop:
        return _calculateBishopMoves(position, piece);
      case PieceType.queen:
        return _calculateQueenMoves(position, piece);
      case PieceType.king:
        return _calculateKingMoves(position, piece);
    }
  }

  // Calculate pawn attacks (only diagonal, not forward moves)
  List<ChessPosition> _calculatePawnAttacks(
      ChessPosition position, ChessPiece piece) {
    List<ChessPosition> attacks = [];
    final direction = piece.color == PieceColor.white ? -1 : 1;

    for (int colOffset in [-1, 1]) {
      final attackPos =
          ChessPosition(position.row + direction, position.col + colOffset);
      if (attackPos.isValid()) {
        attacks.add(attackPos);
      }
    }

    return attacks;
  }

  // Make a move
  void _makeMove(ChessPosition from, ChessPosition to) {
    final movingPiece = _board[from.row][from.col];
    final capturedPiece = _board[to.row][to.col];

    if (movingPiece == null) return;

    // Create the move
    final move = ChessMove(
      from: from,
      to: to,
      piece: movingPiece,
      capturedPiece: capturedPiece,
      timestamp: DateTime.now(),
      playerId: _playerId,
    );

    // Update board locally
    _board[to.row][to.col] = movingPiece.copyWith(hasMoved: true);
    _board[from.row][from.col] = null;

    // Switch turns
    _currentPlayer = _currentPlayer == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;

    // Clear selection
    _selectedPosition = null;
    _possibleMoves = [];

    // Check for game end conditions
    _checkGameEndConditions();

    // Update Firebase
    _updateGameInFirestore(move);

    notifyListeners();
  }

  // Check for checkmate, stalemate, etc.
  void _checkGameEndConditions() {
    final currentPlayerHasMoves = _hasValidMoves(_currentPlayer);
    final isInCheck = _isKingInCheck(_currentPlayer);

    if (!currentPlayerHasMoves) {
      if (isInCheck) {
        // Checkmate
        final winner = _currentPlayer == PieceColor.white ? 'black' : 'white';
        _endGame(winner, 'checkmate');
      } else {
        // Stalemate
        _endGame(null, 'stalemate');
      }
    }
  }

  // Check if a player has any valid moves
  bool _hasValidMoves(PieceColor color) {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece != null && piece.color == color) {
          final moves = _calculatePossibleMoves(ChessPosition(row, col));
          if (moves.isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // End the game
  void _endGame(String? winner, String reason) {
    _gameStatus = reason;
    _winner = winner;
    _gameTimer?.cancel();

    // Update Firebase with final game state
    _updateGameInFirestore(null);
  }

  // Update game state in Firestore
  void _updateGameInFirestore(ChessMove? move) {
    final Map<String, dynamic> boardState = {};

    for (int row = 0; row < _board.length; row++) {
      for (int col = 0; col < _board[row].length; col++) {
        final piece = _board[row][col];
        if (piece != null) {
          boardState['$row-$col'] = piece.toMap();
        }
      }
    }

    final data = {
      'boardState': boardState,
      'currentPlayer': _currentPlayer.toString().split('.').last,
      'gameStatus': _gameStatus ?? 'playing',
      'winner': _winner,
      'whiteTimeLeft': _whiteTimeLeft,
      'blackTimeLeft': _blackTimeLeft,
      'lastMove': move?.toMap(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    _firestore.collection('games').doc(_roomCode).update(data);
  }

  // Update timers in Firestore
  void _updateTimersInFirestore() {
    _firestore.collection('games').doc(_roomCode).update({
      'whiteTimeLeft': _whiteTimeLeft,
      'blackTimeLeft': _blackTimeLeft,
    });
  }

  // Resign game
  void resignGame() {
    final winner = _playerColor == PieceColor.white ? 'black' : 'white';
    _endGame(winner, 'resignation');
  }

  // Offer draw (simplified - auto accept for now)
  void offerDraw() {
    _endGame(null, 'draw');
  }

  // Format time for display
  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _gameSubscription?.cancel();
    super.dispose();
  }
}
