import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen>
    with SingleTickerProviderStateMixin {
  // late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppConstants.history),
        // bottom: TabBar(
        //   labelColor: ColorResources.secondaryColor,
        //   indicatorColor: ColorResources.secondaryColor,
        //   controller: _tabController,
        //   tabs: const [
        //     Tab(text: AppConstants.upcoming),
        //     Tab(text: AppConstants.completed),
        //   ],
        // ),
      ),
      body: _buildGameList(AppConstants.completed),
      // body: TabBarView(
      //   controller: _tabController,
      //   children: [
      //     _upcomingGameList(AppConstants.upcoming),
      //     _buildGameList(AppConstants.completed),
      //   ],
      // ),
    );
  }

  Widget _buildGameList(String status) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No games found.'));
        }

        final games = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 20),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index].data() as Map<String, dynamic>;
            final opponentId = game['opponent'] ?? '';
            final timestamp = game['datetime'];
            String formattedDate = '';
            if (timestamp != null) {
              DateTime dateTime;
              if (timestamp is Timestamp) {
                dateTime = timestamp.toDate();
              } else if (timestamp is DateTime) {
                dateTime = timestamp;
              } else {
                dateTime = DateTime.now();
              }
              formattedDate =
                  DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(opponentId)
                  .get(),
              builder: (context, opponentSnapshot) {
                String opponentName = opponentId;
                if (opponentSnapshot.hasData && opponentSnapshot.data!.exists) {
                  final data =
                      opponentSnapshot.data!.data() as Map<String, dynamic>;
                  opponentName = data['username'] ?? opponentId;
                }

                return Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ColorResources.secondaryColor)),
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Image.asset(
                      'assets/images/lose.png',
                      height: 60,
                      color: Colors.white,
                    ),
                    title: Text(
                      game['game_name'] ?? 'Chess4Cash',
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle:
                        Text('Opponent: $opponentName\nDate: $formattedDate'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(game['result'] ?? ''),
                        const Icon(Icons.emoji_events, color: Colors.orange),
                        Text(
                          "₹ ${game['prize'].toString()}",
                          style: TextStyle(
                              color: game['result'].toString() == 'loss'
                                  ? Colors.red
                                  : game['prize'].toString() == "0"
                                      ? ColorResources.secondaryColor
                                      : Colors.green),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _upcomingGameList(String status) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<QuerySnapshot>(
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No games found.'));
        }

        final games = snapshot.data!.docs;

        return ListView.builder(
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index].data() as Map<String, dynamic>;
            final opponentId = game['opponent'] ?? '';
            final timestamp = game['datetime'];
            String formattedDate = '';

            return Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ColorResources.secondaryColor)),
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: Image.asset(
                  'assets/images/lose.png',
                  height: 60,
                  color: Colors.white,
                ),
                title: const Text(
                  'Chess4Cash',
                  style: TextStyle(fontSize: 16),
                ),
                subtitle: const Text('Opponent: My Name'),
                trailing: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Result'),
                    Icon(Icons.emoji_events, color: Colors.orange),
                    // Text(
                    //   "₹ ${game['prize'].toString()}",
                    //   style: TextStyle(
                    //       color: game['prize'].toString() == "0"
                    //           ? ColorResources.secondaryColor
                    //           : Colors.green),
                    // )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
