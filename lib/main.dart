import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Providers/LeaderBoardProvider/LeaderBoardProvider.dart';
import 'package:chess_cash/Providers/ProfileProvider/ProfileProvider.dart';
import 'package:chess_cash/Providers/WalletProvider/WalletProvider.dart';
import 'package:chess_cash/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'AIzaSyCWiSHMmORX9SBCusBQjL2bOkszlYt3IlE',
          appId: '1:1023134763353:android:8b822128cf38dd947de448',
          messagingSenderId: '1023134763353',
          projectId: 'chess4cash-37f67',
          storageBucket: "chess4cash-37f67.firebasestorage.app"));
  runApp(
    MultiProvider(
      providers: providers(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: ColorResources.secondaryColor,
        // Gold color
        scaffoldBackgroundColor: const Color(0xFF000000),
        // Black background
        textTheme: TextTheme(
          bodyLarge:
              TextStyle(color: ColorResources.secondaryColor), // Primary Text
          // bodyMedium: TextStyle(color: Color(0xFFFFC107)), // Secondary Text
          titleLarge: TextStyle(
              color: ColorResources.secondaryColor,
              fontWeight: FontWeight.bold),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          titleTextStyle: TextStyle(
              color: ColorResources.secondaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: ColorResources.secondaryColor),
        ),
        buttonTheme: const ButtonThemeData(
          buttonColor: Colors.black, // Black button background
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: ColorResources.secondaryColor,
            side:
                BorderSide(color: ColorResources.secondaryColor), // Gold border
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        iconTheme:
            IconThemeData(color: ColorResources.secondaryColor), // Gold icons
      ),
      home: const SplashScreen(),
    );
  }
}

List<SingleChildWidget> providers() {
  return [
    ChangeNotifierProvider(create: (context) => AuthProvider()),
    ChangeNotifierProvider(create: (context) => ProfileProvider()),
    ChangeNotifierProvider(create: (context) => LeaderBoardProvider()),
    ChangeNotifierProvider(create: (context) => WalletProvider()),
  ];
}
