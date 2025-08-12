import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/visitor_service.dart';
import '../models/visitor_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreRegisterScreen extends StatefulWidget {
  const PreRegisterScreen({super.key});

  @override
  State<PreRegisterScreen> createState() => _PreRegisterScreenState();
}

class _PreRegisterScreenState extends State<PreRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _purposeController = TextEditingController(text: 'Meeting');
  DateTime _visitDateTime = DateTime.now().add(const Duration(days: 1));
  String? _selectedHostId;
  String? _selectedHostName;
  final _firebase = FirebaseServices();
  List<Map<String, String>> _hosts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    try {
      // In a real app, fetch hosts from Firestore
      // For now, we'll use a more realistic set of hosts
      setState(() {
        _hosts = [
          {
            'id': 'host_marketing_001',
            'name': 'Sarah Johnson - Marketing Director'
          },
          {'id': 'host_hr_002', 'name': 'Michael Chen - HR Manager'},
          {'id': 'host_it_003', 'name': 'David Rodriguez - IT Lead'},
          {'id': 'host_finance_004', 'name': 'Lisa Thompson - Finance Manager'},
          {
            'id': 'host_operations_005',
            'name': 'Robert Kim - Operations Director'
          },
          {'id': 'host_sales_006', 'name': 'Jennifer Davis - Sales Manager'},
        ];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading hosts: $e')),
      );
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.grey[300]!,
              onPrimary: Colors.black,
              surface: Colors.grey[850]!,
              onSurface: Colors.grey[100]!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_visitDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.grey[300]!,
              onPrimary: Colors.black,
              surface: Colors.grey[850]!,
              onSurface: Colors.grey[100]!,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;
    setState(() {
      _visitDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedHostId == null) return;

    setState(() => _isLoading = true);

    try {
      final visitor = Visitor(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        purpose: _purposeController.text.trim(),
        hostId: _selectedHostId!,
        hostName: _selectedHostName!,
        idImageUrl: null,
        visitDate: _visitDateTime,
        checkIn: _visitDateTime,
        status: 'pending',
        qrCode: null,
      );

      final id = await _firebase.addVisitor(visitor);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text(
            'Pre-Registration Created',
            style: TextStyle(color: Colors.grey[100]),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Scheduled: ${DateFormat('MMM dd, yyyy HH:mm').format(_visitDateTime)}',
                      style: TextStyle(
                          color: Colors.grey[300], fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Host: $_selectedHostName',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share this QR with the visitor',
                style: TextStyle(color: Colors.grey[300]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: id,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.grey[300]),
              ),
            ),
          ],
        ),
      );

      // Clear form
      _nameController.clear();
      _contactController.clear();
      _purposeController.text = 'Meeting';
      setState(() {
        _selectedHostId = null;
        _selectedHostName = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Pre-register Visitor'),
        backgroundColor: Colors.black,
        elevation: 0,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visitor Name
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: Colors.grey[100]),
                  decoration: InputDecoration(
                    labelText: 'Visitor Name',
                    prefixIcon: Icon(Icons.person, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter name' : null,
                ),
                const SizedBox(height: 16),

                // Contact
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Colors.grey[100]),
                  decoration: InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter contact' : null,
                ),
                const SizedBox(height: 16),

                // Purpose
                TextFormField(
                  controller: _purposeController,
                  style: TextStyle(color: Colors.grey[100]),
                  decoration: InputDecoration(
                    labelText: 'Purpose of Visit',
                    prefixIcon: Icon(Icons.assignment, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Host Selection
                DropdownButtonFormField<String>(
                  value: _selectedHostId,
                  style: TextStyle(color: Colors.grey[100]),
                  dropdownColor: Colors.grey[850],
                  decoration: InputDecoration(
                    labelText: 'Select Host',
                    prefixIcon: Icon(Icons.work, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _hosts
                      .map((h) => DropdownMenuItem<String>(
                            value: h['id'],
                            child: Text(h['name']!),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedHostId = v;
                      _selectedHostName =
                          _hosts.firstWhere((e) => e['id'] == v)['name'];
                    });
                  },
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select host' : null,
                ),
                const SizedBox(height: 16),

                // Schedule
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[600]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: Colors.grey[400]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scheduled Visit',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy HH:mm')
                                  .format(_visitDateTime),
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDateTime,
                        child: Text(
                          'Change',
                          style: TextStyle(color: Colors.grey[300]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800]!,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[300]!),
                            ),
                          )
                        : const Text(
                            'Create Pre-registration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
