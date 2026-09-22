import 'package:cached_network_image/cached_network_image.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/LeaderBoardProvider/LeaderBoardProvider.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final provider = Provider.of<LeaderBoardProvider>(context);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final players = provider.leaderboard;
    final myIndex = players.indexWhere((p) => p['uid'] == myUid);

    return Scaffold(
      appBar: const PremiumAppBar(title: 'Ratings'),
      body: provider.isLoading
          ? const Center(child: Loader())
          : players.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.leaderboard_outlined,
                  message: 'No rated players yet. Play a match to appear here.',
                )
              : RefreshIndicator(
                  color: ColorResources.primary,
                  backgroundColor: ColorResources.surface,
                  onRefresh: () =>
                      Provider.of<LeaderBoardProvider>(context, listen: false)
                          .fetchLeaderboard(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Elo leaderboard',
                                style: TextStyle(
                                  color: ColorResources.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${players.length} players  ·  ranked by rating',
                                style: const TextStyle(
                                  color: ColorResources.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              if (myIndex >= 0) ...[
                                const SizedBox(height: 14),
                                _YourRankBanner(
                                  rank: myIndex + 1,
                                  elo: (players[myIndex]['eloRating'] as num)
                                      .toInt(),
                                ),
                              ],
                              const SizedBox(height: 18),
                              _Podium(players: players.take(3).toList()),
                              const SizedBox(height: 8),
                              const ChessSectionHeader(title: 'All players'),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final user = players[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _RankRow(
                                  rank: index + 1,
                                  name: user['name']?.toString() ?? 'Player',
                                  imageUrl:
                                      user['profilePictureUrl']?.toString() ??
                                          '',
                                  elo: (user['eloRating'] as num).toInt(),
                                  games: user['gamesPlayed'] ?? 0,
                                  isMe: user['uid'] == myUid,
                                ),
                              );
                            },
                            childCount: players.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _YourRankBanner extends StatelessWidget {
  final int rank;
  final int elo;

  const _YourRankBanner({required this.rank, required this.elo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColorResources.primary.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorResources.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.military_tech, color: ColorResources.accentSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are #$rank',
              style: const TextStyle(
                color: ColorResources.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            '$elo Elo',
            style: const TextStyle(
              color: ColorResources.accentSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> players;

  const _Podium({required this.players});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    Widget slot(int index, {required bool tall}) {
      if (index >= players.length) return const SizedBox(width: 96);
      final p = players[index];
      return _PodiumPlayer(
        rank: index + 1,
        name: p['name']?.toString() ?? 'Player',
        imageUrl: p['profilePictureUrl']?.toString() ?? '',
        elo: (p['eloRating'] as num).toInt(),
        tall: tall,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: slot(1, tall: false)),
        const SizedBox(width: 8),
        Expanded(child: slot(0, tall: true)),
        const SizedBox(width: 8),
        Expanded(child: slot(2, tall: false)),
      ],
    );
  }
}

class _PodiumPlayer extends StatelessWidget {
  final int rank;
  final String name;
  final String imageUrl;
  final int elo;
  final bool tall;

  const _PodiumPlayer({
    required this.rank,
    required this.name,
    required this.imageUrl,
    required this.elo,
    required this.tall,
  });

  Color get _medal {
    switch (rank) {
      case 1:
        return const Color(0xFFF0C14B);
      case 2:
        return const Color(0xFFC0C6D0);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, tall ? 18 : 12, 8, 12),
      decoration: BoxDecoration(
        color: ColorResources.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank == 1
              ? _medal.withOpacity(0.7)
              : ColorResources.divider,
        ),
      ),
      child: Column(
        children: [
          Text(
            '#$rank',
            style: TextStyle(
              color: _medal,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            radius: tall ? 28 : 22,
            backgroundColor: ColorResources.elevatedSurface,
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : const AssetImage('assets/images/pawn_image.jpg')
                    as ImageProvider,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ColorResources.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$elo',
            style: TextStyle(
              color: rank == 1
                  ? ColorResources.accentSoft
                  : ColorResources.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String imageUrl;
  final int elo;
  final dynamic games;
  final bool isMe;

  const _RankRow({
    required this.rank,
    required this.name,
    required this.imageUrl,
    required this.elo,
    required this.games,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? ColorResources.primary.withOpacity(0.12)
            : ColorResources.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? ColorResources.primary.withOpacity(0.4)
              : ColorResources.divider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rank <= 3
                    ? ColorResources.accentSoft
                    : ColorResources.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: ColorResources.elevatedSurface,
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : const AssetImage('assets/images/pawn_image.jpg')
                    as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ColorResources.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ColorResources.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: ColorResources.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${games ?? 0} games',
                  style: const TextStyle(
                    color: ColorResources.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$elo',
            style: const TextStyle(
              color: ColorResources.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
