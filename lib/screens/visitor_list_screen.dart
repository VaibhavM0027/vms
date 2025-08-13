import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../services/auth_service.dart';
import 'visitor_details_screen.dart';
import 'checkout_screen.dart';

class VisitorListScreen extends StatefulWidget {
  const VisitorListScreen({super.key});

  @override
  _VisitorListScreenState createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  String _filterStatus = 'all';
  bool _showCheckedOut = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthService>(context).role ?? 'admin';
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Visitor List'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[100]),
            onPressed: () => _showSearchDialog(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.grey[100]),
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'approved', child: Text('Approved')),
              const PopupMenuItem(value: 'checked-in', child: Text('Checked In')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
              const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
          ),
          Row(
            children: [
              Switch(
                value: _showCheckedOut,
                onChanged: (value) => setState(() => _showCheckedOut = value),
                activeColor: Colors.grey[300],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Show Checked-out', style: TextStyle(color: Colors.grey[100], fontSize: 12)),
              ),
            ],
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
        child: Column(
          children: [
            if (_searchQuery.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          hintText: 'Search visitors...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
                            onPressed: () => setState(() => _searchQuery = ''),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Filter: ', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey[800]!, borderRadius: BorderRadius.circular(12)),
                    child: Text(_getFilterDisplayName(_filterStatus), style: TextStyle(color: Colors.grey[100], fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Visitor>>(
                stream: _getVisitorsStream(role),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Error loading visitors', style: TextStyle(color: Colors.grey[100], fontSize: 18)),
                      Text('${snapshot.error}', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    ]));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[300]!))),
                      const SizedBox(height: 16),
                      Text('Loading visitors...', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ]));
                  }

                  final visitors = snapshot.data ?? [];
                  final filteredVisitors = _filterVisitors(visitors);

                  if (filteredVisitors.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No visitors found', style: TextStyle(color: Colors.grey[100], fontSize: 18)),
                      Text('Try adjusting your filters', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    ]));
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
                          boxShadow: [BoxShadow(color: Colors.grey[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VisitorDetailsScreen(visitor: visitor))),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(visitor.name, style: TextStyle(color: Colors.grey[100]!, fontSize: 18, fontWeight: FontWeight.w600))),
                                      _buildStatusChip(visitor.status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(Icons.phone, 'Contact: ${visitor.contact}'),
                                  _buildInfoRow(Icons.email, 'Email: ${visitor.email}'),
                                  _buildInfoRow(Icons.work, 'Host: ${visitor.hostName}'),
                                  _buildInfoRow(Icons.description, 'Purpose: ${visitor.purpose}'),
                                  _buildInfoRow(Icons.calendar_today, 'Visit Date: ${DateFormat('MMM dd, yyyy').format(visitor.visitDate)}'),
                                  _buildInfoRow(Icons.access_time, 'Check-in: ${DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkIn)}'),
                                  if (visitor.checkOut != null)
                                    _buildInfoRow(Icons.exit_to_app, 'Check-out: ${DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkOut!)}'),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (visitor.status == 'pending' && (role == 'admin' || role == 'host'))
                                        ElevatedButton.icon(
                                          onPressed: () => _approveVisitor(visitor.id!),
                                          icon: Icon(Icons.check, size: 16),
                                          label: Text('Approve'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[700], 
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      if (visitor.status == 'pending' && (role == 'admin' || role == 'host'))
                                        ElevatedButton.icon(
                                          onPressed: () => _rejectVisitor(visitor.id!),
                                          icon: Icon(Icons.close, size: 16),
                                          label: Text('Reject'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[700], 
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      // Show checkout button for visitors who have QR codes and are checked in
                                      if (_canCheckOut(visitor, role))
                                        ElevatedButton.icon(
                                          onPressed: () => _checkOutVisitor(visitor),
                                          icon: Icon(Icons.exit_to_app, size: 16),
                                          label: Text('Check-out'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[700], 
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
      ),
    );
  }

  Stream<List<Visitor>> _getVisitorsStream(String role) {
    if (role == 'admin') {
      return _firebaseServices.getAllVisitors();
    } else {
      final hostId = _firebaseServices.getCurrentUserId();
      return hostId != null ? _firebaseServices.getVisitorsByHost(hostId) : Stream.value([]);
    }
  }

  List<Visitor> _filterVisitors(List<Visitor> visitors) {
    return visitors.where((visitor) {
      if (_filterStatus != 'all' && visitor.status != _filterStatus) return false;
      if (!_showCheckedOut && visitor.checkOut != null) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return visitor.name.toLowerCase().contains(query) ||
               visitor.contact.toLowerCase().contains(query) ||
               visitor.email.toLowerCase().contains(query) ||
               visitor.hostName.toLowerCase().contains(query) ||
               visitor.purpose.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  String _getFilterDisplayName(String status) {
    switch (status) {
      case 'all': return 'All Visitors';
      case 'pending': return 'Pending Approval';
      case 'approved': return 'Approved';
      case 'checked-in': return 'Checked In';
      case 'completed': return 'Completed';
      case 'rejected': return 'Rejected';
      default: return status;
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 14))),
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
        statusText = 'Pending';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(statusIcon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  bool _canCheckOut(Visitor visitor, String role) {
    // Allow checkout for visitors who:
    // 1. Have a QR code (meaning they were registered)
    // 2. Are not already checked out
    // 3. Are either approved, checked-in, or pending (for self-registered visitors)
    // 4. User has appropriate role (admin, receptionist, or the visitor themselves)
    
    if (visitor.checkOut != null) return false; // Already checked out
    
    final hasValidStatus = ['approved', 'checked-in', 'pending'].contains(visitor.status);
    final hasQRCode = visitor.qrCode != null && visitor.qrCode!.isNotEmpty;
    final hasPermission = role == 'admin' || role == 'receptionist' || 
                         (role == 'visitor' && visitor.contact == _getCurrentUserContact());
    
    return hasValidStatus && hasQRCode && hasPermission;
  }

  String _getCurrentUserContact() {
    // This would need to be implemented based on your auth system
    // For now, returning empty string
    return '';
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('Search Visitors', style: TextStyle(color: Colors.grey[100])),
        content: TextField(
          style: TextStyle(color: Colors.grey[100]),
          decoration: InputDecoration(
            hintText: 'Enter search term...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey[400]))),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Search', style: TextStyle(color: Colors.blue[300]))),
        ],
      ),
    );
  }

  void _approveVisitor(String visitorId) async {
    try {
      await _firebaseServices.approveVisitor(visitorId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visitor approved successfully'), backgroundColor: Colors.green[700]));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve visitor: $e'), backgroundColor: Colors.red[700]));
    }
  }

  void _rejectVisitor(String visitorId) async {
    try {
      await _firebaseServices.rejectVisitor(visitorId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visitor rejected'), backgroundColor: Colors.red[700]));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject visitor: $e'), backgroundColor: Colors.red[700]));
    }
  }

  void _checkOutVisitor(Visitor visitor) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutScreen(visitor: visitor)));
  }
}
