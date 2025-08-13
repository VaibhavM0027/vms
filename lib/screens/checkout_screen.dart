import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/visitor_service.dart';
import '../models/visitor_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  late Stream<List<Visitor>> _visitorsStream;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    String? hostId = _firebaseServices.getCurrentUserId();
    if (hostId != null) {
      _visitorsStream = _firebaseServices.getVisitorsByHost(hostId);
    } else {
      _visitorsStream = Stream.value([]);
    }
  }

  Future<void> _checkoutVisitor(Visitor visitor) async {
    try {
      await _firebaseServices.updateVisitor(
        Visitor(
          id: visitor.id,
          name: visitor.name,
          contact: visitor.contact,
          email: visitor.email,
          purpose: visitor.purpose,
          hostId: visitor.hostId,
          hostName: visitor.hostName,
          idImageUrl: visitor.idImageUrl,
          visitDate: visitor.visitDate,
          checkIn: visitor.checkIn,
          checkOut: DateTime.now(),
          meetingNotes: _notesController.text,
          status: 'completed',
          qrCode: visitor.qrCode,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor checked out successfully')),
      );

      _notesController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Check-out')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Visitor>>(
              stream: _visitorsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final visitors = snapshot.data ?? [];
                final activeVisitors =
                    visitors.where((v) => v.checkOut == null).toList();

                if (activeVisitors.isEmpty) {
                  return const Center(child: Text('No active visitors'));
                }

                return ListView.builder(
                  itemCount: activeVisitors.length,
                  itemBuilder: (context, index) {
                    final visitor = activeVisitors[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(visitor.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Purpose: ${visitor.purpose}'),
                            Text(
                                'Check-in: ${DateFormat('yyyy-MM-dd HH:mm').format(visitor.checkIn)}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.exit_to_app),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Check-out Visitor'),
                                content: TextField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Meeting Notes',
                                  ),
                                  maxLines: 3,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('CANCEL'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _checkoutVisitor(visitor);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('CONFIRM'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
