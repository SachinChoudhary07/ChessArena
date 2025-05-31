import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> joinTournament(String tournamentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('tournaments').doc(tournamentId).update({
        'players': FieldValue.arrayUnion([user.uid]),
      });

      // Add user to the first available match
      final matchesSnapshot = await _firestore.collection('tournaments').doc(tournamentId).collection('matches').where('player1', isNull: true).limit(1).get();

      if (matchesSnapshot.docs.isNotEmpty) {
        await matchesSnapshot.docs.first.reference.update({
          'player1': user.uid,
        });
      } else {
        final matchesSnapshot2 = await _firestore.collection('tournaments').doc(tournamentId).collection('matches').where('player2', isNull: true).limit(1).get();

        if (matchesSnapshot2.docs.isNotEmpty) {
          await matchesSnapshot2.docs.first.reference.update({
            'player2': user.uid,
          });
        }
      }
    } catch (e) {
      print('Error joining tournament: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tournaments').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final tournament = snapshot.data!.docs[index];
              final data = tournament.data() as Map<String, dynamic>;
              final startDate = (data['startDate'] as Timestamp?)?.toDate();
              final now = DateTime.now();
              final bool canStart = startDate != null && startDate.difference(now).inMinutes <= 5 && startDate.difference(now).inMinutes >= 0;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unnamed Tournament',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Entry Fee: \$${data['entryFee']?.toString() ?? '0'}'),
                      Text('Prize Pool: \$${data['prizeAmount']?.toString() ?? '0'}'),
                      if (startDate != null) Text('Start Date: ${startDate.toString().split('.')[0]}'),
                      const SizedBox(height: 16),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('tournaments').doc(tournament.id).snapshots(),
                        builder: (context, tournamentSnapshot) {
                          final tournamentData = tournamentSnapshot.data?.data() as Map<String, dynamic>?;
                          final players = List<String>.from(tournamentData?['players'] ?? []);
                          final hasJoined = players.contains(_auth.currentUser?.uid);

                          if (hasJoined && canStart) {
                            return ElevatedButton(
                              onPressed: () {
                                // Handle game start
                              },
                              child: const Text('Start Game'),
                            );
                          } else if (!hasJoined) {
                            return ElevatedButton(
                              onPressed: () => joinTournament(tournament.id),
                              child: const Text('Join Tournament'),
                            );
                          } else {
                            return const Text('Waiting for game to start...');
                          }
                        },
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
