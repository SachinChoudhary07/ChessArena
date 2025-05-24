import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/WalletProvider/WalletProvider.dart';
import 'package:chess_cash/Screens/GameScreens/MatchMakingScreen.dart';
import 'package:chess_cash/Screens/PaidContest/JoinPaidContest.dart';
import 'package:chess_cash/Screens/create_contest.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../Constant/ui_helper.dart';

class Dashboardscreen extends StatefulWidget {
  const Dashboardscreen({super.key});

  @override
  State<Dashboardscreen> createState() => _DashboardscreenState();
}

class _DashboardscreenState extends State<Dashboardscreen> {
  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

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
                    _buildButton(
                      AppConstants.addMoney,
                      Icons.account_balance_wallet,
                      ColorResources.secondaryColor,
                      () => _showAddCashBottomSheet(context, walletProvider),
                    ),
                    Helper.widthSizedBox(),
                    _buildButton(
                        AppConstants.withdraw,
                        Icons.account_balance_wallet_outlined,
                        ColorResources.secondaryColor,
                        () => _showWithdrawalCashBottomSheet(
                            context, walletProvider)),
                  ],
                ),
                _buildButton(AppConstants.playFreeMatch, Icons.play_arrow,
                    ColorResources.secondaryColor, () {
                  push(context, const MatchMakingScreen());
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
                    ColorResources.secondaryColor, () {
                  push(context, const CreateContest());
                }),
                Helper.heightSizedBox(20),
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ColorResources.secondaryColor)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: '1 min',
                        // Time options: 1 min, 3 min, 5 min, 10 min, 15 min, 30 min.
                        items: <String>[
                          '1 min',
                          '3 min',
                          '5 min',
                          '10 min',
                          '15 min',
                          '30 min'
                        ].map<DropdownMenuItem<String>>((String value) {
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
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            border: Border.all(color: ColorResources.secondaryColor),
            borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          splashColor: Colors.black,
          onTap: onTap,
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
          ),
        ));
  }

  void _showAddCashBottomSheet(
      BuildContext context, WalletProvider walletProvider) {
    final focusNode = FocusNode();

    showModalBottomSheet(
      constraints: BoxConstraints.tight(
          Size.fromHeight(MediaQuery.of(context).size.height / 1.7)),
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Amount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                focusNode: focusNode,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'e.g. 100',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    walletProvider.enteredAmount =
                        double.tryParse(controller.text);
                    if (walletProvider.enteredAmount != null &&
                        walletProvider.enteredAmount! > 0) {
                      Navigator.pop(context);
                      walletProvider.openCheckout(controller.text, context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a valid amount')),
                      );
                    }
                  }
                },
                child: const Text('PROCEED TO PAY'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    focusNode.requestFocus();
  }

  TextEditingController withdrawalupiController = TextEditingController();
  TextEditingController withdrawalController = TextEditingController();
  TextEditingController controller = TextEditingController();

  void _showWithdrawalCashBottomSheet(
      BuildContext context, WalletProvider walletProvider) {
    final focusNode = FocusNode();

    showModalBottomSheet(
      constraints: BoxConstraints.tight(
          Size.fromHeight(MediaQuery.of(context).size.height / 1.5)),
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Amount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: withdrawalController,
                focusNode: focusNode,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'e.g. 100',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter UPI ID',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: withdrawalupiController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  hintText: 'e.g. abc@paytm',
                  prefixText: '@ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  final amount = double.tryParse(withdrawalController.text);
                  final upiID = withdrawalupiController.text;
                  if (amount != null && upiID.isNotEmpty) {
                    walletProvider.requestWithdrawal(amount, upiID, context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter valid details')),
                    );
                  }
                },
                child: const Text('PROCEED TO WITHDRAWAL'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    focusNode.requestFocus();
  }
}
