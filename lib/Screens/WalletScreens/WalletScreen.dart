import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Providers/WalletProvider/WalletProvider.dart';
import '../../Widgets/loader.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController controller = TextEditingController();

  final TextEditingController withdrawalController = TextEditingController();

  final TextEditingController withdrawalupiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WalletProvider>(context, listen: false).fetchUserBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppConstants.wallet),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return Padding(
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
                  '₹${walletProvider.balance}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: ColorResources.secondaryColor,
                  ),
                ),
                Helper.heightSizedBox(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      context,
                      label: AppConstants.addCash,
                      color: Colors.transparent,
                      textColor: ColorResources.secondaryColor,
                      onTap: () =>
                          _showAddCashBottomSheet(context, walletProvider),
                    ),
                    _buildActionButton(
                      context,
                      label: AppConstants.withdraw,
                      color: Colors.transparent,
                      textColor: ColorResources.secondaryColor,
                      onTap: () => _showWithdrawalCashBottomSheet(
                          context, walletProvider),
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
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .collection('transactions')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          walletProvider.isLoading) {
                        return const Center(child: Loader());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text("No transactions found."));
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final amount = doc['amount'];
                          final type = doc['type'];
                          final status = doc['status'];
                          final timestamp =
                              (doc['timestamp'] as Timestamp?)?.toDate();

                          return _buildTransactionItem(
                              amount, type, status, timestamp);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required String label,
      required Color color,
      Color textColor = Colors.white,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: ColorResources.secondaryColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      double amount, String type, String status, DateTime? timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorResources.secondaryColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildTransactionDetail('Date & Time', _formatDate(timestamp)),
          Helper.heightSizedBox(8),
          _buildTransactionDetail(
              'Description', type == 'deposit' ? 'Deposited' : 'Withdrawal'),
          Helper.heightSizedBox(8),
          _buildTransactionDetail('Transaction Amount', '₹ $amount'),
          Helper.heightSizedBox(8),
          _buildTransactionDetail('Status', status),
          Helper.heightSizedBox(8),
        ],
      ),
    );
  }

  Widget _buildTransactionDetail(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(color: ColorResources.secondaryColor),
        ),
      ],
    );
  }

  void _showAddCashBottomSheet(
      BuildContext context, WalletProvider walletProvider) {
    final focusNode = FocusNode();

    showModalBottomSheet(
      constraints: BoxConstraints.tight(
          Size.fromHeight(MediaQuery.of(context).size.height / 1.4)),
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
              const SizedBox(height: 16),
              const Text(
                'Quick Select',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                runSpacing: 5,
                children: [
                  _buildAmountChip('50'),
                  _buildAmountChip('100'),
                  _buildAmountChip('200'),
                  _buildAmountChip('500'),
                  _buildAmountChip('1000'),
                  _buildAmountChip('2000'),
                  _buildAmountChip('5000'),
                ],
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

  Widget _buildAmountChip(String amount) {
    return ActionChip(
      label: Text('₹$amount'),
      onPressed: () {
        controller.text = amount;
      },
      backgroundColor: ColorResources.secondaryColor.withOpacity(0.1),
      labelStyle: TextStyle(
        color: ColorResources.secondaryColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

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
                  hintText: '100',
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
                  hintText: 'abc@paytm',
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

  String _formatDate(DateTime? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
  }
}
