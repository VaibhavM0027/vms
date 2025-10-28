import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/visitor_model.dart';
import '../services/notification_service.dart';

class GuardCheckoutRequestScreen extends StatefulWidget {
  const GuardCheckoutRequestScreen({super.key});

  @override
  _GuardCheckoutRequestScreenState createState() => _GuardCheckoutRequestScreenState();
}

class _GuardCheckoutRequestScreenState extends State<GuardCheckoutRequestScreen> {
  final _searchController = TextEditingController();
  List<Visitor> _visitors = [];
  List<Visitor> _filteredVisitors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveVisitors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveVisitors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('visitors')
          .where('status', isEqualTo: 'approved')
          .where('checkOut', isNull: true)
          .get();

      final visitors = snapshot.docs
          .map((doc) => Visitor.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _visitors = visitors;
        _filteredVisitors = visitors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading visitors: $e')),
      );
    }
  }

  void _filterVisitors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVisitors = _visitors;
      } else {
        _filteredVisitors = _visitors
            .where((visitor) =>
                visitor.name.toLowerCase().contains(query.toLowerCase()) ||
                visitor.email.toLowerCase().contains(query.toLowerCase()) ||
                visitor.contact.contains(query))
            .toList();
      }
    });
  }

  Future<void> _requestCheckout(Visitor visitor) async {
    try {
      // Create a checkout request notification for admins
      await FirebaseFirestore.instance.collection('checkoutRequests').add({
        'visitorId': visitor.id,
        'visitorName': visitor.name,
        'requestedBy': 'guard',
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'hostId': visitor.hostId,
        'hostName': visitor.hostName,
      });

      // Send notification to admins
      await NotificationService().sendAdminNotification(
        title: 'Checkout Request',
        body: 'Guard requested checkout for visitor: ${visitor.name}',
        data: {
          'type': 'checkout_request',
          'visitorId': visitor.id,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout request sent to admin for approval'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request checkout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Visitor Checkout'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Visitors',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterVisitors,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVisitors.isEmpty
                    ? const Center(child: Text('No active visitors found'))
                    : ListView.builder(
                        itemCount: _filteredVisitors.length,
                        itemBuilder: (context, index) {
                          final visitor = _filteredVisitors[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.grey[300],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: (visitor.photoUrl != null && visitor.photoUrl!.isNotEmpty)
                                      ? Image.network(
                                          visitor.photoUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 48,
                                              height: 48,
                                              color: Colors.grey[300],
                                              child: Center(
                                                child: Text(
                                                  visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : (visitor.idImageUrl != null && visitor.idImageUrl!.isNotEmpty)
                                          ? Image.network(
                                              visitor.idImageUrl!,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: Colors.grey[300],
                                                  child: Center(
                                                    child: Text(
                                                      visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 48,
                                              height: 48,
                                              color: Colors.grey[300],
                                              child: Center(
                                                child: Text(
                                                  visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ),
                                ),
                              ),
                              title: Text(visitor.name),
                              subtitle: Text(
                                  '${visitor.email}\nHost: ${visitor.hostName}'),
                              isThreeLine: true,
                              trailing: ElevatedButton(
                                onPressed: () => _requestCheckout(visitor),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Request Checkout'),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}