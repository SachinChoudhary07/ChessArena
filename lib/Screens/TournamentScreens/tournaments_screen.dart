import 'package:chess_cash/Constant/color_resources.dart';
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

  @override
  void initState() {
    super.initState();
    // Start checking tournaments when screen initializes
    _startTournamentCheck();
  }

  void _startTournamentCheck() {
    // Check tournaments every minute
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        _checkAndCancelTournaments();
        _startTournamentCheck();
      }
    });
  }

  Future<void> _checkAndCancelTournaments() async {
    try {
      // Get all upcoming tournaments
      final tournaments = await _firestore.collection('tournaments').where('status', isEqualTo: 'upcoming').get();

      for (var tournament in tournaments.docs) {
        final data = tournament.data();
        final startDate = (data['startDate'] as Timestamp?)?.toDate();
        final players = List<String>.from(data['players'] ?? []);
        final maxPlayers = data['playerCount'] ?? 8;
        final entryFee = (data['entryFee'] ?? 0.0).toDouble();

        // Check if tournament starts in less than 30 minutes and has insufficient players
        if (startDate != null) {
          final timeUntilStart = startDate.difference(DateTime.now());
          if (timeUntilStart.inMinutes <= 30 && timeUntilStart.inMinutes > 0 && players.length < maxPlayers / 2) {
            // Cancel tournament and process refunds
            await _cancelTournamentAndRefund(
              tournament.id,
              players,
              entryFee,
              'Tournament cancelled due to insufficient players',
            );
          }
        }
      }
    } catch (e) {
      print('Error checking tournaments: $e');
    }
  }

  Future<void> _cancelTournamentAndRefund(
    String tournamentId,
    List<String> players,
    double entryFee,
    String reason,
  ) async {
    try {
      // Use transaction to ensure all operations complete
      await _firestore.runTransaction((transaction) async {
        // Update tournament status
        final tournamentRef = _firestore.collection('tournaments').doc(tournamentId);
        transaction.update(tournamentRef, {
          'status': 'cancelled',
          'cancelReason': reason,
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        // Process refunds for each player
        for (String playerId in players) {
          final userRef = _firestore.collection('users').doc(playerId);
          final userDoc = await transaction.get(userRef);

          if (userDoc.exists) {
            // Refund entry fee
            transaction.update(userRef, {
              'Balance': FieldValue.increment(entryFee),
            });

            // Add transaction record
            final transactionRef = _firestore.collection('users').doc(playerId).collection('transactions').doc();

            transaction.set(transactionRef, {
              'amount': entryFee,
              'type': 'Tournament Refund',
              'description': 'Refund for cancelled tournament: $tournamentId',
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'completed',
              'tournamentId': tournamentId,
            });
          }
        }

        // Delete all tournament matches
        final matchesSnapshot = await _firestore.collection('tournaments').doc(tournamentId).collection('matches').get();

        for (var match in matchesSnapshot.docs) {
          transaction.delete(match.reference);
        }
      });

      // Show toast notification
      Fluttertoast.showToast(
        msg: "Tournament cancelled and refunds processed",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Error cancelling tournament: $e');
      Fluttertoast.showToast(
        msg: "Error processing tournament cancellation",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  String getTournamentStatus(Map<String, dynamic> data) {
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final players = List<String>.from(data['players'] ?? []);
    final maxPlayers = data['playerCount'] ?? 8;

    // Check for cancelled status first
    if (data['status'] == 'cancelled') return 'Cancelled';

    if (players.length >= maxPlayers) return 'Full';

    if (data['winner'] != null || (endDate != null && now.isAfter(endDate))) return 'Completed';
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
      final double userBalance = (userDoc.data()?['Balance'] ?? 0).toDouble();

      if (userBalance < entryFee) {
        Fluttertoast.showToast(
          msg: "Insufficient balance! Need ₹${entryFee.toStringAsFixed(2)} to join",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Start a transaction to handle balance deduction and tournament joining
      await _firestore.runTransaction((transaction) async {
        // ---------- READS SECTION ----------
        // 1. Get fresh user data
        final freshUserDoc = await transaction.get(_firestore.collection('users').doc(user.uid));
        final double currentBalance = (freshUserDoc.data()?['Balance'] ?? 0).toDouble();

        if (currentBalance < entryFee) {
          throw Exception('Insufficient balance');
        }

        // 2. Get tournament data
        final tournamentDoc = await transaction.get(_firestore.collection('tournaments').doc(tournamentId));
        final tournamentData = tournamentDoc.data()!;
        final players = List<String>.from(tournamentData['players'] ?? []);
        final maxPlayers = tournamentData['playerCount'] ?? 8;

        // Check if tournament is cancelled
        if (tournamentData['status'] == 'cancelled') {
          throw Exception('This tournament has been cancelled');
        }

        if (players.contains(user.uid)) {
          throw Exception('Already joined this tournament');
        }

        if (players.length >= maxPlayers) {
          throw Exception('Tournament is full');
        }

        // 3. Get all round-1 matches
        final roundOneMatches = await _firestore.collection('tournaments').doc(tournamentId).collection('matches').where('round', isEqualTo: 1).orderBy('matchNumber').get();

        // 4. Find the first available slot by reading each match
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

        // ---------- WRITES SECTION ----------
        // 1. Update user's balance and tournaments list
        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {
            'Balance': currentBalance - entryFee,
            'tournaments': FieldValue.arrayUnion([tournamentId])
          },
        );

        // Add transaction record for entry fee
        final transactionRef = _firestore.collection('users').doc(user.uid).collection('transactions').doc();

        transaction.set(transactionRef, {
          'amount': -entryFee,
          'type': 'Tournament Entry',
          'description': 'Entry fee for tournament: $tournamentId',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
          'tournamentId': tournamentId,
        });

        // 2. Update tournament's player list
        transaction.update(
          _firestore.collection('tournaments').doc(tournamentId),
          {
            'players': FieldValue.arrayUnion([user.uid]),
            'currentPlayers': FieldValue.increment(1),
          },
        );

        // 3. Update the match with the player
        transaction.update(
          targetMatchRef,
          {targetField: user.uid},
        );
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
    if (roundTimes == null || roundTimes.isEmpty) return const SizedBox.shrink();

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
                    color: roundDateTime.isBefore(DateTime.now()) ? Colors.grey : Colors.white,
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

// get this data in descending order
        stream: _firestore.collection('tournaments').orderBy('createdAt', descending: true).snapshots(),
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
                color: Colors.black,
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tournament Name
                      Row(
                        children: [
                          Icon(
                            data['name'].toString().toLowerCase().contains('rush') ? Icons.emoji_events : Icons.emoji_events, // Use a chess icon if available
                            color: Colors.yellow[700],
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['name'] ?? 'Unnamed Tournament',
                              style: const TextStyle(
                                color: Color(0xFFFFD600),
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Entry Fee
                      Row(
                        children: [
                          Icon(Icons.attach_money, color: Colors.green[400], size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Entry: ₹${data['entryFee']?.toStringAsFixed(0) ?? '0'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Prize Pool
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.green[400], size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Prize pool: ₹${data['prizeAmount']?.toStringAsFixed(0) ?? '0'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Players
                      Row(
                        children: [
                          Icon(Icons.group, color: Colors.yellow[700], size: 18),
                          const SizedBox(width: 4),
                          const Text(
                            'Players: ',
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          Text(
                            '${players.length}',
                            style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '/$maxPlayers joined',
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Start Time
                      if (startDate != null)
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'Starts: ${DateFormat('d MMM, h:mm a').format(startDate)}',
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),

                      // Rounds

                      // Round Times
                      _buildRoundTimes(roundTimes), const SizedBox(height: 8),

                      // Status
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          const Text(
                            'Status: ',
                            style: TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          Text(
                            status == 'Ongoing' ? 'Joined' : status,
                            style: TextStyle(
                              color: status == 'Ongoing'
                                  ? Colors.green
                                  : status == 'Completed'
                                      ? Colors.blue
                                      : status == 'Full'
                                          ? Colors.red
                                          : status == 'Cancelled'
                                              ? Colors.red
                                              : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // CTA Button
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8,
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: _firestore.collection('tournaments').doc(tournament.id).snapshots(),
                            builder: (context, tournamentSnapshot) {
                              if (tournamentSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final tournamentData = tournamentSnapshot.data?.data() as Map<String, dynamic>?;
                              final currentPlayers = List<String>.from(tournamentData?['players'] ?? []);
                              final hasJoined = currentPlayers.contains(_auth.currentUser?.uid);
                              final isFull = currentPlayers.length >= maxPlayers;
                              // if tournament 1 st round is before datetime
                              final isRound1BeforeDateTime = roundTimes?[1] != null && DateTime.parse(roundTimes?[1] as String).isBefore(DateTime.now());
                              // final hasStarted = startDate != null && startDate.isBefore(DateTime.now());

                              return ElevatedButton(
                                onPressed: hasJoined || isFull || isRound1BeforeDateTime
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TournamentDetailsScreen(
                                              tournamentId: tournament.id,
                                            ),
                                          ),
                                        );
                                      }
                                    : () => joinTournament(tournament.id, (data['entryFee'] ?? 0.0).toDouble()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasJoined ? Colors.yellow[700] : Colors.yellow[700],
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  hasJoined
                                      ? 'Enter Room'
                                      : isFull || isRound1BeforeDateTime
                                          ? 'View Details'
                                          : 'Join Now',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                          ),
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
