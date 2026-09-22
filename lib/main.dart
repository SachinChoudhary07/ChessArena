import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/app_theme.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Providers/CreateTournamentProvider/CreateTournamentProvider.dart';
import 'package:chess_cash/Providers/LeaderBoardProvider/LeaderBoardProvider.dart';
import 'package:chess_cash/Providers/ProfileProvider/ProfileProvider.dart';
import 'package:chess_cash/Screens/PlayWithOnlineFriends/play_with_online_friend_provider.dart';
import 'package:chess_cash/Services/notification_service.dart';
import 'package:chess_cash/Services/challenge_service.dart';
import 'package:chess_cash/Services/challenge_expiration_service.dart';
import 'package:chess_cash/Screens/GameScreens/waitingRoom.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'Providers/gameProvider/GameProvider.dart';

// Add navigator key for global dialog handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  await FirebaseMessaging.instance
      .requestPermission(alert: true, badge: true, sound: true);

  // Obtain and print FCM token
  String? token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: ${token ?? ''}');

  // Listen for messages when the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService().showNotification(message);
    _handleIncomingMessage(message); // <-- show dialog if needed
  });

  // Listen when the app is brought to foreground/opened via a notification tap
  FirebaseMessaging.onMessageOpenedApp.listen(_handleIncomingMessage);

  runApp(
    MultiProvider(
      providers: providers(),
      child: const MyApp(),
    ),
  );

  // Handle the case when the app is launched by tapping the notification while
  // it was completely terminated.
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    // Delay until a frame is rendered so navigatorKey has a valid context
    Future.delayed(Duration.zero, () => _handleIncomingMessage(initialMessage));
  }

  // Start the challenge expiration timer
  ChallengeExpirationService.startExpirationTimer();
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().init();
  // Show a local notification ONLY for data-only messages. If the message already
  // contains a notification payload, the system has displayed it for us, so
  // calling showNotification would create a duplicate.
  if (message.notification == null) {
    await NotificationService().showNotification(message);
  }
  // We still want to surface the accept/reject dialog once the app is opened.
  // (This will be triggered from onMessageOpenedApp or getInitialMessage.)
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // allow showing dialogs from anywhere
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}

List<SingleChildWidget> providers() {
  return [
    ChangeNotifierProvider(create: (context) => AutProvider()),
    ChangeNotifierProvider(create: (context) => ProfileProvider()),
    ChangeNotifierProvider(create: (context) => LeaderBoardProvider()),
    ChangeNotifierProvider(create: (context) => CreateTournamentProvider()),
    ChangeNotifierProvider(create: (context) => ChessGameProvider()),
    ChangeNotifierProvider(create: (context) => PlayWithOnlineFriendProvider()),
  ];
}

// debug token app check
//A3225464-5115-407C-A9AB-9238773D13A9

// ----------------------------------------------------------------------------
// Helper to process inbound FCM messages and trigger UI if they represent
// a chess challenge.
// ----------------------------------------------------------------------------
void _handleIncomingMessage(RemoteMessage message) async {
  final data = message.data;

  // Extract body/title for simple string matching (case-insensitive)
  final body = (message.notification?.body ?? '').toLowerCase();
  final title = (message.notification?.title ?? '').toLowerCase();

  // Determine if this is a chess challenge.
  final bool isChallengeType = data['type'] == 'challenge';
  final bool containsChallengePhrase = body.contains('challange you') ||
      body.contains('challenged you') ||
      title.contains('challange you') ||
      title.contains('challenged you');

  if (isChallengeType || containsChallengePhrase) {
    // Extract challenge ID from data
    final challengeId = data['challengeId'];
    if (challengeId != null) {
      await _showChallengeDialogWithId(message, challengeId);
    } else {
      // Fallback for old notifications without challenge ID
      _showChallengeDialog(message);
    }
  }
}

void _showChallengeDialog(RemoteMessage message) {
  final BuildContext? ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  // Extract useful information to display
  final challengerUid = message.data['challengerUid'] ?? '';
  final title = message.notification?.title ?? 'New Chess Challenge!';
  final body = message.notification?.body ?? 'A player challenged you.';

  _showChallengeDialogWithValidation(ctx, title, body, challengerUid, null);
}

Future<void> _showChallengeDialogWithId(
    RemoteMessage message, String challengeId) async {
  final BuildContext? ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  // Validate the challenge first
  final validation = await ChallengeService.validateChallenge(challengeId);

  if (!validation.isValid) {
    // Show expired/error dialog
    _showExpiredChallengeDialog(ctx, validation.message, validation.challenge);
    return;
  }

  // Extract useful information to display
  final challengerUid = message.data['challengerUid'] ?? '';
  final title = message.notification?.title ?? 'New Chess Challenge!';
  final body = message.notification?.body ?? 'A player challenged you.';

  _showChallengeDialogWithValidation(
      ctx, title, body, challengerUid, challengeId);
}

void _showChallengeDialogWithValidation(BuildContext ctx, String title,
    String body, String challengerUid, String? challengeId) {
  showDialog(
    context: ctx,
    barrierDismissible: false, // Non-dismissable
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ColorResources.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ColorResources.divider),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        color: ColorResources.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Body
                    Text(
                      body,
                      style: const TextStyle(
                          color: ColorResources.textSecondary, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Reject
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: ColorResources.divider),
                            foregroundColor: ColorResources.textPrimary,
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            if (challengeId != null) {
                              await ChallengeService.rejectChallenge(
                                  challengeId);
                            }
                            Navigator.of(context).pop();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Text('Reject'),
                          ),
                        ),
                        // Accept
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorResources.primary,
                            foregroundColor: ColorResources.onPrimary,
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            if (challengeId != null) {
                              final result =
                                  await ChallengeService.acceptChallenge(
                                      challengeId);
                              if (result.success && result.roomCode != null) {
                                // Navigate to waiting room
                                Navigator.of(context).pop();
                                push(
                                    context,
                                    EnhancedWaitingRoom(
                                        roomCode: result.roomCode!));
                              } else {
                                // Show error message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                                Navigator.of(context).pop();
                              }
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showExpiredChallengeDialog(
    BuildContext ctx, String message, Challenge? challenge) {
  showDialog(
    context: ctx,
    barrierDismissible: true,
    barrierColor: Colors.black87.withOpacity(0.7),
    builder: (context) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ColorResources.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ColorResources.error),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  const Icon(
                    Icons.timer_off,
                    color: ColorResources.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  // Title
                  const Text(
                    'Challenge Expired',
                    style: TextStyle(
                      color: ColorResources.error,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Message
                  Text(
                    message,
                    style: const TextStyle(
                        color: ColorResources.textSecondary, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // OK Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorResources.error,
                        foregroundColor: ColorResources.textPrimary,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('OK'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
