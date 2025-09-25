import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/visitor_model.dart';
import '../services/notification_service.dart';

class VisitorStatusScreen extends StatefulWidget {
  final String visitorId;
  
  const VisitorStatusScreen({super.key, required this.visitorId});

  @override
  _VisitorStatusScreenState createState() => _VisitorStatusScreenState();
}

class _VisitorStatusScreenState extends State<VisitorStatusScreen> {
  final NotificationService _notificationService = NotificationService();
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _visitorStream;

  @override
  void initState() {
    super.initState();
    _visitorStream = FirebaseFirestore.instance
        .collection('visitors')
        .doc(widget.visitorId)
        .snapshots();
    
    // Initialize notification listeners for this visitor
    _notificationService.initialize();
    
    // Start listening for status changes to show notifications
    _notificationService.startVisitorStatusListener(widget.visitorId);
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Your visit request is pending approval. Please wait while the admin reviews your application.';
      case 'approved':
        return 'Your visit has been approved! You can now proceed to the reception and check out when ready.';
      case 'rejected':
        return 'Your visit request has been rejected. Please contact the host or admin for more information.';
      case 'checked-in':
        return 'You are checked in. Enjoy your visit!';
      case 'completed':
        return 'Your visit has been completed. Thank you for visiting!';
      default:
        return 'Status unknown.';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'checked-in':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'checked-in':
        return Icons.login;
      case 'completed':
        return Icons.logout;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Visit Status'),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _visitorStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text(
                  'Visitor not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final visitorData = snapshot.data!.data()!;
            final visitor = Visitor.fromMap(visitorData, widget.visitorId);
            final status = visitor.status;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Status Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[800]!.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile picture
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: (visitor.photoUrl != null && visitor.photoUrl!.isNotEmpty)
                              ? NetworkImage(visitor.photoUrl!)
                              : (visitor.idImageUrl != null && visitor.idImageUrl!.isNotEmpty)
                                  ? NetworkImage(visitor.idImageUrl!)
                                  : null,
                          child: ((visitor.photoUrl == null || visitor.photoUrl!.isEmpty) && (visitor.idImageUrl == null || visitor.idImageUrl!.isEmpty))
                              ? Text(
                                  visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        // Status icon and text
                        Icon(
                          _getStatusIcon(status),
                          size: 80,
                          color: _getStatusColor(status),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Status: ${status.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getStatusMessage(status),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Visitor Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[800]!.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visit Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Name', visitor.name),
                        _buildDetailRow('Contact', visitor.contact),
                        _buildDetailRow('Email', visitor.email),
                        _buildDetailRow('Host', visitor.hostName),
                        _buildDetailRow('Purpose', visitor.purpose),
                        _buildDetailRow('Check-in Time', 
                          '${visitor.checkIn.day}/${visitor.checkIn.month}/${visitor.checkIn.year} ${visitor.checkIn.hour}:${visitor.checkIn.minute.toString().padLeft(2, '0')}'),
                        if (visitor.checkOut != null)
                          _buildDetailRow('Check-out Time', 
                            '${visitor.checkOut!.day}/${visitor.checkOut!.month}/${visitor.checkOut!.year} ${visitor.checkOut!.hour}:${visitor.checkOut!.minute.toString().padLeft(2, '0')}'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (status == 'approved' || status == 'checked-in')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context, 
                            '/checkout', 
                            arguments: {'qrCode': visitor.qrCode}
                          );
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Check Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  if (status == 'pending')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You will receive a notification when your visit is approved or rejected.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
