import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Screens/GameScreens/MatchMakingScreen.dart';
import 'package:chess_cash/Screens/PaidContest/JoinPaidContest.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:flutter/material.dart';

import '../../Constant/ui_helper.dart';

class Dashboardscreen extends StatefulWidget {
  const Dashboardscreen({super.key});

  @override
  State<Dashboardscreen> createState() => _DashboardscreenState();
}

class _DashboardscreenState extends State<Dashboardscreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: ColorResources.primaryColor,
        body: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.only(top: 80, bottom: 20, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppConstants.appName.toUpperCase(),
                  style: TextStyle(
                    color: ColorResources.secondaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Helper.heightSizedBox(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton(AppConstants.addMoney,
                        Icons.account_balance_wallet, Colors.green, () {}),
                    Helper.widthSizedBox(),
                    _buildButton(AppConstants.withdraw, Icons.money_off,
                        ColorResources.secondaryColor, () {}),
                  ],
                ),
                _buildButton(
                    AppConstants.playFreeMatch, Icons.play_arrow, Colors.blue,
                    () {
                  push(context, MatchMakingScreen());
                }),
                _buildButton(AppConstants.joinPaidContest, Icons.attach_money,
                    ColorResources.secondaryColor, () {
                  push(context, const JoinPaidContest());
                }),
                _buildButton(AppConstants.tournaments, Icons.emoji_events,
                    ColorResources.secondaryColor, () {}),
                _buildButton(
                    AppConstants.createContest,
                    Icons.compare_arrows_sharp,
                    ColorResources.secondaryColor,
                    () {}),
                Helper.heightSizedBox(20),
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ColorResources.secondaryColor)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: '10 min',
                        items: <String>['10 min', '15 min', '30 min']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            alignment: Alignment.center,
                            value: value,
                            child: Center(
                              child: Text(
                                value,
                                style: TextStyle(
                                    color: ColorResources.secondaryColor),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, iconColor, onTap) {
    return InkWell(
      splashColor: Colors.transparent,
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          margin: const EdgeInsets.symmetric(vertical: 10),
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
    );
  }
}
