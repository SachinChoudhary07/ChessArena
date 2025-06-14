import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Providers/CreateTournamentProvider/CreateTournamentProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TournamentDetails extends StatelessWidget {
  final String tournamentId;

  const TournamentDetails({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tournament = snapshot.data!.data() as Map<String, dynamic>;
          final currentUser = FirebaseAuth.instance.currentUser;
          final players = List<String>.from(tournament['players'] ?? []);
          final isJoined = currentUser != null && players.contains(currentUser.uid);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament['name'],
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text('Start: ${DateTime.parse(tournament['startDateTime']).toString()}'),
                Text('Players: ${players.length}/${tournament['maxPlayers']}'),
                Text('Status: ${tournament['status']}'),
                const SizedBox(height: 24),
                if (!isJoined && tournament['status'] == 'pending')
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await context.read<CreateTournamentProvider>().joinTournament(tournamentId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Successfully joined tournament')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    child: const Text('Join Tournament'),
                  ),
                const SizedBox(height: 16),
                const Text('Players:', style: TextStyle(fontWeight: FontWeight.bold)),
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('users').where('uid', whereIn: players).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final user = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: user['photoURL'] ?? '',
                                fit: BoxFit.cover,
                                width: 50,
                                height: 50,
                                placeholder: (context, url) => Image.asset(
                                  'assets/images/pawn_image.jpg',
                                  fit: BoxFit.cover,
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              ),
                            ),
                          ),
                          title: Text(user['displayName'] ?? 'Unknown Player'),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
