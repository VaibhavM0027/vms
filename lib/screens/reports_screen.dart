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
import 'visitor_model.dart';

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
    }
    return newDateRange;
  }

  Future<List<Visitor>> _fetchVisitors() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('visitors')
          .where('checkIn',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange.start))
          .where('checkIn',
              isLessThanOrEqualTo: Timestamp.fromDate(
                  _dateRange.end.add(const Duration(days: 1))))
          .get();

      return snapshot.docs
          .map((doc) => Visitor.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
      return [];
    } finally {
      setState(() => _isLoading = false);
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
      hostCount[visitor.hostName] = (hostCount[visitor.hostName] ?? 0) + 1;
    }

    return hostCount;
  }

  Map<String, int> _generatePurposeReport(List<Visitor> visitors) {
    final purposeCount = <String, int>{};

    for (final visitor in visitors) {
      purposeCount[visitor.purpose] = (purposeCount[visitor.purpose] ?? 0) + 1;
    }

    return purposeCount;
  }

  Widget _buildChart(Map<String, int> data, String title) {
    final chartData = data.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: const CategoryAxis(),
      series: <CartesianSeries<dynamic, dynamic>>[
        ColumnSeries<dynamic, dynamic>(
          dataSource: chartData,
          xValueMapper: (dynamic d, _) => (d as ChartData).category,
          yValueMapper: (dynamic d, _) => (d as ChartData).value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        )
      ],
    );
  }

  Widget _buildPieChart(Map<String, int> data, String title) {
    final chartData = data.entries
        .map((e) => ChartData(e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SfCircularChart(
      title: ChartTitle(text: title),
      legend: const Legend(isVisible: true),
      series: <CircularSeries<dynamic, dynamic>>[
        PieSeries<dynamic, dynamic>(
          dataSource: chartData,
          xValueMapper: (dynamic d, _) => (d as ChartData).category,
          yValueMapper: (dynamic d, _) => (d as ChartData).value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Report Type:'),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _reportType,
                  items: const [
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Daily Visitors'),
                    ),
                    DropdownMenuItem(
                      value: 'host',
                      child: Text('By Host'),
                    ),
                    DropdownMenuItem(
                      value: 'purpose',
                      child: Text('By Purpose'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _reportType = value);
                    }
                  },
                ),
                const Spacer(),
                Text(
                  '${DateFormat('MMM d').format(_dateRange.start)} - '
                  '${DateFormat('MMM d, y').format(_dateRange.end)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Visitor>>(
              future: _fetchVisitors(),
              builder: (context, snapshot) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No visitor data found'));
                }

                final visitors = snapshot.data!;
                final totalVisitors = visitors.length;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'SUMMARY',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildSummaryCard(
                                      'Total Visitors',
                                      totalVisitors.toString(),
                                      Icons.people,
                                    ),
                                    _buildSummaryCard(
                                      'Avg/Day',
                                      (totalVisitors /
                                              _dateRange.duration.inDays)
                                          .toStringAsFixed(1),
                                      Icons.trending_up,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_reportType == 'daily')
                        _buildChart(
                          _generateDailyReport(visitors),
                          'Daily Visitor Count',
                        ),
                      if (_reportType == 'host')
                        _buildPieChart(
                          _generateHostReport(visitors),
                          'Visitors by Host',
                        ),
                      if (_reportType == 'purpose')
                        _buildPieChart(
                          _generatePurposeReport(visitors),
                          'Visitors by Purpose',
                        ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ElevatedButton(
                          onPressed: () => _exportReport(visitors),
                          child: const Text('Export Report'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
      // also create a simple PDF summary
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              pw.Text('Visitor Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: const ['Name', 'Contact', 'Host', 'Purpose', 'Status', 'Check-in', 'Check-out'],
                data: visitors.map((v) => [
                  v.name,
                  v.contact,
                  v.hostName,
                  v.purpose,
                  v.status,
                  df.format(v.checkIn),
                  v.checkOut != null ? df.format(v.checkOut!) : '',
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ];
          },
        ),
      );
      final pdfBytes = await pdf.save();
      final pdfFile = File('${dir.path}/visitors_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await pdfFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(pdfFile.path)], text: 'Visitor report (PDF)');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class ChartData {
  final String category;
  final int value;

  ChartData(this.category, this.value);
}
