import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../homepage.dart'; // Make sure this path is correct

class CreateUsernamePage extends StatefulWidget {
  const CreateUsernamePage({Key? key}) : super(key: key); // Add key

  @override
  State<CreateUsernamePage> createState() => _CreateUsernamePageState();
}

class _CreateUsernamePageState extends State<CreateUsernamePage> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _isSaving = false; // Track saving state

  Future<void> _saveUsername() async {
    String username = _controller.text.trim();
    if (username.isEmpty) {
      setState(() {
        _error = "Please enter a username";
      });
      return;
    }

    setState(() {
      _isSaving = true; // Show loading indicator
      _error = null;       // Clear any previous error
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('AppUser').doc(user.uid).set({
          'username': username,
          'email': user.email,
        }, SetOptions(merge: true));

        // Navigate *after* successful save
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      } catch (e) {
        // Handle errors from Firestore
        if (mounted) {
          setState(() {
            _isSaving = false; // Stop loading on error
            _error = "Failed to save username: $e";
          });
          ScaffoldMessenger.of(context).showSnackBar( // Show error to user
            SnackBar(
              content: Text('Error saving username: $e'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = "No user found.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Complete Your Profile",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Choose a username to personalize your experience.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: "Username",
                    hintText: "Enter a unique username",
                    errorText: _error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    enabled: !_isSaving, // Disable input while saving
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveUsername, // Disable button
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                        : const Text("Save & Continue"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

