import 'dart:math';

import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/CreateTournamentProvider/CreateTournamentProvider.dart';
import 'package:chess_cash/Screens/TournamentScreens/tournament_details_screen.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class CreateTournament extends StatefulWidget {
  const CreateTournament({super.key});

  @override
  State<CreateTournament> createState() => _CreateTournamentState();
}

class _CreateTournamentState extends State<CreateTournament>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _roomCodeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _joinTournamentByRoomCode() async {
    if (_roomCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code')),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Please login to join tournament');

      final tournamentsQuery = await _firestore
          .collection('user_tournaments')
          .where('roomCode', isEqualTo: _roomCodeController.text.toUpperCase())
          .get();

      if (tournamentsQuery.docs.isEmpty) {
        throw Exception('Tournament not found with this room code');
      }

      final tournamentDoc = tournamentsQuery.docs.first;
      final tournamentData = tournamentDoc.data();
      final tournamentId = tournamentDoc.id;
      final players = List<String>.from(tournamentData['players'] ?? []);
      final maxPlayers = tournamentData['playerCount'] ?? 8;
      final status = tournamentData['status'] ?? 'pending';

      if (status == 'cancelled') {
        throw Exception('This tournament has been cancelled');
      }
      if (status == 'completed') {
        throw Exception('This tournament is already completed');
      }
      final endDate = tournamentData['endDate'] != null
          ? (tournamentData['endDate'] as Timestamp).toDate()
          : null;
      if (endDate != null && DateTime.now().isAfter(endDate)) {
        throw Exception('This tournament is already completed');
      }
      if (tournamentData['winner'] != null) {
        throw Exception('This tournament is already completed');
      }
      if (players.contains(user.uid)) {
        throw Exception('You have already joined this tournament');
      }
      if (players.length >= maxPlayers) {
        throw Exception('Tournament is full');
      }

