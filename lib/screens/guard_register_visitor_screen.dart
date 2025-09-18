import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/text_input.dart';

class GuardRegisterVisitorScreen extends StatefulWidget {
  const GuardRegisterVisitorScreen({Key? key}) : super(key: key);

  @override
  _GuardRegisterVisitorScreenState createState() => _GuardRegisterVisitorScreenState();
}

class _GuardRegisterVisitorScreenState extends State<GuardRegisterVisitorScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseServices _firebaseServices = FirebaseServices();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  
  String _selectedHostId = '';
  String _selectedHostName = '';
  bool _isRegistered = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _hosts = [];

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('hosts').get();
      setState(() {
        _hosts = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'name': doc.data()['name'] ?? 'Unknown',
                  'department': doc.data()['department'] ?? 'Unknown',
                })
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load hosts: $e')),
      );
    }
  }

  Future<void> _registerVisitor() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHostId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a host')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final visitor = Visitor(
        name: _nameController.text,
        contact: _contactController.text,
        email: _emailController.text,
        purpose: _purposeController.text,
        hostId: _selectedHostId,
        hostName: _selectedHostName,
        visitDate: DateTime.now(),
        checkIn: DateTime.now(),
        isRegistered: _isRegistered,
      );

      final visitorId = await _firebaseServices.addVisitor(visitor);
      
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor registered successfully')),
      );

      // Clear form
      _nameController.clear();
      _contactController.clear();
      _emailController.clear();
      _purposeController.clear();
      setState(() {
        _selectedHostId = '';
        _selectedHostName = '';
        _isRegistered = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register visitor: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Visitor'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextInput(
                      controller: _nameController,
                      label: 'Visitor Name',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter visitor name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextInput(
                      controller: _contactController,
                      label: 'Contact Number',
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter contact number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextInput(
                      controller: _emailController,
                      label: 'Email (Optional)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextInput(
                      controller: _purposeController,
                      label: 'Purpose of Visit',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter purpose of visit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Host',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedHostId.isEmpty ? null : _selectedHostId,
                      items: _hosts.map((host) {
                        return DropdownMenuItem<String>(
                          value: host['id'],
                          child: Text('${host['name']} (${host['department']})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedHostId = value;
                            _selectedHostName = _hosts
                                .firstWhere((host) => host['id'] == value)['name'];
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a host';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Register as permanent visitor'),
                      subtitle: const Text(
                          'Enable this to create a permanent QR code for this visitor'),
                      value: _isRegistered,
                      onChanged: (value) {
                        setState(() {
                          _isRegistered = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Register Visitor',
                      onPressed: _registerVisitor,
                    ),
                  ],
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