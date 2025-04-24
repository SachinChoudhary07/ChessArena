import 'dart:io';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/customToast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  String? profileImageUrl;
  String? name;
  String? email;

  Future<void> fetchUserProfile() async {
    setLoading(true);
    if (currentUser != null) {
      final doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        print(doc['username']);
        print("Nameeeeeeeeeeeeeeeee----------->doc['name']");
        profileImageUrl = doc['profileImage'];
        name = doc['username'];
        email = doc['email'];
        setLoading(false);
        notifyListeners();
      } else {
        setLoading(false);
        print("object-------->");
      }
    }
  }

  Future<void> updateUserDetails({String? newName, XFile? newImage}) async {
    try {
      setLoading(true);
      Map<String, dynamic> updates = {};

      if (newName != null && newName.trim().isNotEmpty) {
        updates['username'] = newName.trim();
        name = newName.trim();
      }

      if (newImage != null) {
        String imageUrl = await uploadImage(newImage);
        updates['profileImage'] = imageUrl;
        profileImageUrl = imageUrl;
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .update(updates);
        CustomToast.show("Profile updated successfully", bgColor: Colors.green);
      } else {
        CustomToast.show("Nothing to update", bgColor: Colors.orange);
      }

      notifyListeners();
    } catch (e) {
      print("Error updating profile: $e");
      CustomToast.show("Failed to update profile", bgColor: Colors.red);
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateProfileImage() async {
    if (await Permission.photos.request().isGranted ||
        await Permission.storage.request().isGranted) {
      final ImagePicker picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Logic to upload image to Firebase Storage and update Firestore
        // Assume uploadImage returns the URL of the uploaded image
        String imageUrl = await uploadImage(pickedFile);
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'profileImage': imageUrl,
        });
        profileImageUrl = imageUrl;
        notifyListeners();
      }
    }
  }

  Future<String> uploadImage(XFile file) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final fileRef = storageRef.child('profile_images/$fileName');

      final uploadTask = await fileRef.putFile(File(file.path));
      final downloadUrl = await fileRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading image: $e");
      throw Exception('Failed to upload image');
    }
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

  Future<void> logout(context) async {
    setLoading(true);
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _setLoginState(false);
    pushAndRemoveUntil(context, const LoginPage(), false);
    setLoading(false);
    CustomToast.show(AppConstants.logoutSuccess, bgColor: Colors.green);
    notifyListeners();
  }

  Future<void> deleteAccount(BuildContext context) async {
    try {
      setLoading(true);

      final user = _auth.currentUser;
      if (user != null) {
        // Step 1: Delete Firestore user document
        await _firestore.collection('users').doc(user.uid).delete();

        // Step 2: Delete Firebase Auth user
        await user.delete();

        // Step 3: Clear SharedPreferences login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('isLoggedIn');

        // Step 4: Sign out from Google if used
        await _googleSignIn.signOut();

        // Step 5: Navigate to login screen
        pushAndRemoveUntil(context, const LoginPage(), false);

        CustomToast.show("Account deleted successfully", bgColor: Colors.green);
      } else {
        CustomToast.show("User not found!", bgColor: Colors.red);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        CustomToast.show(
          "Please log in again to delete your account.",
          bgColor: Colors.orange,
        );
      } else {
        CustomToast.show("Error: ${e.message}", bgColor: Colors.red);
      }
    } catch (e) {
      CustomToast.show("Error deleting account: $e", bgColor: Colors.red);
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }
}
