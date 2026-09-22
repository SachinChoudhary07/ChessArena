import 'package:flutter/material.dart';

/// Payments were removed. Stubs keep unused WalletScreen compiling.
class WalletProvider extends ChangeNotifier {
  double get balance => 0;
  bool isLoading = false;
  double? enteredAmount;

  void fetchUserBalance() {}

  void openCheckout(String amount, BuildContext context) {}

  void requestWithdrawal(double amount, String upiId, BuildContext context) {}
}
