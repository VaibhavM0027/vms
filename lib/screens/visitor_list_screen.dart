import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../widgets/visitor_card.dart';

class VisitorListScreen extends StatefulWidget {
  const VisitorListScreen({super.key});

  @override
  _VisitorListScreenState createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  bool _showCheckedOut = false;
  String _filterStatus = 'all'; // all, pending, approved, completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Visitor List'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.grey[100]),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Visitors')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'approved', child: Text('Approved')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
            ],
          ),
          Switch(
            value: _showCheckedOut,
            onChanged: (value) {
              setState(() {
                _showCheckedOut = value;
              });
            },
            activeColor: Colors.grey[300],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Show Checked-out',
              style: TextStyle(color: Colors.grey[100], fontSize: 12),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: StreamBuilder<List<Visitor>>(
          stream: _getVisitorsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading visitors',
                      style: TextStyle(color: Colors.grey[100], fontSize: 18),
                    ),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading visitors...',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            final visitors = snapshot.data ?? [];
            final filteredVisitors = _filterVisitors(visitors);

            if (filteredVisitors.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No visitors found',
                      style: TextStyle(color: Colors.grey[100], fontSize: 18),
                    ),
                    Text(
                      'Try adjusting your filters',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredVisitors.length,
              itemBuilder: (context, index) {
                final visitor = filteredVisitors[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[800]!.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      visitor.name,
                      style: TextStyle(
                        color: Colors.grey[100]!,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildInfoRow(
                            Icons.phone, 'Contact: ${visitor.contact}'),
                        _buildInfoRow(Icons.work, 'Host: ${visitor.hostName}'),
                        _buildInfoRow(
                            Icons.description, 'Purpose: ${visitor.purpose}'),
                        _buildInfoRow(Icons.access_time,
                            'Check-in: ${DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkIn)}'),
                        if (visitor.checkOut != null)
                          _buildInfoRow(Icons.exit_to_app,
                              'Check-out: ${DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkOut!)}'),
                        const SizedBox(height: 8),
                        _buildStatusChip(visitor.status),
                      ],
                    ),
                    trailing:
                        visitor.checkOut == null && visitor.status == 'approved'
                            ? IconButton(
                                icon: Icon(Icons.exit_to_app,
                                    color: Colors.grey[300]),
                                onPressed: () {
                                  // TODO: Navigate to check-out screen
                                },
                              )
                            : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Stream<List<Visitor>> _getVisitorsStream() {
    // In a real app, you might want to get all visitors for admin/receptionist
    // For now, we'll get visitors by host (current user)
    final hostId = _firebaseServices.getCurrentUserId();
    if (hostId != null) {
      return _firebaseServices.getVisitorsByHost(hostId);
    }
    return Stream.value([]);
  }

  List<Visitor> _filterVisitors(List<Visitor> visitors) {
    return visitors.where((visitor) {
      // Filter by status
      if (_filterStatus != 'all' && visitor.status != _filterStatus) {
        return false;
      }

      // Filter by check-out status
      if (!_showCheckedOut && visitor.checkOut != null) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status) {
      case 'pending':
        chipColor = Colors.orange[700]!;
        statusText = 'Pending';
        break;
      case 'approved':
        chipColor = Colors.green[700]!;
        statusText = 'Approved';
        break;
      case 'rejected':
        chipColor = Colors.red[700]!;
        statusText = 'Rejected';
        break;
      case 'completed':
        chipColor = Colors.blue[700]!;
        statusText = 'Completed';
        break;
      default:
        chipColor = Colors.grey[600]!;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
