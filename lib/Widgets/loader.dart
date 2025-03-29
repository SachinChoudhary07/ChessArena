import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/lottie/Loader_animation.json', // Path to your Lottie animation
        width: 150,
        height: 150,
        fit: BoxFit.contain,
      ),
    );
  }
}
