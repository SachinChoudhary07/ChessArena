import 'dart:async';

import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

class Otpscreen extends StatefulWidget {
  final String email;
  final String number;
  final String password;
  final String username;
  final String imagePath;
  final String skillLevel;

  const Otpscreen(
      {super.key,
      required this.email,
      required this.number,
      required this.password,
      required this.username,
      required this.imagePath,
      required this.skillLevel});

  @override
  State<Otpscreen> createState() => _OtpscreenState();
}

class _OtpscreenState extends State<Otpscreen> {
  final TextEditingController _otpController = TextEditingController();
  int _resendCooldown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    startResendTimer();
  }

  void startResendTimer() {
    _resendCooldown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AutProvider>(context);

    return Scaffold(
      appBar: const PremiumAppBar(title: "Verify OTP"),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter the OTP sent to your number",
              style: TextStyle(color: ColorResources.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Pinput(
              length: 6,
              controller: _otpController,
              keyboardType: TextInputType.number,
              defaultPinTheme: PinTheme(
                width: 48,
                height: 56,
                textStyle: const TextStyle(
                    fontSize: 20, color: ColorResources.textPrimary),
                decoration: BoxDecoration(
                  color: ColorResources.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorResources.divider),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: authProvider.isLoading
                  ? null
                  : () {
                      authProvider.verifyOtpAndRegister(
                          context: context,
                          smsCode: _otpController.text,
                          email: widget.email,
                          imagePath: widget.imagePath,
                          number: widget.number,
                          password: widget.password,
                          username: widget.username,
                          skillLevel: widget.skillLevel);
                    },
              child: authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Verify"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resendCooldown == 0
                  ? () {
                      authProvider.resendOtp(widget.number,
                          context); // You'll need to implement this in your provider
                      startResendTimer(); // Restart timer
                    }
                  : null,
              child: Text(_resendCooldown == 0
                  ? "Resend OTP"
                  : "Resend in $_resendCooldown sec"),
            ),
          ],
        ),
      ),
    );
  }
}
