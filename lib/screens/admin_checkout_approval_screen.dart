import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/visitor_model.dart';

class AdminCheckoutApprovalScreen extends StatefulWidget {
  const AdminCheckoutApprovalScreen({super.key});

  @override
  _AdminCheckoutApprovalScreenState createState() => _AdminCheckoutApprovalScreenState();
}

class _AdminCheckoutApprovalScreenState extends State<AdminCheckoutApprovalScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _checkoutRequests = [];

  @override
  void initState() {
    super.initState();
    _loadCheckoutRequests();
  }

  Future<void> _loadCheckoutRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('checkoutRequests')
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedAt', descending: true)
          .get();

      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'visitorId': data['visitorId'],
          'visitorName': data['visitorName'],
          'requestedBy': data['requestedBy'],
          'requestedAt': data['requestedAt'],
          'hostName': data['hostName'],
        };
      }).toList();

      setState(() {
        _checkoutRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading checkout requests: $e')),
      );
    }
  }

  Future<void> _approveCheckout(String requestId, String visitorId) async {
    try {
      // Update the checkout request status
      await FirebaseFirestore.instance
          .collection('checkoutRequests')
          .doc(requestId)
          .update({'status': 'approved'});

      // Update the visitor status and set checkout time
      await FirebaseFirestore.instance
          .collection('visitors')
          .doc(visitorId)
          .update({
        'status': 'completed',
        'checkOut': FieldValue.serverTimestamp(),
      });

      // Remove the approved request from the list
      setState(() {
        _checkoutRequests.removeWhere((request) => request['id'] == requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve checkout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectCheckout(String requestId) async {
    try {
      // Update the checkout request status
      await FirebaseFirestore.instance
          .collection('checkoutRequests')
          .doc(requestId)
          .update({'status': 'rejected'});

      // Remove the rejected request from the list
      setState(() {
        _checkoutRequests.removeWhere((request) => request['id'] == requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout request rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject checkout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Approval'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _checkoutRequests.isEmpty
              ? const Center(child: Text('No pending checkout requests'))
              : ListView.builder(
                  itemCount: _checkoutRequests.length,
                  itemBuilder: (context, index) {
                    final request = _checkoutRequests[index];
                    final requestedAt = request['requestedAt'] != null
                        ? (request['requestedAt'] as Timestamp).toDate()
                        : DateTime.now();
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visitor: ${request['visitorName']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Host: ${request['hostName']}'),
                            Text('Requested by: ${request['requestedBy']}'),
                            Text('Requested at: ${requestedAt.toString().substring(0, 16)}'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _rejectCheckout(request['id']),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () => _approveCheckout(
                                    request['id'],
                                    request['visitorId'],
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Approve Checkout'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCheckoutRequests,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}