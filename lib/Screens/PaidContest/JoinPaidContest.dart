import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class JoinPaidContest extends StatefulWidget {
  const JoinPaidContest({super.key});

  @override
  State<JoinPaidContest> createState() => _JoinPaidContestState();
}

class _JoinPaidContestState extends State<JoinPaidContest> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> contests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchContests();
  }

  Future<void> fetchContests() async {
    try {
      final QuerySnapshot contestSnapshot = await _firestore
          .collection('contests')
          .where('status', isEqualTo: 'active')
          .where('contestType', isEqualTo: 'paid')
          .get();

      setState(() {
        contests = contestSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final startDate = (data['startDate'] as Timestamp).toDate();
          return {
            'id': doc.id,
            'title': data['contestName'],
            'entryFee': '\$${data['entryFee']}',
            'prize': '\$${data['prizeAmount']}',
            'time': DateFormat('h:mm a').format(startDate),
            'startDate': startDate,
            'currentParticipants': data['currentParticipants'],
            'participants': data['participants'] ?? [],
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching contests: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> joinContest(String contestId, List<dynamic> participants) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Handle user not logged in
        return;
      }

      // Update contest document
      await _firestore.collection('contests').doc(contestId).update({
        'participants': FieldValue.arrayUnion([user.uid]),
        'currentParticipants': FieldValue.increment(1),
      });

      // Refresh the contests list
      await fetchContests();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the contest')),
      );
    } catch (e) {
      print('Error joining contest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join contest')),
      );
    }
  }

  final user = FirebaseAuth.instance.currentUser;

  Widget _buildActionButton(Map<String, dynamic> contest) {
    final now = DateTime.now();
    final startDate = contest['startDate'] as DateTime;
    final timeUntilStart = startDate.difference(now);
    final isFull = contest['currentParticipants'] >= 2;
    final isWithin10Minutes = timeUntilStart.inMinutes <= 10;

    if (isFull && isWithin10Minutes) {
      return ElevatedButton(
        onPressed: () {
          // TODO: Implement start game functionality
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorResources.secondaryColor,
        ),
        child: const Text('Start Game', style: TextStyle(color: Colors.white)),
      );
    } else if (isFull) {
      return Text(
        'Match will start in ${_formatTimeRemaining(timeUntilStart)}',
        style: TextStyle(color: ColorResources.secondaryColor),
      );
    } else {
      return InkWell(
        onTap: () => joinContest(contest['id'], contest['participants']),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorResources.secondaryColor),
          ),
          child: Text(
            contest['participants'].contains(user!.uid) ? 'Joined' : "Join Now",
            style: TextStyle(
              color: ColorResources.secondaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.joinContest),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: contests.length,
              itemBuilder: (context, index) {
                final contest = contests[index];
                return Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: ColorResources.secondaryColor),
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Center(child: Text(contest['title'])),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Entry Fee:'),
                            Text(
                              ' ${contest['entryFee']}',
                              style: TextStyle(
                                  color: ColorResources.secondaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Time: '),
                            Text(
                              '${contest['time']}',
                              style: TextStyle(
                                  color: ColorResources.secondaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Prize: '),
                            Text(
                              '${contest['prize']}',
                              style: TextStyle(
                                  color: ColorResources.secondaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Participants: '),
                            Text(
                              '${contest['currentParticipants']}',
                              style: TextStyle(
                                  color: ColorResources.secondaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Center(
                          child: _buildActionButton(contest),
                        )
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
