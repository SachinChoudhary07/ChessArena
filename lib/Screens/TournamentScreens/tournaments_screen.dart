import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'tournament_details_screen.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _startTournamentCheck();
  }

  void _startTournamentCheck() {
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        _checkAndCancelTournaments();
        _startTournamentCheck();
      }
    });
  }

  Future<void> _checkAndCancelTournaments() async {
    try {
      final tournaments = await _firestore
          .collection('tournaments')
          .where('status', isEqualTo: 'upcoming')
          .get();

      for (var tournament in tournaments.docs) {
        final data = tournament.data();
        final startDate = (data['startDate'] as Timestamp?)?.toDate();
        final players = List<String>.from(data['players'] ?? []);
        final maxPlayers = data['playerCount'] ?? 8;

        if (startDate != null) {
          final timeUntilStart = startDate.difference(DateTime.now());
          if (timeUntilStart.inMinutes <= 30 &&
              timeUntilStart.inMinutes > 0 &&
              players.length < maxPlayers / 2) {
            await _cancelTournament(
              tournament.id,
              'Tournament cancelled due to insufficient players',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking tournaments: $e');
    }
  }

  Future<void> _cancelTournament(
    String tournamentId,
    String reason,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final tournamentRef =
            _firestore.collection('tournaments').doc(tournamentId);
        transaction.update(tournamentRef, {
          'status': 'cancelled',
          'cancelReason': reason,
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        final matchesSnapshot = await _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .collection('matches')
            .get();

        for (var match in matchesSnapshot.docs) {
          transaction.delete(match.reference);
        }
      });

      Fluttertoast.showToast(
        msg: 'Tournament cancelled due to insufficient players',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint('Error cancelling tournament: $e');
    }
  }

  String getTournamentStatus(Map<String, dynamic> data) {
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final players = List<String>.from(data['players'] ?? []);
    final maxPlayers = data['playerCount'] ?? 8;

    if (data['status'] == 'cancelled') return 'Cancelled';
    if (players.length >= maxPlayers) return 'Full';
    if (data['winner'] != null || (endDate != null && now.isAfter(endDate))) {
      return 'Completed';
    }
    if (startDate != null) {
      if (startDate.isBefore(now)) return 'Ongoing';
      return 'Upcoming';
    }
    return 'Upcoming';
  }

  Future<void> joinTournament(String tournamentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        Fluttertoast.showToast(
          msg: 'Please login to join tournament',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      await _firestore.runTransaction((transaction) async {
        final tournamentDoc = await transaction
            .get(_firestore.collection('tournaments').doc(tournamentId));
        final tournamentData = tournamentDoc.data()!;
        final players = List<String>.from(tournamentData['players'] ?? []);
        final maxPlayers = tournamentData['playerCount'] ?? 8;

        if (tournamentData['status'] == 'cancelled') {
          throw Exception('This tournament has been cancelled');
        }

        final liveStatus = getTournamentStatus(tournamentData);
        if (liveStatus == 'Completed') {
          throw Exception('This tournament is already completed');
        }
        if (liveStatus == 'Ongoing') {
          throw Exception('This tournament has already started');
        }
        if (liveStatus == 'Full') {
          throw Exception('Tournament is full');
        }

        if (players.contains(user.uid)) {
          throw Exception('Already joined this tournament');
        }
        if (players.length >= maxPlayers) {
          throw Exception('Tournament is full');
        }

        final roundOneMatches = await _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .collection('matches')
            .where('round', isEqualTo: 1)
            .orderBy('matchNumber')
            .get();

        DocumentReference? targetMatchRef;
        String? targetField;

        for (final match in roundOneMatches.docs) {
          final matchRef = match.reference;
          final freshSnap = await transaction.get(matchRef);
          final freshData = freshSnap.data();
          if (freshData == null) continue;

          if (freshData['player1'] == null) {
            targetMatchRef = matchRef;
            targetField = 'player1';
            break;
          }
          if (freshData['player2'] == null) {
            targetMatchRef = matchRef;
            targetField = 'player2';
            break;
          }
        }

        if (targetMatchRef == null || targetField == null) {
          throw Exception('Tournament is full');
        }

        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {'tournaments': FieldValue.arrayUnion([tournamentId])},
        );
        transaction.update(
          _firestore.collection('tournaments').doc(tournamentId),
          {
            'players': FieldValue.arrayUnion([user.uid]),
            'currentPlayers': FieldValue.increment(1),
          },
        );
        transaction.update(targetMatchRef, {targetField: user.uid});
      });

      Fluttertoast.showToast(
        msg: 'Successfully joined tournament!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString().replaceAll('Exception:', '').trim(),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Ongoing':
        return ColorResources.success;
      case 'Completed':
        return const Color(0xFF64B5F6);
      case 'Full':
      case 'Cancelled':
        return ColorResources.error;
      default:
        return ColorResources.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PremiumAppBar(title: 'Tournaments'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Events',
                  style: TextStyle(
                    color: ColorResources.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Join a bracket, play rated rounds, climb the field',
                  style: TextStyle(
                    color: ColorResources.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in const [
                        'All',
                        'Upcoming',
                        'Ongoing',
                        'Completed'
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                            showCheckmark: false,
                            selectedColor: ColorResources.primary,
                            labelStyle: TextStyle(
                              color: _filter == f
                                  ? ColorResources.onPrimary
                                  : ColorResources.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            backgroundColor: ColorResources.elevatedSurface,
                            side: BorderSide(
                              color: _filter == f
                                  ? ColorResources.primary
                                  : ColorResources.divider,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('tournaments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Loader());
                }
                if (snapshot.hasError) {
                  return const EmptyStateWidget(
                    message: 'Could not load tournaments.',
                    icon: Icons.error_outline,
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = getTournamentStatus(data);
                  if (_filter == 'All') return status != 'Cancelled';
                  return status == _filter;
                }).toList();

                if (filtered.isEmpty) {
                  return _TournamentEmptyState(filter: _filter);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tournament = filtered[index];
                    final data = tournament.data() as Map<String, dynamic>;
                    final startDate =
                        (data['startDate'] as Timestamp?)?.toDate();
                    final status = getTournamentStatus(data);
                    final players = List<String>.from(data['players'] ?? []);
                    final maxPlayers = data['playerCount'] ?? 8;
                    final roundTimes =
                        data['roundTimes'] as Map<dynamic, dynamic>?;
                    final hasJoined =
                        players.contains(_auth.currentUser?.uid);
                    final isFull = players.length >= maxPlayers;
                    final isRound1Started = roundTimes?[1] != null &&
                        DateTime.parse(roundTimes![1] as String)
                            .isBefore(DateTime.now());
                    final isOpenForJoin = status == 'Upcoming';
                    final canJoin = isOpenForJoin &&
                        !hasJoined &&
                        !isFull &&
                        !isRound1Started;

                    return _TournamentCard(
                      name: data['name']?.toString() ?? 'Unnamed Tournament',
                      players: players.length,
                      maxPlayers: maxPlayers,
                      startDate: startDate,
                      status: status,
                      statusColor: _statusColor(status),
                      roundCount: roundTimes?.length ?? 0,
                      actionLabel: hasJoined
                          ? 'Enter room'
                          : canJoin
                              ? 'Join'
                              : 'View details',
                      onAction: () {
                        if (canJoin) {
                          joinTournament(tournament.id);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentDetailsScreen(
                                tournamentId: tournament.id,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final String name;
  final int players;
  final int maxPlayers;
  final DateTime? startDate;
  final String status;
  final Color statusColor;
  final int roundCount;
  final String actionLabel;
  final VoidCallback onAction;

  const _TournamentCard({
    required this.name,
    required this.players,
    required this.maxPlayers,
    required this.startDate,
    required this.status,
    required this.statusColor,
    required this.roundCount,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxPlayers == 0 ? 0.0 : players / maxPlayers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorResources.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorResources.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ColorResources.primary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: ColorResources.accentSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ColorResources.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Rated bracket',
                      style: TextStyle(
                        color: ColorResources.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetaChip(
                icon: Icons.group_outlined,
                text: '$players / $maxPlayers',
              ),
              const SizedBox(width: 8),
              if (startDate != null)
                _MetaChip(
                  icon: Icons.schedule,
                  text: DateFormat('d MMM · h:mm a').format(startDate!),
                ),
            ],
          ),
          if (roundCount > 0) ...[
            const SizedBox(height: 8),
            _MetaChip(
              icon: Icons.account_tree_outlined,
              text: '$roundCount rounds',
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: ColorResources.elevatedSurface,
              color: ColorResources.primary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ColorResources.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ColorResources.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: ColorResources.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentEmptyState extends StatelessWidget {
  final String filter;

  const _TournamentEmptyState({required this.filter});

  IconData get _icon {
    switch (filter) {
      case 'Upcoming':
        return Icons.event_available_outlined;
      case 'Ongoing':
        return Icons.sports_esports_outlined;
      case 'Completed':
        return Icons.emoji_events_outlined;
      default:
        return Icons.inbox_outlined;
    }
  }

  String get _title {
    switch (filter) {
      case 'Upcoming':
        return 'No upcoming events';
      case 'Ongoing':
        return 'Nothing live right now';
      case 'Completed':
        return 'No completed events yet';
      default:
        return 'No tournaments yet';
    }
  }

  String get _subtitle {
    switch (filter) {
      case 'Upcoming':
        return 'New brackets will show up here when they are scheduled.';
      case 'Ongoing':
        return 'Check back when a tournament is in progress.';
      case 'Completed':
        return 'Finished events will appear here after they wrap up.';
      default:
        return 'When events are added, you will see them listed here.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: ColorResources.surface,
                shape: BoxShape.circle,
                border: Border.all(color: ColorResources.divider),
              ),
              child: Icon(
                _icon,
                size: 40,
                color: ColorResources.accentSoft,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColorResources.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColorResources.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
