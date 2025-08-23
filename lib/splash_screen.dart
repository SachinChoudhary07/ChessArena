import 'dart:async';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Services/presence_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    Timer(const Duration(seconds: 3), () async {
      if (isLoggedIn) {
        // Check if user is still authenticated and not banned
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Check ban status
          final isBanned = await _checkBanStatus(user.uid);
          if (isBanned) {
            // User is banned, logout and go to login
            await FirebaseAuth.instance.signOut();
            await prefs.setBool('isLoggedIn', false);
            _navigateToLogin();
          } else {
            // User is not banned, proceed to dashboard
            await PresenceService.instance.start();
            _navigateToDashboard();
          }
        } else {
          // User not authenticated, go to login
          await prefs.setBool('isLoggedIn', false);
          _navigateToLogin();
        }
      } else {
        _navigateToLogin();
      }
    });
  }

  Future<bool> _checkBanStatus(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection(AppConstants.usersCollection).doc(uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData[AppConstants.isBannedField] ?? false;
      }
    } catch (e) {
      print('Error checking ban status: $e');
    }
    return false;
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BottomNavBar(key: bottomNavBarKey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.primaryColor,
      body: Center(
        child: Image.asset(
          AppConstants.splashIcon,
          width: double.infinity,
          height: Helper.mediaQueryHeight(context, 150),
        ),
      ),
    );
  }
}
