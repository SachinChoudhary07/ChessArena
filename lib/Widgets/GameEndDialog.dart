import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Constant/color_resources.dart';
import '../Providers/gameProvider/GameProvider.dart';

class GameEndDialog extends StatefulWidget {
  final ChessGameProvider gameProvider;
  final bool youWon;
  final String player1Name;
  final String player2Name;
  final String roomCode;
  final VoidCallback onOkPressed;

  const GameEndDialog({
    super.key,
    required this.gameProvider,
    required this.youWon,
    required this.player1Name,
    required this.player2Name,
    required this.roomCode,
    required this.onOkPressed,
  });

  @override
  State<GameEndDialog> createState() => _GameEndDialogState();
}

class _GameEndDialogState extends State<GameEndDialog> {
  Map<String, dynamic>? gameData;
  int? eloChange;
  int? currentUserElo;
  int? opponentElo;
  String? eloContext; // To explain why the Elo change is what it is

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    try {
      // Load game data for the result summary
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.roomCode)
          .get();

      if (gameDoc.exists) {
        gameData = gameDoc.data();
      }

      // If game is aborted, skip ELO and winner logic
      if (widget.gameProvider.gameStatus == 'abort') {
        if (mounted) setState(() {});
        return;
      }

      // Get current user and opponent Elo ratings to calculate proper Elo change
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final gameData = gameDoc.data();
        final player1UID = gameData?['player1'];
        final player2UID = gameData?['player2'];

        // Determine which player is the current user
        final isPlayer1 = player1UID == currentUser.uid;
        final currentUserId = currentUser.uid;
        final opponentId = isPlayer1 ? player2UID : player1UID;

        // Get both players' Elo ratings
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        final opponentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(opponentId)
            .get();

        final currentUserElo = currentUserDoc.data()?['eloRating'] ?? 1200;
        final opponentElo = opponentDoc.data()?['eloRating'] ?? 1200;

        // Store Elo ratings for display
        this.currentUserElo = currentUserElo.toInt();
        this.opponentElo = opponentElo.toInt();

        // Calculate Elo change based on the new system
        // 1. Equal ratings: ±15 points
        // 2. Upset win/loss: ±20 points (lower-rated player wins or higher-rated player loses)
        // 3. Expected win/loss: ±10 points (higher-rated player wins or lower-rated player loses)
        if (widget.youWon) {
          // Current user won
          if (currentUserElo == opponentElo) {
            eloChange = 15; // Equal ratings
            eloContext = "Equal ratings - standard win";
          } else if (currentUserElo < opponentElo) {
            eloChange = 20; // Upset win
            eloContext = "Upset win against higher-rated opponent";
          } else {
            eloChange = 10; // Expected win
            eloContext = "Expected win against lower-rated opponent";
          }
        } else {
          // Current user lost
          if (currentUserElo == opponentElo) {
            eloChange = -15; // Equal ratings
            eloContext = "Equal ratings - standard loss";
          } else if (currentUserElo < opponentElo) {
            eloChange = -10; // Expected loss
            eloContext = "Expected loss against higher-rated opponent";
          } else {
            eloChange = -20; // Upset loss
            eloContext = "Upset loss against lower-rated opponent";
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      print("Error loading game data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final playerColor = widget.gameProvider.playerColor;
    final winnerName = widget.youWon
        ? (playerColor == PieceColor.white
            ? widget.player1Name
            : widget.player2Name)
        : (playerColor == PieceColor.white
            ? widget.player2Name
            : widget.player1Name);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ColorResources.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorResources.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Game Result Header
            Icon(
              _isAborted()
                  ? Icons.info_outline
                  : _isDraw()
                      ? Icons.handshake
                      : (widget.youWon
                          ? Icons.emoji_events
                          : Icons.sentiment_dissatisfied),
              size: 64,
              color: _isAborted()
                  ? ColorResources.textSecondary
                  : _isDraw()
                      ? ColorResources.primaryLight
                      : (widget.youWon
                          ? ColorResources.accent
                          : ColorResources.textSecondary),
            ),
            const SizedBox(height: 16),

            Text(
              _isAborted()
                  ? 'Game Ended'
                  : _isDraw()
                      ? '🤝 Draw!'
                      : (widget.youWon ? '🎉 Victory!' : '😔 Defeat'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _isAborted()
                    ? ColorResources.textSecondary
                    : _isDraw()
                        ? ColorResources.primaryLight
                        : (widget.youWon
                            ? ColorResources.success
                            : ColorResources.error),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _getGameEndReason(),
              style: TextStyle(
                fontSize: 16,
                color: ColorResources.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Game Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColorResources.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorResources.divider),
              ),
              child: Column(
                children: [
                  Text(
                    'Game Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ColorResources.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isAborted()) ...[
                    _buildDetailRow('Winner', winnerName),
                  ],
                  _buildDetailRow('Game Mode', _getGameMode()),
                  _buildDetailRow('Duration', _getGameDuration()),
                  if (!_isAborted() && eloChange != null) ...[
                    const Divider(height: 20),
                    _buildDetailRow(
                      'Your ELO',
                      '$currentUserElo',
                      valueColor: Colors.blue,
                    ),
                    _buildDetailRow(
                      'Opponent ELO',
                      '$opponentElo',
                      valueColor: Colors.orange,
                    ),
                    _buildDetailRow(
                      'ELO Change',
                      '${eloChange! >= 0 ? '+' : ''}$eloChange',
                      valueColor: eloChange! >= 0 ? Colors.green : Colors.red,
                    ),
                    if (eloContext != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Text(
                          eloContext!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // OK Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onOkPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorResources.primary,
                  foregroundColor: ColorResources.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getGameEndReason() {
    switch (widget.gameProvider.gameStatus) {
      case 'checkmate':
        return widget.youWon
            ? 'You checkmated your opponent!'
            : 'You were checkmated!';
      case 'stalemate':
        return 'Game ended in stalemate';
      case 'draw':
        return 'Game ended in a draw';
      case 'resignation':
        return widget.youWon
            ? 'Your opponent resigned'
            : 'You resigned from the game';
      case 'timeout':
        return widget.youWon
            ? 'Your opponent ran out of time'
            : 'You ran out of time';
      case 'abort':
        return 'Game was aborted. No result.';
      default:
        return 'Game ended';
    }
  }

  String _getGameMode() {
    return 'Free Match';
  }

  String _getGameDuration() {
    // Calculate based on remaining time vs initial time
    final timeLimit = gameData?['time'] ?? '10 min';
    return 'Time Control: $timeLimit';
  }

  bool _isDraw() {
    return widget.gameProvider.gameStatus == 'draw';
  }

  bool _isAborted() {
    return widget.gameProvider.gameStatus == 'abort';
  }
}
