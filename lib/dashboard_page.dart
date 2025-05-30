import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/percent_indicator.dart'; // Keep this import for CircularPercentIndicator

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Categories Configuration ---
  final List<String> categories = const [
    'Sales - Fact-finding',
    'Sales - Closing',
    'Sales - Presentation',
    'Recruitment - Approaches',
    'Recruitment - Exam Date',
    'Recruitment - Exam Passes',
    'Servicing',
    'Personal',
  ];
  List<String> _selectedCategories = []; // Categories selected for filtering

  // --- Date Range Filter ---
  DateTimeRange? _selectedDateRange; // Date range selected for filtering

  // --- UI State Management ---
  bool _loading = false; // Indicates if data is being loaded
  bool _chartGenerated = false; // True if 'Generate' button has been pressed

  // --- Overall (All Time) Statistics ---
  double _overallPercent = 0.0;
  int _overallMade = 0;
  int _overallDone = 0;
  double _overallSales = 0.0; // Overall sales for all time

  // --- Filtered Statistics (based on selected categories and date range) ---
  double _filteredPercent = 0.0;
  int _filteredMade = 0;
  int _filteredDone = 0;
  double _filteredSales = 0.0;

  // --- Chart Data ---
  List<_CategoryData> _chartData = []; // Data for the detailed category chart

  @override
  void initState() {
    super.initState();
    _loadOverallData(); // Load overall data when the page initializes
  }

  /// Helper to get the start of the current week (Monday at 00:00:00).
  DateTime _getStartOfWeek(DateTime date) {
    // DateTime.weekday: Monday = 1, Sunday = 7
    int diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: diff));
  }

  /// Helper to get the end of the current week (Sunday at 23:59:59).
  DateTime _getEndOfWeek(DateTime date) {
    int diff = DateTime.sunday - date.weekday;
    return DateTime(date.year, date.month, date.day)
        .add(Duration(days: diff))
        .add(const Duration(hours: 23, minutes: 59, seconds: 59)); // To include the whole day
  }

  /// Loads overall (all-time) appointment statistics for the current user.
  Future<void> _loadOverallData() async {
    setState(() {
      _loading = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _resetOverallStats();
      return;
    }

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('Appointment')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      int made = 0;
      int done = 0;
      double totalSales = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String status = (data['status'] ?? '').toString().toLowerCase();
        double amount = 0.0;
        if (data['amount'] != null && data['amount'] is num) {
          amount = (data['amount'] as num).toDouble();
        }

        made++;
        if (status == 'completed' || status == 'done') {
          done++;
        }
        // Only sum sales for 'Sales - Closing' category for overall sales
        if (data['category'] == 'Sales - Closing' && status == 'completed') {
          totalSales += amount;
        }
      }

      setState(() {
        _overallMade = made;
        _overallDone = done;
        _overallPercent = made > 0 ? done / made : 0.0;
        _overallSales = totalSales;
      });
    } catch (e) {
      debugPrint("Error loading overall data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load overall data: $e')),
      );
      _resetOverallStats();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Resets overall statistics to default values.
  void _resetOverallStats() {
    setState(() {
      _overallPercent = 0.0;
      _overallMade = 0;
      _overallDone = 0;
      _overallSales = 0.0;
    });
  }

  /// Shows a date range picker and updates the selected date range.
  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5), // Allow selecting up to 5 years in the past
      lastDate: DateTime(now.year + 5), // Allow selecting up to 5 years in the future
      initialDateRange: _selectedDateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now), // Default to last 30 days
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  /// Resets the selected date range filter.
  void _resetDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
  }

  /// Toggles the selection status of a category for filtering.
  void _toggleCategorySelection(String category, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedCategories.contains(category)) {
          _selectedCategories.add(category);
        }
      } else {
        _selectedCategories.remove(category);
      }
    });
  }

  /// Clears all selected categories.
  void _clearSelectedCategories() {
    setState(() {
      _selectedCategories.clear();
    });
  }

  /// Generates the filtered chart data based on selected categories and date range.
  Future<void> _generateChart() async {
    setState(() {
      _loading = true;
      _chartGenerated = false; // Reset chart generated state
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _resetFilteredStats();
      return;
    }

    try {
      Query query = _firestore
          .collection('Appointment')
          .where('userId', isEqualTo: currentUser.uid);

      // Apply date range filter
      if (_selectedDateRange != null) {
        query = query
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.start))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_selectedDateRange!.end));
      }

      // Apply category filter if any selected
      if (_selectedCategories.isNotEmpty) {
        // Firestore 'whereIn' supports up to 10 items
        if (_selectedCategories.length > 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select up to 10 categories for filtering.')),
          );
          _resetFilteredStats();
          return;
        }
        query = query.where('category', whereIn: _selectedCategories);
      }

      QuerySnapshot snapshot = await query.get();

      // Aggregate data
      int made = 0;
      int done = 0;
      double totalSales = 0.0;

      // Initialize maps for all possible categories, not just selected ones
      Map<String, int> madePerCategory = { for (var cat in categories) cat : 0 };
      Map<String, int> donePerCategory = { for (var cat in categories) cat : 0 };
      Map<String, double> salesPerCategory = { for (var cat in categories) cat : 0.0 };


      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String category = data['category'] ?? 'Uncategorized';
        String status = (data['status'] ?? '').toString().toLowerCase();
        double amount = 0.0;
        if (data['amount'] != null && data['amount'] is num) {
          amount = (data['amount'] as num).toDouble();
        }

        // Aggregate for overall filtered stats
        made++;
        if (status == 'completed' || status == 'done') {
          done++;
        }
        // Only sum sales for 'Sales - Closing' category in filtered sales
        if (category == 'Sales - Closing' && status == 'completed') {
          totalSales += amount;
        }


        // Aggregate per category if it's one of the selected categories (or all if none selected)
        if (_selectedCategories.isEmpty || _selectedCategories.contains(category)) {
          madePerCategory[category] = (madePerCategory[category] ?? 0) + 1;
          if (status == 'completed' || status == 'done') {
            donePerCategory[category] = (donePerCategory[category] ?? 0) + 1;
          }
          salesPerCategory[category] = (salesPerCategory[category] ?? 0) + amount;
        }
      }

      double percent = made > 0 ? done / made : 0;

      List<_CategoryData> chartData = [];
      // Only add data for categories that were selected AND had data, or all categories if none selected
      final categoriesToDisplay = _selectedCategories.isEmpty ? categories : _selectedCategories;

      for (var cat in categoriesToDisplay) {
        int catMade = madePerCategory[cat] ?? 0;
        int catDone = donePerCategory[cat] ?? 0;
        double catSales = salesPerCategory[cat] ?? 0.0;
        // Add to chart data only if there's actual data for the category
        if (catMade > 0 || catDone > 0) { // Only add if there are appointments made or done
          chartData.add(_CategoryData(
            category: cat,
            made: catMade,
            done: catDone,
            sales: catSales,
            percent: catMade > 0 ? catDone / catMade : 0,
          ));
        }
      }

      setState(() {
        _filteredMade = made;
        _filteredDone = done;
        _filteredPercent = percent;
        _filteredSales = totalSales;
        _chartData = chartData;
        _chartGenerated = true; // Indicate that chart data has been generated
      });
    } catch (e) {
      debugPrint("Error generating chart: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate chart: $e')),
      );
      _resetFilteredStats();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Resets filtered statistics and chart data to default values.
  void _resetFilteredStats() {
    setState(() {
      _filteredMade = 0;
      _filteredDone = 0;
      _filteredPercent = 0.0;
      _filteredSales = 0.0;
      _chartData = [];
      _chartGenerated = false;
    });
  }

  /// Exports the current dashboard data as a PDF document.
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    final String dateRangeText = _selectedDateRange != null
        ? '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}'
        : "All Time (Overall)";
    final String categoriesText = _selectedCategories.isNotEmpty
        ? _selectedCategories.join(", ")
        : "All Categories";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Dashboard Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('Report Generated: ${DateFormat.yMMMd().add_jm().format(DateTime.now())}'),
              pw.SizedBox(height: 8),
              pw.Text('Date Range: $dateRangeText'),
              pw.Text('Categories: $categoriesText'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Overall Statistics (Filtered Data):',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Appointments Made: $_filteredMade'),
              pw.Text('Appointments Completed: $_filteredDone'),
              pw.Text('Completion Rate: ${(100 * _filteredPercent).toStringAsFixed(1)}%'),
              // Show filtered sales if 'Sales - Closing' is selected or no categories are selected (implying all)
              if (_selectedCategories.contains('Sales - Closing') || _selectedCategories.isEmpty)
                pw.Text('Total Sales: RM ${_filteredSales.toStringAsFixed(2)}'),
              pw.SizedBox(height: 20),
              pw.Text('Category Breakdown:',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              // Use a ListView.builder for dynamic list of category data
              if (_chartData.isEmpty)
                pw.Text('No data available for the selected filters.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic))
              else
                pw.ListView.builder(
                  itemCount: _chartData.length,
                  itemBuilder: (context, index) {
                    final data = _chartData[index];
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        '${data.category}: Made - ${data.made}, Done - ${data.done}, '
                            'Completion - ${(100 * data.percent).toStringAsFixed(1)}%, '
                            'Sales - RM ${data.sales.toStringAsFixed(2)}',
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generated successfully!')),
      );
    } catch (e) {
      debugPrint("Error exporting PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- OVERALL COMPLETION RATE (All Time) - CircularPercentIndicator ---
            const Text(
              'Overall Completion Rate (All Time)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Center(
              child: CircularPercentIndicator(
                radius: 80.0,
                lineWidth: 10.0,
                percent: _overallPercent, // Use the overall calculated percent
                center: Text(
                  "${(_overallPercent * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                progressColor: Colors.blue,
                backgroundColor: Colors.grey.shade300,
                animation: true,
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text("$_overallDone of $_overallMade tasks completed")),
            const SizedBox(height: 8),
            Center(
                child: Text("Overall Sales: RM ${_overallSales.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            const Divider(height: 30, thickness: 1),

            // --- FILTER SECTION ---
            const Text(
              'Generate Custom Chart',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // CATEGORY FILTER
            ExpansionTile(
              title: Text(_selectedCategories.isEmpty
                  ? "Select Categories (All)"
                  : "Selected Categories (${_selectedCategories.length})"),
              children: categories
                  .map(
                    (cat) => CheckboxListTile(
                  value: _selectedCategories.contains(cat),
                  title: Text(cat),
                  onChanged: (bool? selected) {
                    _toggleCategorySelection(cat, selected ?? false);
                  },
                ),
              )
                  .toList(),
            ),
            // Display selected categories as chips
            if (_selectedCategories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: _selectedCategories.map((category) {
                        return Chip(
                          label: Text(category),
                          onDeleted: () => _toggleCategorySelection(category, false),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        );
                      }).toList(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _clearSelectedCategories,
                        child: const Text('Clear All Categories'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // DATE PICKER
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDateRange == null
                        ? 'Select Date Range'
                        : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}'),
                    onPressed: _pickDateRange,
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _resetDateRange,
                    tooltip: 'Reset Date Range',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateChart,
              child: const Text('Generate Chart'),
            ),

            const SizedBox(height: 24),

            // --- Filtered Chart Display Section ---
            if (_chartGenerated)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtered Completion Rate: ${(_filteredPercent * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_selectedCategories.contains('Sales - Closing') || _selectedCategories.isEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Filtered Total Sales: RM ${_filteredSales.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Dynamic Chart display (No data prompt, CircularPercentIndicator for single category, Column for multiple)
                  SizedBox(
                    height: 300,
                    child: _chartData.isEmpty
                        ? const Center(
                      child: Text(
                        'No data found for the selected filters.',
                        style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : _chartData.length == 1 // Check if exactly one category has data
                        ? Center(
                      child: CircularPercentIndicator(
                        radius: 80.0,
                        lineWidth: 10.0,
                        percent: _chartData.first.percent, // Use the percent of the single category
                        center: Text(
                          "${(_chartData.first.percent * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        progressColor: Colors.blue,
                        backgroundColor: Colors.grey.shade300,
                        animation: true,
                      ),
                    )
                        : SfCartesianChart( // Column chart for multiple categories
                      primaryXAxis: CategoryAxis(title: const AxisTitle(text: 'Category')),
                      primaryYAxis: NumericAxis(
                        title: const AxisTitle(text: 'Number of Appointments'),
                        minimum: 0,
                        interval: 1.0, // Force integer intervals on Y-axis
                      ),
                      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
                      series: <CartesianSeries<dynamic, dynamic>>[
                        ColumnSeries<_CategoryData, String>(
                          dataSource: _chartData,
                          xValueMapper: (_CategoryData data, _) => data.category,
                          yValueMapper: (_CategoryData data, _) => data.made,
                          name: 'Made',
                          color: Colors.blue,
                          dataLabelSettings: const DataLabelSettings(isVisible: true),
                          enableTooltip: true,
                        ),
                        ColumnSeries<_CategoryData, String>(
                          dataSource: _chartData,
                          xValueMapper: (_CategoryData data, _) => data.category,
                          yValueMapper: (_CategoryData data, _) => data.done,
                          name: 'Completed',
                          color: Colors.green,
                          dataLabelSettings: const DataLabelSettings(isVisible: true),
                          enableTooltip: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download as PDF'),
                    onPressed: _exportPdf,
                  )
                ],
              ),
            if (!_chartGenerated && !_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Text(
                    'Select filters and tap "Generate Chart" to see results.',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double value;

  _ChartData(this.label, this.value);
}

class _CategoryData {
  final String category;
  final int made;
  final int done;
  final double sales;
  final double percent;

  _CategoryData({
    required this.category,
    required this.made,
    required this.done,
    required this.sales,
    required this.percent,
  });
}