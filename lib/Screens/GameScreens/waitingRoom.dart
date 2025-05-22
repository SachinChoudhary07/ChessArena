import 'dart:async';

import 'package:chess_cash/Screens/GameScreens/GamePlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WaitingRoom extends StatefulWidget {
  final String roomCode;

  const WaitingRoom({super.key, required this.roomCode});

  @override
  State<WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<WaitingRoom> {
  bool _navigated = false; // Prevent multiple navigations
  Timer? _startTimer;

  void _startGameAfterDelay(Map<String, dynamic> roomData) {
    if (_navigated) return;

    _startTimer?.cancel(); // Cancel if already running

    _startTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(roomCode: widget.roomCode),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel(); // Always cancel the timer on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Waiting Room")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(widget.roomCode)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(
                child: Text("Waiting for room to be created..."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final player1 = data['player1'];
          final player2 = data['player2'];
          final status = data['status'];

          final players = [player1, if (player2 != null) player2];

          if (status == 'ready') {
            _startGameAfterDelay(data); // Start timer when ready
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Waiting for players...",
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              Text("Room Code: ${widget.roomCode}"),
              const SizedBox(height: 20),
              ...players.map((player) => Container(
                    padding: const EdgeInsets.all(12),
                    margin:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    color: Colors.green,
                    child: Text(player.toString(),
                        style: const TextStyle(color: Colors.white)),
                  )),
              const SizedBox(height: 20),
              if (status == 'ready')
                const Text("Game starting in 5 seconds..."),
            ],
          );
        },
      ),
    );
  }
}
