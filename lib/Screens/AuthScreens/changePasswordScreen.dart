import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/AuthProvider/AuthProvider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;
  final ValueNotifier<bool> _isCurrentVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isNewVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isConfirmVisible = ValueNotifier<bool>(false);

  void _submit() async {
    final current = _currentController.text.trim();
    final newPass = _newController.text.trim();
    final confirm = _confirmController.text.trim();
    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Your new password should be at least 6 characters long.')),
      );
      return;
    }
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('The new passwords you entered do not match.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AutProvider>(context, listen: false);
    final result = await authProvider.changePassword(current, newPass);
    setState(() => _isLoading = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been updated!')),
      );
      Navigator.of(context).pop();
    } else {
      // Custom error handling for common Firebase errors
      String errorMsg = result;
      if (result.contains('user is not signed in')) {
        errorMsg = 'Please log in again to change your password.';
      } else if (result.contains('password is invalid')) {
        errorMsg = 'Your current password is incorrect.';
      } else if (result.contains('network')) {
        errorMsg = 'Network error. Please check your connection.';
      } else {
        errorMsg = 'Oops! Something went wrong. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _isCurrentVisible,
              builder: (context, isVisible, child) {
                return TextField(
                  controller: _currentController,
                  obscureText: !isVisible,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        _isCurrentVisible.value = !_isCurrentVisible.value;
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: _isNewVisible,
              builder: (context, isVisible, child) {
                return TextField(
                  controller: _newController,
                  obscureText: !isVisible,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        _isNewVisible.value = !_isNewVisible.value;
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: _isConfirmVisible,
              builder: (context, isVisible, child) {
                return TextField(
                  controller: _confirmController,
                  obscureText: !isVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        _isConfirmVisible.value = !_isConfirmVisible.value;
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Change Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
