import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  String _reportType = 'daily';
  bool _isLoading = false;
  List<Visitor> _visitors = [];
  String? _errorMessage;
  final FirebaseServices _firebaseServices = FirebaseServices();

  @override
  void initState() {
    super.initState();
    _fetchVisitors();
  }

  Future<DateTimeRange?> pickDateRange() async {
    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDateRange != null) {
      setState(() => _dateRange = newDateRange);
      _fetchVisitors(); // Refresh data when date range changes
    }
    return newDateRange;
  }

  Future<void> _fetchVisitors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the enhanced service method
      final visitors = await _firebaseServices.getVisitorsForReports(
        _dateRange.start,
        _dateRange.end,
      );

      setState(() {
        _visitors = visitors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    }
  }

  Map<String, int> _generateDailyReport(List<Visitor> visitors) {
    final dailyCount = <String, int>{};
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final visitor in visitors) {
      final dateKey = dateFormat.format(visitor.checkIn);
      dailyCount[dateKey] = (dailyCount[dateKey] ?? 0) + 1;
    }

    return dailyCount;
  }

  Map<String, int> _generateHostReport(List<Visitor> visitors) {
    final hostCount = <String, int>{};

    for (final visitor in visitors) {
      final hostName = visitor.hostName.isNotEmpty ? visitor.hostName : 'No Host';
      hostCount[hostName] = (hostCount[hostName] ?? 0) + 1;
    }

    return hostCount;
  }

  Map<String, int> _generatePurposeReport(List<Visitor> visitors) {
    final purposeCount = <String, int>{};

    for (final visitor in visitors) {
      final purpose = visitor.purpose.isNotEmpty ? visitor.purpose : 'No Purpose';
      purposeCount[purpose] = (purposeCount[purpose] ?? 0) + 1;
    }

    return purposeCount;
  }

  Map<String, int> _generateStatusReport(List<Visitor> visitors) {
    final statusCount = <String, int>{};

    for (final visitor in visitors) {
      final status = visitor.status.isNotEmpty ? visitor.status : 'Unknown';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    return statusCount;
  }

  Widget _buildChart(Map<String, int> data, String title) {
    if (data.isEmpty) {
      return Card(
        color: Colors.grey[850],
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available for this report type',
                style: TextStyle(color: Colors.grey[300]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final chartData = data.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SfCartesianChart(
          title: ChartTitle(text: title, textStyle: const TextStyle(color: Colors.white)),
          primaryXAxis: const CategoryAxis(
            labelStyle: TextStyle(color: Colors.white),
            majorGridLines: MajorGridLines(color: Colors.grey),
          ),
          primaryYAxis: const NumericAxis(
            labelStyle: TextStyle(color: Colors.white),
            majorGridLines: MajorGridLines(color: Colors.grey),
          ),
          series: <CartesianSeries<dynamic, dynamic>>[
            ColumnSeries<dynamic, dynamic>(
              dataSource: chartData,
              xValueMapper: (dynamic d, _) => (d as ChartData).category,
              yValueMapper: (dynamic d, _) => (d as ChartData).value,
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              color: Colors.blue,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> data, String title) {
    if (data.isEmpty) {
      return Card(
        color: Colors.grey[850],
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.pie_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available for this report type',
                style: TextStyle(color: Colors.grey[300]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final chartData = data.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SfCircularChart(
          title: ChartTitle(text: title, textStyle: const TextStyle(color: Colors.white)),
          legend: const Legend(
            isVisible: true,
            textStyle: TextStyle(color: Colors.white),
          ),
          series: <CircularSeries<dynamic, dynamic>>[
            PieSeries<dynamic, dynamic>(
              dataSource: chartData,
              xValueMapper: (dynamic d, _) => (d as ChartData).category,
              yValueMapper: (dynamic d, _) => (d as ChartData).value,
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Visitor Reports'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVisitors,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: pickDateRange,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            // Report Type and Date Range Controls
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Report Type:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _reportType,
                        dropdownColor: Colors.grey[800],
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Daily Visitors', style: TextStyle(color: Colors.white)),
                          ),
                          DropdownMenuItem(
                            value: 'host',
                            child: Text('By Host', style: TextStyle(color: Colors.white)),
                          ),
                          DropdownMenuItem(
                            value: 'purpose',
                            child: Text('By Purpose', style: TextStyle(color: Colors.white)),
                          ),
                          DropdownMenuItem(
                            value: 'status',
                            child: Text('By Status', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _reportType = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date Range:',
                        style: TextStyle(color: Colors.grey[300]),
                      ),
                      Text(
                        '${DateFormat('MMM d').format(_dateRange.start)} - '
                        '${DateFormat('MMM d, y').format(_dateRange.end)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchVisitors,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _visitors.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No visitor data found for the selected date range',
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting the date range or check if there are visitors in the system',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                children: [
                                  // Summary Card
                                  Card(
                                    color: Colors.grey[850],
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'SUMMARY',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildSummaryCard(
                                                'Total Visitors',
                                                _visitors.length.toString(),
                                                Icons.people,
                                              ),
                                              _buildSummaryCard(
                                                'Avg/Day',
                                                (_visitors.length /
                                                        _dateRange.duration.inDays)
                                                    .toStringAsFixed(1),
                                                Icons.trending_up,
                                              ),
                                              _buildSummaryCard(
                                                'Date Range',
                                                '${_dateRange.duration.inDays + 1} days',
                                                Icons.calendar_today,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Charts based on report type
                                  if (_reportType == 'daily')
                                    _buildChart(
                                      _generateDailyReport(_visitors),
                                      'Daily Visitor Count',
                                    ),
                                  if (_reportType == 'host')
                                    _buildPieChart(
                                      _generateHostReport(_visitors),
                                      'Visitors by Host',
                                    ),
                                  if (_reportType == 'purpose')
                                    _buildPieChart(
                                      _generatePurposeReport(_visitors),
                                      'Visitors by Purpose',
                                    ),
                                  if (_reportType == 'status')
                                    _buildPieChart(
                                      _generateStatusReport(_visitors),
                                      'Visitors by Status',
                                    ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Export Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _exportReport(_visitors),
                                      icon: const Icon(Icons.download),
                                      label: const Text('Export Report'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blue),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _exportReport(List<Visitor> visitors) async {
    try {
      final rows = <List<dynamic>>[
        [
          'Name',
          'Contact',
          'Email',
          'Host',
          'Purpose',
          'Status',
          'Check-in',
          'Check-out',
        ]
      ];
      final df = DateFormat('yyyy-MM-dd HH:mm');
      for (final v in visitors) {
        rows.add([
          v.name,
          v.contact,
          v.email,
          v.hostName,
          v.purpose,
          v.status,
          df.format(v.checkIn),
          v.checkOut != null ? df.format(v.checkOut!) : '',
        ]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/visitors_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Visitor report');
      
      // Create PDF summary
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Text('Visitor Report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Date Range: ${DateFormat('MMM d, y').format(_dateRange.start)} - ${DateFormat('MMM d, y').format(_dateRange.end)}'),
              pw.SizedBox(height: 10),
              pw.Text('Total Visitors: ${visitors.length}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: const [
                  'Name',
                  'Contact',
                  'Email',
                  'Host',
                  'Purpose',
                  'Status',
                  'Check-in',
                  'Check-out'
                ],
                data: visitors
                    .map((v) => [
                          v.name,
                          v.contact,
                          v.email,
                          v.hostName,
                          v.purpose,
                          v.status,
                          df.format(v.checkIn),
                          v.checkOut != null ? df.format(v.checkOut!) : '',
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ];
          },
        ),
      );
      final pdfBytes = await pdf.save();
      final pdfFile = File(
          '${dir.path}/visitors_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await pdfFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(pdfFile.path)],
          text: 'Visitor report (PDF)');
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class ChartData {
  final String category;
  final int value;

  ChartData(this.category, this.value);
}
