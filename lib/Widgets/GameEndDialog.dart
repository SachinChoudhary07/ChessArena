import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Providers/gameProvider/GameProvider.dart';
import '../Constant/color_resources.dart';

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
  double? prizeAmount;
  int? eloChange;

  @override
  void initState() {
    super.initState();
    _loadGameData();
  }

  Future<void> _loadGameData() async {
    try {
      // Get game data for prize information
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.roomCode)
          .get();

      if (gameDoc.exists) {
        gameData = gameDoc.data();
        final entryFee = gameData?['entryFee'] ?? 0;
        prizeAmount = entryFee > 0 ? entryFee * 0.8 : 0;
      }

      // Calculate ELO change (simplified)
      eloChange = widget.youWon
          ? (widget.gameProvider.gameStatus == 'resignation' ? 15 : 20)
          : -(widget.gameProvider.gameStatus == 'resignation' ? 10 : 15);

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
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.youWon
                ? [
                    Colors.green.withOpacity(0.1),
                    Colors.green.withOpacity(0.05)
                  ]
                : [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Game Result Header
            Icon(
              widget.youWon ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 64,
              color: widget.youWon ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 16),

            Text(
              widget.youWon ? '🎉 Victory!' : '😔 Defeat',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: widget.youWon ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _getGameEndReason(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Game Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: ColorResources.secondaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Game Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ColorResources.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Winner', winnerName),
                  _buildDetailRow('Game Mode', _getGameMode()),
                  _buildDetailRow('Duration', _getGameDuration()),
                  if (prizeAmount != null && prizeAmount! > 0) ...[
                    const Divider(height: 20),
                    _buildDetailRow(
                      'Prize Money',
                      widget.youWon
                          ? '+₹${prizeAmount!.toStringAsFixed(0)}'
                          : '₹0',
                      valueColor: widget.youWon ? Colors.green : null,
                    ),
                  ],
                  if (eloChange != null) ...[
                    _buildDetailRow(
                      'ELO Rating',
                      '${eloChange! >= 0 ? '+' : ''}$eloChange',
                      valueColor: eloChange! >= 0 ? Colors.green : Colors.red,
                    ),
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
                  backgroundColor: ColorResources.secondaryColor,
                  foregroundColor: Colors.black,
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
      default:
        return 'Game ended';
    }
  }

  String _getGameMode() {
    final entryFee = gameData?['entryFee'] ?? 0;
    return entryFee > 0 ? 'Paid Match (₹$entryFee)' : 'Free Match';
  }

  String _getGameDuration() {
    // Calculate based on remaining time vs initial time
    final timeLimit = gameData?['time'] ?? '10 min';
    return 'Time Control: $timeLimit';
  }
}
