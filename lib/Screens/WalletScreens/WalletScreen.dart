import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Razorpay _razorpay = Razorpay();
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    // _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchUserBalance();
  }

  void _fetchUserBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      setState(() {
        _balance = (userDoc.data()?['Balance'] ?? 0).toDouble();
      });
    }
  }

  void _openCheckout(String amount) {
    var options = {
      'key': 'rzp_test_5ncJUexf5K9Yeq',
      //Key Secret ---- Fmu8TPq2Hc3TOKs083ZWVBup
      'amount': int.parse(amount) * 100,
      'name': 'Chess 4 Cash',
      'description': 'Add Cash to Wallet',
      'prefill': {
        'contact': '9876543210',
        'email': 'user@example.com',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        double currentBalance = (snapshot.data()?['Balance'] ?? 0).toDouble();

        double newBalance = currentBalance + (_enteredAmount ?? 0);

        transaction.update(docRef, {'Balance': newBalance});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful!')),
      );

      _fetchUserBalance(); // Refresh balance
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Failed')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet Selected')),
    );
  }

  double? _enteredAmount;

  void _showAddCashBottomSheet() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter Amount'),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 100',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    _enteredAmount = double.tryParse(controller.text);
                    if (_enteredAmount != null && _enteredAmount! > 0) {
                      Navigator.pop(context);
                      _openCheckout(controller.text);
                    }
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

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
              '₹$_balance',
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
                  onTap: () => _showAddCashBottomSheet(),
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
