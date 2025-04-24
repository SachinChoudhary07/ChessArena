import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:flutter/material.dart';

class CreateContest extends StatefulWidget {
  const CreateContest({super.key});

  @override
  State<CreateContest> createState() => _CreateContestState();
}

class _CreateContestState extends State<CreateContest> {
  String selectedTime = '3 min';
  final List<String> timeOptions = ['1 min', '3 min', '5 min', '10 min'];

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime
        .now()
        .millisecondsSinceEpoch;
    return List.generate(
        6, (index) => chars[(random + index * 13) % chars.length]).join();
  }

  void _createGame() {
    final roomCode = _generateRoomCode();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(
              appBar: AppBar(title: const Text("Game")),
              body:
              Center(child: Text("Room Code: $roomCode\nTime: $selectedTime")),
            ),
      ),
    );
  }

  void _joinWithInvite() {
    // Navigate to invite join screen
    showDialog(
      context: context,
      builder: (_) {
        final TextEditingController _inviteController = TextEditingController();
        return AlertDialog(
          title: const Text("Enter Invite Code"),
          content: TextField(
            controller: _inviteController,
            decoration: const InputDecoration(
              hintText: "Enter code",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                String inviteCode = _inviteController.text.trim();
                if (inviteCode.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          Scaffold(
                            appBar: AppBar(title: const Text("Joining Game")),
                            body: Center(child: Text(
                                "Joined Room: $inviteCode")),
                          ),
                    ),
                  );
                }
              },
              child: const Text("Join"),
            )
          ],
        );
      },
    );
  }

  void _joinRandom() {
    // Join random room logic here (e.g. matchmaking)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Scaffold(
              appBar: AppBar(title: const Text("Joining Random Match")),
              body: const Center(
                  child: Text("Searching for available game...")),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Contest")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Helper.heightSizedBox(40),
            TextField(
              controller: TextEditingController(text: ''),
              decoration: const InputDecoration(
                labelText: 'Game Name',
                border: OutlineInputBorder(),
              ),
            ),
            Helper.heightSizedBox(20),
            DropdownButtonFormField<String>(
              value: selectedTime,
              items: timeOptions.map((time) {
                return DropdownMenuItem(value: time, child: Text(time));
              }).toList(),
              decoration: const InputDecoration(
                labelText: "Select Time Control",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (value != null) setState(() => selectedTime = value);
              },
            ),
            Helper.heightSizedBox(60),
            ElevatedButton(
              onPressed: _createGame,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: const Text("Create Game"),
            ),
            Helper.heightSizedBox(20),
            const Text("OR",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Helper.heightSizedBox(10),
            OutlinedButton(
              onPressed: _joinWithInvite,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: const Text("Join via Invite Code"),
            ),
          ],
        ),
      ),
    );
  }
}
