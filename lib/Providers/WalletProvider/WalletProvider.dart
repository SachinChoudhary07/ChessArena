import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class WalletProvider extends ChangeNotifier {
  final Razorpay _razorpay = Razorpay();
  double _balance = 0.0;

  double get balance => _balance;

  double? _enteredAmount;

  double? get enteredAmount => _enteredAmount;

  set enteredAmount(double? value) {
    _enteredAmount = value;
    notifyListeners();
  }

  WalletProvider() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    fetchUserBalance();
  }

  void fetchUserBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _balance = (userDoc.data()?['Balance'] ?? 0).toDouble();
      notifyListeners();
    }
  }

  void openCheckout(String amount, BuildContext context) {
    var options = {
      'key': 'rzp_test_5ncJUexf5K9Yeq',
      'amount': int.parse(amount) * 100,
      'name': 'Chess 4 Cash',
      'description': 'Add Cash to Wallet',
      'prefill': {
        'contact': '9876543210',
        'email': 'user@example.com',
      },
      'method': {
        'card': true,
        'netbanking': true,
        'upi': true,
        'wallet': true,
      },
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .add({
        'amount': _enteredAmount,
        'type': 'deposit',
        'timestamp': Timestamp.now(),
        'status': 'success',
      });

      fetchUserBalance();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Optional: log error or notify UI if needed
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Optional: log or handle external wallet
  }

  void requestWithdrawal(
      double amount, String UpiID, BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await userRef.get();
    double currentBalance = (snapshot.data()?['Balance'] ?? 0).toDouble();

    if (currentBalance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      Navigator.pop(context);
      return;
    }

    await userRef.collection('transactions').add({
      'amount': amount,
      'type': 'withdrawal',
      'UPI': UpiID,
      'timestamp': Timestamp.now(),
      'status': 'pending',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Withdrawal request submitted')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}
