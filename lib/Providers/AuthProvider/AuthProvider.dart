import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:chess_cash/Widgets/customToast.dart';
import 'package:chess_cash/services/navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
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

  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    notifyListeners();
  }

  Future<void> _setLoginState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
    isLoggedIn = value;
    notifyListeners();
  }

  Future<void> signUp(String username, String email, String password,
      BuildContext context) async {
    setLoading(true);
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userCredential.user!.uid)
          .set({
        AppConstants.uidField: userCredential.user!.uid,
        AppConstants.emailField: email,
        AppConstants.usernameField: username,
        AppConstants.createdAtField: Timestamp.now(),
      });
      await _setLoginState(true);
      setLoading(false);
      CustomToast.show(AppConstants.registrationSuccess, bgColor: Colors.green);
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _handleAuthError(e);
    } catch (e) {
      setLoading(false);
      CustomToast.show(AppConstants.unexpectedError, bgColor: Colors.red);
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
            AppConstants.createdAtField: Timestamp.now(),
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
