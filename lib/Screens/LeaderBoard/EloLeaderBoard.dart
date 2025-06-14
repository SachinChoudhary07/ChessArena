import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/LeaderBoardProvider/LeaderBoardProvider.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EloLeaderboard extends StatefulWidget {
  const EloLeaderboard({super.key});

  @override
  State<EloLeaderboard> createState() => _EloLeaderboardState();
}

class _EloLeaderboardState extends State<EloLeaderboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<LeaderBoardProvider>(context, listen: false)
            .fetchLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardProvider = Provider.of<LeaderBoardProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elo Leaderboard'),
      ),
      body: leaderboardProvider.isLoading
          ? const Center(child: Loader())
          : leaderboardProvider.leaderboard.isEmpty
              ? const Center(child: Text('No Data Found'))
              : ListView.builder(
                  itemCount: leaderboardProvider.leaderboard.length,
                  itemBuilder: (context, index) {
                    final user = leaderboardProvider.leaderboard[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: ColorResources.secondaryColor)),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 25,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: user['profilePictureUrl'] ?? '',
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
                        title: Text(user['name']),
                        subtitle: Text(
                            'Elo: ${user['eloRating'].toStringAsFixed(0)} | Points: ${user['points']}'),
                      ),
                    );
                  },
                ),
    );
  }
}
