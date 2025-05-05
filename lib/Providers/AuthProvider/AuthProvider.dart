import 'dart:io';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:chess_cash/Widgets/customToast.dart';
import 'package:chess_cash/services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  bool isLoading = false;
  bool isLoggedIn = false;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  String? _verificationId;

  Future<void> sendOtp(String phoneNumber, BuildContext context) async {
    setLoading(true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-complete case
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setLoading(false);
          CustomToast.show(e.message ?? "Verification failed",
              bgColor: Colors.red);
        },
        codeSent: (String verificationId, int? resendToken) {
          setLoading(false);
          _verificationId = verificationId;
          CustomToast.show("OTP Sent", bgColor: Colors.green);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setLoading(false);
      CustomToast.show("Failed to send OTP", bgColor: Colors.red);
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
    if (_verificationId == null) {
      CustomToast.show("No OTP was sent", bgColor: Colors.red);
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
      CustomToast.show("Invalid OTP", bgColor: Colors.red);
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
      String imagePath, // Local image file path
      String skillLevel) async {
    setLoading(true);
    try {
      // Step 1: Create Firebase Auth User
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Step 2: Upload image to Firebase Storage
      String uid = userCredential.user!.uid;
      String imageUrl = "";
      if (imagePath.isNotEmpty) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("profileImages")
            .child("$uid.jpg");
        await ref.putFile(File(imagePath));
        imageUrl = await ref.getDownloadURL();
      }

      // Step 3: Save user data in Firestore
      await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
        AppConstants.uidField: uid,
        AppConstants.emailField: email,
        AppConstants.usernameField: username,
        'phoneNumber': number,
        'skillLevel': skillLevel,
        AppConstants.profileImageField: imageUrl,
        AppConstants.createdAtField: Timestamp.now(),
        AppConstants.deviceInfoField: "Unknown",
        AppConstants.fcmTokenField: "",
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

      await _setLoginState(true);
      setLoading(false);
      CustomToast.show(AppConstants.registrationSuccess, bgColor: Colors.green);
      push(context, LoginPage());
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      print("object");
      _handleAuthError(e);
    } catch (e) {
      setLoading(false);
      print('eeeeeeeeeeeee----------${e.toString()}');
      CustomToast.show(AppConstants.unexpectedError, bgColor: Colors.red);
    }
  }

  String verificationId = '';

  void resendOtp(String phoneNumber, BuildContext context) {
    FirebaseAuth _auth = FirebaseAuth.instance;

    try {
      // Show loading UI
      isLoading = true;
      notifyListeners();

      _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        // Auto verify (e.g., for Android sometimes auto SMS detection)
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Optionally sign in directly if auto-complete works
          // await _auth.signInWithCredential(credential);
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
      await _setLoginState(true);
      setLoading(false);
      CustomToast.show(AppConstants.loginSuccess, bgColor: Colors.green);
      push(context, BottomNavBar());
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _handleAuthError(e);
    } catch (e) {
      setLoading(false);
      CustomToast.show(AppConstants.unexpectedError, bgColor: Colors.red);
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
            AppConstants.fcmTokenField: "",
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
        }
      }
      await _setLoginState(true);
      setLoading(false);
      CustomToast.show(AppConstants.loginSuccess, bgColor: Colors.green);
      push(context, BottomNavBar());
      notifyListeners();
    } catch (e) {
      setLoading(false);
      CustomToast.show(e.toString(), bgColor: Colors.red);
      print("Catchhhhhhhhhhh ${e.toString()}");
    }
  }

  Future<void> logout() async {
    setLoading(true);
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _setLoginState(false);
    setLoading(false);
    CustomToast.show(AppConstants.logoutSuccess, bgColor: Colors.green);
    notifyListeners();
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message;
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
        message = AppConstants.wrongPassword;
        break;
      default:
        message = AppConstants.authFailed;
    }
    CustomToast.show(message, bgColor: Colors.red);
  }
}
