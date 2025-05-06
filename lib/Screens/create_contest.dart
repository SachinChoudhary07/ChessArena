import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

class CreateContest extends StatefulWidget {
  const CreateContest({super.key});

  @override
  State<CreateContest> createState() => _CreateContestState();
}

class _CreateContestState extends State<CreateContest> {
  final timeOptions = ['1 min', '3 min', '5 min', '10 min'];
  final entryFees = ['₹50', '₹100', '₹200', '₹500', '₹1000', '₹5000', '₹10000'];
  final playersOptions = ['2', '4', '6', '8'];

  String selectedTime = '3 min';
  String selectedFee = '₹100';
  String selectedPlayers = '2';

  final _formKey = GlobalKey<FormState>();

  final TextEditingController gameNameController = TextEditingController();

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
        6, (index) => chars[(random + index * 13) % chars.length]).join();
  }

  void _createGame() {
    if (_formKey.currentState?.validate() ?? false) {
      final roomCode = _generateRoomCode();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("Game")),
            body: Center(
              child: Text(
                "Room Code: $roomCode\n"
                "Time: $selectedTime\n"
                "Entry Fee: $selectedFee\n"
                "Players: $selectedPlayers",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      );
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
            onPressed: () {
              Navigator.pop(context);
              if (inviteController.text.trim().isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text("Joining Game")),
                      body: Center(
                          child: Text(
                              "Joined Room: ${inviteController.text.trim()}")),
                    ),
                  ),
                );
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
                  child: Text(
                    item,
                    style: TextStyle(color: ColorResources.secondaryColor),
                  )))
              .toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select $label';
            }
            return null;
          },
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          buttonStyleData: const ButtonStyleData(
            padding: EdgeInsets.symmetric(horizontal: 12),
            height: 35,
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Helper.heightSizedBox(20),
                TextField(
                  controller: gameNameController,
                  decoration: const InputDecoration(
                    labelText: 'Game Name',
                    border: OutlineInputBorder(),
                  ),
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
                Helper.heightSizedBox(10),
                buildDropdown(
                  label: "Number of Players",
                  items: playersOptions,
                  selectedValue: selectedPlayers,
                  onChanged: (val) => setState(() => selectedPlayers = val!),
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
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}
