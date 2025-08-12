import 'package:flutter/material.dart';
import '../services/visitor_service.dart';
import '../models/visitor_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VisitorRegistrationScreen extends StatefulWidget {
  final String? idImagePath;

  const VisitorRegistrationScreen({super.key, this.idImagePath});

  @override
  _VisitorRegistrationScreenState createState() =>
      _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState extends State<VisitorRegistrationScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _purposeController = TextEditingController();
  String? _selectedHostId;
  String? _selectedHostName;
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedHostId != null) {
      setState(() => _isLoading = true);

      try {
        String? idImageUrl;
        if (widget.idImagePath != null) {
          idImageUrl = await _firebaseServices.uploadIdImage(
            'visitor_${DateTime.now().millisecondsSinceEpoch}',
            widget.idImagePath!,
          );
        }

        // Create visitor
        final now = DateTime.now();
        Visitor visitor = Visitor(
          name: _nameController.text,
          contact: _contactController.text,
          purpose: _purposeController.text,
          hostId: _selectedHostId!,
          hostName: _selectedHostName!,
          idImageUrl: idImageUrl,
          visitDate: now,
          checkIn: now,
          status: 'pending',
          qrCode: null,
        );

        // Save to Firestore
        String visitorId = await _firebaseServices.addVisitor(visitor);

        // Send notification to host
        await _firebaseServices.sendNotificationToHost(
          _selectedHostId!,
          _nameController.text,
        );

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[850],
            title: Text(
              'Registration Successful',
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
                        'Visitor: ${_nameController.text}',
                        style: TextStyle(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Host: $_selectedHostName',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Show this QR at the security gate',
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
                    data: visitorId,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: Text(
                  'Done',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Visitor Registration'),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter visitor name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Contact Number
                TextFormField(
                  controller: _contactController,
                  style: TextStyle(color: Colors.grey[100]),
                  decoration: InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter contact number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Purpose of Visit
                TextFormField(
                  controller: _purposeController,
                  style: TextStyle(color: Colors.grey[100]),
                  decoration: InputDecoration(
                    labelText: 'Purpose of Visit',
                    prefixIcon:
                        Icon(Icons.description, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter purpose of visit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Host Selection
                DropdownButtonFormField<String>(
                  style: TextStyle(color: Colors.grey[100]),
                  dropdownColor: Colors.grey[850],
                  decoration: InputDecoration(
                    labelText: 'Host/Person to Meet',
                    prefixIcon: Icon(Icons.work, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  value: _selectedHostId,
                  items: _hosts.map((host) {
                    return DropdownMenuItem<String>(
                      value: host['id'],
                      child: Text(host['name']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedHostId = value;
                      _selectedHostName = _hosts
                          .firstWhere((host) => host['id'] == value)['name'];
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a host';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
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
                            'COMPLETE CHECK-IN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
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
