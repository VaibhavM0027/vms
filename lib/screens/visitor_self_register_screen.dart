import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/qr_code_widget.dart';

class VisitorSelfRegisterScreen extends StatefulWidget {
  const VisitorSelfRegisterScreen({super.key});

  @override
  State<VisitorSelfRegisterScreen> createState() => _VisitorSelfRegisterScreenState();
}

class _VisitorSelfRegisterScreenState extends State<VisitorSelfRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _hostNameController = TextEditingController();
  final _purposeController = TextEditingController();
  File? _photo;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  String? _lastGeneratedQR; // Store the last generated QR code

  Future<void> _pickPhoto() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera);
      if (x != null) {
        setState(() => _photo = File(x.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a photo')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final docRef = FirebaseFirestore.instance.collection('visitors').doc();

      final visitorData = {
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'email': _emailController.text.trim(),
        'hostName': _hostNameController.text.trim(),
        'purpose': _purposeController.text.trim(),
        'hostId': '',
        'visitDate': now,
        'checkIn': now,
        'checkOut': null,
        'meetingNotes': null,
        'status': 'pending',
        'qrCode': docRef.id,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(visitorData);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _lastGeneratedQR = docRef.id; // Store the QR code
      });
      _showQRCodeDialog(docRef.id);

      () async {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('visitor_photos/${docRef.id}.jpg');
          await ref.putFile(_photo!);
          final url = await ref.getDownloadURL();
          await docRef.update({'photoUrl': url});
        } catch (_) {}
      }();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering: $e')),
        );
      }
    }
  }

  void _showQRCodeDialog(String qrData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Registration Successful!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your QR Code has been generated. Please show this to the guard.',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: CustomQRCodeWidget(
                data: qrData,
                size: 200,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                errorMessage: 'QR Code Unavailable',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Visitor ID: ${qrData.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCheckoutOption(qrData);
            },
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutOption(String qrData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Registration Complete!',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 48,
              color: Colors.orange[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Your visit request is pending approval.',
              style: TextStyle(color: Colors.grey[300], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You will receive a notification when your visit is approved or rejected. You can check your status anytime.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Don't navigate away, just close the dialog to show the floating action button
            },
            child: Text(
              'Stay Here',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToStatus(qrData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Check Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }


  void _navigateToStatus(String qrData) {
    Navigator.pushNamed(context, '/visitor-status', arguments: {'visitorId': qrData});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Self Registration'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: _lastGeneratedQR != null
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToStatus(_lastGeneratedQR!),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              icon: const Icon(Icons.info),
              label: const Text('Check Status'),
            )
          : null,
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[800]!.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_add, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Visitor Self Registration',
                        style: TextStyle(
                            fontSize: 24,
                            color: Colors.grey[100],
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Register yourself as a visitor',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Photo Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[800]!.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo Capture',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[100],
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Photo is mandatory for registration',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[800]!,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[600]!, width: 2),
                            ),
                            child: _photo != null
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _photo!,
                                fit: BoxFit.cover,
                              ),
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 32, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to capture',
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[800]!.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[100],
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fields marked with * are mandatory',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 20),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.person, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                            return 'Please enter your name';
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
                          labelText: 'Contact Number *',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.phone, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                            return 'Please enter your contact number';
                          }
                          final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
                          if (!phoneRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid contact number';
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
                          labelText: 'Email Address *',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.email, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                            return 'Please enter your email address';
                          }
                          final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Host Name Field
                      TextFormField(
                        controller: _hostNameController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Host Name *',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.person_pin, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                            return 'Please enter the host name';
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
                          labelText: 'Purpose of Visit *',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon:
                          Icon(Icons.description, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                            return 'Please enter the purpose of your visit';
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
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
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
    _hostNameController.dispose();
    _purposeController.dispose();
    super.dispose();
  }
}
