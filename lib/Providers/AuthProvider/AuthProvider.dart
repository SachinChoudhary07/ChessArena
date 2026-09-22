import 'dart:io';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:chess_cash/services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chess_cash/Services/presence_service.dart';

class AutProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  bool isLoading = false;
  bool isLoggedIn = false;

  // Save or refresh the device's FCM token in Firestore for this user
  Future<void> _updateFCMToken(String uid) async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({AppConstants.fcmTokenField: token});
      }
    } catch (e) {
      // Non-fatal – just log it
      print('Error updating FCM token: $e');
    }
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  String? _verificationId;

  Future<void> sendOtp(
    String phoneNumber,
    BuildContext context,
    VoidCallback onOtpSent,
  ) async {
    setLoading(true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: "+91$phoneNumber",
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setLoading(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? "Verification failed"),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setLoading(false);
          _verificationId = verificationId;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("OTP Sent"),
              backgroundColor: Colors.green,
            ),
          );

          // ✅ Navigate here
          onOtpSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send OTP"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> verifyOtpAndRegister({
    required String smsCode,
    required String username,
    required String email,
    required String number,
    required String password,
    required BuildContext context,
    required String imagePath,
    required String skillLevel,
  }) async {
    print('printing smsCode:- $smsCode');
    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No OTP was sent"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setLoading(true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Sign in with the phone number (This verifies the user with phone)
      await _auth.signInWithCredential(credential);

      // Now that the phone is verified, proceed with email and password registration
      await signUp(
          username, email, number, password, context, imagePath, skillLevel);
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      print("error");
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid OTP"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setLoginState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
    isLoggedIn = value;
    notifyListeners();
  }

  Future<void> signUp(
    String username,
    String email,
    String number,
    String password,
    BuildContext context,
    String imagePath, // Can be asset or file path
    String skillLevel,
  ) async {
    setLoading(true);
    try {
      // Step 1: Create Firebase Auth User
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;
      String imageUrl = "";
      // 🔑 Grab FCM token for this brand-new account
      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      // Step 2: Upload profile image
      if (imagePath.isNotEmpty) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("profileImages")
            .child("$uid.jpg");

        if (imagePath.startsWith("assets/")) {
          // 📦 It's an asset image
          try {
            final byteData = await rootBundle.load(imagePath);
            final uploadTask = ref.putData(
              byteData.buffer.asUint8List(),
              SettableMetadata(contentType: 'image/jpeg'),
            );
            await uploadTask;
            imageUrl = await ref.getDownloadURL();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to load asset image."),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // 📁 It's a file image
          final file = File(imagePath);
          print('Image Path: $imagePath');
          print('File exists: ${file.existsSync()}');

          if (!file.existsSync()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Image file not found at the given path"),
                backgroundColor: Colors.red,
              ),
            );
            setLoading(false);
            return;
          }

          await ref.putFile(file);
          imageUrl = await ref.getDownloadURL();
        }
      }

      // Step 3: Save user data in Firestore
      await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
        AppConstants.uidField: uid,
        AppConstants.emailField: email,
        AppConstants.usernameField: username,
        'phoneNumber': "+91$number",
        'skillLevel': skillLevel,
        AppConstants.profileImageField: imageUrl,
        AppConstants.createdAtField: Timestamp.now(),
        AppConstants.deviceInfoField: "Unknown",
        AppConstants.fcmTokenField: fcmToken ?? "",
        AppConstants.eloRatingField: 1200,
        AppConstants.gamesPlayedField: 0,
        AppConstants.gamesWonField: 0,
        AppConstants.gamesLostField: 0,
        AppConstants.gamesDrawnField: 0,
        AppConstants.rankingField: 0,
        AppConstants.balanceField: 0.0,
        AppConstants.isBannedField: false,
        AppConstants.isVerifiedField: true,
        AppConstants.banReasonField: "",
        AppConstants.suspiciousFlagField: false,
      });

      await _setLoginState(true);
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppConstants.registrationSuccess),
          backgroundColor: Colors.green,
        ),
      );
      push(context, const LoginPage());
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _handleAuthError(e, context);
    } catch (e) {
      setLoading(false);
      print('Unexpected error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppConstants.unexpectedError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String verificationId = '';

  void resendOtp(String phoneNumber, BuildContext context) {
    FirebaseAuth auth = FirebaseAuth.instance;
    try {
      // Show loading UI
      isLoading = true;
      notifyListeners();

      auth.verifyPhoneNumber(
        phoneNumber: "+91$phoneNumber",
        timeout: const Duration(seconds: 60),

        // Auto verify (e.g., for Android sometimes auto SMS detection)
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Optionally sign in directly if auto-complete works
          await auth.signInWithCredential(credential);
          isLoading = false;
          notifyListeners();
        },

        // Triggered if Firebase can't send the OTP
        verificationFailed: (FirebaseAuthException e) {
          isLoading = false;
          notifyListeners();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("OTP sending failed: ${e.message}")),
          );
        },

        // When OTP is successfully sent
        codeSent: (String newVerificationId, int? resendToken) {
          isLoading = false;
          verificationId = newVerificationId; // Store this in your provider
          notifyListeners();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OTP sent again")),
          );
        },

        // Triggered when auto-retrieval timeout expires
        codeAutoRetrievalTimeout: (String newVerificationId) {
          verificationId = newVerificationId;
          notifyListeners();
        },
      );
    } catch (e) {
      isLoading = false;
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Something went wrong: $e")),
      );
    }
  }

  Future<void> login(
      String email, String password, BuildContext context) async {
    setLoading(true);

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Check ban status after successful authentication
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isBanned = userData[AppConstants.isBannedField] ?? false;
          final banReason = userData[AppConstants.banReasonField] ?? '';

          if (isBanned) {
            // User is banned, logout and show ban dialog
            await _auth.signOut();
            setLoading(false);
            _showBanDialog(context, banReason);
            return;
          }
          // 👍 User is allowed – make sure their token is stored
          await _updateFCMToken(user.uid);
        }
      }

      await _setLoginState(true);
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppConstants.loginSuccess),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => BottomNavBar(key: bottomNavBarKey)),
        (route) => false, // This removes all previous routes from the stack
      );
      // Start presence tracking after successful login navigation
      await PresenceService.instance.start();
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _handleAuthError(e, context);
      print("object#@11111111111111111${e.toString()}");
    } catch (e) {
      print("object#@${e.toString()}");
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppConstants.unexpectedError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setLoading(false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      User? user = userCredential.user;
      if (user != null) {
        final String? fcmToken = await FirebaseMessaging.instance.getToken();
        DocumentSnapshot userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .set({
            AppConstants.uidField: user.uid,
            AppConstants.emailField: user.email,
            AppConstants.usernameField: user.displayName ?? "",
            AppConstants.profileImageField: user.photoURL ?? "",
            AppConstants.createdAtField: Timestamp.now(),
            AppConstants.deviceInfoField: "Unknown",
            AppConstants.fcmTokenField: fcmToken ?? "",
            AppConstants.eloRatingField: 400,
            AppConstants.gamesPlayedField: 0,
            AppConstants.gamesWonField: 0,
            AppConstants.gamesLostField: 0,
            AppConstants.gamesDrawnField: 0,
            AppConstants.rankingField: 0,
            AppConstants.balanceField: 0.0,
            AppConstants.isBannedField: false,
            AppConstants.isVerifiedField: true,
            AppConstants.banReasonField: "",
            AppConstants.suspiciousFlagField: false,
          });
        } else {
          // Check ban status for existing user
          final userData = userDoc.data() as Map<String, dynamic>;
          final isBanned = userData[AppConstants.isBannedField] ?? false;
          final banReason = userData[AppConstants.banReasonField] ?? '';

          if (isBanned) {
            // User is banned, logout and show ban dialog
            await _auth.signOut();
            await _googleSignIn.signOut();
            setLoading(false);
            _showBanDialog(context, banReason);
            return;
          }
          // Existing, non-banned user – refresh their token
          await _updateFCMToken(user.uid);
        }
      }
      await _setLoginState(true);
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppConstants.loginSuccess),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) => BottomNavBar(key: bottomNavBarKey)),
        (route) => false, // This removes all previous routes from the stack
      );
      notifyListeners();
    } catch (e) {
      setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
      print("Catchhhhhhhhhhh ${e.toString()}");
    }
  }

  Future<void> logout(BuildContext context) async {
    setLoading(true);
    // Ensure presence is marked offline
    await PresenceService.instance.stop();
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _setLoginState(false);
    setLoading(false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppConstants.logoutSuccess),
        backgroundColor: Colors.green,
      ),
    );
    notifyListeners();
  }

  void _handleAuthError(FirebaseAuthException e, BuildContext context) {
    String message;
    print("Firebase Auth Error Code: ${e.code}");
    print("Firebase Auth Error Message: ${e.message}");

    switch (e.code) {
      case 'email-already-in-use':
        message = AppConstants.emailAlreadyInUse;
        break;
      case 'invalid-email':
        message = AppConstants.invalidEmail;
        break;
      case 'weak-password':
        message = AppConstants.weakPassword;
        break;
      case 'user-not-found':
        message = AppConstants.userNotFound;
        break;
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-password':
        message = AppConstants.wrongPassword;
        break;
      case 'too-many-requests':
        message = 'Too many failed attempts. Please try again later.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'operation-not-allowed':
        message = 'This operation is not allowed.';
        break;
      default:
        message = AppConstants.authFailed;
    }
    print("Selected message: $message");
    print("AppConstants.wrongPassword: ${AppConstants.wrongPassword}");
    print("AppConstants.authFailed: ${AppConstants.authFailed}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to send password reset email.';
    } catch (e) {
      return 'Failed to send password reset email.';
    }
  }

  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return 'No user is currently signed in.';
      }
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to change password.';
    } catch (e) {
      return 'Failed to change password.';
    }
  }

  void _showBanDialog(BuildContext context, String banReason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Account Banned', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account has been suspended by the administrator.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'If you believe this is an error, please contact our support team.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showContactAdminDialog(context);
            },
            child: const Text('Contact Admin'),
          ),
        ],
      ),
    );
  }

  void _showContactAdminDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Admin'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('To appeal your ban, please contact us:'),
            SizedBox(height: 12),
            Text('📧 Email: support@chessarena.app'),
            Text('📱 WhatsApp: +91 9876543210'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Method to check ban status periodically (can be called from dashboard)
  Future<bool> checkBanStatus() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData[AppConstants.isBannedField] ?? false;
      }
    } catch (e) {
      print('Error checking ban status: $e');
    }
    return false;
  }
}
