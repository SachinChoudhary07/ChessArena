import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Services/navigation.dart';
import '../PlayWithOnlineFriends/play_with_online_friend.dart';
import '../PlayWithOnlineFriends/play_with_online_friend_provider.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayWithOnlineFriendProvider>().fetchFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PremiumAppBar(
        title: 'Friends',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Challenge a friend',
            onPressed: () => push(context, const PlayWithOnlineFriendScreen()),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: Consumer<PlayWithOnlineFriendProvider>(
        builder: (context, provider, _) {
          if (provider.isFetchingFriends && provider.friends.isEmpty) {
            return const LoadingWidget();
          }

          final online = provider.friends
              .where((f) => provider.friendOnlineMap[f.uid] == true)
              .toList();
          final offline = provider.friends
              .where((f) => provider.friendOnlineMap[f.uid] != true)
              .toList();

          return RefreshIndicator(
            color: ColorResources.accent,
            onRefresh: () => provider.fetchFriends(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (provider.friends.isEmpty)
                  _NoFriendsCard(
                    onChallenge: () =>
                        push(context, const PlayWithOnlineFriendScreen()),
                  )
                else ...[
                  ChessSectionHeader(title: 'Online · ${online.length}'),
                  if (online.isEmpty)
                    const _EmptyGroupCard(
                      title: 'Nobody is online',
                      message:
                          'Your friends are away. You can still send a challenge from their profile when they return.',
                      icon: Icons.wifi_off_outlined,
                    )
                  else
                    ...online.map((f) => _friendTile(context, f, true)),
                  const SizedBox(height: 20),
                  ChessSectionHeader(title: 'Offline · ${offline.length}'),
                  if (offline.isEmpty)
                    const _EmptyGroupCard(
                      title: 'Everyone is online',
                      message: 'None of your friends are offline right now.',
                      icon: Icons.circle_outlined,
                    )
                  else
                    ...offline.map((f) => _friendTile(context, f, false)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _friendTile(BuildContext context, FriendInfo friend, bool online) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ChessCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: ColorResources.elevatedSurface,
                  child: Text(
                    friend.name.isNotEmpty
                        ? friend.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: ColorResources.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: online
                          ? ColorResources.success
                          : ColorResources.textSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ColorResources.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ColorResources.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    online ? 'Online now' : 'Offline',
                    style: TextStyle(
                      color: online
                          ? ColorResources.accentSoft
                          : ColorResources.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (online)
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () {
                    final provider =
                        context.read<PlayWithOnlineFriendProvider>();
                    provider.setSelectedFriend(friend);
                    push(context, const PlayWithOnlineFriendScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Challenge'),
                ),
              )
            else
              const Text(
                'Away',
                style: TextStyle(
                  color: ColorResources.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _EmptyGroupCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ChessCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ColorResources.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ColorResources.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: ColorResources.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFriendsCard extends StatelessWidget {
  final VoidCallback onChallenge;

  const _NoFriendsCard({required this.onChallenge});

  @override
  Widget build(BuildContext context) {
    return ChessCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ColorResources.elevatedSurface,
              shape: BoxShape.circle,
              border: Border.all(color: ColorResources.divider),
            ),
            child: const Icon(
              Icons.group_outlined,
              size: 30,
              color: ColorResources.accentSoft,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No friends yet',
            style: TextStyle(
              color: ColorResources.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Play an online match and become friends — then you can challenge.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ColorResources.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ChessPrimaryButton(
            label: 'Send a challenge',
            icon: Icons.sports_esports_outlined,
            onPressed: onChallenge,
          ),
        ],
      ),
    );
  }
}
