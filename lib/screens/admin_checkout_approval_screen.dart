import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCheckoutApprovalScreen extends StatefulWidget {
  const AdminCheckoutApprovalScreen({super.key});

  @override
  _AdminCheckoutApprovalScreenState createState() => _AdminCheckoutApprovalScreenState();
}

class _AdminCheckoutApprovalScreenState extends State<AdminCheckoutApprovalScreen> {
  late Stream<QuerySnapshot> _checkoutRequestsStream;

  @override
  void initState() {
    super.initState();
    // Initialize real-time stream
    _checkoutRequestsStream = FirebaseFirestore.instance
        .collection('checkoutRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  Future<void> _approveCheckout(String requestId, String visitorId) async {
    try {
      // Update the checkout request status
      await FirebaseFirestore.instance
          .collection('checkoutRequests')
          .doc(requestId)
          .update({'status': 'approved'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout request approved - Guard will be notified'),
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
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _checkoutRequestsStream,
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Badge(
                    label: Text('$count'),
                    child: const Icon(Icons.pending_actions),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _checkoutRequestsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _checkoutRequestsStream = FirebaseFirestore.instance
                            .collection('checkoutRequests')
                            .where('status', isEqualTo: 'pending')
                            .orderBy('requestedAt', descending: true)
                            .snapshots();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No pending checkout requests',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'All checkout requests have been processed',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final requestedAt = data['requestedAt'] != null
                  ? (data['requestedAt'] as Timestamp).toDate()
                  : DateTime.now();
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Profile picture
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('visitors')
                                .doc(data['visitorId'])
                                .get(),
                            builder: (context, visitorSnapshot) {
                              String? photoUrl;
                              String? idImageUrl;
                              String visitorInitial = (data['visitorName'] ?? 'U')[0].toUpperCase();
                              
                              if (visitorSnapshot.hasData && visitorSnapshot.data!.exists) {
                                final visitorData = visitorSnapshot.data!.data() as Map<String, dynamic>?;
                                photoUrl = visitorData?['photoUrl'];
                                idImageUrl = visitorData?['idImageUrl'];
                              }
                              
                              return Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.blue.shade100,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: (photoUrl != null && photoUrl.isNotEmpty)
                                      ? Image.network(
                                          photoUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.blue.shade100,
                                              child: Center(
                                                child: Text(
                                                  visitorInitial,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : (idImageUrl != null && idImageUrl.isNotEmpty)
                                          ? Image.network(
                                              idImageUrl,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 40,
                                                  height: 40,
                                                  color: Colors.blue.shade100,
                                                  child: Center(
                                                    child: Text(
                                                      visitorInitial,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.blue.shade100,
                                              child: Center(
                                                child: Text(
                                                  visitorInitial,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.person, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Visitor: ${data['visitorName'] ?? 'Unknown'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'PENDING',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.business, 'Host', data['hostName'] ?? 'Unknown'),
                      _buildInfoRow(Icons.security, 'Requested by', data['guardName'] ?? data['requestedBy'] ?? 'Guard'),
                      _buildInfoRow(Icons.schedule, 'Requested at', _formatDateTime(requestedAt)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _rejectCheckout(doc.id),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _approveCheckout(
                              doc.id,
                              data['visitorId'],
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}