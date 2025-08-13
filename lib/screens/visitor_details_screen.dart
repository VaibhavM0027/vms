import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import 'checkout_screen.dart';

class VisitorDetailsScreen extends StatelessWidget {
  final Visitor visitor;
  final FirebaseServices _firebaseServices = FirebaseServices();

  VisitorDetailsScreen({super.key, required this.visitor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Visitor Details'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (visitor.status == 'pending')
            IconButton(
              icon: Icon(Icons.check, color: Colors.green[300]),
              onPressed: () => _approveVisitor(context),
            ),
          if (visitor.status == 'pending')
            IconButton(
              icon: Icon(Icons.close, color: Colors.red[300]),
              onPressed: () => _rejectVisitor(context),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[850]!,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[700]!,
                      child: Text(
                        visitor.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(fontSize: 32, color: Colors.grey[100], fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      visitor.name,
                      style: TextStyle(fontSize: 24, color: Colors.grey[100], fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusChip(visitor.status),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Personal Information
              _buildSection('Personal Information', [
                _buildInfoTile(Icons.phone, 'Contact', visitor.contact),
                _buildInfoTile(Icons.email, 'Email', visitor.email),
                _buildInfoTile(Icons.work, 'Host', visitor.hostName),
                _buildInfoTile(Icons.description, 'Purpose', visitor.purpose),
              ]),

              const SizedBox(height: 20),

              // Visit Information
              _buildSection('Visit Information', [
                _buildInfoTile(Icons.calendar_today, 'Visit Date', DateFormat('EEEE, MMMM dd, yyyy').format(visitor.visitDate)),
                _buildInfoTile(Icons.access_time, 'Check-in Time', DateFormat('EEEE, MMMM dd, yyyy HH:mm').format(visitor.checkIn)),
                if (visitor.checkOut != null)
                  _buildInfoTile(Icons.exit_to_app, 'Check-out Time', DateFormat('EEEE, MMMM dd, yyyy HH:mm').format(visitor.checkOut!)),
                if (visitor.checkOut != null)
                  _buildInfoTile(Icons.timer, 'Duration', _calculateDuration(visitor.checkIn, visitor.checkOut!)),
              ]),

              if (visitor.meetingNotes != null && visitor.meetingNotes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSection('Meeting Notes', [
                  _buildInfoTile(Icons.note, 'Notes', visitor.meetingNotes!),
                ]),
              ],

              const SizedBox(height: 20),

              // Action buttons
              if (visitor.status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveVisitor(context),
                        icon: Icon(Icons.check),
                        label: Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectVisitor(context),
                        icon: Icon(Icons.close),
                        label: Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),

              if (visitor.status == 'approved' && visitor.checkOut == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _checkOutVisitor(context),
                    icon: Icon(Icons.exit_to_app),
                    label: Text('Check-out Visitor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850]!,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey[100], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, color: Colors.grey[100]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange[700]!;
        statusText = 'Pending Approval';
        statusIcon = Icons.schedule;
        break;
      case 'approved':
        chipColor = Colors.green[700]!;
        statusText = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'checked-in':
        chipColor = Colors.blue[700]!;
        statusText = 'Checked In';
        statusIcon = Icons.login;
        break;
      case 'rejected':
        chipColor = Colors.red[700]!;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'completed':
        chipColor = Colors.grey[600]!;
        statusText = 'Completed';
        statusIcon = Icons.done_all;
        break;
      default:
        chipColor = Colors.grey[600]!;
        statusText = status;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(statusIcon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _calculateDuration(DateTime checkIn, DateTime checkOut) {
    final duration = checkOut.difference(checkIn);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '$hours hours $minutes minutes';
    } else {
      return '$minutes minutes';
    }
  }

  void _approveVisitor(BuildContext context) async {
    try {
      await _firebaseServices.approveVisitor(visitor.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visitor approved successfully'), backgroundColor: Colors.green[700]),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve visitor: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _rejectVisitor(BuildContext context) async {
    try {
      await _firebaseServices.rejectVisitor(visitor.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visitor rejected'), backgroundColor: Colors.red[700]),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject visitor: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _checkOutVisitor(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CheckoutScreen(visitor: visitor)),
    );
  }
}
