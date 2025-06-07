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

  String getTournamentStatus(Map<String, dynamic> data) {
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final players = List<String>.from(data['players'] ?? []);
    final maxPlayers = data['playerCount'] ?? 8;

    // if (players.length >= maxPlayers) return 'Full';

    if (data['winner'] != null || (endDate != null && now.isAfter(endDate)))
      return 'Completed';
    if (startDate != null) {
      if (startDate.isBefore(now)) return 'Ongoing';
      return 'Upcoming';
    }
    return 'Upcoming';
  }

  Future<void> joinTournament(String tournamentId, double entryFee) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        Fluttertoast.showToast(
          msg: "Please login to join tournament",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Get user's current balance
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userBalance = (userDoc.data()?['Balance'] ?? 0.0) as double;

      if (userBalance < entryFee) {
        Fluttertoast.showToast(
          msg:
              "Insufficient balance! Need ₹${entryFee.toStringAsFixed(2)} to join",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Start a transaction to handle balance deduction and tournament joining
      await _firestore.runTransaction((transaction) async {
        // Get fresh user data within transaction
        final freshUserDoc =
            await transaction.get(_firestore.collection('users').doc(user.uid));
        final currentBalance =
            (freshUserDoc.data()?['Balance'] ?? 0.0) as double;

        if (currentBalance < entryFee) {
          throw Exception('Insufficient balance');
        }

        // Get tournament data to check if it's still joinable
        final tournamentDoc = await transaction
            .get(_firestore.collection('tournaments').doc(tournamentId));
        final tournamentData = tournamentDoc.data()!;
        final players = List<String>.from(tournamentData['players'] ?? []);
        final maxPlayers = tournamentData['playerCount'] ?? 8;

        if (players.contains(user.uid)) {
          throw Exception('Already joined this tournament');
        }

        if (players.length >= maxPlayers) {
          throw Exception('Tournament is full');
        }

        // Deduct entry fee
        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {
            'Balance': currentBalance - entryFee,
            'tournaments': FieldValue.arrayUnion([tournamentId])
          },
        );

        // Add to tournament players
        transaction.update(
          _firestore.collection('tournaments').doc(tournamentId),
          {
            'players': FieldValue.arrayUnion([user.uid]),
            'currentPlayers': FieldValue.increment(1),
          },
        );

        // Find first available match
        final matchesSnapshot = await _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .collection('matches')
            .where('player1', isNull: true)
            .limit(1)
            .get();

        if (matchesSnapshot.docs.isNotEmpty) {
          transaction.update(
            matchesSnapshot.docs.first.reference,
            {'player1': user.uid},
          );
        } else {
          final matchesSnapshot2 = await _firestore
              .collection('tournaments')
              .doc(tournamentId)
              .collection('matches')
              .where('player2', isNull: true)
              .limit(1)
              .get();

          if (matchesSnapshot2.docs.isNotEmpty) {
            transaction.update(
              matchesSnapshot2.docs.first.reference,
              {'player2': user.uid},
            );
          }
        }
      });

      Fluttertoast.showToast(
        msg: "Successfully joined tournament!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString().replaceAll('Exception:', '').trim(),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      print('Error joining tournament: $e');
    }
  }

  Widget _buildRoundTimes(Map<dynamic, dynamic>? roundTimes) {
    if (roundTimes == null || roundTimes.isEmpty)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            Icon(Icons.event_note, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              'Tournament Rounds',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...roundTimes.entries.map((entry) {
          final roundNumber = entry.key;
          final roundDateTime = DateTime.parse(entry.value as String);
          return Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4),
            child: Row(
              children: [
                Text(
                  'Round $roundNumber: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  DateFormat('d MMM, h:mm a').format(roundDateTime),
                  style: TextStyle(
                    color: roundDateTime.isBefore(DateTime.now())
                        ? Colors.grey
                        : Colors.white,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // get only upcoming Tournaments

        stream: _firestore.collection('tournaments').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.data?.docs.isEmpty ?? true) {
            return const Center(
              child: Text('No Tournament found'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final tournament = snapshot.data!.docs[index];
              final data = tournament.data() as Map<String, dynamic>;
              final startDate = (data['startDate'] as Timestamp?)?.toDate();
              final status = getTournamentStatus(data);
              final players = List<String>.from(data['players'] ?? []);
              final maxPlayers = data['playerCount'] ?? 8;
              final roundTimes = data['roundTimes'] as Map<dynamic, dynamic>?;

              return Card(
                margin: const EdgeInsets.all(12.0),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tournament Name
                      Text(
                        data['name'] ?? 'Unnamed Tournament',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),

                      // Entry Fee and Prize Amount
                      Row(
                        children: [
                          Icon(Icons.monetization_on,
                              size: 20, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Entry: ₹${data['entryFee']?.toString() ?? '0'} | Prize: ₹${data['prizeAmount']?.toString() ?? '0'}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Player Count
                      Row(
                        children: [
                          const Icon(Icons.group, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Players: ${players.length}/$maxPlayers',
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (maxPlayers - players.length <= 1) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Only ${maxPlayers - players.length} slots left!',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Start Time
                      if (startDate != null)
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Round 1: ${DateFormat('d MMM, h:mm a').format(startDate)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),

                      // Round Times
                      _buildRoundTimes(roundTimes),

                      // Status
                      Row(
                        children: [
                          Icon(
                            status == 'Ongoing'
                                ? Icons.sports_esports
                                : status == 'Completed'
                                    ? Icons.emoji_events
                                    : status == 'Full'
                                        ? Icons.block
                                        : Icons.schedule,
                            size: 20,
                            color: status == 'Ongoing'
                                ? Colors.green
                                : status == 'Completed'
                                    ? Colors.blue
                                    : status == 'Full'
                                        ? Colors.red
                                        : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              fontSize: 16,
                              color: status == 'Ongoing'
                                  ? Colors.green
                                  : status == 'Completed'
                                      ? Colors.blue
                                      : status == 'Full'
                                          ? Colors.red
                                          : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: _firestore
                              .collection('tournaments')
                              .doc(tournament.id)
                              .snapshots(),
                          builder: (context, tournamentSnapshot) {
                            if (tournamentSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final tournamentData = tournamentSnapshot.data
                                ?.data() as Map<String, dynamic>?;
                            final currentPlayers = List<String>.from(
                                tournamentData?['players'] ?? []);
                            final hasJoined =
                                currentPlayers.contains(_auth.currentUser?.uid);
                            final isFull = currentPlayers.length >= maxPlayers;
                            final hasStarted = startDate != null &&
                                startDate.isBefore(DateTime.now());

                            return ElevatedButton(
                              onPressed: hasJoined || isFull || hasStarted
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TournamentDetailsScreen(
                                            tournamentId: tournament.id,
                                          ),
                                        ),
                                      );
                                    }
                                  : () => joinTournament(tournament.id,
                                      (data['entryFee'] ?? 0.0).toDouble()),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: hasJoined || isFull
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                              child: Text(
                                hasJoined || isFull || hasStarted
                                    ? 'View Details'
                                    : 'Join Now',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

extension StringExt on String {
  T let<T>(T Function(String) operation) => operation(this);
}
