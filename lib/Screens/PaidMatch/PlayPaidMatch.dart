import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Screens/PaidMatch/PaidMatchmaking.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PlayPaidMatch extends StatefulWidget {
  final String? defaultTime; // Add default time parameter

  const PlayPaidMatch({super.key, this.defaultTime});

  @override
  State<PlayPaidMatch> createState() => _PlayPaidMatchState();
}

class _PlayPaidMatchState extends State<PlayPaidMatch> {
  String selectedFee = '₹100';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController gameNameController = TextEditingController();

  // Add filter state
  String? selectedTimeFilter;
  final List<String> timeOptions = [
    'All',
    '1 min',
    '3 min',
    '5 min',
    '10 min',
    '15 min'
  ];

  @override
  void initState() {
    super.initState();
    // Set default time filter from widget parameter or use 'All'
    selectedTimeFilter = widget.defaultTime ?? 'All';
  }

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

  // Filter matches based on selected time
  List<QueryDocumentSnapshot> _filterMatches(
      List<QueryDocumentSnapshot> matches) {
    if (selectedTimeFilter == null || selectedTimeFilter == 'All') {
      return matches;
    }
    return matches.where((match) {
      final data = match.data() as Map<String, dynamic>;
      // Check multiple possible field names for time control
      final timeControl =
          data['timeControl'] ?? data['timecontrol'] ?? data['time'] ?? '';

      // Extract the numeric value from the time control (e.g., "3" from "3 min")
      final numericValue = selectedTimeFilter!.split(' ')[0];

      // Check if the time control contains the numeric value
      return timeControl.toString().contains(numericValue);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Play Paid Match"),
        actions: [
          if (selectedTimeFilter != null && selectedTimeFilter != 'All')
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ColorResources.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: ColorResources.secondaryColor.withOpacity(0.3)),
              ),
              child: Text(
                selectedTimeFilter!,
                style: TextStyle(
                  color: ColorResources.secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Time Control',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColorResources.secondaryColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField2<String>(
                  isExpanded: true,
                  value: selectedTimeFilter,
                  items: timeOptions
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              item,
                              style: TextStyle(
                                  color: ColorResources.secondaryColor),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedTimeFilter = value;
                    });
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    hintText: 'Select time control',
                  ),
                  buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    height: 40,
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Matches List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('paidMatch')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No paid matches available'));
                }

                final allMatches = snapshot.data!.docs;
                final filteredMatches = _filterMatches(allMatches);

                if (filteredMatches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matches found for ${selectedTimeFilter ?? 'All'}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try changing the time filter',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredMatches.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredMatches[index].data() as Map<String, dynamic>;
                    final entryFee = data['entryFee'] ?? 0;
                    final time = data['timeControl'] ??
                        data['timecontrol'] ??
                        data['time'] ??
                        '';
                    const spots = 2;
                    // Calculate prize pool after 18% admin cut
                    final double entryFeeValue =
                        double.tryParse(entryFee.toString()) ?? 0.0;
                    final int spotsValue = int.tryParse(spots.toString()) ?? 2;
                    const double adminPercent = 18.0;
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
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Prize Pool',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16)),
                                Text('Entry Fee   ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16)),
                              ],
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('₹${prizePool.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 28)),
                                SizedBox(
                                  width: 100,
                                  child: ElevatedButton(
                                    onPressed: () => _startMatchmaking(
                                        time.toString(), entryFee.toString()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          ColorResources.secondaryColor,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
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
                                    const Icon(Icons.timelapse_sharp,
                                        color: Colors.grey, size: 20),
                                    const SizedBox(width: 4),
                                    Text('$time Minutes')
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
          ),
        ],
      ),
    );
  }
}
