import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Screens/PaidMatch/PaidMatchmaking.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PlayPaidMatch extends StatefulWidget {
  const PlayPaidMatch({super.key});

  @override
  State<PlayPaidMatch> createState() => _PlayPaidMatchState();
}

class _PlayPaidMatchState extends State<PlayPaidMatch> {
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
        "💰 CreateContest: Converting entry fee $selectedFee to amount: $amount");
    return amount;
  }

  // Show dialog when user doesn't have enough balance
  void _showInsufficientFundsDialog() {
    print(
        "💰 CreateContest: Showing insufficient funds dialog for amount $selectedFee");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Insufficient Balance'),
          content: Text(
            'You don\'t have enough money in your wallet for a contest of $selectedFee.\n\nPlease add money to your wallet and try again.',
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
  Future<bool> _hasEnoughBalance(double requiredAmount) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentBalance = (userDoc.data()?['Balance'] ?? 0.0) as num;
      return currentBalance >= requiredAmount;
    } catch (e) {
      return false;
    }
  }

  void _startMatchmaking(String time, String amount) async {
    final requiredAmount =
        double.parse(amount.replaceAll('₹', '').replaceAll(',', ''));
    if (await _hasEnoughBalance(requiredAmount)) {
      push(context, PaidMatchmaking(time: time, amount: amount));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('You Dont have enough balance, please add some money')),
      );
    }
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
      appBar: AppBar(title: const Text("Play Paid Match")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('paidMatch').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No paid matches available'));
          }
          final matches = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final data = matches[index].data() as Map<String, dynamic>;
              final entryFee = data['entryFee'] ?? 0;
              final time = data['timeControl'] ?? '';
              const spots = 2;
              // Calculate prize pool after 8% admin cut
              final double entryFeeValue =
                  double.tryParse(entryFee.toString()) ?? 0.0;
              final int spotsValue = int.tryParse(spots.toString()) ?? 2;
              const double adminPercent = 8.0;
              final double prizePool =
                  entryFeeValue * spotsValue * (1 - adminPercent / 100);
              return Card(
                margin: const EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prize Pool',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 16)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₹${prizePool.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 28)),
                          SizedBox(
                            width: 100,
                            child: ElevatedButton(
                              onPressed: () => _startMatchmaking(
                                  time.toString(), entryFee.toString()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorResources.secondaryColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      5), // <-- No rounded corners
                                ),
                              ),
                              child: Text('₹$entryFee',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                      // Helper.heightSizedBox(20),
                      const Divider(
                        color: Colors.white70,
                        height: 40,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.emoji_events,
                                  color: Colors.amber[700], size: 20),
                              const SizedBox(width: 4),
                              Text('₹${prizePool.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 12),
                              const Icon(Icons.emoji_events_outlined,
                                  color: Colors.grey, size: 20),
                              const SizedBox(width: 4),
                              const Text('50%',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(width: 12),
                              Text('$time Minutues')
                            ],
                          ),
                          const Text("2 Spots"),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
