import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/config_service.dart';
import 'guard_register_visitor_screen.dart';

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
      // scan QR in visitors collection
      final qs = await FirebaseFirestore.instance
          .collection('visitors')
          .where('qrCode', isEqualTo: payload)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) {
        _show('Invalid QR code');
        return;
      }
      final doc = qs.docs.first;
      final data = doc.data();
      final name = data['name'] as String? ?? 'Visitor';
      final status = data['status'] as String? ?? 'pending';
      final checkOut = data['checkOut'];
      final checkIn = data['checkIn'];
      final isRegistered = data['isRegistered'] ?? false;
      
      // Enhanced logic for permanent QR codes
      if (isRegistered) {
        // For registered visitors with permanent QR codes
        if (status == 'completed' && checkOut != null) {
          // Previous visit completed - offer new visit
          _showActionDialog(payload, name, 'checkin_new', doc.id);
        } else if (status == 'checked-in' && checkOut == null) {
          // Currently checked in - offer checkout request
          _showActionDialog(payload, name, 'checkout', doc.id);
        } else if (status == 'approved' && checkIn == null) {
          // Approved but not checked in yet
          _showActionDialog(payload, name, 'checkin', doc.id);
        } else if (status == 'pending') {
          _show('Visit pending approval: $name');
        } else if (status == 'rejected') {
          _show('Recent visit was rejected: $name');
        } else {
          // Default check-in for approved registered visitors
          _performDirectCheckIn(doc.id, name);
        }
      } else {
        // For non-registered visitors (legacy/temporary)
        if (status == 'approved' || status == 'checked-in') {
          if (checkOut == null && status == 'checked-in') {
            // Visitor is currently inside - offer checkout request
            _showActionDialog(payload, name, 'checkout', doc.id);
          } else if (status == 'approved' && checkIn == null) {
            // Visitor is approved but not checked in yet
            _showActionDialog(payload, name, 'checkin', doc.id);
          } else if (checkOut != null) {
            // Visitor was checked out - this QR is no longer valid for non-registered
            _show('Visit completed. Please register for new visit.');
          }
          return;
        }
        
        // Handle other statuses for non-registered visitors
        final requireApproval = await ConfigService.requireApproval();
        final canEnter = requireApproval ? (status == 'approved') : (status == 'approved' || status == 'pending');
        
        if (canEnter) {
          await doc.reference.update({
            'checkIn': FieldValue.serverTimestamp(),
            'status': 'checked-in'
          });
          _show('Check-in successful: $name');
        } else if (status == 'completed') {
          _show('Visit completed. Please register for new visit.');
        } else if (status == 'rejected') {
          _show('Entry denied: $name');
        } else {
          _show('Awaiting approval: $name');
        }
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
  
  Future<void> _performDirectCheckIn(String visitorId, String visitorName) async {
    try {
      // Get visitor document to check if it's a registered visitor
      final visitorDoc = await FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId)
          .get();
      final visitorData = visitorDoc.data();
      
      if (visitorData != null && visitorData['isRegistered'] == true) {
        // For registered visitors, update the current visit in history
        List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
            ? List.from(visitorData['visitHistory'])
            : [];
            
        if (history.isNotEmpty) {
          // Update the most recent visit
          final now = Timestamp.now();
          history.last['checkIn'] = now;
          history.last['status'] = 'checked-in';
        }
        
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .update({
          'checkIn': FieldValue.serverTimestamp(),
          'status': 'checked-in',
          'visitHistory': history,
        });
      } else {
        // For non-registered visitors
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .update({
          'checkIn': FieldValue.serverTimestamp(),
          'status': 'checked-in'
        });
      }
      
      _show('Check-in successful: $visitorName');
    } catch (e) {
      _show('Error checking in visitor: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.start();
        }
      });
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
  
  void _showActionDialog(String qrCode, String visitorName, String action, String visitorId) {
    String title = '';
    String message = '';
    IconData icon = Icons.help;
    Color iconColor = Colors.blue;
    
    switch (action) {
      case 'checkin':
        title = 'Check-in Visitor';
        message = 'Check-in $visitorName?';
        icon = Icons.login;
        iconColor = Colors.green;
        break;
      case 'checkout':
        title = 'Checkout Request';
        message = 'Send checkout request to admin for $visitorName?\n\nNote: Admin approval is required for checkout.';
        icon = Icons.exit_to_app;
        iconColor = Colors.orange;
        break;
      case 'checkin_new':
        title = 'Register New Visit';
        message = 'Register new visit for $visitorName? This will require approval before entry.';
        icon = Icons.add_circle;
        iconColor = Colors.blue;
        break;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Restart scanner
                _controller.start();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (action == 'checkin') {
                  _performCheckIn(visitorId, visitorName);
                } else if (action == 'checkout') {
                  _requestCheckout(visitorId, visitorName);
                } else if (action == 'checkin_new') {
                  _startNewVisit(visitorId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'checkout' ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                action == 'checkin' ? 'Check-in' :
                action == 'checkout' ? 'Request Checkout' : 'Register New Visit'
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _performCheckIn(String visitorId, String visitorName) async {
    try {
      // Get visitor document to check if it's a registered visitor
      final visitorDoc = await FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId)
          .get();
      final visitorData = visitorDoc.data();
      
      if (visitorData != null && visitorData['isRegistered'] == true) {
        // For registered visitors, update the current visit in history
        List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
            ? List.from(visitorData['visitHistory'])
            : [];
        final now = Timestamp.now();
            
        if (history.isNotEmpty) {
          // Update the most recent visit
          history.last['checkIn'] = now;
          history.last['status'] = 'checked-in';
        }
        
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .update({
          'checkIn': FieldValue.serverTimestamp(),
          'status': 'checked-in',
          'visitHistory': history,
        });
      } else {
        // For non-registered visitors
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .update({
          'checkIn': FieldValue.serverTimestamp(),
          'status': 'checked-in'
        });
      }
      
      _show('Check-in successful: $visitorName');
    } catch (e) {
      _show('Error checking in visitor: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.start();
        }
      });
    }
  }
  
  Future<void> _requestCheckout(String visitorId, String visitorName) async {
    try {
      // Get current user (guard) info
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        _show('Authentication error');
        return;
      }
      
      // Get guard info
      final guardDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final guardName = guardDoc.data()?['name'] ?? 'Guard';
      
      // Get visitor info for host details
      final visitorDoc = await FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId)
          .get();
      final visitorData = visitorDoc.data();
      if (visitorData == null) {
        _show('Visitor not found');
        return;
      }
      
      // Create checkout request
      await FirebaseFirestore.instance.collection('checkoutRequests').add({
        'visitorId': visitorId,
        'visitorName': visitorName,
        'guardId': currentUserId,
        'guardName': guardName,
        'hostId': visitorData['hostId'],
        'hostName': visitorData['hostName'],
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      _show('Checkout request sent to admin for approval');
      
      // Listen for approval
      _listenForCheckoutApproval(visitorId, visitorName);
      
    } catch (e) {
      _show('Error requesting checkout: $e');
    } finally {
      // Restart scanner after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.start();
        }
      });
    }
  }
  
  void _listenForCheckoutApproval(String visitorId, String visitorName) {
    // Listen for checkout approval in real-time
    FirebaseFirestore.instance
        .collection('checkoutRequests')
        .where('visitorId', isEqualTo: visitorId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Show approval notification
        _showCheckoutApprovalDialog(visitorId, visitorName);
      }
    });
  }
  
  void _showCheckoutApprovalDialog(String visitorId, String visitorName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Checkout Approved'),
            ],
          ),
          content: Text('Admin approved checkout for $visitorName.\nConfirm final checkout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _controller.start();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmFinalCheckout(visitorId, visitorName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Checkout'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _confirmFinalCheckout(String visitorId, String visitorName) async {
    try {
      // Get the visitor document
      final visitorDoc = await FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId)
          .get();
      final visitorData = visitorDoc.data();
      
      if (visitorData != null) {
        final isRegistered = visitorData['isRegistered'] ?? false;
        final checkOutTime = FieldValue.serverTimestamp();
        
        if (isRegistered) {
          // For registered visitors, update visit history
          List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
              ? List.from(visitorData['visitHistory'])
              : [];
          final now = Timestamp.now();
              
          if (history.isNotEmpty) {
            // Update the most recent visit
            history.last['checkOut'] = now;
            history.last['status'] = 'completed';
          }
          
          await FirebaseFirestore.instance
              .collection('visitors')
              .doc(visitorId)
              .update({
            'checkOut': checkOutTime,
            'status': 'completed',
            'visitHistory': history,
          });
        } else {
          // For non-registered visitors
          await FirebaseFirestore.instance
              .collection('visitors')
              .doc(visitorId)
              .update({
            'checkOut': checkOutTime,
            'status': 'completed',
          });
        }
        
        // Update the checkout request
        final checkoutRequests = await FirebaseFirestore.instance
            .collection('checkoutRequests')
            .where('visitorId', isEqualTo: visitorId)
            .where('status', isEqualTo: 'approved')
            .get();
            
        for (final doc in checkoutRequests.docs) {
          await doc.reference.update({'status': 'completed'});
        }
        
        _show('Checkout completed for $visitorName');
      }
    } catch (e) {
      _show('Error completing checkout: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.start();
        }
      });
    }
  }
  
  Future<void> _startNewVisit(String visitorId) async {
    try {
      // Get visitor document
      final visitorDoc = await FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId)
          .get();
      final visitorData = visitorDoc.data();
      
      if (visitorData == null) {
        _show('Visitor not found');
        return;
      }
      
      final isRegistered = visitorData['isRegistered'] ?? false;
      
      if (isRegistered) {
        // For registered visitors, create new visit entry
        List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
            ? List.from(visitorData['visitHistory'])
            : [];
            
        // Add new visit to history (starting as pending for approval)
        final now = Timestamp.now();
        final newVisit = {
          'checkIn': now,
          'checkOut': null,
          'purpose': visitorData['purpose'] ?? 'Visit',
          'hostId': visitorData['hostId'],
          'hostName': visitorData['hostName'],
          'status': 'pending',
          'visitDate': now,
        };
        history.add(newVisit);
        
        // Update visitor document (new visit starts as pending)
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .update({
          'checkIn': FieldValue.serverTimestamp(),
          'checkOut': null,
          'status': 'pending',
          'visitDate': FieldValue.serverTimestamp(),
          'visitHistory': history,
        });
        
        _show('New visit registered for ${visitorData['name']}. Awaiting approval.');
      } else {
        // For non-registered visitors, just update status
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .update({
          'checkIn': FieldValue.serverTimestamp(),
          'checkOut': null,
          'status': 'checked-in',
          'visitDate': FieldValue.serverTimestamp(),
        });
        
        _show('Check-in successful for ${visitorData['name']}');
      }
    } catch (e) {
      _show('Error starting new visit: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.start();
        }
      });
    }
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

        ],
      ),
    );
  }
}

// Removed unused _HoleClipper after using scanWindow API


