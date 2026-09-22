import 'dart:async';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Services/presence_service.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      if (isLoggedIn) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final isBanned = await _checkBanStatus(user.uid);
          if (isBanned) {
            await FirebaseAuth.instance.signOut();
            await prefs.setBool('isLoggedIn', false);
            _goLogin();
          } else {
            await PresenceService.instance.start();
            _goHome();
          }
        } else {
          await prefs.setBool('isLoggedIn', false);
          _goLogin();
        }
      } else {
        _goLogin();
      }
    });
  }

  Future<bool> _checkBanStatus(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData[AppConstants.isBannedField] ?? false;
      }
    } catch (e) {
      debugPrint('Error checking ban status: $e');
    }
    return false;
  }

  void _goLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BottomNavBar(key: bottomNavBarKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: ColorResources.background,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _Background(),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SizedBox(
                  width: size.width,
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const _LogoMark(),
                      const SizedBox(height: 28),
                      const Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ColorResources.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          AppConstants.appMotto,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ColorResources.accentSoft,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Rated matches  ·  Friends  ·  Tournaments',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ColorResources.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Spacer(flex: 3),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: ColorResources.primary,
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1F2420),
            Color(0xFF1A1C21),
            Color(0xFF14161A),
          ],
        ),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlowPainter(),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          ColorResources.primary.withOpacity(0.18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.34),
          radius: size.width * 0.6,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final line = Paint()
      ..color = ColorResources.primary.withOpacity(0.05)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          color: ColorResources.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: ColorResources.divider),
          boxShadow: [
            BoxShadow(
              color: ColorResources.primary.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const _BoardFace(),
        ),
      ),
    );
  }
}

class _BoardFace extends StatelessWidget {
  const _BoardFace();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return SizedBox(
          width: side,
          height: side,
          child: CustomPaint(painter: _BoardPainter()),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final cell = size.width / 8;

    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell, cell),
          Paint()
            ..color = (row + col).isOdd
                ? ColorResources.darkSquare
                : ColorResources.lightSquare,
        );
      }
    }

    // Simple king crown mark — centered.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final path = Path()
      ..moveTo(cx - cell * 1.1, cy + cell * 1.35)
      ..lineTo(cx + cell * 1.1, cy + cell * 1.35)
      ..lineTo(cx + cell * 0.85, cy + cell * 0.55)
      ..lineTo(cx + cell * 1.05, cy - cell * 0.55)
      ..lineTo(cx + cell * 0.35, cy + cell * 0.05)
      ..lineTo(cx, cy - cell * 1.05)
      ..lineTo(cx - cell * 0.35, cy + cell * 0.05)
      ..lineTo(cx - cell * 1.05, cy - cell * 0.55)
      ..lineTo(cx - cell * 0.85, cy + cell * 0.55)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF121410).withOpacity(0.9),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ColorResources.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
