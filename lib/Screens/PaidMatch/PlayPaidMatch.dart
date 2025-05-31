// import 'package:chess_cash/Constant/app_constant.dart';
// import 'package:chess_cash/Constant/color_resources.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// class JoinPaidContest extends StatefulWidget {
//   const JoinPaidContest({super.key});
//
//   @override
//   State<JoinPaidContest> createState() => _JoinPaidContestState();
// }
//
// class _JoinPaidContestState extends State<JoinPaidContest> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   List<Map<String, dynamic>> contests = [];
//   bool isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchContests();
//   }
//
//   Future<void> fetchContests() async {
//     try {
//       final QuerySnapshot contestSnapshot = await _firestore
//           .collection('contests')
//           .where('status', isEqualTo: 'active')
//           .where('contestType', isEqualTo: 'paid')
//           .get();
//
//       setState(() {
//         contests = contestSnapshot.docs.map((doc) {
//           final data = doc.data() as Map<String, dynamic>;
//           final startDate = (data['startDate'] as Timestamp).toDate();
//           return {
//             'id': doc.id,
//             'title': data['contestName'],
//             'entryFee': '\$${data['entryFee']}',
//             'prize': '\$${data['prizeAmount']}',
//             'time': DateFormat('h:mm a').format(startDate),
//             'startDate': startDate,
//             'currentParticipants': data['currentParticipants'],
//             'participants': data['participants'] ?? [],
//           };
//         }).toList();
//         isLoading = false;
//       });
//     } catch (e) {
//       print('Error fetching contests: $e');
//       setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> joinContest(String contestId, List<dynamic> participants) async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         // Handle user not logged in
//         return;
//       }
//
//       //here before joining the contest we need to check if user have enough balance
//       final userDoc = await _firestore.collection('users').doc(user.uid).get();
//       final balance = userDoc.data()?['Balance'] ?? 0;
//       final contest =
//           await _firestore.collection('contests').doc(contestId).get();
//       final entryFeeAmount = contest.data()?['entryFee'] ?? 0;
//       if (balance < entryFeeAmount) {
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             title: Text('Insufficient Balance'),
//             content: Text('You do not have enough balance to join the contest'),
//             actions: [
//               TextButton(
//                   onPressed: () => Navigator.pop(context), child: Text('OK'))
//             ],
//           ),
//         );
//         return;
//       } else {
//         //deduct the amount from user
//         await _firestore.collection('users').doc(user.uid).update({
//           'Balance': FieldValue.increment(-entryFeeAmount),
//         });
//         await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .collection('transactions')
//             .add({
//           'amount': entryFeeAmount,
//           'type': 'Paid Contest',
//           'timestamp': Timestamp.now(),
//           'status': 'success',
//         });
//
//         // Update contest document
//         await _firestore.collection('contests').doc(contestId).update({
//           'participants': FieldValue.arrayUnion([user.uid]),
//           'currentParticipants': FieldValue.increment(1),
//         });
//       }
//
//       // Refresh the contests list
//       await fetchContests();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Successfully joined the contest')),
//       );
//     } catch (e) {
//       print('Error joining contest: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to join contest')),
//       );
//     }
//   }
//
//   final user = FirebaseAuth.instance.currentUser;
//
//   Widget _buildActionButton(Map<String, dynamic> contest) {
//     final now = DateTime.now();
//     final startDate = contest['startDate'] as DateTime;
//     final timeUntilStart = startDate.difference(now);
//     final isFull = int.parse(contest['currentParticipants'].toString()) >=
//         int.parse(contest['max_player']
//             .toString()); //this limit will come from firebase
//     final hasStarted = now.isAfter(startDate.add(const Duration(minutes: 10)));
//     final isWithin10Minutes = !hasStarted && timeUntilStart.inMinutes <= 10;
//
//     if (isWithin10Minutes) {
//       return ElevatedButton(
//         onPressed: () {},
//         style: ElevatedButton.styleFrom(
//           backgroundColor: ColorResources.secondaryColor,
//         ),
//         child: const Text('Start Game', style: TextStyle(color: Colors.white)),
//       );
//     } else {
//       return InkWell(
//         onTap: () {
//           if (contest['participants'].contains(user!.uid)) {
//             //show a dialog that you have already joined the contest
//             showDialog(
//               context: context,
//               builder: (context) => AlertDialog(
//                 title: Text('Already Joined'),
//                 content: Text('You have already joined the contest'),
//                 actions: [
//                   TextButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: Text('OK'))
//                 ],
//               ),
//             );
//           } else {
//             joinContest(contest['id'], contest['participants']);
//           }
//         },
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(10),
//             border: Border.all(color: ColorResources.secondaryColor),
//           ),
//           child: Text(
//             contest['participants'].contains(user!.uid) ? 'Joined' : "Join Now",
//             style: TextStyle(
//               color: ColorResources.secondaryColor,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       );
//     }
//   }
//
//   String _formatTimeRemaining(Duration duration) {
//     if (duration.inHours > 0) {
//       return '${duration.inHours}h ${duration.inMinutes % 60}m';
//     } else {
//       return '${duration.inMinutes}m';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(AppConstants.joinContest),
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: contests.length,
//               itemBuilder: (context, index) {
//                 final contest = contests[index];
//                 return Container(
//                   margin:
//                       const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   decoration: BoxDecoration(
//                       border: Border.all(color: ColorResources.secondaryColor),
//                       borderRadius: BorderRadius.circular(12)),
//                   child: ListTile(
//                     title: Center(child: Text(contest['title'])),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text('Entry Fee:'),
//                             Text(
//                               ' ${contest['entryFee']}',
//                               style: TextStyle(
//                                   color: ColorResources.secondaryColor,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ],
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text('Time: '),
//                             Text(
//                               '${contest['time']}',
//                               style: TextStyle(
//                                   color: ColorResources.secondaryColor,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ],
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text('Prize: '),
//                             Text(
//                               '${contest['prize']}',
//                               style: TextStyle(
//                                   color: ColorResources.secondaryColor,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ],
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text('Participants: '),
//                             Text(
//                               '${contest['currentParticipants']}',
//                               style: TextStyle(
//                                   color: ColorResources.secondaryColor,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ],
//                         ),
//                         Center(
//                           child: _buildActionButton(contest),
//                         )
//                       ],
//                     ),
//                     isThreeLine: true,
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }

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
                onPressed: () async {
                  await _hasEnoughBalance()
                      ? push(
                          context,
                          PaidMatchmaking(
                            time: selectedTime,
                            amount: selectedFee,
                          ))
                      : ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'You Dont have enough balance, please add some money')),
                        );
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text("Start Match"),
              ),
              Helper.heightSizedBox(20),
              // const Text("OR",
              //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              // Helper.heightSizedBox(10),
              // OutlinedButton(
              //   onPressed: _joinWithInvite,
              //   style: OutlinedButton.styleFrom(
              //       minimumSize: const Size.fromHeight(50)),
              //   child: const Text("Join via Invite Code"),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
