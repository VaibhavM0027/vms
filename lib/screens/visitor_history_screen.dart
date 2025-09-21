import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/visitor_model.dart';

class VisitorHistoryScreen extends StatelessWidget {
  final String visitorId;
  final String visitorName;

  const VisitorHistoryScreen({
    Key? key,
    required this.visitorId,
    required this.visitorName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$visitorName\'s Visit History'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visitors')
            .doc(visitorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Visitor not found'));
          }

          final visitorData = snapshot.data!.data() as Map<String, dynamic>;
          final visitor = Visitor.fromMap(visitorData, visitorId);

          if (visitor.visitHistory == null || visitor.visitHistory!.isEmpty) {
            return const Center(
              child: Text('No visit history available for this visitor'),
            );
          }

          // Sort visit history by check-in date (most recent first)
          final sortedHistory = List.from(visitor.visitHistory!);
          sortedHistory.sort((a, b) {
            final aDate = a['checkIn'] is Timestamp 
                ? (a['checkIn'] as Timestamp).toDate() 
                : DateTime.now();
            final bDate = b['checkIn'] is Timestamp 
                ? (b['checkIn'] as Timestamp).toDate() 
                : DateTime.now();
            return bDate.compareTo(aDate); // Most recent first
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedHistory.length,
            itemBuilder: (context, index) {
              final visit = sortedHistory[index];
              final checkIn = visit['checkIn'] is Timestamp 
                  ? (visit['checkIn'] as Timestamp).toDate() 
                  : DateTime.parse(visit['checkIn'].toString());
              
              final checkOut = visit['checkOut'] != null 
                  ? (visit['checkOut'] is Timestamp 
                      ? (visit['checkOut'] as Timestamp).toDate() 
                      : DateTime.parse(visit['checkOut'].toString()))
                  : null;
              
              final dateFormat = DateFormat('MMM dd, yyyy');
              final timeFormat = DateFormat('hh:mm a');
              
              final status = visit['status'] ?? 'unknown';
              final purpose = visit['purpose'] ?? 'Not specified';
              final hostName = visit['hostName'] ?? 'Unknown';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateFormat.format(checkIn),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          _buildStatusChip(status),
                        ],
                      ),
                      const Divider(),
                      _buildInfoRow('Purpose', purpose),
                      _buildInfoRow('Host', hostName),
                      _buildInfoRow('Check-in', timeFormat.format(checkIn)),
                      if (checkOut != null)
                        _buildInfoRow('Check-out', timeFormat.format(checkOut)),
                      if (visit['meetingNotes'] != null)
                        _buildInfoRow('Notes', visit['meetingNotes']),
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

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'approved':
        color = Colors.blue;
        label = 'Approved';
        break;
      case 'checked-in':
        color = Colors.green;
        label = 'Checked In';
        break;
      case 'completed':
        color = Colors.purple;
        label = 'Completed';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}