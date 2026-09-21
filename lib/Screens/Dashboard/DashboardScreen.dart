import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/CreateTournament/createTournament.dart';
import 'package:chess_cash/Screens/GameScreens/MatchMakingScreen.dart';
import 'package:chess_cash/Screens/PaidMatch/PlayPaidMatch.dart';
import 'package:chess_cash/Screens/TournamentScreens/tournaments_screen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../Constant/ui_helper.dart';
import '../PlayWithOnlineFriends/play_with_online_friend.dart';

class Dashboardscreen extends StatefulWidget {
  const Dashboardscreen({super.key});

  @override
  State<Dashboardscreen> createState() => _DashboardscreenState();
}

class _DashboardscreenState extends State<Dashboardscreen> {
  String selectedTime = '3 min';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: ColorResources.primaryColor,
        body: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.only(top: 20, bottom: 20, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: () {
                      // Navigate to wallet screen (index 1)
                      bottomNavBarKey.currentState?.changeIndex(1);
                    },
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 33,
                    ),
                  ),
                ),
                Image.asset(
                  AppConstants.splashIcon,
                  height: 200,
                ),
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ColorResources.secondaryColor)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled_sharp),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              value: selectedTime,
                              items: <String>[
                                '1 min',
                                '3 min',
                                '5 min',
                                '10 min',
                                '15 min',
                                '30 min',
                                '60 min'
                              ]
                                  .map((number) => DropdownMenuItem(
                                        value: number,
                                        child: Text(
                                          number,
                                          style: TextStyle(
                                              color: ColorResources
                                                  .secondaryColor),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedTime = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Helper.heightSizedBox(10),
                _buildButton(AppConstants.playFreeMatch, Icons.play_arrow,
                    ColorResources.secondaryColor, () {
                  _startMatchmaking();
                }),
                _buildButton(AppConstants.joinPaidContest, Icons.attach_money,
                    ColorResources.secondaryColor, () {
                  push(context, PlayPaidMatch(defaultTime: selectedTime));
                }),
                _buildButton(AppConstants.tournaments, Icons.emoji_events,
                    ColorResources.secondaryColor, () {
                  push(context, const TournamentsScreen());
                }),
                _buildButton(
                    AppConstants.createContest,
                    Icons.compare_arrows_sharp,
                    ColorResources.secondaryColor, () {
                  push(context, const CreateTournament());
                }),
                // _buildButton(
                //     AppConstants.playWithFriends,
                //     Icons.people_outline_rounded,
                //     ColorResources.secondaryColor, () {
                //   push(context, const PlayWithFriends());
                // }),
                _buildButton(
                    AppConstants.playWithFriends,
                    Icons.people_outline_rounded,
                    ColorResources.secondaryColor, () {
                  push(context, const PlayWithOnlineFriendScreen());
                }),
                Helper.heightSizedBox(20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, iconColor, onTap) {
    return Column(
      children: [
        Helper.heightSizedBox(10),
        InkWell(
          splashColor: Colors.black,
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              decoration: BoxDecoration(
                  border: Border.all(color: ColorResources.secondaryColor),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: iconColor,
                    size: 35,
                  ),
                  Helper.widthSizedBox(),
                  Text(
                    text,
                    style: TextStyle(
                        color: ColorResources.secondaryColor, fontSize: 18),
                  )
                ],
              )),
        ),
        Helper.heightSizedBox(10)
      ],
    );
  }

  void _startMatchmaking() async {
    if (kDebugMode) {
      print(
          "🎮 Dashboard: Starting matchmaking with time limit: $selectedTime");
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchMakingScreen(time: selectedTime),
      ),
    );
  }
}