      await _firestore.runTransaction((transaction) async {
        final freshTournamentDoc = await transaction
            .get(_firestore.collection('user_tournaments').doc(tournamentId));
        final freshTournamentData = freshTournamentDoc.data()!;
        final freshPlayers =
            List<String>.from(freshTournamentData['players'] ?? []);
        final freshMaxPlayers = freshTournamentData['playerCount'] ?? 8;

        if (freshPlayers.contains(user.uid)) {
          throw Exception('Already joined this tournament');
        }
        if (freshPlayers.length >= freshMaxPlayers) {
          throw Exception('Tournament is full');
        }

        final roundOneMatches = await _firestore
            .collection('user_tournaments')
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
          _firestore.collection('user_tournaments').doc(tournamentId),
          {
            'players': FieldValue.arrayUnion([user.uid]),
            'currentPlayers': FieldValue.increment(1),
          },
        );
        transaction.update(targetMatchRef, {targetField: user.uid});
      });

      _roomCodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Joined ${tournamentData['name'] ?? 'contest'} successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PremiumAppBar(title: 'Private room'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ColorResources.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorResources.divider),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: ColorResources.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: ColorResources.onPrimary,
                unselectedLabelColor: ColorResources.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Create'),
                  Tab(text: 'Join'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateTab(),
                _buildJoinTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return Consumer<CreateTournamentProvider>(
      builder: (context, provider, child) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const Text(
              'Create a contest',
              style: TextStyle(
                color: ColorResources.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Invite friends with a room code',
              style: TextStyle(
                color: ColorResources.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            Form(
              key: provider.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: provider.tournamentNameController,
                    decoration: const InputDecoration(
                      labelText: 'Contest name',
                      hintText: 'Friday Night Blitz',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a contest name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: ColorResources.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorResources.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: provider.selectedPlayerCount,
                        isExpanded: true,
                        dropdownColor: ColorResources.surface,
                        items: [4, 6, 8, 16, 32, 64]
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('$n players'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => provider.selectedPlayerCount = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DateTile(
                    title: 'Start date',
                    value: provider.startDate == null
                        ? 'Select start date'
                        : DateFormat('d MMM yyyy').format(provider.startDate!),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: provider.startDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) provider.setStartDate(date);
                    },
                  ),
                  const SizedBox(height: 10),
                  _DateTile(
                    title: 'End date',
                    value: provider.endDate == null
                        ? 'Select end date'
                        : DateFormat('d MMM yyyy').format(provider.endDate!),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: provider.endDate ??
                            (provider.startDate ?? DateTime.now()),
                        firstDate: provider.startDate ?? DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) provider.setEndDate(date);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Round times (${provider.numberOfRounds})',
                    style: const TextStyle(
                      color: ColorResources.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(provider.numberOfRounds, (index) {
                    final round = index + 1;
                    final roundTime = provider.roundTimes[round];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DateTile(
                        title: 'Round $round',
                        value: roundTime == null
                            ? 'Pick date & time'
                            : DateFormat('d MMM · HH:mm').format(roundTime),
                        icon: Icons.schedule,
                        onTap: () async {
                          DateTime minimumDate = DateTime.now();
                          if (round == 1) {
                            minimumDate =
                                provider.startDate ?? DateTime.now();
                          } else {
                            minimumDate =
                                provider.roundTimes[round - 1] ?? DateTime.now();
                          }

                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                provider.roundTimes[round] ?? minimumDate,
                            firstDate: minimumDate,
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (date == null) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: provider.roundTimes[round] != null
                                ? TimeOfDay.fromDateTime(
                                    provider.roundTimes[round]!)
                                : TimeOfDay.now(),
                          );
                          if (time == null) return;
                          provider.setRoundTime(
                            round,
                            DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            ),
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  ChessPrimaryButton(
                    label: provider.isLoading
                        ? 'Creating...'
                        : 'Create contest',
                    icon: Icons.add_circle_outline,
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            if (!provider.formKey.currentState!.validate()) {
                              return;
                            }
                            try {
                              final tournamentRef =
                                  await provider.createTournament();
                              final roomCode = _generateRoomCode();
                              await tournamentRef
                                  .update({'roomCode': roomCode});
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Contest created. Room code: $roomCode'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJoinTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const Text(
          'Join with a code',
          style: TextStyle(
            color: ColorResources.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter the 6-character room code from your friend',
          style: TextStyle(
            color: ColorResources.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _roomCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Room code',
            hintText: 'ABC123',
          ),
        ),
        const SizedBox(height: 14),
        ChessPrimaryButton(
          label: _isJoining ? 'Joining...' : 'Join contest',
          icon: Icons.login_rounded,
          onPressed: _isJoining ? null : _joinTournamentByRoomCode,
        ),
        const SizedBox(height: 28),
        const ChessSectionHeader(title: 'My rooms'),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('user_tournaments')
              .where('players', arrayContains: _auth.currentUser?.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Loader()),
              );
            }

            final tournaments = snapshot.data?.docs ?? [];
            if (tournaments.isEmpty) {
              return const EmptyStateWidget(
                message: 'No private rooms yet. Create one or join with a code.',
                icon: Icons.meeting_room_outlined,
              );
            }

            return Column(
              children: tournaments.map((tournament) {
                final data = tournament.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'Unknown Tournament';
                final playerCount = data['playerCount'] ?? 8;
                final currentPlayers = data['currentPlayers'] ?? 0;
                final status = data['status'] ?? 'pending';
                final startDate = data['startDate'] != null
                    ? (data['startDate'] as Timestamp).toDate()
                    : null;
                final endDate = data['endDate'] != null
                    ? (data['endDate'] as Timestamp).toDate()
                    : null;
                final roomCode = data['roomCode'] ?? 'N/A';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ColorResources.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ColorResources.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.meeting_room_outlined,
                                color: ColorResources.accentSoft),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: ColorResources.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              _statusText(status, endDate),
                              style: TextStyle(
                                color: _statusColor(status, endDate),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$currentPlayers / $playerCount players  ·  Code $roomCode',
                          style: const TextStyle(
                            color: ColorResources.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (startDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Starts ${DateFormat('d MMM · h:mm a').format(startDate)}',
                            style: const TextStyle(
                              color: ColorResources.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TournamentDetailsScreen(
                                        tournamentId: tournament.id,
                                        isFromTournament: false,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Details'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await Share.share(
                                      "Join my ChessArena contest \"$name\" with room code: $roomCode",
                                    );
                                  } catch (_) {
                                    Fluttertoast.showToast(
                                      msg: 'Failed to share',
                                      backgroundColor: Colors.red,
                                    );
                                  }
                                },
                                child: const Text('Share'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _statusText(String status, DateTime? endDate) {
    if (endDate != null &&
        DateTime.now().isAfter(endDate) &&
        status.toLowerCase() == 'pending') {
      return 'Completed';
    }
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _statusColor(String status, DateTime? endDate) {
    if (endDate != null &&
        DateTime.now().isAfter(endDate) &&
        status.toLowerCase() == 'pending') {
      return const Color(0xFF64B5F6);
    }
    switch (status.toLowerCase()) {
      case 'pending':
        return ColorResources.warning;
      case 'active':
        return ColorResources.success;
      case 'completed':
        return const Color(0xFF64B5F6);
      case 'cancelled':
        return ColorResources.error;
      default:
        return ColorResources.textSecondary;
    }
  }
}

class _DateTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final IconData icon;

  const _DateTile({
    required this.title,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: ColorResources.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorResources.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ColorResources.accentSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ColorResources.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: ColorResources.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: ColorResources.textSecondary),
          ],
        ),
      ),
    );
  }
}
