import 'dart:math' show log;

import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/TournamentScreens/tornament_waiting_room.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TournamentDetailsScreen extends StatelessWidget {
  final String tournamentId;
  final bool isFromTournament;

  const TournamentDetailsScreen({
    super.key,
    required this.tournamentId,
    this.isFromTournament = true,
  });

  @override
  Widget build(BuildContext context) {
    Future<String> getPlayerName(String? uid) async {
      if (uid == null) return 'TBD';
      try {
        final playerDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        return playerDoc.data()?['username'] ?? 'Unknown Player';
      } catch (e) {
        return 'Unknown Player';
      }
    }

    bool isMatchTimeNear(Map<dynamic, dynamic> roundTimes, int roundNumber) {
      try {
        final roundTime = roundTimes[roundNumber.toString()];
        if (roundTime == null) return false;

        final matchDateTime = DateTime.parse(roundTime.toString());
        final now = DateTime.now();
        final difference = matchDateTime.difference(now);

        // Return true if match is within next 5 minutes and hasn't started more than 10 minutes ago
        return difference.inMinutes >= -10 && difference.inMinutes <= 5;
      } catch (e) {
        return false;
      }
    }

    String getRoundTitle(int currentRound, int maxPlayers) {
      // Calculate total rounds based on maxPlayers
      // Example:
      // 2 players = 1 round (Finals)
      // 4 players = 2 rounds (Semi Finals, Finals)
      // 8 players = 3 rounds (Quarter Finals, Semi Finals, Finals)
      // 16 players = 4 rounds (Round 1, Quarter Finals, Semi Finals, Finals)
      // 32 players = 5 rounds (Round 1, Round 2, Quarter Finals, Semi Finals, Finals)
      int totalRounds = (log(maxPlayers) / log(2)).floor();

      // For tournaments with 4 or fewer players, adjust titles
      if (maxPlayers <= 4) {
        if (maxPlayers == 2) {
          // 2 players
          return 'Finals';
        } else if (maxPlayers == 4) {
          // 4 players
          // For 4 players: Round 1 is Semi Finals, Round 2 is Finals
          return currentRound == 1 ? 'Semi Finals' : 'Finals';
        }
      }

      // For tournaments with 8 or more players
      if (currentRound == totalRounds) {
        return 'Finals';
      } else if (currentRound == totalRounds - 1) {
        return 'Semi Finals';
      } else if (currentRound == totalRounds - 2 && maxPlayers >= 8) {
        // Only show Quarter Finals for 8 or more players
        return 'Quarter Finals';
      } else {
        // For earlier rounds in larger tournaments (16+ players)
        return 'Round $currentRound';
      }
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(isFromTournament ? 'tournaments' : 'user_tournaments')
          .doc(tournamentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: const PremiumAppBar(title: 'Tournament'),
            body: const EmptyStateWidget(
              message: 'Something went wrong',
              icon: Icons.error_outline,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: PremiumAppBar(title: 'Tournament'),
            body: Center(child: Loader()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final roundTimes = data['roundTimes'] as Map<dynamic, dynamic>?;
        final players = List<String>.from(data['players'] ?? []);
        final maxPlayers = data['playerCount'] ?? 8;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: PremiumAppBar(
              title: data['name']?.toString() ?? 'Tournament',
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ColorResources.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorResources.divider),
                    ),
                    child: const TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: ColorResources.primary,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      labelColor: ColorResources.onPrimary,
                      unselectedLabelColor: ColorResources.textSecondary,
                      labelStyle: TextStyle(fontWeight: FontWeight.w800),
                      tabs: [
                        Tab(text: 'Overview'),
                        Tab(text: 'Matches'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: ColorResources.divider),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2A3A24),
                                    Color(0xFF25282F),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'EVENT',
                                    style: TextStyle(
                                      color: ColorResources.accentSoft,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    data['name']?.toString() ?? 'Tournament',
                                    style: const TextStyle(
                                      color: ColorResources.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      _InfoPill(
                                        label: 'Players',
                                        value:
                                            '${players.length}/$maxPlayers',
                                      ),
                                      const SizedBox(width: 8),
                                      const _InfoPill(
                                        label: 'Format',
                                        value: 'Bracket',
                                      ),
                                      const SizedBox(width: 8),
                                      _InfoPill(
                                        label: 'Rounds',
                                        value: '${roundTimes?.length ?? 0}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (roundTimes != null) ...[
                              const SizedBox(height: 16),
                              const ChessSectionHeader(title: 'Schedule'),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: ColorResources.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: ColorResources.divider),
                                ),
                                child: Column(
                                  children: roundTimes.entries.map((entry) {
                                    final roundDateTime =
                                        DateTime.parse(entry.value as String);
                                    final isUpcoming =
                                        roundDateTime.isAfter(DateTime.now());
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 72,
                                            child: Text(
                                              'Round ${entry.key}',
                                              style: const TextStyle(
                                                color:
                                                    ColorResources.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              DateFormat('d MMM · h:mm a')
                                                  .format(roundDateTime),
                                              style: TextStyle(
                                                color: isUpcoming
                                                    ? ColorResources
                                                        .textPrimary
                                                    : ColorResources
                                                        .textSecondary,
                                              ),
                                            ),
                                          ),
                                          if (isUpcoming)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: ColorResources.primary
                                                    .withOpacity(0.18),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Upcoming',
                                                style: TextStyle(
                                                  color: ColorResources
                                                      .accentSoft,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(isFromTournament
                          ? 'tournaments'
                          : 'user_tournaments')
                      .doc(tournamentId)
                      .collection('matches')
                      .orderBy('round', descending: true)
                      .snapshots(),
                  builder: (context, matchSnapshot) {
                    if (matchSnapshot.hasError) {
                      return const EmptyStateWidget(
                        message: 'Error loading matches',
                        icon: Icons.error_outline,
                      );
                    }

                    if (matchSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: Loader());
                    }

                    final matches = matchSnapshot.data!.docs;
                    if (matches.isEmpty) {
                      return const EmptyStateWidget(
                        message: 'No matches scheduled yet',
                        icon: Icons.sports_esports_outlined,
                      );
                    }

                    // Group matches by round and sort them
                    Map<int, List<QueryDocumentSnapshot>> matchesByRound = {};
                    for (var match in matches) {
                      final matchData = match.data() as Map<String, dynamic>;
                      final round = matchData['round'] as int? ?? 1;
                      matchesByRound.putIfAbsent(round, () => []);
                      matchesByRound[round]!.add(match);
                    }

                    // Get max players from tournament data
                    final maxPlayers = data['playerCount'] as int? ?? 8;

                    // Sort rounds in ascending order for proper display
                    final sortedRounds = matchesByRound.keys.toList()..sort();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: matchesByRound.length,
                      itemBuilder: (context, index) {
                        final round = sortedRounds[index];
                        final roundMatches = matchesByRound[round]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: ColorResources.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: ColorResources.primary
                                        .withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    getRoundTitle(round, maxPlayers),
                                    style: const TextStyle(
                                      color: ColorResources.accentSoft,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (roundTimes != null &&
                                      roundTimes[round.toString()] != null)
                                    Text(
                                      DateFormat('d MMM · h:mm a').format(
                                          DateTime.parse(
                                              roundTimes[round.toString()]
                                                  as String)),
                                      style: const TextStyle(
                                        color: ColorResources.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ...roundMatches.map((match) {
                              final matchId = match.id;
                              final matchData =
                                  match.data() as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: matchData['status'] ==
                                                      'completed'
                                                  ? Colors.green
                                                  : matchData['status'] ==
                                                          'ongoing'
                                                      ? Colors.orange
                                                      : Colors.blue,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              matchData['status']
                                                      ?.toString()
                                                      .toUpperCase() ??
                                                  'PENDING',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Column(
                                            children: [
                                              const CircleAvatar(
                                                child: Icon(Icons.person),
                                              ),
                                              const SizedBox(height: 8),
                                              FutureBuilder<String>(
                                                future: matchData['player1'] ==
                                                        FirebaseAuth.instance
                                                            .currentUser?.uid
                                                    ? Future.value('You')
                                                    : getPlayerName(
                                                        matchData['player1']
                                                            ?.toString()),
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const CircularProgressIndicator();
                                                  }
                                                  return Text(
                                                    snapshot.data ?? 'TBD',
                                                    style: TextStyle(
                                                      color: matchData[
                                                                  'player1'] ==
                                                              FirebaseAuth
                                                                  .instance
                                                                  .currentUser
                                                                  ?.uid
                                                          ? Colors.green
                                                          : Colors.white,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const Text(
                                            'VS',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              const CircleAvatar(
                                                child: Icon(Icons.person),
                                              ),
                                              const SizedBox(height: 8),
                                              FutureBuilder<String>(
                                                future: matchData['player2'] ==
                                                        FirebaseAuth.instance
                                                            .currentUser?.uid
                                                    ? Future.value('You')
                                                    : getPlayerName(
                                                        matchData['player2']
                                                            ?.toString()),
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const CircularProgressIndicator();
                                                  }
                                                  return Text(
                                                    snapshot.data ?? 'TBD',
                                                    style: TextStyle(
                                                      color: matchData[
                                                                  'player2'] ==
                                                              FirebaseAuth
                                                                  .instance
                                                                  .currentUser
                                                                  ?.uid
                                                          ? Colors.green
                                                          : Colors.white,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (matchData['winner'] != null) ...[
                                        const SizedBox(height: 16),
                                        FutureBuilder<String>(
                                          future: getPlayerName(
                                              matchData['winner']?.toString()),
                                          builder: (context, snapshot) {
                                            return Text(
                                              'Winner: ${snapshot.data ?? 'Unknown'}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                      if ((matchData['player1'] ==
                                                  FirebaseAuth.instance
                                                      .currentUser?.uid ||
                                              matchData['player2'] ==
                                                  FirebaseAuth.instance
                                                      .currentUser?.uid) &&
                                          isMatchTimeNear(
                                              data['roundTimes'] ?? {},
                                              round) &&
                                          matchData['winnerId'] == null) ...[
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () {
                                            push(
                                                context,
                                                TournamentWaitingRoom(
                                                    roomCode: matchId,
                                                    tournamentId: tournamentId,
                                                    player1:
                                                        matchData['player1'],
                                                    player2:
                                                        matchData['player2']));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 32, vertical: 12),
                                          ),
                                          child: const Text(
                                            'Play Match',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: ColorResources.elevatedSurface.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: ColorResources.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: ColorResources.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on int {
  int toStringLength() {
    if (this <= 1) return 0;
    return (log(this) / log(2)).floor() + 1;
  }
}
