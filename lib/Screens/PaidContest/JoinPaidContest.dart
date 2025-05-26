import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/GameScreens/MatchMakingScreen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:flutter/material.dart';

class JoinPaidContest extends StatefulWidget {
  const JoinPaidContest({super.key});

  @override
  State<JoinPaidContest> createState() => _JoinPaidContestState();
}

class _JoinPaidContestState extends State<JoinPaidContest> {
  final List<Map<String, String>> contests = [
    {
      'title': 'Chess Championship',
      'entryFee': '\$10',
      'time': '3:00 PM',
      'prize': '\$18',
    },
    {
      'title': 'Rapid Chess Tournament',
      'entryFee': '\$5',
      'time': '5:00 PM',
      'prize': '\$9',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.joinContest),
      ),
      body: ListView.builder(
        itemCount: contests.length,
        itemBuilder: (context, index) {
          final contest = contests[index];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            decoration: BoxDecoration(
                border: Border.all(color: ColorResources.secondaryColor),
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Center(child: Text(contest['title']!)),
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
                  Center(
                    child: InkWell(
                      // onTap: () => push(context, const MatchMakingScreen()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: ColorResources.secondaryColor)),
                        child: Text(
                          "Join Now",
                          style: TextStyle(
                              color: ColorResources.secondaryColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  )
                ],
              ),
              isThreeLine: true,
              onTap: () {
                // Handle contest selection
              },
            ),
          );
        },
      ),
    );
  }
}
