import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EntryExitHistoryScreen extends StatefulWidget {
  const EntryExitHistoryScreen({super.key});

  @override
  State<EntryExitHistoryScreen> createState() => _EntryExitHistoryScreenState();
}

class _EntryExitHistoryScreenState extends State<EntryExitHistoryScreen> {
  final DateFormat _dateFmt = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFmt = DateFormat('hh:mm a');

  DateTimeRange? _range;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry/Exit History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickRange,
            tooltip: 'Filter by date range',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearch,
            tooltip: 'Search',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('visitors').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final events = _buildEvents(snapshot.data?.docs ?? []);
          if (events.isEmpty) {
            return const Center(child: Text('No entry/exit events found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final e = events[index];
              final isEntry = e.type == _EventType.entry;
              final icon = isEntry ? Icons.login : Icons.exit_to_app;
              final color = isEntry ? Colors.green[600] : Colors.orange[700];
              final dateStr = _dateFmt.format(e.timestamp);
              final timeStr = _timeFmt.format(e.timestamp);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white),
                  ),
                  title: Text('${e.visitorName} • ${isEntry ? 'Entry' : 'Exit'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.event, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text('$dateStr  •  $timeStr'),
                      ]),
                      const SizedBox(height: 4),
                      if (e.hostName.isNotEmpty)
                        Row(children: [
                          Icon(Icons.work, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(child: Text('Host: ${e.hostName}')),
                        ]),
                      if (e.purpose.isNotEmpty)
                        Row(children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(child: Text('Purpose: ${e.purpose}')),
                        ]),
                    ],
                  ),
                  trailing: _buildStatusChip(e.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<_Event> _buildEvents(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final List<_Event> events = [];

    for (final doc in docs) {
      final data = doc.data();
      final name = (data['name'] ?? '') as String;
      final contact = (data['contact'] ?? '') as String;
      final hostName = (data['hostName'] ?? '') as String;
      final purpose = (data['purpose'] ?? '') as String;
      final status = (data['status'] ?? 'pending') as String;

      // Entries directly from top-level checkIn/checkOut for non-registered visitors
      if (data['checkIn'] != null) {
        final dt = _toDate(data['checkIn']);
        if (_withinRange(dt) && _matchesSearch(name, contact, hostName, purpose)) {
          events.add(_Event(_EventType.entry, dt, name, hostName, purpose, status));
        }
      }
      if (data['checkOut'] != null) {
        final dt = _toDate(data['checkOut']);
        if (_withinRange(dt) && _matchesSearch(name, contact, hostName, purpose)) {
          events.add(_Event(_EventType.exit, dt, name, hostName, purpose, status));
        }
      }

      // History array for registered visitors
      if (data['visitHistory'] is List) {
        for (final v in List<Map<String, dynamic>>.from(data['visitHistory'])) {
          if (v['checkIn'] != null) {
            final dt = _toDate(v['checkIn']);
            if (_withinRange(dt) && _matchesSearch(name, contact, v['hostName']?.toString() ?? hostName, v['purpose']?.toString() ?? purpose)) {
              events.add(_Event(_EventType.entry, dt, name, v['hostName']?.toString() ?? hostName, v['purpose']?.toString() ?? purpose, (v['status'] ?? status).toString()));
            }
          }
          if (v['checkOut'] != null) {
            final dt = _toDate(v['checkOut']);
            if (_withinRange(dt) && _matchesSearch(name, contact, v['hostName']?.toString() ?? hostName, v['purpose']?.toString() ?? purpose)) {
              events.add(_Event(_EventType.exit, dt, name, v['hostName']?.toString() ?? hostName, v['purpose']?.toString() ?? purpose, (v['status'] ?? status).toString()));
            }
          }
        }
      }
    }

    // Sort newest first
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  bool _withinRange(DateTime dt) {
    if (_range == null) return true;
    final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
    final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59, 999);
    return dt.isAfter(start.subtract(const Duration(milliseconds: 1))) && dt.isBefore(end.add(const Duration(milliseconds: 1)));
  }

  bool _matchesSearch(String name, String contact, String hostName, String purpose) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return name.toLowerCase().contains(q)
        || contact.toLowerCase().contains(q)
        || hostName.toLowerCase().contains(q)
        || purpose.toLowerCase().contains(q);
  }

  DateTime _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  void _showSearch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search events'),
        content: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(hintText: 'Name, contact, host, purpose...'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _search = '';
                _searchCtrl.clear();
              });
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _search = _searchCtrl.text.trim());
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _range ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange; label = 'Pending'; break;
      case 'approved':
        color = Colors.blue; label = 'Approved'; break;
      case 'checked-in':
        color = Colors.green; label = 'Checked In'; break;
      case 'completed':
        color = Colors.purple; label = 'Completed'; break;
      case 'rejected':
        color = Colors.red; label = 'Rejected'; break;
      default:
        color = Colors.grey; label = status; break;
    }
    return Chip(label: Text(label, style: const TextStyle(color: Colors.white)), backgroundColor: color);
  }
}

enum _EventType { entry, exit }

class _Event {
  final _EventType type;
  final DateTime timestamp;
  final String visitorName;
  final String hostName;
  final String purpose;
  final String status;

  _Event(this.type, this.timestamp, this.visitorName, this.hostName, this.purpose, this.status);
}
