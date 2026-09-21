import 'package:chess_cash/Screens/GameScreens/waitingRoom.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../Constant/color_resources.dart';
import '../../Constant/ui_helper.dart';
import '../../Services/navigation.dart';

class PlayWithFriends extends StatefulWidget {
  const PlayWithFriends({super.key});

  @override
  State<PlayWithFriends> createState() => _PlayWithFriendsState();
}

class _PlayWithFriendsState extends State<PlayWithFriends> {
  final timeOptions = ['1 min', '3 min', '5 min', '10 min', '15 min'];
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

  // Convert fee string (e.g. "₹100") to double (e.g. 100.0)
  double _getEntryFeeAmount() {
    final amount =
        double.parse(selectedFee.replaceAll('₹', '').replaceAll(',', ''));
    print(
        "💰 CreateContest: Converting entry fee ${selectedFee} to amount: $amount");
    return amount;
  }

  // Show dialog when user doesn't have enough balance
  void _showInsufficientFundsDialog() {
    print(
        "💰 CreateContest: Showing insufficient funds dialog for amount ${selectedFee}");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Insufficient Balance'),
          content: Text(
            'You don\'t have enough money in your wallet for a contest of ${selectedFee}.\n\nPlease add money to your wallet and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                print(
                    "💰 CreateContest: User acknowledged insufficient funds dialog");
                Navigator.pop(context);
              },
              child: const Text('Okay'),
            ),
          ],
        );
      },
    );
  }

  // Check if user has sufficient balance
  Future<bool> _hasEnoughBalance() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("❌ CreateContest: No authenticated user found");
        return false;
      }

      print("💰 CreateContest: Checking balance for user ${currentUser.uid}");
      // Get user's wallet balance
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      // Get current balance, default to 0 if not found
      final currentBalance = (userDoc.data()?['Balance'] ?? 0.0) as num;
      final requiredAmount = _getEntryFeeAmount();

      print(
          "💰 CreateContest: User balance: $currentBalance, Required amount: $requiredAmount");
      final hasEnough = currentBalance >= requiredAmount;
      print("💰 CreateContest: Has enough balance: $hasEnough");

      return hasEnough;
    } catch (e) {
      print("❌ CreateContest: Error checking balance: $e");
      return false;
    }
  }

  Future<void> _createGame() async {
    print("🎮 CreateContest: Attempting to create new game");
    if (_formKey.currentState?.validate() ?? false) {
      // First check if user has enough balance
      final hasBalance = await _hasEnoughBalance();
      if (!hasBalance) {
        print("❌ CreateContest: Insufficient balance to create game");
        _showInsufficientFundsDialog();
        return;
      }

      final roomCode = _generateRoomCode();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      print("🎮 CreateContest: Generated room code: $roomCode for user: $uid");

      final roomData = {
        'roomCode': roomCode,
        'hostId': uid,
        'player1': uid,
        'player2': null,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'gameName': gameNameController.text.trim(),
        'time': selectedTime,
        'entryFee': _getEntryFeeAmount(),
      };

      print("🎮 CreateContest: Creating game with data: $roomData");

      try {
        await FirebaseFirestore.instance
            .collection('games')
            .doc(roomCode)
            .set(roomData);
        print("✅ CreateContest: Game created successfully");

        print("🎮 CreateContest: Navigating to waiting room");
        push(context, EnhancedWaitingRoom(roomCode: roomCode));
      } catch (e) {
        print("❌ CreateContest: Error creating game: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Error creating game. Please try again.")),
        );
      }
    } else {
      print("❌ CreateContest: Form validation failed");
    }
  }

  void _joinWithInvite() {
    print("🎮 CreateContest: Opening join game dialog");
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
              print(
                  "🎮 CreateContest: Attempting to join game with code: $code");

              if (code.isNotEmpty) {
                try {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('games')
                      .doc(code)
                      .get();

                  if (snapshot.exists && snapshot.data()?['player2'] == null) {
                    print("✅ CreateContest: Found valid game to join");
                    selectedFee = '₹' + snapshot.data()!['entryFee'].toString();
                    print("💰 CreateContest: Game entry fee: $selectedFee");

                    // Check balance
                    final hasBalance = await _hasEnoughBalance();
                    if (!hasBalance) {
                      print(
                          "❌ CreateContest: Insufficient balance to join game");
                      _showInsufficientFundsDialog();
                      return;
                    }

                    print(
                        "💰 CreateContest: Deducting entry fee from both players");
                    // Deduct from joining player
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .update({
                      'Balance': FieldValue.increment(-_getEntryFeeAmount()),
                    });
                    print(
                        "✅ CreateContest: Amount deducted from joining player");

                    // Deduct from host
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(snapshot.data()?['hostId'])
                        .update({
                      'Balance': FieldValue.increment(-_getEntryFeeAmount()),
                    });
                    print("✅ CreateContest: Amount deducted from host");

                    // Update game status
                    await FirebaseFirestore.instance
                        .collection('games')
                        .doc(code)
                        .update({
                      'player2': FirebaseAuth.instance.currentUser?.uid,
                      'status': 'ready',
                    });
                    print("✅ CreateContest: Game status updated to ready");

                    print("🎮 CreateContest: Navigating to waiting room");
                    push(context, EnhancedWaitingRoom(roomCode: code));
                  } else {
                    print(
                        "❌ CreateContest: Invalid or already joined game code");
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Invalid or already joined game code."),
                    ));
                  }
                } catch (e) {
                  print("❌ CreateContest: Error joining game: $e");
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Error joining game. Please try again."),
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
      appBar: AppBar(title: const Text("Play with Friend")),
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
