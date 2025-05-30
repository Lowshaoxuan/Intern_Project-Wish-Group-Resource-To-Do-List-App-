import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'custom_bottom_nav.dart';
import 'homepage.dart';
import 'profile_page.dart';
import 'dart:async';

class AddAppointmentPage extends StatefulWidget {
  const AddAppointmentPage({super.key});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  // Controller for the new amount field
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = _roundToNextHalfHour(TimeOfDay.now());
  String? _selectedCategory;
  bool _isSaving = false;
  int _selectedIndex = 1;

  // Error message for the amount field
  String? _amountError;

  final List<String> _categories = [
    'Sales - Fact-finding',
    'Sales - Closing',
    'Sales - Presentation',
    'Recruitment - Approaches',
    'Recruitment - Exam Date',
    'Recruitment - Exam Passes',
    'Servicing',
    'Personal',
  ];

  // Helper function to round time to the next half hour
  static TimeOfDay _roundToNextHalfHour(TimeOfDay time) {
    final minute = time.minute;
    int newMinute = minute <= 30 ? 30 : 0;
    int newHour = time.hour + (minute > 30 ? 1 : 0);
    if (newHour >= 24) newHour = 0; // Handle midnight wrap-around
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose(); // Dispose the amount controller
    super.dispose();
  }

  // Handles navigation bar taps
  void _onNavTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      // Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 2) {
      // Navigate to ProfilePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  // Opens the date picker to allow selection of a date
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900), // Changed to allow selection of past dates from 1900
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Opens the time picker to allow selection of a time
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // Saves the new appointment to Firestore
  Future<void> _saveAppointment() async {
    // Reset amount error before validation
    setState(() {
      _amountError = null;
    });

    // Validate the form fields
    if (!_formKey.currentState!.validate()) {
      // If validation fails, check amount field specifically if category is Sales - Closing
      if (_selectedCategory == 'Sales - Closing') {
        if (_amountController.text.trim().isEmpty) {
          setState(() {
            _amountError = 'Amount is required for Sales - Closing';
          });
        } else if (double.tryParse(_amountController.text.trim()) == null) {
          setState(() {
            _amountError = 'Please enter a valid number for amount';
          });
        }
      }
      return;
    }

    setState(() => _isSaving = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Show snackbar if user is not logged in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      setState(() => _isSaving = false);
      return;
    }

    // Combine selected date and time into a single DateTime object
    final appointmentDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Prepare appointment data for Firestore
    Map<String, dynamic> appointment = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'date': Timestamp.fromDate(appointmentDateTime),
      'userId': currentUser.uid,
      'status': 'Pending', // Default status for new appointments
      'createdAt': Timestamp.now(), // Timestamp of creation
    };

    // Conditionally add the amount field if the category is 'Sales - Closing'
    if (_selectedCategory == 'Sales - Closing') {
      // Parse the amount to a double before saving
      appointment['amount'] = double.parse(_amountController.text.trim());
    }

    try {
      // Add the appointment to the 'Appointment' collection in Firestore
      await FirebaseFirestore.instance.collection('Appointment').add(appointment);

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Appointment added successfully!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          duration: Duration(seconds: 1),
        ),
      );

      // Clear form fields and reset state
      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      _amountController.clear(); // Clear amount field on success
      setState(() {
        _selectedCategory = null;
        _selectedDate = DateTime.now();
        _selectedTime = _roundToNextHalfHour(TimeOfDay.now());
        _amountError = null; // Clear amount error
      });

      // Redirect to HomePage after a short delay
      Timer(const Duration(seconds: 1), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      });
    } catch (e) {
      // Show error snackbar if saving fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      setState(() => _isSaving = false); // Reset saving state
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format selected date and time for display
    final formattedDate =
        "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";
    final formattedTime = _selectedTime.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "📅 Create New Appointment",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Let's Plan Something Great!",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Dropdown for selecting appointment category
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            items: _categories.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.category, color: Colors.blue),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                                // Clear amount and error if category changes from Sales - Closing
                                if (value != 'Sales - Closing') {
                                  _amountController.clear();
                                  _amountError = null;
                                }
                              });
                            },
                            validator: (value) => value == null ? 'Category is required' : null,
                          ),

                          const SizedBox(height: 16),
                          // Text field for customer name (title)
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Customer Name(Mr,Mrs)',
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.title, color: Colors.blue),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Title required' : null,
                          ),

                          const SizedBox(height: 16),
                          // Text field for description (optional)
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.description, color: Colors.blue),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                            maxLines: 3,
                          ),

                          // Conditionally display the Amount field if category is 'Sales - Closing'
                          if (_selectedCategory == 'Sales - Closing') ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number, // Ensure numeric keyboard
                              decoration: InputDecoration(
                                labelText: 'Amount (RM)',
                                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                                prefixIcon: const Icon(Icons.attach_money, color: Colors.blue),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                                ),
                                errorText: _amountError, // Display amount error
                              ),
                              validator: (value) {
                                if (_selectedCategory == 'Sales - Closing') {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Amount is required for Sales - Closing';
                                  }
                                  if (double.tryParse(value.trim()) == null) {
                                    return 'Please enter a valid number';
                                  }
                                }
                                return null; // No error if validation passes or category is not 'Sales - Closing'
                              },
                            ),
                          ],

                          const SizedBox(height: 16),
                          // Date and Time selection widgets
                          Column(
                            children: [
                              InkWell(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Text("Date: $formattedDate", style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),

                              InkWell(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Text("Time: $formattedTime", style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),

                            ],
                          ),
                          const SizedBox(height: 24),
                          // Save Appointment button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveAppointment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Icon(Icons.save, color: Colors.white),
                              label: const Text(
                                "Save Appointment",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
      ),
    );
  }
}
