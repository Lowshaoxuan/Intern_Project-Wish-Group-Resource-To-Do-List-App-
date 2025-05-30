// Imports
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'add_appointment.dart';
import 'custom_bottom_nav.dart';
import 'homepage.dart';
import 'dashboard_page.dart';
import 'access_manage_page.dart';
import 'setting_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 2;
  final currentUser = FirebaseAuth.instance.currentUser!;
  late TextEditingController _usernameController;
  bool _isEditingUsername = false;
  String? _avatarUrl;
  String _email = '';
  String _username = '';
  bool _isUploading = false;
  List<Map<String, dynamic>> subordinates = [];
  Map<String, dynamic>? managedBy;
  int totalTasks = 0;
  int completedTasks = 0;
  double totalSales = 0.0;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _loadUserInfo();
    _loadAppointmentsStats();
    _loadAccessManagement();
  }

  DateTime _getStartOfWeek(DateTime date) {
    int diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: diff));
  }

  DateTime _getEndOfWeek(DateTime date) {
    int diff = DateTime.sunday - date.weekday;
    return DateTime(date.year, date.month, date.day).add(Duration(days: diff));
  }

  Future<void> _loadUserInfo() async {
    final userDoc = await FirebaseFirestore.instance.collection('AppUser').doc(currentUser.uid).get();
    final data = userDoc.data();
    if (data != null) {
      setState(() {
        _username = data['username'] ?? '';
        _email = data['email'] ?? currentUser.email!;
        _avatarUrl = data['avatarUrl'];
        _usernameController.text = _username;
      });
    }
  }

  Future<void> _loadAppointmentsStats() async {
    final now = DateTime.now();
    final startOfWeek = _getStartOfWeek(now);
    final endOfWeek = _getEndOfWeek(now);

    final snapshot = await FirebaseFirestore.instance
        .collection('Appointment')
        .where('userId', isEqualTo: currentUser.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
        .get();

    int completed = 0;
    double sales = 0.0;
    int total = snapshot.docs.length;

    for (var doc in snapshot.docs) {
      final status = (doc['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'completed') {
        completed++;
        final data = doc.data();
        if (data.containsKey('amount') && data['amount'] != null) {
          sales += (data['amount'] as num).toDouble();
        }
      }
    }

    setState(() {
      totalTasks = total;
      completedTasks = completed;
      totalSales = sales;
    });
  }

  Future<void> _loadAccessManagement() async {
    final userDoc = await FirebaseFirestore.instance.collection('AppUser').doc(currentUser.uid).get();
    final userData = userDoc.data();
    List<String> subordinateIds = List<String>.from(userData?['subordinate'] ?? []);

    if (subordinateIds.isNotEmpty) {
      final subordinateUsers = await FirebaseFirestore.instance
          .collection('AppUser')
          .where(FieldPath.documentId, whereIn: subordinateIds)
          .get();

      setState(() {
        subordinates = subordinateUsers.docs.map((doc) => doc.data()).toList();
      });
    } else {
      setState(() {
        subordinates = [];
      });
    }

    final managedByQuery = await FirebaseFirestore.instance
        .collection('AppUser')
        .where('subordinate', arrayContains: currentUser.uid)
        .get();

    setState(() {
      managedBy = managedByQuery.docs.isNotEmpty ? managedByQuery.docs.first.data() : null;
    });
  }

  void _onNavTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddAppointmentPage()));
    }
  }

  void _saveUsername() async {
    await FirebaseFirestore.instance.collection('AppUser').doc(currentUser.uid).update({
      'username': _usernameController.text,
    });
    setState(() {
      _username = _usernameController.text;
      _isEditingUsername = false;
    });
    _showSuccessSnackBar("Updated successfully");
  }

  void _cancelEditUsername() {
    setState(() {
      _usernameController.text = _username;
      _isEditingUsername = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 70,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: "Crop Image",
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: "Crop Image",
          aspectRatioLockEnabled: true,
        ),
      ],
    );


    if (cropped != null) {
      await _uploadImage(File(cropped.path));
    }
  }

  Future<void> _uploadImage(File file) async {
    setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance.ref().child('avatars/${currentUser.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('AppUser').doc(currentUser.uid).update({
        'avatarUrl': url,
      });

      setState(() {
        _avatarUrl = url;
      });

      _showSuccessSnackBar("Profile picture updated");
    } catch (e) {
      _showErrorSnackBar("Upload failed");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: Colors.black87,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double percent = totalTasks == 0 ? 0 : completedTasks / totalTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null ? const Icon(Icons.person, size: 40) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _isEditingUsername
                            ? Expanded(
                          child: TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(isDense: true),
                          ),
                        )
                            : Expanded(
                          child: Text(_username, style: const TextStyle(fontSize: 18)),
                        ),
                        if (_isEditingUsername) ...[
                          IconButton(icon: const Icon(Icons.check), onPressed: _saveUsername),
                          IconButton(icon: const Icon(Icons.close), onPressed: _cancelEditUsername),
                        ] else
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditingUsername = true)),
                      ],
                    ),
                    Text(_email),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          const Text("Dashboard (This Week)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Center(
            child: CircularPercentIndicator(
              radius: 80.0,
              lineWidth: 10.0,
              percent: percent,
              center: Text("${(percent * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              progressColor: Colors.blue,
              backgroundColor: Colors.grey.shade300,
              animation: true,
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text("$completedTasks of $totalTasks tasks completed")),
          const SizedBox(height: 8),
          Center(
              child: Text("Total Sales: RM ${totalSales.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage())),
              child: const Text("See details"),
            ),
          ),
          const Divider(),
          const SizedBox(height: 10),
          const Text("Access Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (subordinates.isNotEmpty) ...[
            const Text("Users you manage:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...subordinates.map(
                  (user) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
                  child: user['avatarUrl'] == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user['username'] ?? 'No name'),
                subtitle: Text(user['email'] ?? ''),
              ),
            ),
          ],
          if (managedBy != null) ...[
            const SizedBox(height: 10),
            const Text("Managed by:", style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: managedBy!['avatarUrl'] != null ? NetworkImage(managedBy!['avatarUrl']) : null,
                child: managedBy!['avatarUrl'] == null ? const Icon(Icons.person) : null,
              ),
              title: Text(managedBy!['username'] ?? 'No name'),
              subtitle: Text(managedBy!['email'] ?? ''),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessManagePage())),
              child: const Text("See details"),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
      ),
    );
  }
}
