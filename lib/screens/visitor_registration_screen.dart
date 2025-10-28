import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../models/host_model.dart';
import '../services/host_service.dart';
import '../utils/validation_helper.dart';
import '../widgets/visitor_photo_widget.dart';
import '../utils/error_handler.dart';

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
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();
  String? _selectedHostId;
  String? _selectedHostName;
  List<Host> _hosts = [];
  bool _isLoading = false;
  File? _visitorPhoto;
  String? _visitorPhotoUrl;

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
      // Upload visitor photo if captured
      if (_visitorPhoto != null) {
        try {
          _visitorPhotoUrl = await _firebaseServices.uploadVisitorPhoto(
            DateTime.now().millisecondsSinceEpoch.toString(), // temporary ID
            _visitorPhoto!.path,
          );
          print('Temporary photo uploaded with URL: $_visitorPhotoUrl');
        } on Exception catch (e) {
          print('Photo upload failed: ${e.toString()}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Photo upload failed: ${e.toString()}')),
            );
          }
          // Continue with registration even if photo upload fails
        }
      }

      // Check if visitor already exists by contact or email
      final existingVisitor = await _checkExistingVisitor(
        _contactController.text.trim(),
        _emailController.text.trim(),
      );

      String visitorId;
      String qrCode;
      bool isNewVisitor = false;

      if (existingVisitor != null) {
        // Existing visitor - reuse their QR code and create new visit
        visitorId = existingVisitor['id'];
        qrCode = existingVisitor['qrCode'];
        
        await _createNewVisitForExistingVisitor(visitorId);
        
        if (!mounted) return;
        
        // Show message about reusing existing QR code
        _showExistingVisitorDialog(existingVisitor, qrCode);
      } else {
        // New visitor - create new registration
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
          isRegistered: true, // Mark as registered for permanent QR
          photoUrl: _visitorPhotoUrl, // Add photo URL to visitor
        );

        visitorId = await _firebaseServices.addVisitor(visitor);
        qrCode = visitorId; // QR code is the visitor ID

        // Upload visitor photo with correct visitor ID if captured
        if (_visitorPhoto != null) {
          try {
            final photoUrl = await _firebaseServices.uploadVisitorPhoto(
              visitorId,
              _visitorPhoto!.path,
            );
            print('Visitor photo uploaded with URL: $photoUrl');
            
            // Update visitor with photo URL
            await _firebaseServices.updateVisitor(
              Visitor(
                id: visitorId,
                name: visitor.name,
                contact: visitor.contact,
                email: visitor.email,
                purpose: visitor.purpose,
                hostId: visitor.hostId,
                hostName: visitor.hostName,
                visitDate: visitor.visitDate,
                checkIn: visitor.checkIn,
                status: visitor.status,
                isRegistered: visitor.isRegistered,
                photoUrl: photoUrl, // Updated photo URL
              ),
            );
            print('Visitor record updated with photo URL');
          } on Exception catch (e) {
            print('Photo upload failed after registration: ${e.toString()}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Photo upload failed after registration: ${e.toString()}')),
              );
            }
            // Continue with registration even if photo upload fails
          }
        }

        if (!mounted) return;

        // Show QR code dialog for new visitor
        _showQRCodeDialog(qrCode, visitor.name, visitor.contact, visitor.purpose, isNewVisitor);
      }

      // Clear form
      _nameController.clear();
      _contactController.clear();
      _emailController.clear();
      _purposeController.clear();
      setState(() {
        _selectedHostId = null;
        _selectedHostName = null;
        _visitorPhoto = null;
        _visitorPhotoUrl = null;
      });
    } catch (e) {
      print('Registration error: $e');
      // Handle the error with proper error handling
      if (mounted) {
        String errorMessage = 'Registration failed. Please try again.';
        // Handle permission errors specifically
        if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
          errorMessage = 'Registration requires proper permissions. Please contact reception or try again.';
        }
        // Handle Firestore permission errors more specifically
        else if (e.toString().contains('firestore') && (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED'))) {
          errorMessage = 'Registration requires proper permissions. Please contact reception or try again.';
        }
        await ErrorHandler.handleError(
          context: context,
          error: Exception(errorMessage),
          showSnackBar: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _checkExistingVisitor(String contact, String email) async {
    try {
      // Check by contact first
      var snapshot = await FirebaseFirestore.instance
          .collection('visitors')
          .where('contact', isEqualTo: contact)
          .where('isRegistered', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'id': doc.id,
          'qrCode': doc.data()['qrCode'] ?? doc.id,
          'name': doc.data()['name'],
          'contact': doc.data()['contact'],
          'email': doc.data()['email'],
        };
      }

      // Check by email if not found by contact
      snapshot = await FirebaseFirestore.instance
          .collection('visitors')
          .where('email', isEqualTo: email)
          .where('isRegistered', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'id': doc.id,
          'qrCode': doc.data()['qrCode'] ?? doc.id,
          'name': doc.data()['name'],
          'contact': doc.data()['contact'],
          'email': doc.data()['email'],
        };
      }

      return null;
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to check for existing visitors. Please contact an administrator.');
      }
      throw Exception('Failed to check existing visitor: $e');
    }
  }

  Future<void> _createNewVisitForExistingVisitor(String visitorId) async {
    try {
      await _firebaseServices.startNewVisit(
        visitorId,
        newPurpose: _purposeController.text.trim(),
        newHostId: _selectedHostId!,
        newHostName: _selectedHostName!,
      );
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to create a new visit. Please contact an administrator.');
      }
      throw Exception('Failed to create new visit: $e');
    }
  }

  void _showExistingVisitorDialog(Map<String, dynamic> existingVisitor, String qrCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.person_pin, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[100],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existing visitor found:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      existingVisitor['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[100],
                      ),
                    ),
                    Text(
                      existingVisitor['contact'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'You can use your existing QR code for this visit. New visit has been registered successfully!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[300],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showQRCodeDialog(
                          qrCode,
                          existingVisitor['name'],
                          existingVisitor['contact'],
                          _purposeController.text.trim(),
                          false, // Not a new visitor
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Show QR Code'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQRCodeDialog(String qrData, String visitorName, String visitorContact, String visitorPurpose, bool isNewVisitor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => QRCodeDialog(
        qrData: qrData,
        visitorName: visitorName,
        visitorContact: visitorContact,
        visitorPurpose: visitorPurpose,
        isNewVisitor: isNewVisitor,
        onDone: () => Navigator.popUntil(context, (route) => route.isFirst),
      ),
    );
  }

  Future<void> _captureVisitorPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _visitorPhoto = File(photo.path);
      });
    }
  }

  Future<void> _selectVisitorPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        _visitorPhoto = File(photo.path);
      });
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

                // Photo Capture Section
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
                        'Visitor Photo',
                        style: TextStyle(fontSize: 18, color: Colors.grey[100], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // Photo Preview or Placeholder
                      Center(
                        child: _visitorPhoto != null
                            ? VisitorPhotoWidget(
                                photoUrl: _visitorPhoto!.path,
                                height: 150,
                                width: 150,
                                enableEnlarge: true,
                                heroTag: 'visitor_photo_preview',
                              )
                            : Container(
                                height: 150,
                                width: 150,
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[600]!),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Photo Capture Options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _captureVisitorPhoto,
                            icon: Icon(Icons.camera, color: Colors.grey[300]),
                            label: Text(
                              'Capture',
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: _selectVisitorPhoto,
                            icon: Icon(Icons.photo_library, color: Colors.grey[300]),
                            label: Text(
                              'Gallery',
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap image or buttons to capture visitor photo (Optional)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
  final bool isNewVisitor;
  final VoidCallback onDone;

  const QRCodeDialog({
    super.key,
    required this.qrData,
    required this.visitorName,
    required this.visitorContact,
    required this.visitorPurpose,
    this.isNewVisitor = true,
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
                Expanded(
                  child: Text(
                    isNewVisitor ? 'Visitor QR Code' : 'Your Permanent QR Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[100],
                    ),
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
              isNewVisitor 
                  ? 'This is your permanent QR code. Save it for future visits to avoid re-registration!'
                  : 'Use this same QR code for entry. Your new visit has been registered.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (isNewVisitor)
              Text(
                '💡 Tip: Take a screenshot or save this QR code!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[300],
                  fontWeight: FontWeight.w500,
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
