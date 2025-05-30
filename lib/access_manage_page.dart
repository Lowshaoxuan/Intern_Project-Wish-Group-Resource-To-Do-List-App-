import 'package:flutter/material.dart';

class AccessManagePage extends StatelessWidget {
  const AccessManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Management'),
      ),
      body: const Center(
        child: Text(
          'Access management tools coming soon...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
