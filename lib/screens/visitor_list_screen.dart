import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'visitor_model.dart';

class VisitorListScreen extends StatefulWidget {
  const VisitorListScreen({super.key});

  @override
  _VisitorListScreenState createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen> {
  List<Visitor> visitors = []; // This would be populated from database
  bool _showCheckedOut = false;

  @override
  void initState() {
    super.initState();
    // TODO: Load visitors from database
    _loadVisitors();
  }

  void _loadVisitors() {
    // Mock data - replace with actual database call
    setState(() {
      visitors = [
        Visitor(
          name: 'John Doe',
          contact: '1234567890',
          purpose: 'Meeting',
          hostId: 'host1',
          hostName: 'Jane Smith',
          visitDate: DateTime.now(),
          checkIn: DateTime.now(),
        ),
        Visitor(
          name: 'Alice Johnson',
          contact: '9876543210',
          purpose: 'Delivery',
          hostId: 'host2',
          hostName: 'Bob Brown',
          visitDate: DateTime.now(),
          checkIn: DateTime.now().subtract(const Duration(hours: 2)),
          checkOut: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      ];
    });
  }

  List<Visitor> get _filteredVisitors {
    return visitors.where((visitor) {
      if (_showCheckedOut) return true;
      return visitor.checkOut == null;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor List'),
        actions: [
          Switch(
            value: _showCheckedOut,
            onChanged: (value) {
              setState(() {
                _showCheckedOut = value;
              });
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('Show Checked-out'),
          ),
        ],
      ),
      body: _filteredVisitors.isEmpty
          ? const Center(child: Text('No visitors found'))
          : ListView.builder(
              itemCount: _filteredVisitors.length,
              itemBuilder: (context, index) {
                final visitor = _filteredVisitors[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(visitor.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Host: ${visitor.hostName}'),
                        Text('Purpose: ${visitor.purpose}'),
                        Text(
                            'Check-in: ${DateFormat('yyyy-MM-dd HH:mm').format(visitor.checkIn)}'),
                        if (visitor.checkOut != null)
                          Text(
                              'Check-out: ${DateFormat('yyyy-MM-dd HH:mm').format(visitor.checkOut!)}'),
                      ],
                    ),
                    trailing: visitor.checkOut == null
                        ? IconButton(
                            icon: const Icon(Icons.exit_to_app),
                            onPressed: () {
                              // TODO: Navigate to check-out screen
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
