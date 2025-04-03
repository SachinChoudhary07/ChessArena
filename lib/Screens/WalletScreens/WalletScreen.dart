import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:flutter/material.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppConstants.wallet),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.totalBalance,
              style: TextStyle(
                fontSize: 16,
                color: ColorResources.secondaryColor,
              ),
            ),
            Helper.heightSizedBox(8),
            Text(
              '₹107.3',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: ColorResources.secondaryColor,
              ),
            ),
            Helper.heightSizedBox(8),
            // Text(
            //   AppConstants.viewTransaction,
            //   style: TextStyle(
            //     fontSize: 14,
            //     color: ColorResources.secondaryColor,
            //     decoration: TextDecoration.underline,
            //   ),
            // ),
            Helper.heightSizedBox(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      border: Border.all(color: ColorResources.secondaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      AppConstants.addCash,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: ColorResources.secondaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppConstants.withdraw,
                      style: TextStyle(
                          color: ColorResources.secondaryColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Helper.heightSizedBox(16),
            Text(
              AppConstants.viewTransaction,
              style: TextStyle(
                fontSize: 16,
                color: ColorResources.secondaryColor,
              ),
            ),
            Helper.heightSizedBox(8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: ColorResources.secondaryColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Date & Time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Feb 20,02:19 PM',
                        style: TextStyle(
                          color: ColorResources.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Helper.heightSizedBox(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Amounts collected from Player_Fantasy 25ZH124W43',
                          style: TextStyle(
                            color: ColorResources.secondaryColor,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  Helper.heightSizedBox(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹100',
                        style: TextStyle(
                          color: ColorResources.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Helper.heightSizedBox(8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Net Balance',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹100',
                        style: TextStyle(
                          color: ColorResources.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Helper.heightSizedBox(8),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
