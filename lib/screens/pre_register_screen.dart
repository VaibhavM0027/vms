import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'firebase_services.dart';
import 'visitor_model.dart';

class PreRegisterScreen extends StatefulWidget {
  const PreRegisterScreen({super.key});

  @override
  State<PreRegisterScreen> createState() => _PreRegisterScreenState();
}

class _PreRegisterScreenState extends State<PreRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _purposeController = TextEditingController(text: 'Meeting');
  DateTime _visitDateTime = DateTime.now().add(const Duration(days: 1));
  String? _selectedHostId;
  String? _selectedHostName;
  final _firebase = FirebaseServices();

  final List<Map<String, String>> _hosts = const [
    {'id': 'host1', 'name': 'John Doe (Marketing)'},
    {'id': 'host2', 'name': 'Jane Smith (HR)'},
    {'id': 'host3', 'name': 'Bob Johnson (IT)'},
  ];

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_visitDateTime),
    );
    if (time == null) return;
    setState(() {
      _visitDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedHostId == null) return;
    try {
      final visitor = Visitor(
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        purpose: _purposeController.text.trim(),
        hostId: _selectedHostId!,
        hostName: _selectedHostName!,
        idImageUrl: null,
        visitDate: _visitDateTime,
        checkIn: _visitDateTime,
        status: 'pending',
        qrCode: null,
      );
      final id = await _firebase.addVisitor(visitor);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pre-Registration Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scheduled: ${DateFormat('yMMMd – HH:mm').format(_visitDateTime)}'),
              const SizedBox(height: 12),
              const Text('Share this QR with the visitor'),
              const SizedBox(height: 12),
              QrImageView(data: id, size: 180),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
      appBar: AppBar(title: const Text('Pre-register Visitor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Visitor Name', prefixIcon: Icon(Icons.person)),
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
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(labelText: 'Purpose', prefixIcon: Icon(Icons.assignment)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedHostId,
                items: _hosts
                    .map((h) => DropdownMenuItem<String>(value: h['id'], child: Text(h['name']!)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Host', prefixIcon: Icon(Icons.work)),
                onChanged: (v) {
                  setState(() {
                    _selectedHostId = v;
                    _selectedHostName = _hosts.firstWhere((e) => e['id'] == v)['name'];
                  });
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Select host' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Schedule'),
                subtitle: Text(DateFormat('yMMMd – HH:mm').format(_visitDateTime)),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: const Text('Pick'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Create Pre-registration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


