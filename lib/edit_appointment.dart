import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'model.dart'; // Ensure your model.dart includes the 'status' and 'amount' fields.

class EditAppointmentPage extends StatefulWidget {
  final Appointment appointment;

  const EditAppointmentPage({super.key, required this.appointment});

  @override
  State<EditAppointmentPage> createState() => _EditAppointmentPageState();
}

class _EditAppointmentPageState extends State<EditAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController; // New controller for amount
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _selectedCategory;
  late String _currentStatus;
  bool _isSaving = false;
  bool _isDeleting = false;

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

  @override
  void initState() {
    super.initState();
    final appt = widget.appointment;
    _titleController = TextEditingController(text: appt.title);
    _descriptionController = TextEditingController(text: appt.description ?? '');
    // Initialize amount controller, format double to string
    _amountController = TextEditingController(
        text: appt.amount != null ? appt.amount!.toStringAsFixed(2) : '');
    _selectedDate = appt.date;
    _selectedTime = TimeOfDay.fromDateTime(appt.date);
    _selectedCategory = appt.category;
    _currentStatus = appt.status;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade400, // Softer primary blue
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade600, // Slightly darker for contrast
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade400, // Softer primary blue
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade600, // Slightly darker for contrast
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _updateAppointment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updatedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final Map<String, dynamic> updateData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'date': Timestamp.fromDate(updatedDateTime),
      'status': _currentStatus,
    };

    if (_selectedCategory == 'Sales - Closing') {
      double? parsedAmount = double.tryParse(_amountController.text.trim());
      updateData['amount'] = parsedAmount;
    } else {
      updateData['amount'] = FieldValue.delete();
    }

    try {
      await FirebaseFirestore.instance
          .collection('Appointment')
          .doc(widget.appointment.appointmentId)
          .update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Appointment updated successfully!',
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

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Update failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAppointment() async {
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to delete this appointment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmDelete) return;

    setState(() => _isDeleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('Appointment')
          .doc(widget.appointment.appointmentId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Appointment deleted successfully!'),
        backgroundColor: Colors.red,
      ));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deletion failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _toggleStatus() {
    setState(() {
      _currentStatus = _currentStatus == 'Completed' ? 'Pending' : 'Completed';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Theme(
      data: ThemeData(
          primarySwatch: Colors.blue,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue.shade500,
            foregroundColor: Colors.white,
            elevation: 1,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            // Even lighter and more transparent fill color
            fillColor: Colors.blue.shade50.withOpacity(0.5), // Increased transparency
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            // Softer enabled border
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade50, width: 1), // Even lighter border
            ),
            // Softer focused border
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade200, width: 2), // Softer focused border
            ),
            labelStyle: TextStyle(color: Colors.blue.shade600),
            hintStyle: TextStyle(color: Colors.blue.shade300),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade500,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade600,
            ),
          ),
          listTileTheme: ListTileThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            tileColor: Colors.blue.shade50.withOpacity(0.7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            titleTextStyle: TextStyle(fontSize: 16, color: Colors.blue.shade700),
            subtitleTextStyle: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            textStyle: const TextStyle(color: Colors.black87),
          )
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Appointment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Category dropdown - NOW FIRST
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: Colors.blue.shade50.withOpacity(0.9),
                  items: _categories
                      .map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(
                      cat,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      // Clear amount if category changes away from Sales - Closing
                      if (val != 'Sales - Closing') {
                        _amountController.clear();
                      }
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: 'Select a category',
                    suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600),
                  ),
                  validator: (value) => value == null ? 'Please select a category' : null,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // Title field - NOW SECOND
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name(Mr,Mrs)',
                    hintText: 'Enter Customer Name(Mr,Mrs)',
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter Customer Name(Mr,Mrs)' : null,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // Description field - NOW THIRD
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Add details about the appointment',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // Conditional Amount field - NOW FOURTH (if category is 'Sales - Closing')
                if (_selectedCategory == 'Sales - Closing') ...[
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter closing amount (e.g., 1000.00)',
                      prefixText: '\$',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid positive number';
                      }
                      return null;
                    },
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                ],

                // Date picker
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(formattedDate),
                  trailing: Icon(Icons.calendar_today, color: Colors.blue.shade600),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 15),

                // Time picker
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text(formattedTime),
                  trailing: Icon(Icons.access_time, color: Colors.blue.shade600),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 25),

                // Status Toggle
                ListTile(
                  title: const Text('Status'),
                  subtitle: Text(
                    _currentStatus,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Switch(
                    value: _currentStatus == 'Completed',
                    onChanged: (newValue) => _toggleStatus(),
                    activeColor: Colors.green.shade600,
                    inactiveThumbColor: Colors.orange.shade600,
                    inactiveTrackColor: Colors.orange.shade200,
                  ),
                  onTap: _toggleStatus,
                ),
                const SizedBox(height: 30),

                // Update & Save button
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Update & Save'),
                  onPressed: _isSaving ? null : _updateAppointment,
                ),
                const SizedBox(height: 15),

                // Delete button
                OutlinedButton.icon(
                  icon: _isDeleting
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.red.shade600,
                      strokeWidth: 3,
                    ),
                  )
                      : const Icon(Icons.delete_forever, color: Colors.red),
                  label: Text(
                    _isDeleting ? 'Deleting...' : 'Delete Appointment',
                    style: TextStyle(fontSize: 18, color: Colors.red.shade600),
                  ),
                  onPressed: _isDeleting ? null : _deleteAppointment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300, width: 2),
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}