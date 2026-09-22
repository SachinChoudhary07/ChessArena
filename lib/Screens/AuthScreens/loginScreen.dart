import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/forgotPasswordScreen.dart';
import 'package:chess_cash/Screens/AuthScreens/signupScreen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/customTextField.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
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
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _isPasswordVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AutProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          backgroundColor: ColorResources.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const _LoginBackdrop(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ColorResources.primary
                                          .withOpacity(0.22),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.asset(
                                    'assets/Icons/app_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              AppConstants.appName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ColorResources.textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              AppConstants.appMotto,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ColorResources.accentSoft,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                              decoration: BoxDecoration(
                                color: ColorResources.surface,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: ColorResources.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Welcome back',
                                    style: TextStyle(
                                      color: ColorResources.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Sign in to continue your rated games',
                                    style: TextStyle(
                                      color: ColorResources.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  CustomTextField(
                                    controller: emailController,
                                    label: AppConstants.email,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Email is required';
                                      }
                                      final emailRegex = RegExp(
                                          r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                                      if (!emailRegex.hasMatch(value)) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _isPasswordVisible,
                                    builder: (context, isVisible, _) {
                                      return CustomTextField(
                                        controller: passwordController,
                                        label: AppConstants.password,
                                        obscureText: !isVisible,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            isVisible
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                            color: ColorResources.textSecondary,
                                          ),
                                          onPressed: () {
                                            _isPasswordVisible.value =
                                                !isVisible;
                                          },
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Password is required';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      );
                                    },
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen(),
                                          ),
                                        );
                                      },
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  authProvider.isLoading
                                      ? const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: LoadingWidget(),
                                        )
                                      : ChessPrimaryButton(
                                          label: 'Sign in',
                                          icon: Icons.login_rounded,
                                          onPressed: () {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              authProvider.login(
                                                emailController.text.trim(),
                                                passwordController.text,
                                                context,
                                              );
                                            }
                                          },
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: ColorResources.textSecondary
                                          .withOpacity(0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () => authProvider.signInWithGoogle(context),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                side: const BorderSide(
                                    color: ColorResources.divider),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    AppConstants.googleImage,
                                    height: 20,
                                    width: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      color: ColorResources.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    color: ColorResources.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    push(context, const RegisterPage());
                                  },
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(
                                      color: ColorResources.accentSoft,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1F2A22),
            ColorResources.background,
            Color(0xFF14161A),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _GlowPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          ColorResources.primary.withOpacity(0.14),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.18),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
