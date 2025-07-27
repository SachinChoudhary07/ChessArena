import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Constant/color_resources.dart';
import 'play_with_online_friend_provider.dart';

class PlayWithOnlineFriendScreen extends StatefulWidget {
  const PlayWithOnlineFriendScreen({super.key});

  @override
  State<PlayWithOnlineFriendScreen> createState() => _PlayWithOnlineFriendScreenState();
}

class _PlayWithOnlineFriendScreenState extends State<PlayWithOnlineFriendScreen> with SingleTickerProviderStateMixin {
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

              // Time control selection
              Text('Select Time Control', style: Theme.of(context).textTheme.titleMedium),
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
                  ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
              Text('Select Amount', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton2<int>(
                  value: provider.selectedAmount,
                  isExpanded: true,
                  items: const [0, 10, 20, 50, 100].map((amt) => DropdownMenuItem(value: amt, child: Text('₹$amt'))).toList(),
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
                          await provider.sendChallenge();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Challenge sent!')),
                            );
                          }
                        },
                  child: provider.isSendingChallenge
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
class _ChallengeHistoryTab extends StatelessWidget {
  const _ChallengeHistoryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayWithOnlineFriendProvider>(
      builder: (context, provider, _) {
        if (provider.history.isEmpty) {
          return const Center(child: Text('No history yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.history.length,
          itemBuilder: (context, index) {
            final item = provider.history[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  item.result == 'win' ? Icons.emoji_events : (item.result == 'loss' ? Icons.close : Icons.hourglass_empty),
                  color: item.result == 'win' ? Colors.green : (item.result == 'loss' ? Colors.red : Colors.orange),
                ),
                title: Text(item.opponentName),
                subtitle: Text('${item.timeControl} • ₹${item.amount}'),
                trailing: Text(
                  item.result.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
