import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../../Screens/GameScreens/GamePlay.dart';
import '../../Models/chat_message.dart';

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

  // Add this at class level
  Function(PieceType)? _onPromotionSelected;
  bool _isPromotionPending = false;
  ChessPosition? _promotionFrom;
  ChessPosition? _promotionTo;

  int? _currentRound;
  int? _currentMatchNumber;

  // Balance update tracking to prevent duplicates
  bool _balanceUpdated = false;
  bool _statsUpdated = false;

  // Threefold repetition tracking
  final Map<String, int> _positionCounts = {};

  // -------------------------------------------------
  // Latest chat support (single, overwriting message)
  // -------------------------------------------------
  List<ChatMessage> _chatMessages = [];
  List<ChatMessage> get chatMessages => _chatMessages;

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

  String? _tournamentId;

  String? get tournamentId => _tournamentId;

  // Getter to expose position of king currently in check (if any)
  ChessPosition? get kingInCheck {
    if (_isKingInCheck(PieceColor.white)) {
      return _findKingPosition(PieceColor.white);
    }
    if (_isKingInCheck(PieceColor.black)) {
      return _findKingPosition(PieceColor.black);
    }
    return null;
  }

  ChessPosition? _findKingPosition(PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = _board[r][c];
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.color == color) {
          return ChessPosition(r, c);
        }
      }
    }
    return null;
  }

  // Initialize the chess game
  void initializeGame(String roomCode, String playerId, PieceColor playerColor,
      {String? tournamentId, int? round, int? matchNumber}) {
    print(
        "🎲 GameProvider: Initializing game - Room: $roomCode, Player: $playerId, Color: $playerColor");

    // Reset previous game state first
    resetGameState();

    _roomCode = roomCode;
    _playerId = playerId;
    _playerColor = playerColor;
    _tournamentId = tournamentId;
    _currentRound = round;
    _currentMatchNumber = matchNumber;
    _listenToGameUpdates();
    _startTimer();
    notifyListeners();
  }

  // Initialize the chess board with starting positions
  void initializeBoard() {
    print("🎲 GameProvider: Initializing chess board");
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
    print("🎲 GameProvider: Chess board initialized with starting positions");
  }

  void _placePiece(int row, int col, ChessPiece piece) {
    _board[row][col] = piece;
  }

  // Listen to game updates from Firebase
  void _listenToGameUpdates() {
    print(
        "🎲 GameProvider: Starting game updates listener for room: $_roomCode");

    // ✅ IMPORTANT: Cancel existing subscription first
    _gameSubscription?.cancel();

    final docRef = tournamentId != null
        ? _firestore
            .collection('tournaments')
            .doc(tournamentId!)
            .collection('matches')
            .doc(_roomCode)
        : _firestore.collection('games').doc(_roomCode);

    _gameSubscription = docRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        print("🎲 GameProvider: Received game update for room: $_roomCode");
        final data = snapshot.data() as Map<String, dynamic>;
        _updateGameFromFirestore(data);
      } else {
        print(
            "⚠️ GameProvider: Game document does not exist for room: $_roomCode");
      }
    }, onError: (error) {
      print("❌ GameProvider: Error in game listener: $error");
    });
  }

  // Update local game state from Firestore data
  void _updateGameFromFirestore(Map<String, dynamic> data) {
    print("🎲 GameProvider: Updating game state from Firestore");
    if (data['boardState'] != null) {
      print("🎲 GameProvider: Updating board state");
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

    // -------------------------------
    // Latest chat parsing
    // -------------------------------
    print("🎲 GameProvider: Chat data from Firestore: ${data['chatMessages']}");

    // Initialize chatMessages if it doesn't exist
    if (data['chatMessages'] == null) {
      print("🎲 GameProvider: No chatMessages field found, initializing empty array");
      _chatMessages = [];
    } else {
      try {
        final chatData = data['chatMessages'];
        if (chatData is List) {
          final chatList = List<Map<String, dynamic>>.from(chatData);
          final newMessages = chatList.map((msg) => ChatMessage.fromMap(msg)).toList();

          print("🎲 GameProvider: New messages count: ${newMessages.length}, Current messages count: ${_chatMessages.length}");

          // Simply update messages
          _chatMessages = newMessages;
          print("🎲 GameProvider: Final message count: ${_chatMessages.length}");
        } else {
          print("⚠️ GameProvider: chatMessages is not a List, it's: ${chatData.runtimeType}");
          _chatMessages = [];
        }
      } catch (e) {
        print("❌ GameProvider: Error parsing chat messages: $e");
        _chatMessages = [];
      }
    }

    // Update opponent info
    if (data['player1'] != _playerId) {
      _opponentId = data['player1'];
    } else {
      _opponentId = data['player2'];
    }

    print(
        "🎲 GameProvider: Game state updated - Current Player: $_currentPlayer, Status: $_gameStatus");
    if (_gameStatus != 'playing') {
      print(
          "🎲 GameProvider: Game ended - Winner: $_winner, Reason: $_gameStatus");

      // Handle game end conditions that might be set from UI
      if (_gameStatus == 'draw' && _winner == null) {
        print("🎲 GameProvider: Draw detected from UI - handling refund");
        
        // Check if balance has already been updated using Firestore
        if (data['balanceUpdated'] == true) {
          print("🎲 GameProvider: Balance already updated (from Firestore data), skipping draw refund");
        } else {
          _handleDrawRefund(_roomCode);
        }
      } else if (_winner != null && _gameStatus != 'draw') {
        // Handle win conditions (checkmate, stalemate, resignation, timeout)
        final winnerColor = _winner == 'white' ? PieceColor.white : PieceColor.black;
        print("🎲 GameProvider: Win detected from UI - handling prize distribution");
        print("🎲 GameProvider: _balanceUpdated flag in Firestore update: $_balanceUpdated");
        
        // Check if balance has already been updated using Firestore
        if (data['balanceUpdated'] == true) {
          print("🎲 GameProvider: Balance already updated (from Firestore data), skipping");
        } else {
          _updateWinnerBalance(winnerColor, _roomCode);
        }

        // Also update user stats and record game history (only once)
        if (!_statsUpdated) {
          print("🎲 GameProvider: Updating stats and history");
          _updateUserStats(_playerId, _playerColor == winnerColor);
          _updateUserStats(_opponentId!, _playerColor != winnerColor);
          _recordGameHistory(_playerId, _playerColor == winnerColor, _opponentId!);
          _recordGameHistory(_opponentId!, _playerColor != winnerColor, _playerId);
          _statsUpdated = true;
        } else {
          print("🎲 GameProvider: Stats already updated, skipping");
        }
      }
    }

    notifyListeners();
  }

  // Start the game timer
  void _startTimer() {
    print("🎲 GameProvider: Starting game timer");
    _gameTimer?.cancel();
    _lastMoveTime = DateTime.now();

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameStatus == 'playing') {
        if (_currentPlayer == PieceColor.white) {
          _whiteTimeLeft--;
          if (_whiteTimeLeft <= 0) {
            print("🎲 GameProvider: White player ran out of time");
            _endGame('black', 'timeout');
          }
        } else {
          _blackTimeLeft--;
          if (_blackTimeLeft <= 0) {
            print("🎲 GameProvider: Black player ran out of time");
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
    if (!isMyTurn || _gameStatus != 'playing') {
      print(
          "🎲 GameProvider: Invalid move - Not player's turn or game not active");
      return;
    }

    final position = ChessPosition(row, col);
    final piece = _board[row][col];

    print("🎲 GameProvider: Square tapped at row: $row, col: $col");

    if (_selectedPosition == null) {
      if (piece != null && piece.color == _playerColor) {
        _selectedPosition = position;
        _possibleMoves = _calculatePossibleMoves(position);
        print(
            "🎲 GameProvider: Piece selected - Type: ${piece.type}, Color: ${piece.color}");
        print(
            "🎲 GameProvider: Possible moves calculated: ${_possibleMoves.length}");
        notifyListeners();
      }
    } else {
      if (_selectedPosition == position) {
        print("🎲 GameProvider: Piece deselected");
        _selectedPosition = null;
        _possibleMoves = [];
        notifyListeners();
        return;
      }

      if (_possibleMoves.contains(position)) {
        print(
            "🎲 GameProvider: Making move from $_selectedPosition to $position");
        _makeMove(_selectedPosition!, position);
      } else if (piece != null && piece.color == _playerColor) {
        print("🎲 GameProvider: Selecting different piece");
        _selectedPosition = position;
        _possibleMoves = _calculatePossibleMoves(position);
        notifyListeners();
      } else {
        print("🎲 GameProvider: Invalid move - Deselecting piece");
        _selectedPosition = null;
        _possibleMoves = [];
        notifyListeners();
      }
    }
  }

  // Calculate possible moves for a piece
  List<ChessPosition> _calculatePossibleMoves(ChessPosition position) {
    final piece = _board[position.row][position.col];
    if (piece == null) {
      print(
          "❌ GameProvider: Attempted to calculate moves for empty square at $position");
      return [];
    }

    print(
        "🎲 GameProvider: Calculating moves for ${piece.type} at position $position");
    List<ChessPosition> moves = [];

    switch (piece.type) {
      case PieceType.pawn:
        moves = _calculatePawnMoves(position, piece);
        print("🎲 GameProvider: Found ${moves.length} potential pawn moves");
        break;
      case PieceType.rook:
        moves = _calculateRookMoves(position, piece);
        print("🎲 GameProvider: Found ${moves.length} potential rook moves");
        break;
      case PieceType.knight:
        moves = _calculateKnightMoves(position, piece);
        print("🎲 GameProvider: Found ${moves.length} potential knight moves");
        break;
      case PieceType.bishop:
        moves = _calculateBishopMoves(position, piece);
        print("🎲 GameProvider: Found ${moves.length} potential bishop moves");
        break;
      case PieceType.queen:
        moves = _calculateQueenMoves(position, piece);
        print("🎲 GameProvider: Found ${moves.length} potential queen moves");
        break;
      case PieceType.king:
        moves = _calculateKingMoves(position, piece);
        print("🎲 GameProvider: Found ${moves.length} potential king moves");
        break;
    }

    // Filter out moves that would put own king in check
    final validMoves = moves
        .where((move) => !_wouldBeInCheckAfterMove(position, move))
        .toList();
    print(
        "🎲 GameProvider: After check validation - ${validMoves.length} legal moves from ${moves.length} potential moves");

    if (validMoves.isEmpty && moves.isNotEmpty) {
      print("⚠️ GameProvider: All potential moves were blocked due to check");
    }

    return validMoves;
  }

  // Calculate pawn moves
  List<ChessPosition> _calculatePawnMoves(
      ChessPosition position, ChessPiece piece) {
    print(
        "🎲 GameProvider: Calculating pawn moves for ${piece.color} at row ${position.row}, col ${position.col}");
    List<ChessPosition> moves = [];
    final direction = piece.color == PieceColor.white ? -1 : 1;
    final startRow = piece.color == PieceColor.white ? 6 : 1;

    // Check if pawn has reached the last rank
    if ((piece.color == PieceColor.white && position.row == 0) ||
        (piece.color == PieceColor.black && position.row == 7)) {
      print("🎲 GameProvider: Pawn at promotion square - should be promoted");
      return moves; // No moves possible, should be promoted
    }

    // Forward move
    final oneForward = ChessPosition(position.row + direction, position.col);
    if (oneForward.isValid() &&
        _board[oneForward.row][oneForward.col] == null) {
      print(
          "🎲 GameProvider: Adding forward move to ${oneForward.row},${oneForward.col}");
      moves.add(oneForward);

      // Two squares forward from starting position
      if (position.row == startRow) {
        final twoForward =
            ChessPosition(position.row + 2 * direction, position.col);
        if (twoForward.isValid() &&
            _board[twoForward.row][twoForward.col] == null) {
          print(
              "🎲 GameProvider: Adding double forward move to ${twoForward.row},${twoForward.col}");
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
          print(
              "🎲 GameProvider: Adding diagonal capture move to ${capturePos.row},${capturePos.col}");
          moves.add(capturePos);
        }
      }
    }

    print("🎲 GameProvider: Found ${moves.length} possible moves for pawn");
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

    // ---------------------------
    // Castling moves (added)
    // ---------------------------
    // Only if king has not moved and king is not currently in check
    if (!piece.hasMoved && !_isKingInCheck(piece.color)) {
      // King-side castling (short) -> move king to G-file (col 6)
      if (_canCastle(piece.color, kingSide: true)) {
        moves.add(ChessPosition(position.row, 6));
      }

      // Queen-side castling (long) -> move king to C-file (col 2)
      if (_canCastle(piece.color, kingSide: false)) {
        moves.add(ChessPosition(position.row, 2));
      }
    }

    return moves;
  }

  // Check if a move would result in own king being in check
  bool _wouldBeInCheckAfterMove(ChessPosition from, ChessPosition to) {
    // Make temporary move
    final originalPiece = _board[to.row][to.col];
    var movingPiece = _board[from.row][from.col];

    _board[to.row][to.col] = movingPiece;
    _board[from.row][from.col] = null;

    // Check if king is in check
    final isInCheck = _isKingInCheck(movingPiece!.color);

    // Restore original position
    _board[from.row][from.col] = movingPiece;
    _board[to.row][to.col] = originalPiece;

    if (isInCheck) {
      print(
          "⚠️ GameProvider: Move from $from to $to would leave/put king in check");
    }

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
        // For attack purposes, king only controls adjacent squares; castling is not an attack
        List<ChessPosition> kingAttacks = [];
        for (int r = -1; r <= 1; r++) {
          for (int c = -1; c <= 1; c++) {
            if (r == 0 && c == 0) continue;
            final pos = ChessPosition(position.row + r, position.col + c);
            if (pos.isValid()) kingAttacks.add(pos);
          }
        }
        return kingAttacks;
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

  // Calculate queen moves (combination of rook and bishop)
  List<ChessPosition> _calculateQueenMoves(
      ChessPosition position, ChessPiece piece) {
    // Queen moves are the union of rook and bishop moves
    return [
      ..._calculateRookMoves(position, piece),
      ..._calculateBishopMoves(position, piece),
    ];
  }

  // Make a move
  Future<void> _makeMove(ChessPosition from, ChessPosition to) async {
    print("🎲 GameProvider: Processing move from $from to $to");
    var movingPiece = _board[from.row][from.col];
    final capturedPiece = _board[to.row][to.col];

    if (movingPiece == null) return;

    // -------------------------------------------------
    // Detect and execute CASTLING before other checks
    // -------------------------------------------------
    final bool isCastlingMove = movingPiece.type == PieceType.king &&
        from.row == to.row &&
        (from.col - to.col).abs() == 2;

    if (isCastlingMove) {
      _performCastling(from, to, movingPiece);
      return;
    }

    // Check for pawn promotion before making the move
    if (movingPiece.type == PieceType.pawn) {
      final isPromotion =
          (movingPiece.color == PieceColor.white && to.row == 0) ||
              (movingPiece.color == PieceColor.black && to.row == 7);

      if (isPromotion) {
        print("🎲 GameProvider: Pawn promotion pending at ${to.row},${to.col}");
        _isPromotionPending = true;
        _promotionFrom = from;
        _promotionTo = to;
        notifyListeners();
        return; // Don't complete the move until promotion is chosen
      }
    }

    _completeMoveAfterPromotion(from, to, movingPiece, capturedPiece);
  }

  // Complete the move after promotion (if any)
  void _completeMoveAfterPromotion(ChessPosition from, ChessPosition to,
      ChessPiece movingPiece, ChessPiece? capturedPiece,
      {PieceType? promotionType}) {
    if (promotionType != null) {
      print("🎲 GameProvider: Promoting pawn to $promotionType");
      movingPiece = ChessPiece(
          type: promotionType, color: movingPiece.color, hasMoved: true);
    }

    final move = ChessMove(
      from: from,
      to: to,
      piece: movingPiece,
      capturedPiece: capturedPiece,
      timestamp: DateTime.now(),
      playerId: _playerId,
    );

    _board[to.row][to.col] = movingPiece.copyWith(hasMoved: true);
    _board[from.row][from.col] = null;

    _currentPlayer = _currentPlayer == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;
    print("🎲 GameProvider: Turn changed to $_currentPlayer");

    _selectedPosition = null;
    _possibleMoves = [];
    _isPromotionPending = false;
    _promotionFrom = null;
    _promotionTo = null;

    _checkGameEndConditions();
    _updateThreefoldRepetition();
    _updateGameInFirestore(move);

    notifyListeners();
  }

  // Handle promotion selection
  void handlePromotion(PieceType promotionType) {
    print("🎲 GameProvider: Handling pawn promotion to $promotionType");
    if (_isPromotionPending && _promotionFrom != null && _promotionTo != null) {
      final movingPiece = _board[_promotionFrom!.row][_promotionFrom!.col];
      final capturedPiece = _board[_promotionTo!.row][_promotionTo!.col];

      if (movingPiece != null) {
        _completeMoveAfterPromotion(
            _promotionFrom!, _promotionTo!, movingPiece, capturedPiece,
            promotionType: promotionType);
      }
    }
  }

  // Getter for promotion state
  bool get isPromotionPending => _isPromotionPending;

  ChessPosition? get promotionSquare => _promotionTo;

  // Check for checkmate, stalemate, etc.
  void _checkGameEndConditions() {
    print("🎲 GameProvider: Checking game end conditions");
    final currentPlayerHasMoves = _hasValidMoves(_currentPlayer);
    final isInCheck = _isKingInCheck(_currentPlayer);

    if (!currentPlayerHasMoves) {
      if (isInCheck) {
        final winner = _currentPlayer == PieceColor.white ? 'black' : 'white';
        print("🎲 GameProvider: Checkmate! Winner: $winner");
        _endGame(winner, 'checkmate');
      } else {
        print("🎲 GameProvider: Stalemate! Game is a draw");
        _endGame(null, 'stalemate');
      }
    } else if (isInCheck) {
      print("🎲 GameProvider: $_currentPlayer is in check!");
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
    print("🎲 GameProvider: Game ended - Winner: $winner, Reason: $reason");
    _gameStatus = reason;
    _winner = winner;
    _gameTimer?.cancel();
    _updateGameInFirestore(null);

    // Get the winner and loser colors
    final winnerColor = winner == 'white' ? PieceColor.white : PieceColor.black;
    if (tournamentId == null) {
      // Update stats for both players (only once)
      if (!_statsUpdated) {
        _updateUserStats(_playerId, _playerColor == winnerColor);
        _updateUserStats(_opponentId!, _playerColor != winnerColor);
        _statsUpdated = true;
      }

      if (reason == 'draw') {
        print("****************************************");
        // Handle draw - refund both players
        _handleDrawRefund(_roomCode);
      } else {
        // Handle win/loss - give prize to winner
        _updateWinnerBalance(winnerColor, _roomCode);
      }

      // Record game history for both players (only once)
      _recordGameHistory(_playerId, _playerColor == winnerColor, _opponentId!);
      _recordGameHistory(_opponentId!, _playerColor != winnerColor, _playerId);
    } else {
      // Tournament game: mark match completed and promote winner
      _handleTournamentGameEnd(winnerColor, reason);
    }

    // Update ELO ratings (this function already handles both players)
    if (winner != null && reason != 'draw') {
      // Only update ELO for decisive games
      final winnerId = _playerColor == winnerColor ? _playerId : _opponentId!;
      final loserId = _playerColor == winnerColor ? _opponentId! : _playerId;
      _updateEloRatings(winnerId, loserId);
    }
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

    // Determine which player moved
    String? movedColor;
    if (move != null) {
      movedColor = move.piece.color == PieceColor.white ? 'white' : 'black';
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
      if (movedColor == 'white') 'moveCountWhite': FieldValue.increment(1),
      if (movedColor == 'black') 'moveCountBlack': FieldValue.increment(1),
    };

    (tournamentId != null
            ? _matchesCollection(tournamentId!).doc(_roomCode)
            : _firestore.collection('games').doc(_roomCode))
        .update(data);
  }

  // Update timers in Firestore
  void _updateTimersInFirestore() {
    (tournamentId != null
            ? _matchesCollection(tournamentId!).doc(_roomCode)
            : _firestore.collection('games').doc(_roomCode))
        .update({
      'whiteTimeLeft': _whiteTimeLeft,
      'blackTimeLeft': _blackTimeLeft,
    });
  }

  // Resign game
  void resignGame() {
    print("🎲 GameProvider: Player $_playerColor resigned");
    final winner = _playerColor == PieceColor.white ? 'black' : 'white';
    _endGame(winner, 'resignation');
  }

  // Abort game
  void abortGame() async {
    print("🎲 GameProvider: Player requested abort");
    _gameStatus = 'abort';
    _winner = null;
    _gameTimer?.cancel();

    // Refund logic for abort
    final gameDoc = await _firestore.collection('games').doc(_roomCode).get();
    final gameData = gameDoc.data();
    final entryFeeRaw = gameData?['entryFee'] ?? gameData?['amount'] ?? 0;
    final entryFeeAmount = entryFeeRaw is String ? int.tryParse(entryFeeRaw) ?? 0 : (entryFeeRaw is num ? entryFeeRaw.toInt() : 0);

    if (entryFeeAmount > 0 && gameData?['balanceUpdated'] != true) {
      await _firestore.runTransaction((transaction) async {
        final currentGameDoc = await transaction.get(_firestore.collection('games').doc(_roomCode));
        if (currentGameDoc.data()?['balanceUpdated'] == true) return;

        transaction.update(_firestore.collection('users').doc(_playerId), {'Balance': FieldValue.increment(entryFeeAmount)});
        transaction.update(_firestore.collection('users').doc(_opponentId!), {'Balance': FieldValue.increment(entryFeeAmount)});
        transaction.update(_firestore.collection('games').doc(_roomCode), {'balanceUpdated': true});
      });
      _balanceUpdated = true;
      print("💰 GameProvider: Refunded ₹$entryFeeAmount to both players for abort");
    }

    _updateGameInFirestore(null);
    notifyListeners();
  }

  // Format time for display
  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    print("🎲 GameProvider: Disposing game provider");
    _gameTimer?.cancel();
    _gameSubscription?.cancel();
    resetGameState();
    super.dispose();
  }

  // Add to GameProvider.dart
  Future<void> _updateUserStats(String userId, bool isWinner) async {
    final userRef = _firestore.collection('users').doc(userId);
    await userRef.update({
      'gamesPlayed': FieldValue.increment(1),
      'gamesWon': isWinner ? FieldValue.increment(1) : FieldValue.increment(0),
      'gamesLost':
          !isWinner ? FieldValue.increment(1) : FieldValue.increment(0),
      'lastGamePlayed': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateWinnerBalance(
      PieceColor winnerColor, String roomCode) async {
    print("💰 GameProvider: Starting balance update for winner: $winnerColor");

    final winnerId = winnerColor == PieceColor.white ? _playerId : _opponentId!;
    final loserId = winnerColor == PieceColor.white ? _opponentId! : _playerId;
    
    // Check if balance has already been updated for this game using Firestore
    final gameDoc = await _firestore.collection('games').doc(roomCode).get();
    final gameData = gameDoc.data();
    
    if (gameData?['balanceUpdated'] == true) {
      print("💰 GameProvider: Balance already updated for this game (from Firestore), skipping duplicate update");
      return;
    }

    final entryFee = await _firestore.collection('games').doc(roomCode).get();
    final gameData2 = entryFee.data();

    // Check both possible field names for entry fee and convert to number
    final entryFeeRaw = gameData2?['entryFee'] ?? gameData2?['amount'] ?? 0;
    final entryFeeAmount = entryFeeRaw is String ? int.tryParse(entryFeeRaw) ?? 0 : (entryFeeRaw is num ? entryFeeRaw.toInt() : 0);

    if (entryFeeAmount > 0) {
      // Calculate total prize pool (entry fee from both players)
      final totalPrizePool = entryFeeAmount * 2; // Both players paid entry fee
      // Calculate winner amount: total prize pool minus 18% admin commission
      final winnerAmount = totalPrizePool * 0.82; // 100% - 18% = 82%
      
      print("💰 GameProvider: About to update balance for winner: $winnerId with amount: $winnerAmount");
      
      // Use a transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        // Check again if balance was updated during transaction
        final currentGameDoc = await transaction.get(_firestore.collection('games').doc(roomCode));
        if (currentGameDoc.data()?['balanceUpdated'] == true) {
          print("💰 GameProvider: Balance already updated during transaction, aborting");
          return;
        }
        
        // Update winner's balance
        transaction.update(
          _firestore.collection('users').doc(winnerId),
          {'Balance': FieldValue.increment(winnerAmount)}
        );
        
        // Mark game as balance updated
        transaction.update(
          _firestore.collection('games').doc(roomCode),
          {'balanceUpdated': true}
        );
      });

      // Mark balance as updated locally too
      _balanceUpdated = true;
      print("💰 GameProvider: _balanceUpdated flag after update: $_balanceUpdated");

      print(
          "💰 GameProvider: Updated winner's balance with prize money: $winnerAmount (after 18% admin deduction from total pool of $totalPrizePool)");
    } else {
      print("💰 GameProvider: No entry fee found for the game");
    }
  }

  // Handle draw refunds
  Future<void> _handleDrawRefund(String roomCode) async {
    print("💰 GameProvider: Handling draw refund for room: $roomCode");
    
    // Check if balance has already been updated for this game using Firestore
    final gameDoc = await _firestore.collection('games').doc(roomCode).get();
    final gameData = gameDoc.data();
    
    if (gameData?['balanceUpdated'] == true) {
      print("💰 GameProvider: Balance already updated for this game (from Firestore), skipping duplicate refund");
      return;
    }
    
    try {
      final gameDoc2 = await _firestore.collection('games').doc(roomCode).get();
      final gameData2 = gameDoc2.data();

      // Check both possible field names for entry fee and convert to number
      final entryFeeRaw = gameData2?['entryFee'] ?? gameData2?['amount'] ?? 0;
      final entryFeeAmount = entryFeeRaw is String ? int.tryParse(entryFeeRaw) ?? 0 : (entryFeeRaw is num ? entryFeeRaw.toInt() : 0);

      if (entryFeeAmount > 0) {
        // Use a transaction to ensure atomicity
        await _firestore.runTransaction((transaction) async {
          // Check again if balance was updated during transaction
          final currentGameDoc = await transaction.get(_firestore.collection('games').doc(roomCode));
          if (currentGameDoc.data()?['balanceUpdated'] == true) {
            print("💰 GameProvider: Balance already updated during transaction, aborting refund");
            return;
          }
          
          // Refund both players their entry fee
          transaction.update(
            _firestore.collection('users').doc(_playerId),
            {'Balance': FieldValue.increment(entryFeeAmount)}
          );

          transaction.update(
            _firestore.collection('users').doc(_opponentId!),
            {'Balance': FieldValue.increment(entryFeeAmount)}
          );
          
          // Mark game as balance updated
          transaction.update(
            _firestore.collection('games').doc(roomCode),
            {'balanceUpdated': true}
          );
        });

        // Mark balance as updated locally too
        _balanceUpdated = true;

        print(
            "💰 GameProvider: Refunded ₹$entryFeeAmount to both players for draw");
      } else {
        print("💰 GameProvider: No entry fee found for draw refund");
      }
    } catch (e) {
      print("❌ GameProvider: Error handling draw refund: $e");
    }
  }

// Add to GameProvider.dart
  Future<void> _recordGameHistory(
      String userId, bool isWinner, String opponentName) async {
    final entryFee = await _firestore.collection('games').doc(_roomCode).get();
    final gameData = entryFee.data();

    // Check both possible field names for entry fee and convert to number
    final entryFeeRaw = gameData?['entryFee'] ?? gameData?['amount'] ?? 0;
    final entryFeeAmount = entryFeeRaw is String ? int.tryParse(entryFeeRaw) ?? 0 : (entryFeeRaw is num ? entryFeeRaw.toInt() : 0);

    // Calculate prize amount: total pool (2 * entry fee) minus 18% admin commission
    final totalPrizePool = entryFeeAmount * 2;
    final prizeAmount = totalPrizePool * 0.82;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('gamehistory')
        .doc(_roomCode)
        .set({
      'datetime': FieldValue.serverTimestamp(),
      'entry_fees': entryFeeAmount, // Already converted to int
      'game_name': 'Chess Match',
      'opponent': opponentName,
      'prize': prizeAmount.round(), // Round to nearest integer
      'result': isWinner ? 'win' : 'loss'
    });
  }

// Add to GameProvider.dart
  /// Updates Elo ratings for both winner and loser based on the new rating system:
  ///
  /// 1. Equal Elo ratings: Winner gets +15, Loser gets -15
  /// 2. Upset win (winner has lower Elo): Winner gets +20, Loser gets -20
  /// 3. Expected win (winner has higher Elo): Winner gets +10, Loser gets -10
  ///
  /// Examples:
  /// - Player A (1200) vs Player B (1200), A wins → A: 1215, B: 1185
  /// - Player A (1150) vs Player B (1250), A wins → A: 1170, B: 1230
  /// - Player A (1300) vs Player B (1200), A wins → A: 1310, B: 1190
  Future<void> _updateEloRatings(String winnerId, String loserId) async {
    final winnerDoc = await _firestore.collection('users').doc(winnerId).get();
    final loserDoc = await _firestore.collection('users').doc(loserId).get();

    final winnerElo = winnerDoc.data()?['eloRating'] ?? 1200;
    final loserElo = loserDoc.data()?['eloRating'] ?? 1200;

    int eloChange;

    // Implement the specific Elo rating conditions
    if (winnerElo == loserElo) {
      // Both players have equal Elo: Winner gets +15, Loser gets -15
      eloChange = 15;
      print("🎯 Elo Update: Equal ratings - Winner: +15, Loser: -15");
    } else if (winnerElo < loserElo) {
      // Winner has lower Elo than opponent (upset win): Winner gets +20, Loser gets -20
      eloChange = 20;
      print("🎯 Elo Update: Upset win - Winner: +20, Loser: -20");
    } else {
      // Winner has higher Elo than opponent (expected win): Winner gets +10, Loser gets -10
      eloChange = 10;
      print("🎯 Elo Update: Expected win - Winner: +10, Loser: -10");
    }

    // Calculate new ratings
    final newWinnerElo = winnerElo + eloChange;
    final newLoserElo = loserElo - eloChange;

    print(
        "🎯 Elo Update: Winner $winnerId: $winnerElo → $newWinnerElo (+$eloChange)");
    print(
        "🎯 Elo Update: Loser $loserId: $loserElo → $newLoserElo (-$eloChange)");

    // Update ratings
    await _firestore
        .collection('users')
        .doc(winnerId)
        .update({'eloRating': newWinnerElo});
    await _firestore
        .collection('users')
        .doc(loserId)
        .update({'eloRating': newLoserElo});
  }

  // Add this method to ChessGameProvider
  void resetGameState() {
    print("🎲 GameProvider: Resetting game state");

    // Cancel existing timers and subscriptions
    _gameTimer?.cancel();
    _gameSubscription?.cancel();

    // Reset all game state variables
    _gameStatus = null;
    _winner = null;
    _currentPlayer = PieceColor.white;
    _selectedPosition = null;
    _possibleMoves = [];
    _whiteTimeLeft = 600;
    _blackTimeLeft = 600;
    _lastMoveTime = null;

    // Reset promotion state
    _isPromotionPending = false;
    _promotionFrom = null;
    _promotionTo = null;
    _onPromotionSelected = null;

    // Clear opponent info
    _opponentId = null;
    _roomCode = '';
    _playerId = '';
    _playerColor = null;
    _opponentId = null;

    _currentRound = null;
    _currentMatchNumber = null;

    // Reset balance update flag
    _balanceUpdated = false;
    _statsUpdated = false;

    isLoading = false;

    // Clear repetition tracker
    _positionCounts.clear();

    print("🎲 GameProvider: Game state reset complete");
  }

  void _handleTournamentGameEnd(PieceColor winnerColor, String reason) async {
    if (tournamentId == null) return;

    final String winnerId =
        winnerColor == _playerColor ? _playerId : _opponentId!;

    final matchRef = _matchesCollection(tournamentId!).doc(_roomCode);

    await _firestore.runTransaction((transaction) async {
      // READS
      final matchSnap = await transaction.get(matchRef);
      if (!matchSnap.exists) return;

      final matchData = matchSnap.data() as Map<String, dynamic>;
      final int round = matchData['round'] ?? _currentRound ?? 1;
      final int matchNumber =
          matchData['matchNumber'] ?? _currentMatchNumber ?? 1;

      final tournamentDocRef =
          _firestore.collection('tournaments').doc(tournamentId);
      final tournamentSnap = await transaction.get(tournamentDocRef);
      final int totalRounds = tournamentSnap.data()?['numberOfRounds'] ?? 1;

      int? nextRound;
      DocumentReference? nextMatchRef;
      String? nextSlot;

      if (round + 1 <= totalRounds) {
        nextRound = round + 1;

        // Fetch ALL matches in the next round ordered by matchNumber
        final nextRoundMatches = await _matchesCollection(tournamentId!)
            .where('round', isEqualTo: nextRound)
            .orderBy('matchNumber')
            .get();

        for (final doc in nextRoundMatches.docs) {
          final snap = await transaction.get(doc.reference);
          final data = snap.data() ?? {};

          if (data['player1'] == null) {
            nextMatchRef = doc.reference;
            nextSlot = 'player1';
            break;
          }

          if (data['player2'] == null) {
            nextMatchRef = doc.reference;
            nextSlot = 'player2';
            break;
          }
        }
      } else {
        // -----------------------------
        // FINAL ROUND  – tournament ends
        // -----------------------------

        // Update tournament document with winner and status
        transaction.update(
            tournamentDocRef, {'winnerId': winnerId, 'status': 'completed'});

        // Credit prize amount to winner's wallet (after 18% admin commission)
        final num prize = tournamentSnap.data()?['prizeAmount'] ?? 0;
        if (prize > 0) {
          final winnerAmount = prize * 0.82; // Apply 18% admin commission
          final userRef = _firestore.collection('users').doc(winnerId);
          transaction.update(userRef, {
            'Balance': FieldValue.increment(winnerAmount),
          });
          print(
              "💰 Tournament: Updated winner's balance with prize money: $winnerAmount (after 18% admin deduction from total prize of $prize)");
        }
      }

      // WRITES
      transaction.update(matchRef, {
        'status': 'completed',
        'winner': winnerId,
      });

      if (nextMatchRef != null && nextSlot != null) {
        transaction.update(nextMatchRef, {nextSlot: winnerId});
      }
    });
  }

  // Helper to access matches subcollection for a tournament
  CollectionReference<Map<String, dynamic>> _matchesCollection(String tid) {
    return _firestore.collection('tournaments').doc(tid).collection('matches');
  }

  // -------------------------------------------------------------
  // Castling helpers
  // -------------------------------------------------------------

  bool _isSquareUnderAttack(ChessPosition pos, PieceColor byColor) {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final attacker = _board[row][col];
        if (attacker != null && attacker.color == byColor) {
          final attacks =
              _calculateAttackSquares(ChessPosition(row, col), attacker);
          if (attacks.contains(pos)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _canCastle(PieceColor color, {required bool kingSide}) {
    final opponentColor =
        color == PieceColor.white ? PieceColor.black : PieceColor.white;
    final int row = color == PieceColor.white ? 7 : 0;

    // King and rook starting columns
    const int kingCol = 4;
    final int rookCol = kingSide ? 7 : 0;

    final kingPiece = _board[row][kingCol];
    if (kingPiece == null || kingPiece.hasMoved) return false;

    final rookPiece = _board[row][rookCol];
    if (rookPiece == null ||
        rookPiece.type != PieceType.rook ||
        rookPiece.hasMoved) {
      return false;
    }

    // Squares between king and rook must be empty
    final int start = min(kingCol, rookCol) + 1;
    final int end = max(kingCol, rookCol) - 1;
    for (int col = start; col <= end; col++) {
      if (_board[row][col] != null) return false;
    }

    // King may not be in check and squares it passes through cannot be under attack
    final List<int> kingPathCols = kingSide ? [5, 6] : [3, 2];
    for (final col in [
      ...[kingCol],
      ...kingPathCols
    ]) {
      if (_isSquareUnderAttack(ChessPosition(row, col), opponentColor)) {
        return false;
      }
    }

    return true;
  }

  void _performCastling(
      ChessPosition from, ChessPosition to, ChessPiece kingPiece) {
    print("🎲 GameProvider: Performing castling move from $from to $to");

    final row = from.row;
    final bool kingSide = to.col == 6; // true for short castle
    final int rookFromCol = kingSide ? 7 : 0;
    final int rookToCol = kingSide ? 5 : 3;

    // Move rook on the board
    final rookPiece = _board[row][rookFromCol];
    if (rookPiece == null || rookPiece.type != PieceType.rook) {
      print("⚠️ Castling error: Rook not found at expected square");
    } else {
      _board[row][rookToCol] = rookPiece.copyWith(hasMoved: true);
      _board[row][rookFromCol] = null;
    }

    // Now move the king using existing helper (this also toggles turn etc.)
    _completeMoveAfterPromotion(from, to, kingPiece, null);
  }

  // -------------------------------------------------------------
  // Three-fold repetition logic
  // -------------------------------------------------------------

  void _updateThreefoldRepetition() {
    final key = _generatePositionKey();
    final count = (_positionCounts[key] ?? 0) + 1;
    _positionCounts[key] = count;

    if (count >= 3 && (_gameStatus == null || _gameStatus == 'playing')) {
      print("🎲 GameProvider: Threefold repetition detected – draw declared");
      _endGame(null, 'draw');
    }
  }

  String _generatePositionKey() {
    final buffer = StringBuffer();

    // Board layout
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece == null) {
          buffer.write('.');
        } else {
          final symbol = _pieceToChar(piece);
          buffer.write(symbol);
        }
      }
      buffer.write('/');
    }

    // Side to move
    buffer.write(_currentPlayer == PieceColor.white ? 'w' : 'b');

    // Castling rights summary (KQkq style)
    buffer.write(_castlingRightsString());

    return buffer.toString();
  }

  String _pieceToChar(ChessPiece piece) {
    final map = {
      PieceType.king: 'k',
      PieceType.queen: 'q',
      PieceType.rook: 'r',
      PieceType.bishop: 'b',
      PieceType.knight: 'n',
      PieceType.pawn: 'p',
    };
    final char = map[piece.type]!;
    return piece.color == PieceColor.white ? char.toUpperCase() : char;
  }

  String _castlingRightsString() {
    final rights = StringBuffer();

    // White rights
    const wRow = 7;
    if (_board[wRow][4]?.type == PieceType.king && !_board[wRow][4]!.hasMoved) {
      if (_board[wRow][7]?.type == PieceType.rook && !_board[wRow][7]!.hasMoved)
        rights.write('K');
      if (_board[wRow][0]?.type == PieceType.rook && !_board[wRow][0]!.hasMoved)
        rights.write('Q');
    }

    // Black rights
    const bRow = 0;
    if (_board[bRow][4]?.type == PieceType.king && !_board[bRow][4]!.hasMoved) {
      if (_board[bRow][7]?.type == PieceType.rook && !_board[bRow][7]!.hasMoved)
        rights.write('k');
      if (_board[bRow][0]?.type == PieceType.rook && !_board[bRow][0]!.hasMoved)
        rights.write('q');
    }

    if (rights.isEmpty) rights.write('-');
    return rights.toString();
  }

  // -------------------------------
  // Chat send helper
  // -------------------------------
  Future<void> sendChat(String text) async {
    print("🎲 GameProvider: Sending chat message: '$text'");
    final docRef = tournamentId != null ? _matchesCollection(tournamentId!).doc(_roomCode) : _firestore.collection('games').doc(_roomCode);

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();

    final messageData = {
      'id': messageId,
      'text': text,
      'sender': _playerId,
      'ts': timestamp,
    };

    print("🎲 GameProvider: Message data to send: $messageData");

    try {
      // First check if chatMessages field exists, if not initialize it
      final docSnapshot = await docRef.get();
      final docData = docSnapshot.data();

      if (docData == null || docData['chatMessages'] == null) {
        print("🎲 GameProvider: Initializing chatMessages field");
        await docRef.update({
          'chatMessages': [messageData],
        });
      } else {
        await docRef.update({
          'chatMessages': FieldValue.arrayUnion([messageData]),
        });
      }
      print("🎲 GameProvider: Chat message sent successfully");
    } catch (e) {
      print("❌ GameProvider: Error sending chat message: $e");
    }
  }
}
