import 'package:chess_cash/splash_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess4Cash',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFFD700),
        // Gold color
        scaffoldBackgroundColor: const Color(0xFF000000),
        // Black background
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFFD700)), // Primary Text
          bodyMedium: TextStyle(color: Color(0xFFFFC107)), // Secondary Text
          titleLarge:
              TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          titleTextStyle: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 20,
              fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Color(0xFFFFD700)),
        ),
        buttonTheme: const ButtonThemeData(
          buttonColor: Colors.black, // Black button background
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: const Color(0xFFFFD700),
            side: const BorderSide(color: Color(0xFFFFD700)), // Gold border
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)), // Gold icons
      ),
      home: const SplashScreen(),
    );
  }
}
