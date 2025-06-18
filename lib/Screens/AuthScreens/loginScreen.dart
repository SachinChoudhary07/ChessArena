import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/forgotPasswordScreen.dart';
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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<AutProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          // appBar: AppBar(
          //   automaticallyImplyLeading: false,
          //   title: const Text(AppConstants.login),
          //   backgroundColor: Colors.black,
          // ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Helper.heightSizedBox(40),
                    Image.asset(
                      AppConstants.splashIcon,
                      // color: Colors.white,
                      height: 250,
                      width: 200,
                    ),
                    // Helper.heightSizedBox(10),

                    /// Email Field
                    CustomTextField(
                      controller: emailController,
                      label: AppConstants.email,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        final emailRegex =
                            RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),

                    Helper.heightSizedBox(20),

                    /// Password Field
                    CustomTextField(
                      controller: passwordController,
                      label: AppConstants.password,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    Helper.heightSizedBox(20),
                    Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ));
                          },
                          child: const Text(
                            "Forgot Password",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        )),
                    Helper.heightSizedBox(20),

                    authProvider.isLoading
                        ? const Padding(
                            padding: EdgeInsets.only(top: 20, bottom: 20),
                            child: Loader(),
                          )
                        : Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    authProvider.login(
                                      emailController.text,
                                      passwordController.text,
                                      context,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: ContinuousRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40),
                                  backgroundColor:
                                      ColorResources.secondaryColor,
                                ),
                                child: const Text(
                                  AppConstants.login,
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                              Helper.heightSizedBox(10),
                              // ElevatedButton(
                              //   onPressed: () {
                              //     authProvider.signInWithGoogle(context);
                              //   },
                              //   style: ElevatedButton.styleFrom(
                              //     backgroundColor: ColorResources.primaryColor,
                              //     padding: const EdgeInsets.symmetric(
                              //       vertical: 10,
                              //       horizontal: 40,
                              //     ),
                              //   ),
                              //   child: Row(
                              //     mainAxisSize: MainAxisSize.min,
                              //     children: [
                              //       Image.asset(
                              //         AppConstants.googleImage,
                              //         height: 24,
                              //       ),
                              //       Helper.widthSizedBox(10),
                              //       const Text(
                              //         AppConstants.google,
                              //         style: TextStyle(
                              //             color: Colors.white, fontSize: 16),
                              //       ),
                              //     ],
                              //   ),
                              // ),
                            ],
                          ),

                    TextButton(
                      onPressed: () {
                        push(context, const RegisterPage());
                      },
                      child: const Text(
                        AppConstants.dontHaveAccount,
                        style: TextStyle(color: Colors.amber),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
