import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../models/host_model.dart';
import '../services/host_service.dart';
import '../utils/validation_helper.dart';

class VisitorRegistrationScreen extends StatefulWidget {
  final String? idImagePath;

  const VisitorRegistrationScreen({super.key, this.idImagePath});

  @override
  _VisitorRegistrationScreenState createState() =>
      _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState extends State<VisitorRegistrationScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  final HostService _hostService = HostService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();
  String? _selectedHostId;
  String? _selectedHostName;
  List<Host> _hosts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    try {
      // Listen to active hosts from Firestore
      _hostService.getAllActiveHosts().listen((hosts) {
        if (mounted) {
          setState(() {
            _hosts = hosts;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hosts: $e')),
        );
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
      final visitor = Visitor(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        email: _emailController.text.trim(),
        purpose: _purposeController.text.trim(),
        hostId: _selectedHostId!,
        hostName: _selectedHostName!,
        visitDate: DateTime.now(),
        checkIn: DateTime.now(),
        status: 'pending',
      );

      final visitorId = await _firebaseServices.addVisitor(visitor);

      if (!mounted) return;

      // Show QR code dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => QRCodeDialog(
          qrData: visitorId,
          visitorName: visitor.name,
          visitorContact: visitor.contact,
          visitorPurpose: visitor.purpose,
          onDone: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      );

      // Clear form
      _nameController.clear();
      _contactController.clear();
      _emailController.clear();
      _purposeController.clear();
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
        title: const Text('Register Visitor'),
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
                      Icon(Icons.person_add, size: 32, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Register New Visitor',
                        style: TextStyle(fontSize: 24, color: Colors.grey[100], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter visitor details to generate QR code',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
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
                          labelText: 'Full Name',
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
                        validator: ValidationHelper.validateName,
                        onChanged: (value) {
                          _nameController.text = ValidationHelper.sanitizeInput(value);
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
                      
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.email, color: Colors.grey[400]),
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
                            return 'Please enter email address';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
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
                            value: host.id,
                            child: Text(
                              '${host.name} - ${host.department}',
                              style: TextStyle(color: Colors.grey[100]),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedHostId = value;
                            _selectedHostName = _hosts.firstWhere((host) => host.id == value).name;
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
    _emailController.dispose();
    _purposeController.dispose();
    super.dispose();
  }
}

class QRCodeDialog extends StatelessWidget {
  final String qrData;
  final String visitorName;
  final String visitorContact;
  final String visitorPurpose;
  final VoidCallback onDone;

  const QRCodeDialog({
    super.key,
    required this.qrData,
    required this.visitorName,
    required this.visitorContact,
    required this.visitorPurpose,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.qr_code, color: Colors.grey[300], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Visitor QR Code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Visitor Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visitor Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person, 'Name', visitorName),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.phone, 'Contact', visitorContact),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.description, 'Purpose', visitorPurpose),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Show this QR code to the guard for entry',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Done Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
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
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[200],
            ),
          ),
        ),
      ],
    );
  }
}
