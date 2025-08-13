import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/qr_code_widget.dart';
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
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.grey[850]!,
              onSurface: Colors.grey[100]!,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_visitDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Colors.grey[850]!,
                onSurface: Colors.grey[100]!,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
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
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHostId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a host')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create visitor document
      final docRef = FirebaseFirestore.instance.collection('visitors').doc();
      final id = docRef.id;

      final visitorData = {
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'email': '',
        'purpose': _purposeController.text.trim(),
        'hostId': _selectedHostId!,
        'hostName': _selectedHostName!,
        'visitDate': _visitDateTime,
        'checkIn': null,
        'checkOut': null,
        'meetingNotes': null,
        'status': 'pending',
        'qrCode': id,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(visitorData);

      if (!mounted) return;

      // Show QR code dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => QRCodeDialog(
          qrData: id,
          visitorName: _nameController.text.trim(),
          visitorContact: _contactController.text.trim(),
          visitorPurpose: _purposeController.text.trim(),
          onDone: () => Navigator.pop(context),
        ),
      );

      // Clear form
      _nameController.clear();
      _contactController.clear();
      _purposeController.clear();
      setState(() {
        _selectedHostId = null;
        _selectedHostName = null;
        _visitDateTime = DateTime.now().add(const Duration(days: 1));
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
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.grey[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Pre-register Visitor',
                        style: TextStyle(fontSize: 24, color: Colors.grey[100], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Schedule a visitor for future date',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Fields
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.grey[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor Information',
                        style: TextStyle(fontSize: 18, color: Colors.grey[100], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Visitor Name',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.person, color: Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter visitor name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Contact Field
                      TextFormField(
                        controller: _contactController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Contact Number',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.phone, color: Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter contact number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Purpose Field
                      TextFormField(
                        controller: _purposeController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Purpose of Visit',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.description, color: Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter purpose of visit';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Date & Time Selection
                      GestureDetector(
                        onTap: _pickDateTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[600]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.grey[400]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Visit Date & Time',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM dd, yyyy HH:mm').format(_visitDateTime),
                                      style: TextStyle(
                                        color: Colors.grey[100],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Host Selection
                      DropdownButtonFormField<String>(
                        value: _selectedHostId,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Select Host',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.work, color: Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        dropdownColor: Colors.grey[850],
                        items: _hosts.map((host) {
                          return DropdownMenuItem<String>(
                            value: host['id'],
                            child: Text(
                              host['name']!,
                              style: TextStyle(color: Colors.grey[100]),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedHostId = value;
                            _selectedHostName = _hosts.firstWhere((host) => host['id'] == value)['name'];
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a host';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Generate QR Code',
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

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _purposeController.dispose();
    super.dispose();
  }
}
