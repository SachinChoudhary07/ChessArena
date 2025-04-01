import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Widgets/customToast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';


class ProfileProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  String? profileImageUrl;
  String? name;
  String? email;

  Future<void> fetchUserProfile() async {
    if (currentUser != null) {
      final doc =
      await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        profileImageUrl = doc['profileImageUrl'];
        name = doc['name'];
        email = doc['email'];
        notifyListeners();
      }
    }
  }

  Future<void> updateProfileImage() async {
    if (await Permission.photos
        .request()
        .isGranted ||
        await Permission.storage
            .request()
            .isGranted) {
      final ImagePicker picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Logic to upload image to Firebase Storage and update Firestore
        // Assume uploadImage returns the URL of the uploaded image
        String imageUrl = await uploadImage(pickedFile);
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'profileImageUrl': imageUrl,
        });
        profileImageUrl = imageUrl;
        notifyListeners();
      }
    }
  }

  Future<String> uploadImage(XFile file) async {
    // Implement Firebase Storage upload logic here
    // Return the URL of the uploaded image
    return 'uploaded_image_url';
  }

  bool isLoading = false;
  bool isLoggedIn = false;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  Future<void> _setLoginState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
    isLoggedIn = value;
    notifyListeners();
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
}
