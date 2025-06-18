import 'dart:io';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Screens/AuthScreens/otpScreen.dart';
import 'package:chess_cash/Screens/Others/PrivacyPolicyPage.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/customTextField.dart';
import 'package:chess_cash/Widgets/customToast.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final ValueNotifier<bool> isAgeConfirmed = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPrivacyConfirmed = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);

  // Skill level variable
  String? _selectedSkillLevel = 'Beginner'; // Default value

  void _register(AutProvider authProvider) {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _selectedSkillLevel == null) {
      CustomToast.show("All fields are required", bgColor: Colors.red);
      return;
    }
    if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+$").hasMatch(email)) {
      CustomToast.show("Enter a valid email", bgColor: Colors.red);
      return;
    }

    if (password.length < 6) {
      CustomToast.show("Password must be at least 6 characters",
          bgColor: Colors.red);
      return;
    }
    if (!isAgeConfirmed.value) {
      CustomToast.show("You must confirm your age", bgColor: Colors.red);
      return;
    }
    if (!isPrivacyConfirmed.value) {
      CustomToast.show("You must accept privacy policy", bgColor: Colors.red);
      return;
    }

    authProvider.sendOtp(phoneNumberController.text, context, () {
      push(
        context,
        Otpscreen(
          imagePath: _selectedImage?.path ?? 'assets/images/pawn_image.jpg',
          email: email,
          number: phoneNumberController.text,
          password: password,
          username: username,
          skillLevel: _selectedSkillLevel!,
        ),
      );
    });
  }

  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppConstants.register),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Consumer<AutProvider>(
            builder: (context, authProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Helper.heightSizedBox(10),
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _selectedImage != null
                          ? FileImage(File(_selectedImage!.path))
                          : const AssetImage('assets/images/pawn_image.jpg') as ImageProvider,
                      backgroundColor: Colors.grey.shade800,
                      child: _selectedImage == null
                          ? const Icon(Icons.camera_alt,
                              color: Colors.white, size: 30)
                          : null,
                    ),
                  ),
                  Helper.heightSizedBox(30),
                  CustomTextField(
                      controller: usernameController,
                      label: AppConstants.userName),
                  Helper.heightSizedBox(10),
                  CustomTextField(
                      controller: emailController, label: AppConstants.email),
                  Helper.heightSizedBox(10),
                  CustomTextField(
                      controller: phoneNumberController, label: 'PhoneNumber'),
                  Helper.heightSizedBox(10),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPasswordVisible,
                    builder: (context, isVisible, child) {
                      return CustomTextField(
                        controller: passwordController,
                        label: AppConstants.password,
                        obscureText: !isVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            isVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _isPasswordVisible.value =
                                !_isPasswordVisible.value;
                          },
                        ),
                      );
                    },
                  ),
                  Helper.heightSizedBox(10),

                  // Skill Level Dropdown
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Text(
                        "Skill - level",
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          // Border color
                          borderRadius:
                              BorderRadius.circular(8.0), // Rounded corners
                        ),
                        child: DropdownButton<String>(
                          value: _selectedSkillLevel,
                          icon: const Icon(Icons.arrow_downward,
                              color: Colors.white),
                          style: const TextStyle(color: Colors.white),
                          dropdownColor: Colors.grey[800],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedSkillLevel = newValue;
                            });
                          },
                          items: <String>['Beginner', 'Intermediate', 'Expert']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          underline: const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                  Helper.heightSizedBox(10),
                  ValueListenableBuilder<bool>(
                    valueListenable: isAgeConfirmed,
                    builder: (context, value, child) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          AppConstants.ageConfirmation,
                          style: TextStyle(color: Colors.white),
                        ),
                        value: value,
                        activeColor: ColorResources.secondaryColor,
                        onChanged: (bool? newValue) {
                          isAgeConfirmed.value = newValue ?? false;
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: isPrivacyConfirmed,
                    builder: (context, value, child) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: "I agree to the ",
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: "Privacy Policy",
                                style: TextStyle(
                                  color: ColorResources.secondaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              PrivacyPolicyPage()),
                                    );
                                  },
                              ),
                              const TextSpan(
                                text: " and ",
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: "Terms & Conditions",
                                style: TextStyle(
                                  color: ColorResources.secondaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              PrivacyPolicyPage()),
                                    );
                                  },
                              ),
                              const TextSpan(
                                text: " of Chees4Cash.",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        value: value,
                        activeColor: ColorResources.secondaryColor,
                        onChanged: (bool? newValue) {
                          isPrivacyConfirmed.value = newValue ?? false;
                        },
                      );
                    },
                  ),
                  Helper.heightSizedBox(20),
                  authProvider.isLoading
                      ? const Loader()
                      : Column(
                          children: [
                            ElevatedButton(
                              onPressed: () => _register(authProvider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorResources.secondaryColor,
                                disabledBackgroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 60),
                              ),
                              child: const Text(
                                AppConstants.register,
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                  Helper.heightSizedBox(10),
                  TextButton(
                    onPressed: () {
                      push(context, const LoginPage());
                    },
                    child: Text(
                      AppConstants.alreadyAccount,
                      style: TextStyle(color: ColorResources.secondaryColor),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
