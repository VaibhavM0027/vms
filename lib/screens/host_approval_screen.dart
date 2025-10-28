import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/visitor_service.dart';
import '../models/visitor_model.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HostApprovalScreen extends StatefulWidget {
  const HostApprovalScreen({super.key});

  @override
  _HostApprovalScreenState createState() => _HostApprovalScreenState();
}

class _HostApprovalScreenState extends State<HostApprovalScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  final NotificationService _notificationService = NotificationService();

  Future<void> _updateVisitorStatus(String visitorId, String status, String visitorName) async {
    try {
      await _firebaseServices.updateVisitorStatus(visitorId, status);
      if (status == 'approved') {
        await FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .update({'checkIn': FieldValue.serverTimestamp()});
      }

      // Send notification to visitor
      try {
        await _notificationService.notifyVisitorApproval(
          visitorId: visitorId,
          visitorName: visitorName,
          approved: status == 'approved',
        );
      } catch (e) {
        debugPrint('Error sending notification: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visitor ${status.toLowerCase()}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthService>(context, listen: false).role;
    final String? hostId = _firebaseServices.getCurrentUserId();
    final Stream<List<Visitor>> visitorsStream = (role == 'admin')
        ? _firebaseServices.getAllPendingVisitors()
        : (hostId != null
            ? _firebaseServices.getPendingVisitorsByHost(hostId)
            : Stream.value([]));
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: StreamBuilder<List<Visitor>>(
        stream: visitorsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final visitors = snapshot.data ?? [];

          if (visitors.isEmpty) {
            return const Center(child: Text('No pending visitors'));
          }

          return ListView.builder(
            itemCount: visitors.length,
            itemBuilder: (context, index) {
              final visitor = visitors[index];
              return Card(
                margin: const EdgeInsets.all(8),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                    ),
                  ),
                  title: Text(visitor.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact: ${visitor.contact}')
                      ,
                      Text('Purpose: ${visitor.purpose}')
                      ,
                      Text(
                          'Check-in: ${DateFormat('yyyy-MM-dd HH:mm').format(visitor.checkIn)}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () =>
                            _updateVisitorStatus(visitor.id!, 'approved', visitor.name),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            _updateVisitorStatus(visitor.id!, 'rejected', visitor.name),
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
}
