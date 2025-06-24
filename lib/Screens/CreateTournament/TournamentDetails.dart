import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/TournamentScreens/tornament_waiting_room.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Providers/CreateTournamentProvider/CreateTournamentProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:math' show log;

class TournamentDetails extends StatelessWidget {
  final String tournamentId;

  const TournamentDetails({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    Future<String> getPlayerName(String? uid) async {
      if (uid == null) return 'TBD';
      try {
        final playerDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        return playerDoc.data()?['displayName'] ?? playerDoc.data()?['username'] ?? 'Unknown Player';
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
      stream: FirebaseFirestore.instance.collection('users_tournaments').doc(tournamentId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament Details')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Something went wrong', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament Details')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading tournament details...'),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament Details')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tournament not found', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament Details')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.data_usage, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tournament data not available', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }

        final tournament = data as Map<String, dynamic>;
        final currentUser = FirebaseAuth.instance.currentUser;
        final players = List<String>.from(tournament['players'] ?? []);
        final isJoined = currentUser != null && players.contains(currentUser.uid);
        final maxPlayers = tournament['maxPlayers'] as int? ?? 8;
        final status = tournament['status'] ?? 'unknown';
        final startDateTime = tournament['startDateTime'] != null ? DateTime.parse(tournament['startDateTime']) : null;
        final roundSchedules = tournament['roundSchedules'] as Map<String, dynamic>? ?? {};
        final numberOfRounds = tournament['numberOfRounds'] ?? 1;
        final entryFee = tournament['entryFee'] ?? 0;
        final prizeAmount = tournament['prizeAmount'] ?? 0;
        final roundTimes = tournament['roundTimes'] as Map<dynamic, dynamic>?;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tournament['name'] ?? 'Tournament Details'),
              backgroundColor: ColorResources.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Matches'),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              ),
            ),
            body: TabBarView(
              children: [
                // Overview Tab
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Tournament Header Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ColorResources.primaryColor, ColorResources.primaryColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tournament['name'] ?? 'Unnamed Tournament',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: _getStatusColor(status),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _buildInfoCard(
                                    icon: Icons.people,
                                    title: 'Players',
                                    value: '$maxPlayers',
                                    subtitle: '${players.length} joined',
                                  ),
                                  const SizedBox(width: 16),
                                  _buildInfoCard(
                                    icon: Icons.schedule,
                                    title: 'Rounds',
                                    value: '$numberOfRounds',
                                    subtitle: 'Total rounds',
                                  ),
                                  const SizedBox(width: 16),
                                  _buildInfoCard(
                                    icon: Icons.calendar_today,
                                    title: 'Start Date',
                                    value: startDateTime != null ? '${startDateTime.day}/${startDateTime.month}' : 'TBD',
                                    subtitle: startDateTime != null ? '${startDateTime.hour}:${startDateTime.minute.toString().padLeft(2, '0')}' : 'Not set',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Join Button
                            if (!isJoined && status == 'pending')
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 24),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await context.read<CreateTournamentProvider>().joinTournament(tournamentId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Successfully joined tournament!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColorResources.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add),
                                      SizedBox(width: 8),
                                      Text(
                                        'Join Tournament',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Prize Pool Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Prize Pool',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Column(
                                          children: [
                                            const Text('Entry Fee'),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₹$entryFee',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            const Text('Prize Amount'),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₹$prizeAmount',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Round Schedules
                            if (roundSchedules.isNotEmpty) ...[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tournament Schedule',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 16),
                                      ...List.generate(numberOfRounds, (index) {
                                        final round = index + 1;
                                        final roundData = roundSchedules['round_$round'] as Map<String, dynamic>? ?? {};
                                        final roundDateTime = roundData['dateTime'] != null ? DateTime.parse(roundData['dateTime']) : null;
                                        final timer = roundData['timer'] ?? 0;

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: ColorResources.primaryColor.withOpacity(0.9),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'R$round',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: ColorResources.secondaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Round $round',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    if (roundDateTime != null)
                                                      Text(
                                                        DateFormat('d MMM, h:mm a').format(roundDateTime),
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '$timer minutes per match',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Icon(
                                              //   Icons.arrow_forward_ios,
                                              //   color: Colors.grey[400],
                                              //   size: 16,
                                              // ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Matches Tab
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users_tournaments').doc(tournamentId).collection('matches').orderBy('round', descending: true).snapshots(),
                  builder: (context, matchSnapshot) {
                    if (matchSnapshot.hasError) {
                      return const Center(child: Text('Error loading matches'));
                    }

                    if (matchSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final matches = matchSnapshot.data!.docs;
                    print('TournamentDetails: Found ${matches.length} matches');
                    print('TournamentDetails: Tournament data: $tournament');

                    if (matches.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sports_esports, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No matches scheduled yet', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            const Text('Matches will be created when players join', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await context.read<CreateTournamentProvider>().generateMatchesForTournament(tournamentId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Matches generated successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error generating matches: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Generate Matches'),
                            ),
                          ],
                        ),
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
                    final maxPlayers = tournament['maxPlayers'] as int? ?? 8;

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
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    getRoundTitle(round, maxPlayers),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (roundTimes != null && roundTimes[round.toString()] != null)
                                    Text(
                                      DateFormat('d MMM, h:mm a').format(DateTime.parse(roundTimes[round.toString()] as String)),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ...roundMatches.map((match) {
                              final matchId = match.id;
                              final matchData = match.data() as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: matchData['status'] == 'completed'
                                                  ? Colors.green
                                                  : matchData['status'] == 'ongoing'
                                                      ? Colors.orange
                                                      : Colors.blue,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              matchData['status']?.toString().toUpperCase() ?? 'PENDING',
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          Column(
                                            children: [
                                              const CircleAvatar(
                                                child: Icon(Icons.person),
                                              ),
                                              const SizedBox(height: 8),
                                              FutureBuilder<String>(
                                                future: matchData['player1'] == FirebaseAuth.instance.currentUser?.uid ? Future.value('You') : getPlayerName(matchData['player1']?.toString()),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return const CircularProgressIndicator();
                                                  }
                                                  return Text(
                                                    snapshot.data ?? 'TBD',
                                                    style: TextStyle(
                                                      color: matchData['player1'] == FirebaseAuth.instance.currentUser?.uid ? Colors.green : Colors.white,
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
                                                future: matchData['player2'] == FirebaseAuth.instance.currentUser?.uid ? Future.value('You') : getPlayerName(matchData['player2']?.toString()),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return const CircularProgressIndicator();
                                                  }
                                                  return Text(
                                                    snapshot.data ?? 'TBD',
                                                    style: TextStyle(
                                                      color: matchData['player2'] == FirebaseAuth.instance.currentUser?.uid ? Colors.green : Colors.white,
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
                                          future: getPlayerName(matchData['winner']?.toString()),
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
                                      if ((matchData['player1'] == FirebaseAuth.instance.currentUser?.uid || matchData['player2'] == FirebaseAuth.instance.currentUser?.uid) &&
                                          isMatchTimeNear(tournament['roundTimes'] ?? {}, round) &&
                                          matchData['winnerId'] == null) ...[
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () {
                                            push(context, TournamentWaitingRoom(roomCode: matchId, tournamentId: tournamentId, player1: matchData['player1'], player2: matchData['player2']));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
