import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'host_approval_screen.dart';
import '../widgets/custom_button.dart';

class CheckInScreen extends StatefulWidget {
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  bool _isCheckingIn = false;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkInVisitor() async {
    final name = _nameController.text.trim();
    final id = _idController.text.trim();

    if (name.isEmpty || id.isEmpty) {
      _showSnack('Please enter name and ID');
      return;
    }

    setState(() => _isCheckingIn = true);

    try {
      await FirebaseFirestore.instance.collection('checkins').add({
        'name': name,
        'id': id,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnack('Notification sent to host');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HostApprovalScreen(),
        ),
      );
    } catch (e) {
      _showSnack('Check-in failed');
    } finally {
      setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Check-in')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Visitor Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'ID / Aadhar / PAN'),
            ),
            const SizedBox(height: 24),
            _isCheckingIn
                ? const CircularProgressIndicator()
                : CustomButton(
                    text: 'Check-in',
                    onPressed: _checkInVisitor,
                  ),
          ],
        ),
      ),
    );
  }
}
