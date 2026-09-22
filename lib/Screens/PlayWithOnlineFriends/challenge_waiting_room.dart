import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Constant/color_resources.dart';
import '../../Services/navigation.dart';
import '../../Widgets/loader.dart';
import '../GameScreens/waitingRoom.dart';

class ChallengeWaitingRoom extends StatefulWidget {
  final String roomCode;
  final String challengeId;

  const ChallengeWaitingRoom({
    super.key,
    required this.roomCode,
    required this.challengeId,
  });

  @override
  State<ChallengeWaitingRoom> createState() => _ChallengeWaitingRoomState();
}

class _ChallengeWaitingRoomState extends State<ChallengeWaitingRoom> {
  bool _isExpired = false;
  String? _opponentName;
  String? _timeControl;
  int? _amount;

  @override
  void initState() {
    super.initState();
    _fetchChallengeDetails();
  }

  Future<void> _fetchChallengeDetails() async {
    try {
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .get();

      if (challengeDoc.exists) {
        final data = challengeDoc.data()!;
        final opponentUid = data['opponent'] as String;
        final timeControl = data['timeControl'] as String;
        final amount = data['amount'] as int;

        // Fetch opponent name
        final opponentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(opponentUid)
            .get();
        final opponentName = opponentDoc.data()?['username'] ?? 'Opponent';

        setState(() {
          _opponentName = opponentName;
          _timeControl = timeControl;
          _amount = amount;
        });
      }
    } catch (e) {
      debugPrint('Error fetching challenge details: $e');
    }
  }

  Future<void> _checkGameResult(String gameRoomCode) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final gameHistoryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('gamehistory')
          .doc(gameRoomCode)
          .get();

      if (gameHistoryDoc.exists) {
        final gameResult = gameHistoryDoc.data()?['result'] as String?;
        if (gameResult == 'win' || gameResult == 'loss') {
          // Game is completed, show result dialog
          if (mounted) {
            _showGameResultDialog(gameResult == 'win', gameRoomCode);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking game result: $e');
    }
  }

  void _showGameResultDialog(bool isWin, String gameRoomCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isWin ? '🎉 You Won!' : '😔 You Lost',
            style: TextStyle(
              color: isWin ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            isWin
                ? 'Congratulations! You won the chess match against ${_opponentName ?? 'your opponent'}.'
                : 'Better luck next time! You lost the chess match against ${_opponentName ?? 'your opponent'}.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to challenges
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge Sent'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('challenges')
            .doc(widget.challengeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(child: Text("Challenge not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          final gameRoomCode = data['gameRoomCode'] as String?;

          // Check if challenge is expired
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final createdTime = createdAt.toDate();
            final now = DateTime.now();
            final difference = now.difference(createdTime);

            if (difference.inMinutes >= 2 && status == 'pending') {
              _isExpired = true;
            }
          }

          // Handle different statuses
          if (status == 'accepted' && gameRoomCode != null) {
            // Check if game has a result asynchronously
            // _checkGameResult(gameRoomCode);

            // Navigate to game waiting room
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // Prevent multiple navigations if snapshot fires again
              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.of(context).pop(); // Pop challenge waiting room
              push(context, EnhancedWaitingRoom(roomCode: gameRoomCode));
            });
            return const Center(child: Text('Redirecting to game...'));
          }

          if (status == 'rejected') {
            return _buildRejectedView();
          }

          if (status == 'expired' || _isExpired) {
            return _buildExpiredView();
          }

          return _buildWaitingView(status);
        },
      ),
    );
  }

  Widget _buildWaitingView(String status) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ColorResources.primaryColor, ColorResources.secondaryColor],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_empty,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 40),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  status == 'pending'
                      ? 'Waiting for response...'
                      : 'Challenge Status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: ColorResources.primaryColor),
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Room Code: ${widget.roomCode}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: ColorResources.secondaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_opponentName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ColorResources.secondaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          _opponentName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "PENDING",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_timeControl != null && _amount != null)
                    Text(
                      _timeControl ?? 'Rated game',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                const Loader(),
                const SizedBox(height: 10),
                Text(
                  "Waiting for ${_opponentName ?? 'opponent'} to respond...",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Challenge expires in 2 minutes",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedView() {
    final opponent = _opponentName ?? 'Opponent';
    final timeLabel = _timeControl?.trim().isNotEmpty == true
        ? _timeControl!
        : 'Rated game';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ColorResources.background,
            Color(0xFF1E2229),
            ColorResources.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ColorResources.error.withOpacity(0.08),
                          ),
                        ),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ColorResources.error.withOpacity(0.14),
                            border: Border.all(
                              color: ColorResources.error.withOpacity(0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.sports_esports_outlined,
                            size: 40,
                            color: ColorResources.error,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ColorResources.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ColorResources.error,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: ColorResources.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ColorResources.error.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ColorResources.error.withOpacity(0.35),
                        ),
                      ),
                      child: const Text(
                        'DECLINED',
                        style: TextStyle(
                          color: ColorResources.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Challenge declined',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ColorResources.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$opponent turned down this match. You can challenge them again anytime.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ColorResources.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ColorResources.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ColorResources.divider),
                      ),
                      child: Column(
                        children: [
                          _RejectedDetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Opponent',
                            value: opponent,
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: ColorResources.divider.withOpacity(0.8),
                          ),
                          const SizedBox(height: 12),
                          _RejectedDetailRow(
                            icon: Icons.timer_outlined,
                            label: 'Time control',
                            value: timeLabel,
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: ColorResources.divider.withOpacity(0.8),
                          ),
                          const SizedBox(height: 12),
                          _RejectedDetailRow(
                            icon: Icons.tag_rounded,
                            label: 'Room',
                            value: widget.roomCode,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorResources.primary,
                    foregroundColor: ColorResources.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: const Text(
                    'Back to challenges',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ColorResources.primaryColor, ColorResources.secondaryColor],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_off,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 40),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Challenge Expired',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The challenge has expired. No response was received within 2 minutes.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorResources.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Challenges'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RejectedDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ColorResources.elevatedSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: ColorResources.accentSoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: ColorResources.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ColorResources.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
