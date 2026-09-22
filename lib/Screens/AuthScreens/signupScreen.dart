import 'dart:io';

import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/legal_urls.dart';
import 'package:chess_cash/Providers/AuthProvider/AuthProvider.dart';
import 'package:chess_cash/Screens/AuthScreens/loginScreen.dart';
import 'package:chess_cash/Screens/AuthScreens/otpScreen.dart';
import 'package:chess_cash/Services/navigation.dart';
import 'package:chess_cash/Widgets/customTextField.dart';
import 'package:chess_cash/Widgets/customToast.dart';
import 'package:chess_cash/Widgets/premium_widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final ImagePicker _picker = ImagePicker();

  String _selectedSkillLevel = 'Beginner';
  XFile? _selectedImage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneNumberController.dispose();
    usernameController.dispose();
    isAgeConfirmed.dispose();
    isPrivacyConfirmed.dispose();
    _isPasswordVisible.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
  }

  void _register(AutProvider authProvider) {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();
    final phone = phoneNumberController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty) {
      CustomToast.show('All fields are required', bgColor: Colors.red);
      return;
    }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      CustomToast.show('Enter a valid email', bgColor: Colors.red);
      return;
    }
    if (password.length < 6) {
      CustomToast.show('Password must be at least 6 characters',
          bgColor: Colors.red);
      return;
    }
    if (!isAgeConfirmed.value) {
      CustomToast.show('You must confirm your age', bgColor: Colors.red);
      return;
    }
    if (!isPrivacyConfirmed.value) {
      CustomToast.show('You must accept privacy policy', bgColor: Colors.red);
      return;
    }

    authProvider.sendOtp(phone, context, () {
      push(
        context,
        Otpscreen(
          imagePath: _selectedImage?.path ?? 'assets/images/pawn_image.jpg',
          email: email,
          number: phone,
          password: password,
          username: username,
          skillLevel: _selectedSkillLevel,
        ),
      );
    });
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorResources.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _RegisterBackdrop(),
          SafeArea(
            child: Consumer<AutProvider>(
              builder: (context, authProvider, _) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: ColorResources.textPrimary,
                          ),
                          const Expanded(
                            child: Text(
                              'Create account',
                              style: TextStyle(
                                color: ColorResources.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: ColorResources.primary,
                                            width: 2,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(3),
                                        child: CircleAvatar(
                                          backgroundColor:
                                              ColorResources.elevatedSurface,
                                          backgroundImage: _selectedImage !=
                                                  null
                                              ? FileImage(
                                                  File(_selectedImage!.path))
                                              : const AssetImage(
                                                      'assets/images/pawn_image.jpg')
                                                  as ImageProvider,
                                        ),
                                      ),
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: ColorResources.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: ColorResources.background,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: ColorResources.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Add a profile photo',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ColorResources.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 18, 16, 16),
                                decoration: BoxDecoration(
                                  color: ColorResources.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: ColorResources.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Your details',
                                      style: TextStyle(
                                        color: ColorResources.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Join ChessArena and start climbing your Elo',
                                      style: TextStyle(
                                        color: ColorResources.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    CustomTextField(
                                      controller: usernameController,
                                      label: AppConstants.userName,
                                    ),
                                    const SizedBox(height: 12),
                                    CustomTextField(
                                      controller: emailController,
                                      label: AppConstants.email,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 12),
                                    CustomTextField(
                                      controller: phoneNumberController,
                                      label: 'Phone number',
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 12),
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
                                                  : Icons
                                                      .visibility_off_rounded,
                                              color: ColorResources
                                                  .textSecondary,
                                            ),
                                            onPressed: () {
                                              _isPasswordVisible.value =
                                                  !isVisible;
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Skill level',
                                      style: TextStyle(
                                        color: ColorResources.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final level in const [
                                          'Beginner',
                                          'Intermediate',
                                          'Expert'
                                        ])
                                          ChoiceChip(
                                            label: Text(level),
                                            selected:
                                                _selectedSkillLevel == level,
                                            onSelected: (_) {
                                              setState(() =>
                                                  _selectedSkillLevel = level);
                                            },
                                            showCheckmark: false,
                                            selectedColor:
                                                ColorResources.primary,
                                            labelStyle: TextStyle(
                                              color: _selectedSkillLevel ==
                                                      level
                                                  ? ColorResources.onPrimary
                                                  : ColorResources
                                                      .textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            backgroundColor: ColorResources
                                                .elevatedSurface,
                                            side: BorderSide(
                                              color: _selectedSkillLevel ==
                                                      level
                                                  ? ColorResources.primary
                                                  : ColorResources.divider,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 6, 12, 6),
                                decoration: BoxDecoration(
                                  color: ColorResources.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: ColorResources.divider),
                                ),
                                child: Column(
                                  children: [
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isAgeConfirmed,
                                      builder: (context, value, _) {
                                        return CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          dense: true,
                                          title: const Text(
                                            AppConstants.ageConfirmation,
                                            style: TextStyle(
                                              color:
                                                  ColorResources.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                          value: value,
                                          activeColor: ColorResources.primary,
                                          checkColor:
                                              ColorResources.onPrimary,
                                          onChanged: (v) => isAgeConfirmed
                                              .value = v ?? false,
                                        );
                                      },
                                    ),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isPrivacyConfirmed,
                                      builder: (context, value, _) {
                                        return CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          dense: true,
                                          title: RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                color: ColorResources
                                                    .textPrimary,
                                                fontSize: 14,
                                              ),
                                              children: [
                                                const TextSpan(
                                                    text: 'I agree to the '),
                                                TextSpan(
                                                  text: 'Privacy Policy',
                                                  style: const TextStyle(
                                                    color: ColorResources
                                                        .accentSoft,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                  recognizer:
                                                      TapGestureRecognizer()
                                                        ..onTap = () =>
                                                            _openUrl(LegalUrls
                                                                .privacyPolicy),
                                                ),
                                                const TextSpan(
                                                    text:
                                                        ' and Terms of ChessArena.'),
                                              ],
                                            ),
                                          ),
                                          value: value,
                                          activeColor: ColorResources.primary,
                                          checkColor:
                                              ColorResources.onPrimary,
                                          onChanged: (v) =>
                                              isPrivacyConfirmed.value =
                                                  v ?? false,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              authProvider.isLoading
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      child: LoadingWidget(),
                                    )
                                  : ChessPrimaryButton(
                                      label: 'Create account',
                                      icon: Icons.person_add_alt_1_rounded,
                                      onPressed: () =>
                                          _register(authProvider),
                                    ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account?',
                                    style: TextStyle(
                                      color: ColorResources.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      push(context, const LoginPage());
                                    },
                                    child: const Text(
                                      'Sign in',
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterBackdrop extends StatelessWidget {
  const _RegisterBackdrop();

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
          ColorResources.primary.withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.12),
          radius: size.width * 0.65,
        ),
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
