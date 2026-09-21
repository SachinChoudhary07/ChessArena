import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Constant/color_resources.dart';
import '../PlayWithOnlineFriends/play_with_online_friend.dart';
import '../PlayWithOnlineFriends/play_with_online_friend_provider.dart';
import '../../Services/navigation.dart';

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
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: ColorResources.primaryColor,
      ),
      body: Consumer<PlayWithOnlineFriendProvider>(
        builder: (context, provider, _) {
          if (provider.isFetchingFriends && provider.friends.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final online = provider.friends
              .where((f) => provider.friendOnlineMap[f.uid] == true)
              .toList();
          final offline = provider.friends
              .where((f) => provider.friendOnlineMap[f.uid] != true)
              .toList();

          return RefreshIndicator(
            color: ColorResources.secondaryColor,
            onRefresh: () => provider.fetchFriends(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader('Online (${online.length})'),
                if (online.isEmpty)
                  _emptyText('No friends online')
                else
                  ...online.map((f) => _friendTile(context, f, true)),
                const SizedBox(height: 24),
                _sectionHeader('Offline (${offline.length})'),
                if (offline.isEmpty)
                  _emptyText('No offline friends')
                else
                  ...offline.map((f) => _friendTile(context, f, false)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _friendTile(BuildContext context, FriendInfo friend, bool online) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: online ? Colors.green : Colors.grey,
          radius: 6,
        ),
        title: Text(friend.name),
        subtitle: Text(online ? 'Online' : 'Offline'),
        trailing: ElevatedButton(
          onPressed: online
              ? () {
                  final provider = context.read<PlayWithOnlineFriendProvider>();
                  provider.setSelectedFriend(friend);
                  push(context, const PlayWithOnlineFriendScreen());
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorResources.primaryColor,
          ),
          child: const Text('Challenge'),
        ),
      ),
    );
  }
}

