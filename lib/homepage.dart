import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'model.dart';
import 'add_appointment.dart';
import 'profile_page.dart';
import 'custom_bottom_nav.dart';
import 'search_page.dart';
import 'edit_appointment.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  AppUser? _currentUser;
  List<Appointment> _appointments = [];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _todaySectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure the "Today" section is visible on initial load if it exists
      if (_todaySectionKey.currentContext != null) {
        Scrollable.ensureVisible(
          _todaySectionKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          alignment: 0.0,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Fetches the current user's data from Firestore
  Future<void> _fetchCurrentUser() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final doc = await FirebaseFirestore.instance.collection('AppUser').doc(userId).get();
      setState(() {
        _currentUser = AppUser.fromFirestore(doc);
      });
      // After fetching the user, fetch their appointments
      _fetchAppointments();
    }
  }

  // Fetches appointments for the current user from Firestore
  Future<void> _fetchAppointments() async {
    // Ensure _currentUser is not null before attempting to fetch appointments
    if (_currentUser == null) {
      print("Current user is null, cannot fetch appointments.");
      return;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('Appointment')
        .where('userId', isEqualTo: _currentUser!.userId)
        .get();

    final data = snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList();
    setState(() => _appointments = data);
  }

  // Handles navigation bar taps
  void _onNavTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      // Navigate to AddAppointmentPage
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddAppointmentPage()));
    } else if (index == 2) {
      // Navigate to ProfilePage
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    }
  }

  // Builds a section for a specific date, displaying appointments for that date
  Widget _buildDateSection(DateTime date, List<Appointment> appts, {bool isToday = false, Key? key}) {
    // Sort appointments: completed ones first, then by time
    appts.sort((a, b) {
      if (a.status == 'Completed' && b.status != 'Completed') return -1;
      if (a.status != 'Completed' && b.status == 'Completed') return 1;
      return a.time.compareTo(b.time);
    });

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Display date, with special formatting for "Today"
        Text(
          isToday
              ? 'Today, ${DateFormat('d MMMM y (EEEE)').format(date)}'
              : DateFormat('d MMMM y (EEEE)').format(date),
          style: TextStyle(
            fontSize: isToday ? 26 : 18,
            fontWeight: FontWeight.bold,
            color: isToday ? Colors.black : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        // Show "Make Appointment" button if no appointments for today
        if (appts.isEmpty && isToday)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Make Appointment'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddAppointmentPage()),
              ),
            ),
          ),
        // List of appointments for the current date section
        ...appts.map((appt) => Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.grey),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Navigate to EditAppointmentPage and refresh appointments on return
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditAppointmentPage(appointment: appt),
                ),
              ).then((_) => _fetchAppointments());
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${appt.title} (${appt.category})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    DateFormat('y-MM-dd h:mm a').format(appt.date),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                trailing: Checkbox(
                  value: appt.status == 'Completed',
                  shape: const CircleBorder(),
                  onChanged: (val) {
                    setState(() => appt.status = val! ? 'Completed' : 'Pending');
                    // Update appointment status in Firestore
                    FirebaseFirestore.instance
                        .collection('Appointment')
                        .doc(appt.appointmentId)
                        .update({'status': appt.status});
                  },
                ),
              ),
            ),
          ),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Normalize today's date to midnight for comparison
    final todayKey = DateTime(today.year, today.month, today.day);

    final grouped = <DateTime, List<Appointment>>{};
    for (final appt in _appointments) {
      // Normalize appointment date to midnight for comparison
      final apptDateKey = DateTime(appt.date.year, appt.date.month, appt.date.day);

      if (!apptDateKey.isBefore(todayKey)) {
        // For today and future dates, include all appointments
        grouped[apptDateKey] = (grouped[apptDateKey] ?? [])..add(appt);
      } else if (appt.status == 'Pending') {
        // For past dates, only include pending appointments
        grouped[apptDateKey] = (grouped[apptDateKey] ?? [])..add(appt);
      }
    }

    // Create a set of all unique dates, including today's date
    final allUniqueDates = <DateTime>{};
    allUniqueDates.addAll(grouped.keys);
    allUniqueDates.add(todayKey); // Ensure today's date is always included

    // Sort all unique dates in ascending order
    final sortedKeys = allUniqueDates.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, ${_currentUser?.username ?? ''} 👋',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Let's achieve something great today!", style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Navigate to SearchPage, passing the list of appointments
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SearchPage(appointments: _appointments)),
              );
            },
          ),
        ],
      ),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator if user data is not yet fetched
          : SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedKeys.map((key) {
            final isToday = key == todayKey;
            // Get appointments for the current key, or an empty list if no appointments for that key
            final apptsForDate = grouped[key] ?? [];
            return _buildDateSection(
              key,
              apptsForDate,
              isToday: isToday,
              key: isToday ? _todaySectionKey : null, // Assign key for today's section
            );
          }).toList(),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
      ),
    );
  }
}
