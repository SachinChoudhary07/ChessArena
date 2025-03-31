import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/signupScreen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/customTextField.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Center(child: Loader());
        }
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text(AppConstants.login),
            backgroundColor: Colors.black,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Image.asset(
                    AppConstants.loginSignupImage,
                    color: Colors.white,
                    height: 140,
                  ),
                  Helper.heightSizedBox(20),
                  CustomTextField(
                      controller: emailController, label: AppConstants.email),
                  Helper.heightSizedBox(10),
                  CustomTextField(
                      controller: passwordController,
                      label: AppConstants.password,
                      obscureText: true),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      authProvider.login(
                        emailController.text,
                        passwordController.text,
                        context,
                      );
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text(AppConstants.login,
                        style: TextStyle(color: Colors.black)),
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
                  TextButton(
                    onPressed: () {
                      push(context, RegisterPage());
                    },
                    child: const Text(AppConstants.dontHaveAccount,
                        style: TextStyle(color: Colors.amber)),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
