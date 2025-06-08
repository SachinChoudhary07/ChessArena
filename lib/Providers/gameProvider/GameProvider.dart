import 'dart:async';
import 'dart:math';

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

  // Add this at class level
  Function(PieceType)? _onPromotionSelected;
  bool _isPromotionPending = false;
  ChessPosition? _promotionFrom;
  ChessPosition? _promotionTo;

  int? _currentRound;
  int? _currentMatchNumber;

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
  Future<void> _makeMove(ChessPosition from, ChessPosition to) async {
    print("🎲 GameProvider: Processing move from $from to $to");
    var movingPiece = _board[from.row][from.col];
    final capturedPiece = _board[to.row][to.col];

    if (movingPiece == null) return;

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
      print("🎲 GameProvider: ${_currentPlayer} is in check!");
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
      // Update stats for both players
      _updateUserStats(_playerId, _playerColor == winnerColor);
      _updateUserStats(_opponentId!, _playerColor != winnerColor);

      //now give the 80% of the entry fee to the winner
      _updateWinnerBalance(winnerColor, _roomCode);

      // Record game history for both players
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

  // Offer draw (simplified - auto accept for now)
  void offerDraw() {
    print("🎲 GameProvider: Draw offered and accepted");
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
    final winnerId = winnerColor == PieceColor.white ? _playerId : _opponentId!;
    final loserId = winnerColor == PieceColor.white ? _opponentId! : _playerId;
    final entryFee = await _firestore.collection('games').doc(roomCode).get();
    final entryFeeAmount = entryFee.data()?['entryFee'] ?? 0;
    if (entryFeeAmount > 0) {
      final winnerAmount = entryFeeAmount * 0.8;
      await _firestore
          .collection('users')
          .doc(winnerId)
          .update({'Balance': FieldValue.increment(winnerAmount)});

      print(
          "💰 GameProvider: Updated winner's balance with prize money: $winnerAmount");
    } else {
      print("💰 GameProvider: No entry fee found for the game");
    }
  }

// Add to GameProvider.dart
  Future<void> _recordGameHistory(
      String userId, bool isWinner, String opponentName) async {
    final entryFee = await _firestore.collection('games').doc(_roomCode).get();
    final entryFeeAmount = entryFee.data()?['entryFee'] ?? 0;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('gamehistory')
        .doc(_roomCode)
        .set({
      'datetime': FieldValue.serverTimestamp(),
      'entry_fees': entryFeeAmount.toInt(), // Get from game data
      'game_name': 'Chess Match',
      'opponent': opponentName,
      'prize': entryFeeAmount * 0.8.toInt(), // Get from game data
      'result': isWinner ? 'win' : 'loss'
    });
  }

// Add to GameProvider.dart
  Future<void> _updateEloRatings(String winnerId, String loserId) async {
    const K = 32; // ELO K-factor

    final winnerDoc = await _firestore.collection('users').doc(winnerId).get();
    final loserDoc = await _firestore.collection('users').doc(loserId).get();

    final winnerElo = winnerDoc.data()?['eloRating'] ?? 1200;
    final loserElo = loserDoc.data()?['eloRating'] ?? 1200;

    // Calculate expected scores
    final expectedWinner = 1.0 / (1.0 + pow(10, (loserElo - winnerElo) / 400));
    final expectedLoser = 1.0 / (1.0 + pow(10, (winnerElo - loserElo) / 400));

    // Calculate new ratings
    final newWinnerElo = winnerElo + K * (1 - expectedWinner);
    final newLoserElo = loserElo + K * (0 - expectedLoser);

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

    isLoading = false;

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
          final data = snap.data() as Map<String, dynamic>? ?? {};

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

        // Credit prize amount to winner's wallet
        final num prize = tournamentSnap.data()?['prizeAmount'] ?? 0;
        if (prize > 0) {
          final userRef = _firestore.collection('users').doc(winnerId);
          transaction.update(userRef, {
            'Balance': FieldValue.increment(prize.toDouble()),
          });
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
}
