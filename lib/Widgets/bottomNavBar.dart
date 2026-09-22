import 'dart:async';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Screens/Dashboard/DashboardScreen.dart';
import 'package:chess_cash/Screens/Friends/friends_screen.dart';
import 'package:chess_cash/Screens/HistoryScreens/GameHistoryScreen.dart';
import 'package:chess_cash/Screens/ProfileScreens/ProfileScreens.dart';
import 'package:chess_cash/Screens/LeaderBoard/EloLeaderBoard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Global key to access BottomNavBar state
final GlobalKey<_BottomNavBarState> bottomNavBarKey =
    GlobalKey<_BottomNavBarState>();

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  DateTime? _lastBackPress;
  StreamSubscription<DocumentSnapshot>? _banStatusSubscription;

  final List<Widget> _pages = [
    const Dashboardscreen(),
    const EloLeaderboard(),
    const GameHistoryScreen(),
    const FriendsScreen(),
    const Profilescreens(),
  ];

  @override
  void initState() {
    super.initState();
    _startBanStatusMonitoring();
  }

  @override
  void dispose() {
    _banStatusSubscription?.cancel();
    super.dispose();
  }

  void _startBanStatusMonitoring() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _banStatusSubscription = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final userData = snapshot.data() as Map<String, dynamic>;
          final isBanned = userData[AppConstants.isBannedField] ?? false;

          if (isBanned) {
            // User is banned, logout and show ban dialog
            _handleUserBanned(userData[AppConstants.banReasonField] ?? '');
          }
        }
      });
    }
  }

  void _handleUserBanned(String banReason) {
    // Cancel the subscription to prevent multiple dialogs
    _banStatusSubscription?.cancel();

    // Show ban dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Account Banned', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account has been suspended by the administrator.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you believe this is an error, please contact our support team.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Logout user
              final authProvider =
                  Provider.of<AutProvider>(context, listen: false);
              await authProvider.logout(context);

              // Navigate to login screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Method to change index from outside
  void changeIndex(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _handleSystemBack() {
    // From any other tab, go Home first.
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }

    final now = DateTime.now();
    final shouldExit = _lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2);

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: ColorResources.surface,
            border: const Border(
              top: BorderSide(color: ColorResources.divider),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.sports_esports_rounded,
                    label: AppConstants.home,
                    selected: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  _NavItem(
                    icon: Icons.military_tech_rounded,
                    label: 'Ratings',
                    selected: _selectedIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  _NavItem(
                    icon: Icons.auto_stories_rounded,
                    label: AppConstants.history,
                    selected: _selectedIndex == 2,
                    onTap: () => _onItemTapped(2),
                  ),
                  _NavItem(
                    icon: Icons.handshake_rounded,
                    label: 'Friends',
                    selected: _selectedIndex == 3,
                    onTap: () => _onItemTapped(3),
                  ),
                  _NavItem(
                    icon: Icons.account_circle_rounded,
                    label: AppConstants.profile,
                    selected: _selectedIndex == 4,
                    onTap: () => _onItemTapped(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 46,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? ColorResources.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected
                    ? ColorResources.onPrimary
                    : ColorResources.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: selected
                    ? ColorResources.accentSoft
                    : ColorResources.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
