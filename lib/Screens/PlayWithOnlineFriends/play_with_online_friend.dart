import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Constant/color_resources.dart';
import '../../Services/navigation.dart';
import 'challenge_waiting_room.dart';
import 'play_with_online_friend_provider.dart';

class PlayWithOnlineFriendScreen extends StatefulWidget {
  const PlayWithOnlineFriendScreen({super.key});

  @override
  State<PlayWithOnlineFriendScreen> createState() =>
      _PlayWithOnlineFriendScreenState();
}

class _PlayWithOnlineFriendScreenState extends State<PlayWithOnlineFriendScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Fetch friends after a frame so provider available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayWithOnlineFriendProvider>().fetchFriends();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play with Friends'),
        backgroundColor: ColorResources.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ColorResources.secondaryColor,
          indicatorColor: ColorResources.secondaryColor,
          tabs: const [
            Tab(text: 'Send Challenge'),
            Tab(text: 'Challenge History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SendChallengeTab(),
          _ChallengeHistoryTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Send Challenge Tab
// ---------------------------------------------------------------------------
class _SendChallengeTab extends StatelessWidget {
  const _SendChallengeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayWithOnlineFriendProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Friend Dropdown
              Text(
                'Select Friend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              provider.isFetchingFriends
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonHideUnderline(
                      child: DropdownButton2<FriendInfo>(
                        value: provider.selectedFriend,
                        hint: const Text('Choose a friend'),
                        isExpanded: true,
                        items: provider.friends
                            .map((f) => DropdownMenuItem<FriendInfo>(
                                  value: f,
                                  child: Row(
                                    children: [
                                      Text(f.name),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: provider.setSelectedFriend,
                        buttonStyleData: ButtonStyleData(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: ColorResources.secondaryColor),
                          ),
                        ),
                        dropdownStyleData: DropdownStyleData(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: ColorResources.primaryColor),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 16),

              // Time control selection
              Text('Select Time Control',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  value: provider.selectedTime,
                  isExpanded: true,
                  items: const [
                    '1 min',
                    '3 min',
                    '5 min',
                    '10 min',
                    '15 min',
                    '30 min',
                    '60 min',
                  ]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) provider.setSelectedTime(val);
                  },
                  buttonStyleData: ButtonStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ColorResources.secondaryColor),
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorResources.primaryColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount selection
              Text('Select Amount',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton2<int>(
                  value: provider.selectedAmount,
                  isExpanded: true,
                  items: const [0, 10, 20, 50, 100]
                      .map((amt) =>
                          DropdownMenuItem(value: amt, child: Text('₹$amt')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) provider.setSelectedAmount(val);
                  },
                  buttonStyleData: ButtonStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ColorResources.secondaryColor),
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorResources.primaryColor),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorResources.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: provider.isSendingChallenge
                      ? null
                      : () async {
                          final result = await provider.sendChallenge();
                          if (context.mounted) {
                            if (result.success && result.roomCode != null) {
                              // Navigate to challenge waiting room
                              push(
                                  context,
                                  ChallengeWaitingRoom(
                                    roomCode: result.roomCode!,
                                    challengeId: result.challengeId!,
                                  ));
                            } else {
                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result.message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: provider.isSendingChallenge
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Challenge', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Challenge History Tab
// ---------------------------------------------------------------------------
class _ChallengeHistoryTab extends StatefulWidget {
  const _ChallengeHistoryTab();

  @override
  State<_ChallengeHistoryTab> createState() => _ChallengeHistoryTabState();
}

class _ChallengeHistoryTabState extends State<_ChallengeHistoryTab> {
  @override
  void initState() {
    super.initState();
    // Fetch challenge history when tab is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayWithOnlineFriendProvider>().fetchChallengeHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayWithOnlineFriendProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingHistory) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No challenge history yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your challenge history will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: ColorResources.secondaryColor,
          onRefresh: () => provider.fetchChallengeHistory(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.history.length,
            itemBuilder: (context, index) {
              final item = provider.history[index];
              return _buildChallengeHistoryCard(item);
            },
          ),
        );
      },
    );
  }

  Widget _buildChallengeHistoryCard(ChallengeHistoryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with opponent name and status
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: ColorResources.secondaryColor,
                  child: Text(
                    item.opponentName.isNotEmpty
                        ? item.opponentName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.opponentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(item.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(item),
              ],
            ),
            const SizedBox(height: 12),

            // Match details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: ColorResources.secondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.timeControl,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  if (item.amount > 0) ...[
                    Icon(
                      Icons.monetization_on,
                      size: 16,
                      color: ColorResources.secondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${item.amount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorResources.secondaryColor,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Free Game',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Challenge role indicator
            Row(
              children: [
                Icon(
                  item.isChallenger ? Icons.send : Icons.call_received,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  item.isChallenger ? 'You challenged' : 'You were challenged',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ChallengeHistoryItem item) {
    Color chipColor;
    String statusText;
    IconData icon;

    switch (item.result) {
      case 'win':
        chipColor = Colors.green;
        statusText = 'YOU WON';
        icon = Icons.emoji_events;
        break;
      case 'loss':
        chipColor = Colors.red;
        statusText = 'YOU LOST';
        icon = Icons.close;
        break;
      case 'accepted':
        chipColor = Colors.blue;
        statusText = 'ACCEPTED';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        chipColor = Colors.red;
        statusText = 'REJECTED';
        icon = Icons.cancel;
        break;
      case 'expired':
        chipColor = Colors.orange;
        statusText = 'EXPIRED';
        icon = Icons.timer_off;
        break;
      default:
        chipColor = Colors.grey;
        statusText = 'PENDING';
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
