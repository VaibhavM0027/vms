import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/visitor_model.dart';
import '../services/visitor_service.dart';
import '../services/auth_service.dart';
import 'visitor_details_screen.dart';
import 'checkout_screen.dart';
import 'visitor_history_screen.dart';

class VisitorListScreen extends StatefulWidget {
  const VisitorListScreen({super.key});

  @override
  State<VisitorListScreen> createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  String _filterStatus = 'all';
  bool _showCheckedOut = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
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
            // Search Bar
            if (_searchQuery.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          hintText: 'Search visitors...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                  ],
                ),
              ),
            // Filter Display
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
                      Text(_searchQuery.isNotEmpty || _filterStatus != 'all' 
                          ? 'Try adjusting your filters' 
                          : 'No visitors have been registered yet', 
                          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      if (_searchQuery.isEmpty && _filterStatus == 'all' && !_showCheckedOut)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Enable "Show Checked-out" to see completed visits', 
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ),
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
                          boxShadow: [BoxShadow(color: Colors.grey[800]!.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VisitorDetailsScreen(visitor: visitor))),
                            onLongPress: () {
                              // Show history option if visitor is registered
                              if (visitor.isRegistered) {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (context) => VisitorHistoryScreen(
                                      visitorId: visitor.id!,
                                      visitorName: visitor.name,
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Visit history is only available for registered visitors'),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row with name, profile picture, and status
                                  Row(
                                    children: [
                                      // Profile picture
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage: (visitor.photoUrl != null && visitor.photoUrl!.isNotEmpty)
                                            ? NetworkImage(visitor.photoUrl!)
                                            : (visitor.idImageUrl != null && visitor.idImageUrl!.isNotEmpty)
                                                ? NetworkImage(visitor.idImageUrl!)
                                                : null,
                                        child: ((visitor.photoUrl == null || visitor.photoUrl!.isEmpty) && (visitor.idImageUrl == null || visitor.idImageUrl!.isEmpty))
                                            ? Text(
                                                visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                visitor.name, 
                                                style: TextStyle(color: Colors.grey[100]!, fontSize: 16, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            if (visitor.isRegistered)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Tooltip(
                                                  message: "Registered visitor - Long press to view history",
                                                  child: Icon(
                                                    Icons.history,
                                                    size: 16,
                                                    color: Colors.blue[300],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusChip(visitor.status),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Compact info rows
                                  _buildCompactInfoRow(Icons.phone, visitor.contact),
                                  _buildCompactInfoRow(Icons.email, visitor.email),
                                  _buildCompactInfoRow(Icons.work, visitor.hostName),
                                  _buildCompactInfoRow(Icons.description, visitor.purpose),
                                  _buildCompactInfoRow(Icons.calendar_today, DateFormat('MMM dd, yyyy').format(visitor.visitDate)),
                                  _buildCompactInfoRow(Icons.access_time, DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkIn)),
                                  if (visitor.checkOut != null)
                                    _buildCompactInfoRow(Icons.exit_to_app, DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkOut!)),
                                  
                                  const SizedBox(height: 8),
                                  
                                  // Action buttons with better spacing
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (visitor.status == 'pending' && (role == 'admin' || role == 'host'))
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _approveVisitor(visitor.id!),
                                            icon: const Icon(Icons.check, size: 14),
                                            label: const Text('Approve', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green[700], 
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
                                          ),
                                        ),
                                      if (visitor.status == 'pending' && (role == 'admin' || role == 'host'))
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _rejectVisitor(visitor.id!),
                                            icon: const Icon(Icons.close, size: 14),
                                            label: const Text('Reject', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[700], 
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
                                          ),
                                        ),
                                      if (visitor.status == 'approved' && (role == 'admin' || role == 'receptionist' || role == 'guard'))
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _checkInVisitor(visitor.id!),
                                            icon: const Icon(Icons.login, size: 14),
                                            label: const Text('Check-in', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue[700], 
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
                                          ),
                                        ),
                                      if (_canCheckOut(visitor, role))
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _checkOutVisitor(visitor),
                                            icon: const Icon(Icons.exit_to_app, size: 14),
                                            label: const Text('Check-out', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange[700], 
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
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
    } else if (role == 'visitor') {
      // For visitors, show their own visits based on contact number
      final currentUserContact = _getCurrentUserContact();
      if (currentUserContact.isNotEmpty) {
        return _firebaseServices.getAllVisitors().map((visitors) => 
          visitors.where((visitor) => visitor.contact == currentUserContact).toList()
        );
      } else {
        return Stream.value([]);
      }
    } else {
      // For hosts and other roles, show visitors by host
      final hostId = _firebaseServices.getCurrentUserId();
      return hostId != null ? _firebaseServices.getVisitorsByHost(hostId) : Stream.value([]);
    }
  }

  List<Visitor> _filterVisitors(List<Visitor> visitors) {
    return visitors.where((visitor) {
      // Status filter
      if (_filterStatus != 'all' && visitor.status != _filterStatus) {
        return false;
      }
      
      // Checked out filter
      if (!_showCheckedOut && visitor.checkOut != null) {
        return false;
      }
      
      // Search filter
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

  Widget _buildCompactInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
              overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(statusIcon, size: 12, color: Colors.white),
        const SizedBox(width: 2),
        Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  bool _canCheckOut(Visitor visitor, String role) {
    if (visitor.checkOut != null) return false; // Already checked out
    
    // Allow checkout for approved, checked-in, and pending visitors
    final hasValidStatus = ['approved', 'checked-in', 'pending'].contains(visitor.status);
    
    // Check permissions based on role
    final hasPermission = role == 'admin' || role == 'receptionist' || 
                         (role == 'host' && visitor.hostId == _firebaseServices.getCurrentUserId()) ||
                         (role == 'visitor' && visitor.contact == _getCurrentUserContact());
    
    return hasValidStatus && hasPermission;
  }

  String _getCurrentUserContact() {
    // Get current user contact from auth service
    final authService = Provider.of<AuthService>(context, listen: false);
    return authService.username ?? '';
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('Search Visitors', style: TextStyle(color: Colors.grey[100])),
        content: TextField(
          controller: _searchController,
          style: TextStyle(color: Colors.grey[100]),
          decoration: InputDecoration(
            hintText: 'Enter search term...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
            }, 
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400]))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Search', style: TextStyle(color: Colors.blue[300]))
          ),
        ],
      ),
    );
  }

  void _approveVisitor(String visitorId) async {
    try {
      await _firebaseServices.approveVisitor(visitorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Visitor approved successfully'), backgroundColor: Colors.green[700])
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve visitor: $e'), backgroundColor: Colors.red[700])
        );
      }
    }
  }

  void _rejectVisitor(String visitorId) async {
    try {
      await _firebaseServices.rejectVisitor(visitorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Visitor rejected'), backgroundColor: Colors.red[700])
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject visitor: $e'), backgroundColor: Colors.red[700])
        );
      }
    }
  }

  void _checkInVisitor(String visitorId) async {
    try {
      await _firebaseServices.checkInVisitor(visitorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Visitor checked in successfully'), backgroundColor: Colors.blue[700])
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check in visitor: $e'), backgroundColor: Colors.red[700])
        );
      }
    }
  }

  void _checkOutVisitor(Visitor visitor) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutScreen(visitor: visitor)));
  }
}
