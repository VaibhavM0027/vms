import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/config_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'visitor_registration_screen.dart';

class ScanIdScreen extends StatefulWidget {
  const ScanIdScreen({super.key});

  @override
  _ScanIdScreenState createState() => _ScanIdScreenState();
}

class _ScanIdScreenState extends State<ScanIdScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _idImagePath;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _scanning = false;

  Future<void> _scanQRCode() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 320,
            height: 360,
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) async {
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue == null) return;
                final data = barcode!.rawValue!;
                _scannerController.stop();
                Navigator.of(context).pop();
                await _handleScan(data);
              },
            ),
          ),
        );
      },
    );
    setState(() => _scanning = false);
  }

  Future<void> _handleScan(String payload) async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('visitors')
          .where('qrCode', isEqualTo: payload)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR')),
        );
        return;
      }
      final doc = qs.docs.first;
      final data = doc.data();
      final status = data['status'] as String?;
      final requireApproval = await ConfigService.requireApproval();
      final canEnter = requireApproval ? (status == 'approved') : (status == 'approved' || status == 'pending');
      if (canEnter) {
        // mark as checked-in (if not already)
        await doc.reference.update({'checkIn': FieldValue.serverTimestamp()});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visitor allowed. Check-in recorded.')),
        );
      } else if (status == 'completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already checked out')),
        );
      } else if (status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry rejected by admin')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waiting for admin approval')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: $e')),
      );
    }
  }

  Future<void> _captureIdImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _idImagePath = image.path;
      });
    }
  }

  void _navigateToRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VisitorRegistrationScreen(idImagePath: _idImagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Visitor ID')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_idImagePath != null)
              Image.file(File(_idImagePath!), height: 200)
            else
              const Icon(Icons.perm_identity, size: 100),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _captureIdImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture ID Photo (Optional)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _scanQRCode,
              icon: const Icon(Icons.qr_code),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _navigateToRegistration,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('PROCEED TO REGISTRATION'),
            ),
          ],
        ),
      ),
    );
  }
}
