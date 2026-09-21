import 'dart:io';

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

  bool isLoading = false;
  bool isLoggedIn = false;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    setLoading(true);
    try {
      if (currentUser != null) {
        final doc =
            await _firestore.collection('users').doc(currentUser!.uid).get();
        if (doc.exists) {
          profileImageUrl = doc['profileImage'];
          name = doc['username'];
          email = doc['email'];
        }
      }
    } catch (e) {
      print("Fetch profile error: $e");
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  Future<void> updateUserDetails({String? newName}) async {
    try {
      setLoading(true);
      Map<String, dynamic> updates = {};

      if (newName != null && newName.trim().isNotEmpty) {
        updates['username'] = newName;
        name = newName;
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
    try {
      if (await Permission.photos.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final ImagePicker picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);

        if (pickedFile != null) {
          String imageUrl = await uploadImage(pickedFile);
          await _firestore.collection('users').doc(currentUser!.uid).update({
            'profileImage': imageUrl,
          });
          profileImageUrl = imageUrl;
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error updating profile image: $e");
    }
  }

  Future<String> uploadImage(XFile file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final fileRef =
          FirebaseStorage.instance.ref().child('profile_images/$fileName');
      await fileRef.putFile(File(file.path));
      return await fileRef.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      throw Exception('Failed to upload image');
    }
  }

  Future<void> logout(BuildContext context) async {
    setLoading(true);
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _setLoginState(false);
    pushAndRemoveUntil(context, const LoginPage(), false);
    setLoading(false);
  }

  Future<void> _setLoginState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', value);
    isLoggedIn = value;
    notifyListeners();
  }

  Future<void> deleteAccount(BuildContext context) async {
    try {
      await logout(context);
      await _firestore.collection('users').doc(currentUser!.uid).delete();
      await currentUser!.delete();
    } catch (e) {
      print("Delete account error: $e");
      CustomToast.show("Failed to delete account", bgColor: Colors.red);
    }
  }
}
