import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();

  bool _showCurrentPwd = false;
  bool _showNewPwd = false;
  bool _showConfirmPwd = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      setState(() => _isLoading = false);
      _showError("User not authenticated.");
      return;
    }

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: _currentPwdController.text.trim(),
    );

    try {
      // Reauthenticate
      await user.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(_newPwdController.text.trim());

      setState(() => _isLoading = false);
      _showSuccessSnackBar("Password changed successfully.");
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showError(e.message ?? "Failed to change password.");
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("An error occurred.");
    }
  }

  void _showSuccessSnackBar(String message) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green[600],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showError(String message) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red[600],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Required";
    final password = value.trim();

    if (password.length < 8) return "Must be at least 8 characters";
    if (!RegExp(r'[A-Z]').hasMatch(password)) return "Include uppercase letter";
    if (!RegExp(r'[a-z]').hasMatch(password)) return "Include lowercase letter";
    if (!RegExp(r'[0-9]').hasMatch(password)) return "Include a number";
    if (!RegExp(r'[!@#\$&*~%^(),.?":{}|<>]').hasMatch(password)) {
      return "Include a symbol";
    }

    return null;
  }

  @override
  void dispose() {
    _currentPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Current Password
              TextFormField(
                controller: _currentPwdController,
                obscureText: !_showCurrentPwd,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showCurrentPwd ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _showCurrentPwd = !_showCurrentPwd),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              // New Password
              TextFormField(
                controller: _newPwdController,
                obscureText: !_showNewPwd,
                decoration: InputDecoration(
                  labelText: "New Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showNewPwd ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _showNewPwd = !_showNewPwd),
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),

              // Confirm New Password
              TextFormField(
                controller: _confirmPwdController,
                obscureText: !_showConfirmPwd,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirmPwd ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _showConfirmPwd = !_showConfirmPwd),
                  ),
                ),
                validator: (value) =>
                value != _newPwdController.text ? "Passwords do not match" : null,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Update Password"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
