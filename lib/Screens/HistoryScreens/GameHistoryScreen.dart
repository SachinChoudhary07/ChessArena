import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:flutter/material.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        automaticallyImplyLeading: false,
        title: const Text(AppConstants.history),
        bottom: TabBar(
          labelColor: ColorResources.secondaryColor,
          indicatorColor: ColorResources.secondaryColor,
          controller: _tabController,
          tabs: const [
            Tab(text: AppConstants.upcoming),
            Tab(text: AppConstants.completed),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGameList(AppConstants.upcoming),
          _buildGameList(AppConstants.completed),
        ],
      ),
    );
  }

  Widget _buildGameList(String status) {
    return ListView.builder(
      itemCount: 3, // Example count
      itemBuilder: (context, index) {
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
              'Chess Tournament',
              style: TextStyle(fontSize: 16),
            ),
            subtitle: Text('$status - Sachin vs Vinu'),
            trailing: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('You won ₹149'),
                Icon(Icons.emoji_events, color: Colors.orange),
              ],
            ),
          ),
        );
      },
    );
  }
}
