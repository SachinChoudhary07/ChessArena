import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/CreateTournament/createTournament.dart';
import 'package:chess_cash/Screens/GameScreens/MatchMakingScreen.dart';
import 'package:chess_cash/Screens/LeaderBoard/EloLeaderBoard.dart';
import 'package:chess_cash/Screens/TournamentScreens/tournaments_screen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:chess_cash/Widgets/shimmer_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../PlayWithOnlineFriends/play_with_online_friend.dart';

class Dashboardscreen extends StatefulWidget {
  const Dashboardscreen({super.key});

  @override
  State<Dashboardscreen> createState() => _DashboardscreenState();
}

class _DashboardscreenState extends State<Dashboardscreen> {
  String selectedTime = '3 min';

  static const _times = [
    _TimeOption('3 min', '3m', 'Blitz'),
    _TimeOption('5 min', '5m', 'Blitz'),
    _TimeOption('10 min', '10m', 'Rapid'),
    _TimeOption('15 min', '15m', 'Rapid'),
    _TimeOption('30 min', '30m', 'Rapid'),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: uid == null
              ? null
              : FirebaseFirestore.instance
                  .collection(AppConstants.usersCollection)
                  .doc(uid)
                  .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final name = data?['username']?.toString() ?? 'Player';
            final image = data?['profileImage']?.toString() ?? '';
            final elo = (data?['eloRating'] ?? 1200);
            final games = data?['gamesPlayed'] ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HomeHeader(
                    name: name,
                    imageUrl: image,
                    elo: '$elo',
                  ),
                  const SizedBox(height: 16),
                  _PlayHeroCard(
                    selectedTime: selectedTime,
                    times: _times,
                    onSelectTime: (time) => setState(() => selectedTime = time),
                    onPlay: _startMatchmaking,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.trending_up,
                          label: 'Rating',
                          value: '$elo',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.sports_esports_outlined,
                          label: 'Games',
                          value: '$games',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Mode',
                          value: 'Rated',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const ChessSectionHeader(title: 'Play another way'),
                  GameModeCard(
                    title: 'Challenge a friend',
                    subtitle: 'Send a rated invite to someone on your list',
                    icon: Icons.people_alt_outlined,
                    onTap: () {
                      push(context, const PlayWithOnlineFriendScreen());
                    },
                  ),
                  const SizedBox(height: 10),
                  GameModeCard(
                    title: 'Tournaments',
                    subtitle: 'Join a bracket and climb the field',
                    icon: Icons.emoji_events_outlined,
                    onTap: () {
                      push(context, const TournamentsScreen());
                    },
                  ),
                  const SizedBox(height: 10),
                  GameModeCard(
                    title: 'Private room',
                    subtitle: 'Create a code and play with anyone',
                    icon: Icons.meeting_room_outlined,
                    onTap: () {
                      push(context, const CreateTournament());
                    },
                  ),
                  const SizedBox(height: 10),
                  GameModeCard(
                    title: 'Elo leaderboard',
                    subtitle: 'See how you rank against other players',
                    icon: Icons.leaderboard_outlined,
                    onTap: () {
                      push(context, const EloLeaderboard());
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _startMatchmaking() async {
    if (kDebugMode) {
      print(
          "🎮 Dashboard: Starting matchmaking with time limit: $selectedTime");
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchMakingScreen(time: selectedTime),
      ),
    );
  }
}

class _TimeOption {
  final String value;
  final String short;
  final String pace;
  const _TimeOption(this.value, this.short, this.pace);
}

class _HomeHeader extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String elo;

  const _HomeHeader({
    required this.name,
    required this.imageUrl,
    required this.elo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShimmerAvatar(
          imageUrl: imageUrl,
          radius: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ColorResources.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Find a rated game in seconds',
                style: TextStyle(
                  color: ColorResources.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ColorResources.primary.withOpacity(0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ColorResources.primary.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.military_tech,
                  size: 16, color: ColorResources.accentSoft),
              const SizedBox(width: 4),
              Text(
                elo,
                style: const TextStyle(
                  color: ColorResources.accentSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayHeroCard extends StatelessWidget {
  final String selectedTime;
  final List<_TimeOption> times;
  final ValueChanged<String> onSelectTime;
  final VoidCallback onPlay;

  const _PlayHeroCard({
    required this.selectedTime,
    required this.times,
    required this.onSelectTime,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColorResources.divider),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A3A24),
            Color(0xFF25282F),
            Color(0xFF1F2228),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: Opacity(
                opacity: 0.22,
                child: _MiniBoard(size: 132),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ColorResources.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'RATED MATCH',
                      style: TextStyle(
                        color: ColorResources.accentSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Play online chess',
                    style: TextStyle(
                      color: ColorResources.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose a clock, then we pair you with a real opponent.',
                    style: TextStyle(
                      color: ColorResources.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: times.map((t) {
                      final selected = t.value == selectedTime;
                      return GestureDetector(
                        onTap: () => onSelectTime(t.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 62,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? ColorResources.primary
                                : ColorResources.elevatedSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? ColorResources.primary
                                  : ColorResources.divider,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                t.short,
                                style: TextStyle(
                                  color: selected
                                      ? ColorResources.onPrimary
                                      : ColorResources.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.pace,
                                style: TextStyle(
                                  color: selected
                                      ? ColorResources.onPrimary.withOpacity(0.8)
                                      : ColorResources.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPlay,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 28),
                          SizedBox(width: 4),
                          Text(
                            'Find an opponent',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBoard extends StatelessWidget {
  final double size;
  const _MiniBoard({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 64,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemBuilder: (_, i) {
          final row = i ~/ 8;
          final col = i % 8;
          final dark = (row + col) % 2 == 1;
          return ColoredBox(
            color: dark ? ColorResources.darkSquare : ColorResources.lightSquare,
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: ColorResources.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorResources.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: ColorResources.accentSoft),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: ColorResources.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
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
    );
  }
}
