import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _HistoryFilter { all, wins, losses }

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: const PremiumAppBar(
        automaticallyImplyLeading: false,
        title: AppConstants.history,
      ),
      body: userId == null
          ? const EmptyStateWidget(
              message: 'Sign in to see your match history.',
              icon: Icons.history,
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('gamehistory')
                  .orderBy('datetime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Loader());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const EmptyStateWidget(
                    message:
                        'No matches yet. Play a rated game and it will show up here.',
                    icon: Icons.history,
                  );
                }

                final games = docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
                final wins = games
                    .where((g) => (g['result'] ?? '').toString().toLowerCase() ==
                        'win')
                    .length;
                final losses = games
                    .where((g) =>
                        (g['result'] ?? '').toString().toLowerCase() == 'loss')
                    .length;

                final visible = games.where((g) {
                  final result = (g['result'] ?? '').toString().toLowerCase();
                  switch (_filter) {
                    case _HistoryFilter.wins:
                      return result == 'win';
                    case _HistoryFilter.losses:
                      return result == 'loss';
                    case _HistoryFilter.all:
                      return true;
                  }
                }).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    const Text(
                      'Your matches',
                      style: TextStyle(
                        color: ColorResources.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Rated games you have finished',
                      style: TextStyle(
                        color: ColorResources.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'Played',
                            value: '${games.length}',
                            color: ColorResources.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatBox(
                            label: 'Wins',
                            value: '$wins',
                            color: ColorResources.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatBox(
                            label: 'Losses',
                            value: '$losses',
                            color: ColorResources.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == _HistoryFilter.all,
                          onTap: () =>
                              setState(() => _filter = _HistoryFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Wins',
                          selected: _filter == _HistoryFilter.wins,
                          onTap: () =>
                              setState(() => _filter = _HistoryFilter.wins),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Losses',
                          selected: _filter == _HistoryFilter.losses,
                          onTap: () =>
                              setState(() => _filter = _HistoryFilter.losses),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyStateWidget(
                          message: 'Nothing in this filter yet.',
                          icon: Icons.filter_list,
                        ),
                      )
                    else
                      ...visible.map((game) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HistoryCard(game: game),
                          )),
                  ],
                );
              },
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: ColorResources.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorResources.divider),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: ColorResources.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ColorResources.primary : ColorResources.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ColorResources.primary : ColorResources.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? ColorResources.onPrimary
                : ColorResources.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> game;

  const _HistoryCard({required this.game});

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }
    return DateFormat('dd MMM · hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final result = (game['result'] ?? '').toString().toLowerCase();
    final won = result == 'win';
    final lost = result == 'loss';
    final opponentRaw = (game['opponent'] ?? '').toString();

    final badgeColor = won
        ? ColorResources.success
        : lost
            ? ColorResources.error
            : ColorResources.textSecondary;
    final badgeLabel = won
        ? 'WIN'
        : lost
            ? 'LOSS'
            : result.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorResources.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorResources.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              badgeLabel,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<String>(
              future: _resolveOpponentName(opponentRaw),
              builder: (context, snap) {
                final name = snap.data ??
                    (opponentRaw.isEmpty ? 'Opponent' : opponentRaw);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ColorResources.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Rated match',
                        _formatDate(game['datetime']),
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      style: const TextStyle(
                        color: ColorResources.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Icon(
            won
                ? Icons.arrow_upward_rounded
                : lost
                    ? Icons.arrow_downward_rounded
                    : Icons.remove,
            color: badgeColor,
            size: 22,
          ),
        ],
      ),
    );
  }

  Future<String> _resolveOpponentName(String opponent) async {
    if (opponent.isEmpty) return 'Opponent';
    if (opponent.length < 20) return opponent;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(opponent)
          .get();
      if (doc.exists) {
        final data = doc.data();
        return data?['username']?.toString() ?? opponent;
      }
    } catch (_) {}
    return opponent;
  }
}
