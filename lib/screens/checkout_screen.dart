import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/visitor_service.dart';
import '../models/visitor_model.dart';
import '../services/auth_service.dart';

class CheckoutScreen extends StatefulWidget {
  final Visitor? visitor;
  
  const CheckoutScreen({super.key, this.visitor});

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  late Stream<List<Visitor>> _visitorsStream;
  final _notesController = TextEditingController();
  bool _initializedFromRoute = false;
  bool _loadingRouteVisitor = false;
  Visitor? _routeVisitor;

  @override
  void initState() {
    super.initState();
    // Initialize with an empty stream; will set the correct stream based on role in didChangeDependencies
    _visitorsStream = Stream.value([]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromRoute) return;
    _initializedFromRoute = true;

    // Select stream based on role: Admin/Receptionist see all active visitors; Hosts see their own
    final role = Provider.of<AuthService>(context, listen: false).role ?? 'admin';
    final hostId = _firebaseServices.getCurrentUserId();
    if (role == 'admin' || role == 'receptionist') {
      _visitorsStream = _firebaseServices.getAllVisitors();
    } else if (hostId != null) {
      _visitorsStream = _firebaseServices.getVisitorsByHost(hostId);
    } else {
      _visitorsStream = Stream.value([]);
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['qrCode'] is String) {
      final qr = args['qrCode'] as String;
      _loadingRouteVisitor = true;
      _firebaseServices.getVisitorByQRCode(qr).then((visitor) {
        if (!mounted) return;
        setState(() {
          _routeVisitor = visitor;
          _loadingRouteVisitor = false;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _loadingRouteVisitor = false;
        });
      });
    }
  }

  Future<void> _checkoutVisitor(Visitor visitor) async {
    try {
      // Check if visitor can be checked out
      if (visitor.checkOut != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Visitor already checked out'), backgroundColor: Colors.orange[700]),
        );
        return;
      }

      if (visitor.status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot checkout rejected visitor'), backgroundColor: Colors.red[700]),
        );
        return;
      }

      if (visitor.status == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Visitor must be approved before checkout'), backgroundColor: Colors.orange[700]),
        );
        return;
      }

      await _firebaseServices.checkOutVisitor(visitor.id!, _notesController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visitor checked out successfully'), backgroundColor: Colors.green[700]),
      );
      _notesController.clear();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Visitor Check-out'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: _loadingRouteVisitor
            ? Center(child: CircularProgressIndicator(color: Colors.grey[300]))
            : (widget.visitor ?? _routeVisitor) != null
                ? _buildDirectCheckout()
                : _buildVisitorList(),
      ),
    );
  }

  Widget _buildDirectCheckout() {
    final visitor = (widget.visitor ?? _routeVisitor)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[850]!,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.grey[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check-out Visitor',
                  style: TextStyle(fontSize: 24, color: Colors.grey[100], fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.person, 'Name: ${visitor.name}'),
                _buildInfoRow(Icons.work, 'Host: ${visitor.hostName}'),
                _buildInfoRow(Icons.description, 'Purpose: ${visitor.purpose}'),
                _buildInfoRow(Icons.access_time, 'Check-in: ${DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkIn)}'),
                _buildInfoRow(Icons.timer, 'Duration: ${_calculateDuration(visitor.checkIn, DateTime.now())}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
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
                  'Meeting Notes (Optional)',
                  style: TextStyle(fontSize: 18, color: Colors.grey[100], fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  style: TextStyle(color: Colors.grey[100]),
                  decoration: InputDecoration(
                    hintText: 'Enter meeting notes...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _checkoutVisitor(visitor),
              icon: Icon(Icons.exit_to_app),
              label: Text('Confirm Check-out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorList() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Visitor>>(
            stream: _visitorsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.grey[100])));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Colors.grey[300]));
              }

              final visitors = snapshot.data ?? [];
              final activeVisitors = visitors
                  .where((v) => v.checkOut == null && (v.status == 'approved' || v.status == 'checked-in'))
                  .toList();

              if (activeVisitors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No active visitors', style: TextStyle(color: Colors.grey[100], fontSize: 18)),
                      Text('All visitors have been checked out', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeVisitors.length,
                itemBuilder: (context, index) {
                  final visitor = activeVisitors[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[850]!,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey[800]!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(visitor.name, style: TextStyle(color: Colors.grey[100], fontSize: 18, fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.work, 'Host: ${visitor.hostName}'),
                          _buildInfoRow(Icons.description, 'Purpose: ${visitor.purpose}'),
                          _buildInfoRow(Icons.access_time, 'Check-in: ${DateFormat('MMM dd, yyyy HH:mm').format(visitor.checkIn)}'),
                        ],
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _showCheckoutDialog(visitor),
                        icon: Icon(Icons.exit_to_app, size: 16),
                        label: Text('Check-out'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
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

  void _showCheckoutDialog(Visitor visitor) {
    _notesController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('Check-out ${visitor.name}', style: TextStyle(color: Colors.grey[100])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to check-out this visitor?', style: TextStyle(color: Colors.grey[300])),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              style: TextStyle(color: Colors.grey[100]),
              decoration: InputDecoration(
                labelText: 'Meeting Notes (Optional)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              _checkoutVisitor(visitor);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            child: Text('Confirm'),
          ),
        ],
      ),
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
}
