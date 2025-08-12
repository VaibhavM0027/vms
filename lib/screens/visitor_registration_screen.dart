import 'package:flutter/material.dart';
import 'firebase_services.dart';
import 'visitor_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    // In a real app, you would fetch hosts from Firestore
    setState(() {
      _hosts = [
        {'id': 'host1', 'name': 'John Doe (Marketing)'},
        {'id': 'host2', 'name': 'Jane Smith (HR)'},
        {'id': 'host3', 'name': 'Bob Johnson (IT)'},
      ];
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedHostId != null) {
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

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Show this QR at the security gate'),
                const SizedBox(height: 12),
                QrImageView(
                  data: visitorId,
                  version: QrVersions.auto,
                  size: 180,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Visitor Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter visitor name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  prefixIcon: Icon(Icons.phone),
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
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purpose of visit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Host/Person to Meet',
                  prefixIcon: Icon(Icons.work),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('COMPLETE CHECK-IN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
