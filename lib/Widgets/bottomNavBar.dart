import 'dart:async';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Screens/Dashboard/DashboardScreen.dart';
import 'package:chess_cash/Screens/Friends/friends_screen.dart';
import 'package:chess_cash/Screens/HistoryScreens/GameHistoryScreen.dart';
import 'package:chess_cash/Screens/ProfileScreens/ProfileScreens.dart';
import 'package:chess_cash/Screens/WalletScreens/WalletScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  StreamSubscription<DocumentSnapshot>? _banStatusSubscription;

  final List<Widget> _pages = [
    const Dashboardscreen(),
    const WalletScreen(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: AppConstants.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: AppConstants.wallet,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: AppConstants.history,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: AppConstants.profile,
          ),
        ],
      ),
    );
  }
}
