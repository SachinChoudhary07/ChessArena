import 'package:chess_cash/Screens/GameScreens/waitingRoom.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Constant/color_resources.dart';
import '../../Constant/ui_helper.dart';
import '../../Services/navigation.dart';

class CreateContest extends StatefulWidget {
  const CreateContest({super.key});

  @override
  State<CreateContest> createState() => _CreateContestState();
}

class _CreateContestState extends State<CreateContest> {
  final timeOptions = ['1 min', '3 min', '5 min', '10 min'];
  final entryFees = ['₹50', '₹100', '₹200', '₹500', '₹1000', '₹5000', '₹10000'];

  String selectedTime = '3 min';
  String selectedFee = '₹100';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController gameNameController = TextEditingController();

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (index) => chars[(timestamp + index * 13) % chars.length],
    ).join();
  }

  Future<void> _createGame() async {
    if (_formKey.currentState?.validate() ?? false) {
      final roomCode = _generateRoomCode();
      final uid = FirebaseAuth.instance.currentUser?.uid;

      final roomData = {
        'roomCode': roomCode,
        'hostId': uid,
        'player1': uid,
        'player2': null,
        'status': 'waiting', // Initial status
        'createdAt': FieldValue.serverTimestamp(),
        'gameName': gameNameController.text.trim(),
        'time': selectedTime,
        'entryFee': selectedFee,
      };

      await FirebaseFirestore.instance
          .collection('games') // 🔁 Update from 'gameRooms' to 'games'
          .doc(roomCode)
          .set(roomData);

      push(context,
          EnhancedWaitingRoom(roomCode: roomCode)); // Push with correct code
    }
  }

  void _joinWithInvite() {
    final inviteController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enter Invite Code"),
        content: TextField(
          controller: inviteController,
          decoration: const InputDecoration(
            hintText: "Enter code",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final code = inviteController.text.trim().toUpperCase();
              Navigator.pop(context);
              if (code.isNotEmpty) {
                final snapshot = await FirebaseFirestore.instance
                    .collection(
                        'games') // 🔁 Updated from 'gameRooms' to 'games'
                    .doc(code)
                    .get();

                if (snapshot.exists && snapshot.data()?['player2'] == null) {
                  await FirebaseFirestore.instance
                      .collection('games') // 🔁 Updated here too
                      .doc(code)
                      .update({
                    'player2': FirebaseAuth.instance.currentUser?.uid,
                    'status': 'ready', // Set status to ready once joined
                  });

                  push(context, EnhancedWaitingRoom(roomCode: code));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Invalid or already joined game code."),
                  ));
                }
              }
            },
            child: const Text("Join"),
          )
        ],
      ),
    );
  }

  Widget buildDropdown({
    required String label,
    required List<String> items,
    required String selectedValue,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorResources.secondaryColor)),
        Helper.heightSizedBox(6),
        DropdownButtonFormField2<String>(
          isExpanded: true,
          value: selectedValue,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item,
                        style: TextStyle(color: ColorResources.secondaryColor)),
                  ))
              .toList(),
          onChanged: onChanged,
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Please select $label' : null,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          buttonStyleData: const ButtonStyleData(
              padding: EdgeInsets.symmetric(horizontal: 12), height: 35),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Contest")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Helper.heightSizedBox(20),
              TextFormField(
                controller: gameNameController,
                decoration: const InputDecoration(
                  labelText: 'Game Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter game name' : null,
              ),
              Helper.heightSizedBox(10),
              buildDropdown(
                label: "Time Control",
                items: timeOptions,
                selectedValue: selectedTime,
                onChanged: (val) => setState(() => selectedTime = val!),
              ),
              Helper.heightSizedBox(10),
              buildDropdown(
                label: "Entry Fee",
                items: entryFees,
                selectedValue: selectedFee,
                onChanged: (val) => setState(() => selectedFee = val!),
              ),
              Helper.heightSizedBox(40),
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
      ),
    );
  }
}
