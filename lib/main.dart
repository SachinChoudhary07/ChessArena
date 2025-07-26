import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Providers/CreateTournamentProvider/CreateTournamentProvider.dart';
import 'package:chess_cash/Providers/LeaderBoardProvider/LeaderBoardProvider.dart';
import 'package:chess_cash/Providers/ProfileProvider/ProfileProvider.dart';
import 'package:chess_cash/Providers/WalletProvider/WalletProvider.dart';
import 'package:chess_cash/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'Providers/gameProvider/GameProvider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chess_cash/Services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'AIzaSyCWiSHMmORX9SBCusBQjL2bOkszlYt3IlE',
          appId: '1:1023134763353:android:8b822128cf38dd947de448',
          messagingSenderId: '1023134763353',
          projectId: 'chess4cash-37f67',
          storageBucket: "chess4cash-37f67.firebasestorage.app"));
  // await FirebaseAppCheck.instance
  //     .activate(androidProvider: AndroidProvider.debug
  //         // Or use: AndroidProvider.debug for development
  //         );

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notification service
  await NotificationService().init();

  // Request notification permissions
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

  // Obtain and print FCM token
  String? token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: ${token ?? ''}');

  // Listen for messages when the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().showNotification(message);
  });

  runApp(
    MultiProvider(
      providers: providers(),
      child: const MyApp(),
    ),
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().init();
  await NotificationService().showNotification(message);
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
    ChangeNotifierProvider(create: (context) => AutProvider()),
    ChangeNotifierProvider(create: (context) => ProfileProvider()),
    ChangeNotifierProvider(create: (context) => LeaderBoardProvider()),
    ChangeNotifierProvider(create: (context) => WalletProvider()),
    ChangeNotifierProvider(create: (context) => CreateTournamentProvider()),
    ChangeNotifierProvider(create: (context) => ChessGameProvider()),
  ];
}

// debug token app check
//A3225464-5115-407C-A9AB-9238773D13A9
