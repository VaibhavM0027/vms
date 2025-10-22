import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/visitor_model.dart';
import 'visitor_history_screen.dart';
import '../widgets/visitor_photo_widget.dart';

class AllVisitorHistoryScreen extends StatefulWidget {
  const AllVisitorHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AllVisitorHistoryScreen> createState() => _AllVisitorHistoryScreenState();
}

class _AllVisitorHistoryScreenState extends State<AllVisitorHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';
  DateTimeRange? _selectedDateRange;
  String _sortBy = 'name'; // 'name', 'date', 'status'
  bool _sortAscending = true;

  final List<String> _statusOptions = [
    'all',
    'pending',
    'approved',
    'checked-in',
    'completed',
    'rejected'
  ];

  final List<String> _sortOptions = [
    'name',
    'date',
    'status',
    'host'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.blue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedStatus = 'all';
      _selectedDateRange = null;
      _sortBy = 'name';
      _sortAscending = true;
    });
  }

  List<Visitor> _filterAndSortVisitors(List<Visitor> visitors) {
    List<Visitor> filtered = visitors;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((visitor) {
        return visitor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               visitor.contact.contains(_searchQuery) ||
               visitor.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               visitor.hostName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((visitor) {
        return visitor.status.toLowerCase() == _selectedStatus.toLowerCase();
      }).toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((visitor) {
        final visitDate = visitor.visitDate;
        return visitDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
               visitDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'date':
          comparison = a.visitDate.compareTo(b.visitDate);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
        case 'host':
          comparison = a.hostName.compareTo(b.hostName);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Status filter
          FilterChip(
            label: Text('Status: ${_selectedStatus.toUpperCase()}'),
            selected: _selectedStatus != 'all',
            onSelected: (selected) {
              _showStatusFilterDialog();
            },
            avatar: const Icon(Icons.filter_list, size: 16),
          ),
          const SizedBox(width: 8),
          // Date range filter
          FilterChip(
            label: Text(_selectedDateRange == null 
                ? 'Date Range' 
                : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}'),
            selected: _selectedDateRange != null,
            onSelected: (selected) {
              if (selected) {
                _selectDateRange();
              } else {
                _clearDateRange();
              }
            },
            avatar: const Icon(Icons.date_range, size: 16),
          ),
          const SizedBox(width: 8),
          // Sort filter
          FilterChip(
            label: Text('Sort: ${_sortBy.toUpperCase()}'),
            selected: true,
            onSelected: (selected) {
              _showSortDialog();
            },
            avatar: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
          ),
          const SizedBox(width: 8),
          // Clear all filters
          if (_searchQuery.isNotEmpty || _selectedStatus != 'all' || _selectedDateRange != null)
            ActionChip(
              label: const Text('Clear All'),
              onPressed: _clearAllFilters,
              avatar: const Icon(Icons.clear, size: 16),
            ),
        ],
      ),
    );
  }

  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter by Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _statusOptions.map((status) {
              return RadioListTile<String>(
                title: Text(status.toUpperCase()),
                value: status,
                groupValue: _selectedStatus,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sort by'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._sortOptions.map((option) {
                return RadioListTile<String>(
                  title: Text(option.toUpperCase()),
                  value: option,
                  groupValue: _sortBy,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                      });
                    }
                  },
                );
              }).toList(),
              const Divider(),
              SwitchListTile(
                title: const Text('Ascending'),
                value: _sortAscending,
                onChanged: (bool value) {
                  setState(() {
                    _sortAscending = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {}); // Refresh the list
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVisitorCard(Visitor visitor) {
    final hasHistory = visitor.visitHistory != null && visitor.visitHistory!.isNotEmpty;
    final statusColor = _getStatusColor(visitor.status);
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: Stack(
          children: [
            VisitorPhotoWidget(
              photoUrl: (visitor.photoUrl != null && visitor.photoUrl!.isNotEmpty)
                  ? visitor.photoUrl!
                  : (visitor.idImageUrl != null && visitor.idImageUrl!.isNotEmpty)
                      ? visitor.idImageUrl!
                      : null,
              height: 40,
              width: 40,
              enableEnlarge: false,
            ),
            if (hasHistory)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.history, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          visitor.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(visitor.contact),
            Text('Host: ${visitor.hostName}'),
            Text('Date: ${dateFormat.format(visitor.visitDate)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                visitor.status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          if (visitor.id != null) {
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
                content: Text('Cannot view history: Invalid visitor ID'),
              ),
            );
          }
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'checked-in':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, contact, email, or host...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Filter chips
          _buildFilterChips(),
          const SizedBox(height: 8),
          // Visitor list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No visitors found',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final allVisitors = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Visitor.fromMap(data, doc.id);
                }).toList();

                final filteredVisitors = _filterAndSortVisitors(allVisitors);

                if (filteredVisitors.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No visitors match your filters',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting or clearing your filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Results count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '${filteredVisitors.length} visitor${filteredVisitors.length != 1 ? 's' : ''} found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Visitor list
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredVisitors.length,
                        itemBuilder: (context, index) {
                          return _buildVisitorCard(filteredVisitors[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}