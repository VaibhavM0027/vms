import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/config_service.dart';
import 'guard_register_visitor_screen.dart';
import 'guard_checkout_request_screen.dart';

class GuardScanScreen extends StatefulWidget {
  const GuardScanScreen({super.key});

  @override
  State<GuardScanScreen> createState() => _GuardScanScreenState();
}

class _GuardScanScreenState extends State<GuardScanScreen> {
  final MobileScannerController _controller = MobileScannerController(formats: const [
    BarcodeFormat.qrCode,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ]);
  bool _handled = false;

  Future<void> _handlePayload(String payload) async {
    if (_handled) return;
    setState(() => _handled = true);
    try {
      final qs = await FirebaseFirestore.instance
          .collection('visitors')
          .where('qrCode', isEqualTo: payload)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) {
        _show('Invalid code');
        return;
      }
      final doc = qs.docs.first;
      final data = doc.data();
      final name = data['name'] as String? ?? 'Visitor';
      final status = data['status'] as String? ?? 'pending';
      final requireApproval = await ConfigService.requireApproval();
      final canEnter = requireApproval ? (status == 'approved') : (status == 'approved' || status == 'pending');
      if (canEnter) {
        await doc.reference.update({
          'checkIn': FieldValue.serverTimestamp(),
          'status': 'approved'
        });
        _show('Allowed: $name');
      } else if (status == 'completed') {
        // Allow reuse of QR code for checked-out visitors
        await doc.reference.update({
          'checkIn': FieldValue.serverTimestamp(),
          'checkOut': null,
          'status': 'approved'
        });
        _show('Welcome back: $name');
      } else if (status == 'rejected') {
        _show('Denied: $name');
      } else {
        _show('Awaiting approval');
      }
    } catch (e) {
      _show('Error: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _handled = false);
        _controller.start();
      });
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guard Scan')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final boxSize = constraints.maxWidth * 0.7;
                  final left = (constraints.maxWidth - boxSize) / 2;
                  final top = (constraints.maxHeight - boxSize) / 2;
                  final scanWindow = Rect.fromLTWH(left, top, boxSize, boxSize);
                  return MobileScanner(
                    controller: _controller,
                    scanWindow: scanWindow,
                    onDetect: (capture) {
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code == null) return;
                      _controller.stop();
                      _handlePayload(code);
                    },
                  );
                }),
                // Dark overlay with a transparent centered square box as scan window
                LayoutBuilder(
                  builder: (context, constraints) {
                    final boxSize = constraints.maxWidth * 0.7;
                    final left = (constraints.maxWidth - boxSize) / 2;
                    final top = (constraints.maxHeight - boxSize) / 2;
                    return Stack(children: [
                      Container(color: Colors.black.withOpacity(0.5)),
                      Positioned(
                        left: left,
                        top: top,
                        width: boxSize,
                        height: boxSize,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // The transparent hole is visualized by not painting over the bordered box area
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'Align QR inside the box',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Flash'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.cameraswitch),
                  label: const Text('Camera'),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to guard register visitor screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GuardRegisterVisitorScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register Visitor'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Restart the scanner
                      _controller.start();
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR Code'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to checkout request screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuardCheckoutRequestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Request Visitor Checkout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Removed unused _HoleClipper after using scanWindow API


