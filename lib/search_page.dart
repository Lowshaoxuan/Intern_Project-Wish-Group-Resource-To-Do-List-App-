import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'model.dart'; // Your Appointment model
import 'edit_appointment.dart'; // Appointment editing page

class SearchPage extends StatefulWidget {
  final List<Appointment> appointments;

  const SearchPage({super.key, required this.appointments});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _searchKeyword = '';
  Set<String> _selectedCategories = {};
  DateTimeRange? _searchDateRange;
  String? _searchStatus;

  final TextEditingController _categoryDisplayController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

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

  final List<String> _statuses = ['Pending', 'Completed'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchKeyword = _searchController.text;
      });
    });
    _updateCategoryDisplayController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryDisplayController.dispose();
    super.dispose();
  }

  void _updateCategoryDisplayController() {
    _categoryDisplayController.text = _selectedCategories.isEmpty
        ? ''
        : _selectedCategories.join(', ');
  }

  void _pickDateRangeOrDay() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Pick One Day'),
                onTap: () => Navigator.pop(context, 'single'),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Pick Date Range'),
                onTap: () => Navigator.pop(context, 'range'),
              ),
            ],
          ),
        );
      },
    );

    if (result == 'single') {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
        initialDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() {
          _searchDateRange = DateTimeRange(start: picked, end: picked);
        });
      }
    } else if (result == 'range') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        setState(() {
          _searchDateRange = picked;
        });
      }
    }
  }

  void _showCategoryMultiSelect() async {
    final Set<String>? selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final tempSelected = Set<String>.from(_selectedCategories);
            return AlertDialog(
              title: const Text('Select Categories'),
              content: SingleChildScrollView(
                child: Column(
                  children: _categories.map((category) {
                    return CheckboxListTile(
                      title: Text(category),
                      value: tempSelected.contains(category),
                      onChanged: (bool? checked) {
                        dialogSetState(() {
                          if (checked == true) {
                            tempSelected.add(category);
                          } else {
                            tempSelected.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedCategories = selected;
        _updateCategoryDisplayController();
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchKeyword = '';
      _searchController.clear();
      _selectedCategories.clear();
      _updateCategoryDisplayController();
      _searchDateRange = null;
      _searchStatus = null;
    });
  }

  TextSpan _highlight(String text, String keyword) {
    if (keyword.isEmpty) return TextSpan(text: text);

    final matches = RegExp(RegExp.escape(keyword), caseSensitive: false).allMatches(text);
    if (matches.isEmpty) return TextSpan(text: text);

    List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(backgroundColor: Colors.yellow, fontWeight: FontWeight.bold),
      ));
      currentIndex = match.end;
    }
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return TextSpan(children: spans);
  }

  List<Appointment> _filtered() {
    List<Appointment> list = widget.appointments;

    list = list.where((appt) {
      bool matches = true;

      if (_searchKeyword.isNotEmpty) {
        matches &= appt.title.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            (appt.description?.toLowerCase().contains(_searchKeyword.toLowerCase()) ?? false);
      }

      if (_searchDateRange != null) {
        final date = DateTime(appt.date.year, appt.date.month, appt.date.day);
        final start = DateTime(_searchDateRange!.start.year, _searchDateRange!.start.month, _searchDateRange!.start.day);
        final end = DateTime(_searchDateRange!.end.year, _searchDateRange!.end.month, _searchDateRange!.end.day);
        matches &= date.isAfter(start.subtract(const Duration(days: 1))) &&
            date.isBefore(end.add(const Duration(days: 1)));
      }

      if (_selectedCategories.isNotEmpty) {
        matches &= _selectedCategories.contains(appt.category);
      }

      if (_searchStatus != null) {
        matches &= appt.status == _searchStatus;
      }

      return matches;
    }).toList();

    list.sort((a, b) {
      final today = DateTime.now();
      bool aPast = a.date.isBefore(today);
      bool bPast = b.date.isBefore(today);

      if (aPast && !bPast) return -1;
      if (!aPast && bPast) return 1;
      return a.date.compareTo(b.date);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered();
    return Scaffold(
      appBar: AppBar(title: const Text('Search Appointments')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Keyword',
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickDateRangeOrDay,
                  tooltip: 'Pick Date or Range',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetFilters,
                  tooltip: 'Reset All Filters',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Category Multi-Select Field
            TextFormField(
              controller: _categoryDisplayController,
              readOnly: true,
              onTap: _showCategoryMultiSelect,
              decoration: InputDecoration(
                labelText: 'Selected Categories',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedCategories.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _selectedCategories.clear();
                            _updateCategoryDisplayController();
                          });
                        },
                      ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            if (_selectedCategories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 8.0,
                  children: _selectedCategories.map((cat) {
                    return Chip(
                      label: Text(cat),
                      onDeleted: () {
                        setState(() {
                          _selectedCategories.remove(cat);
                          _updateCategoryDisplayController();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),

            // Status dropdown
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Select Status'),
                    value: _searchStatus,
                    onChanged: (val) => setState(() => _searchStatus = val),
                    items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  ),
                ),
                if (_searchStatus != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _searchStatus = null),
                    tooltip: 'Clear Status',
                  ),
              ],
            ),
            if (_searchDateRange != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Date: ${DateFormat('yMMMd').format(_searchDateRange!.start)}'
                      '${_searchDateRange!.start != _searchDateRange!.end ? ' – ${DateFormat('yMMMd').format(_searchDateRange!.end)}' : ''}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const Divider(height: 30),

            // Dynamic title for appointment count
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${results.length} ${results.length == 1 ? "Appointment" : "Appointments"}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No appointments found.'))
                  : ListView.builder(
                itemCount: results.length,
                itemBuilder: (_, index) {
                  final appt = results[index];
                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditAppointmentPage(appointment: appt),
                        ),
                      );
                    },
                    title: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black),
                        children: [
                          _highlight('${appt.title} (${appt.category})', _searchKeyword),
                        ],
                      ),
                    ),
                    subtitle: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black),
                        children: [
                          TextSpan(
                            text:
                            '${DateFormat('y-MM-dd').format(appt.date)} ${DateFormat.jm().format(appt.date)}\n',
                          ),
                          if (appt.description != null)
                            _highlight(appt.description!, _searchKeyword),
                        ],
                      ),
                    ),
                    trailing: Text(appt.status),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
