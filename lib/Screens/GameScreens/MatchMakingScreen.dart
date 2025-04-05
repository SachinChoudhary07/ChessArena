import 'dart:async';
import 'package:flutter/material.dart';

class MatchMakingScreen extends StatefulWidget {
  const MatchMakingScreen({super.key});

  @override
  State<MatchMakingScreen> createState() => _MatchMakingScreenState();
}

class _MatchMakingScreenState extends State<MatchMakingScreen> {
  bool isWaiting = true; // Simulate waiting status
  double opacity = 0.0; // For animation

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        opacity = 1.0;
      });
    });
  }

  void _simulateMatchFound() {
    setState(() {
      isWaiting = false;
    });
    // Start game after 5 seconds
    Timer(const Duration(seconds: 5), () {
      _startGame();
    });
  }

  void _startGame() {
    // Navigate to the game screen or perform another action
    // For example, Navigator.pushReplacementNamed(context, '/gameScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MatchMaking'),
      ),
      body: Center(
        child: isWaiting ? _buildWaitingScreen() : _buildMatchFoundScreen(),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(seconds: 1),
          child: const Text(
            'Waiting for an opponent...',
            style: TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _simulateMatchFound,
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildMatchFoundScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 100),
        const SizedBox(height: 20),
        const Text(
          'Match Found!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text(
          'Starting game in 5 seconds...',
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
