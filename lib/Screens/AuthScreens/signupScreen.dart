import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/bottomNavBar.dart';
import 'package:chess_cash/Widgets/customTextField.dart';
import 'package:chess_cash/Widgets/customToast.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final ValueNotifier<bool> isAgeConfirmed = ValueNotifier<bool>(false);

  void _register(AuthProvider authProvider) {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
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
    authProvider.signUp(username, email, password, context);
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
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isLoading) {
                return const Center(child: Loader());
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    AppConstants.loginSignupImage,
                    color: Colors.white,
                    height: 140,
                  ),
                  Helper.heightSizedBox(20),
                  CustomTextField(
                      controller: usernameController,
                      label: AppConstants.userName),
                  Helper.heightSizedBox(10),
                  CustomTextField(
                      controller: emailController, label: AppConstants.email),
                  Helper.heightSizedBox(10),
                  CustomTextField(
                    controller: passwordController,
                    label: AppConstants.password,
                    obscureText: true,
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
                  Helper.heightSizedBox(20),
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
                  Helper.heightSizedBox(10),
                  ElevatedButton(
                    onPressed: () {
                      authProvider.signInWithGoogle(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorResources.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 40),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          AppConstants.googleImage,
                          height: 24,
                        ),
                        Helper.widthSizedBox(10),
                        const Text(
                          AppConstants.google,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Helper.heightSizedBox(40),
                  TextButton(
                    onPressed: () {
                      // push(context, const LoginPage());
                      push(context, BottomNavBar());
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
