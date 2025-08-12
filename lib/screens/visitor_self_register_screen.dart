import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VisitorSelfRegisterScreen extends StatefulWidget {
  const VisitorSelfRegisterScreen({super.key});

  @override
  State<VisitorSelfRegisterScreen> createState() => _VisitorSelfRegisterScreenState();
}

class _VisitorSelfRegisterScreenState extends State<VisitorSelfRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  File? _photo;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickPhoto() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    if (x != null) {
      setState(() => _photo = File(x.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final now = DateTime.now();
      String? photoUrl;
      if (_photo != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('visitor_photos/${now.millisecondsSinceEpoch}_${_contactController.text.trim()}.jpg');
        await ref.putFile(_photo!);
        photoUrl = await ref.getDownloadURL();
      }
      final docRef = FirebaseFirestore.instance.collection('visitors').doc();
      await docRef.set({
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'purpose': 'Self-visit',
        'hostId': '',
        'hostName': '',
        'visitDate': now,
        'checkIn': now,
        'checkOut': null,
        'meetingNotes': null,
        'status': 'pending',
        'qrCode': docRef.id,
        'photoUrl': photoUrl,
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('QR Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please show this QR to the guard'),
              const SizedBox(height: 12),
              QrImageView(data: docRef.id, size: 200),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Self Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact', prefixIcon: Icon(Icons.phone)),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter contact' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _photo != null
                      ? CircleAvatar(radius: 32, backgroundImage: FileImage(_photo!))
                      : const CircleAvatar(radius: 32, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Photo'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Generate QR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


