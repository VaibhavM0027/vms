import 'package:flutter/material.dart';
import '../models/host_model.dart';
import '../services/host_service.dart';

class HostManagementScreen extends StatefulWidget {
  const HostManagementScreen({super.key});

  @override
  State<HostManagementScreen> createState() => _HostManagementScreenState();
}

class _HostManagementScreenState extends State<HostManagementScreen> {
  final HostService _hostService = HostService();
  final _searchController = TextEditingController();
  bool _showInactive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddHostDialog() {
    showDialog(
      context: context,
      builder: (context) => AddHostDialog(hostService: _hostService),
    );
  }

  void _showEditHostDialog(Host host) {
    showDialog(
      context: context,
      builder: (context) => EditHostDialog(host: host, hostService: _hostService),
    );
  }

  void _toggleHostStatus(Host host) async {
    try {
      if (host.isActive) {
        await _hostService.deactivateHost(host.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${host.name} deactivated')),
        );
      } else {
        await _hostService.activateHost(host.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${host.name} activated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Host Management'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
            },
            tooltip: _showInactive ? 'Hide Inactive' : 'Show Inactive',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddHostDialog,
            tooltip: 'Add Host',
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Colors.grey[100]),
                decoration: InputDecoration(
                  hintText: 'Search hosts by name or email...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[850],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  // Implement search functionality
                },
              ),
            ),
            
            // Host List
            Expanded(
              child: StreamBuilder<List<Host>>(
                stream: _showInactive 
                    ? _hostService.getAllHosts()
                    : _hostService.getAllActiveHosts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading hosts: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final hosts = snapshot.data ?? [];
                  
                  if (hosts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No hosts found',
                            style: TextStyle(color: Colors.grey[300], fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first host to get started',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showAddHostDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Host'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return Card(
                        color: Colors.grey[850],
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: host.isActive ? Colors.green : Colors.grey,
                            child: Text(
                              host.name.isNotEmpty ? host.name[0].toUpperCase() : 'H',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            host.name,
                            style: TextStyle(
                              color: Colors.grey[100],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                host.email,
                                style: TextStyle(color: Colors.grey[300]),
                              ),
                              Text(
                                '${host.department}${host.designation != null ? ' • ${host.designation}' : ''}',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            color: Colors.grey[800],
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _showEditHostDialog(host);
                                  break;
                                case 'toggle':
                                  _toggleHostStatus(host);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Edit', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      host.isActive ? Icons.block : Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      host.isActive ? 'Deactivate' : 'Activate',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
}

class AddHostDialog extends StatefulWidget {
  final HostService hostService;

  const AddHostDialog({super.key, required this.hostService});

  @override
  State<AddHostDialog> createState() => _AddHostDialogState();
}

class _AddHostDialogState extends State<AddHostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _designationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _addHost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final host = Host(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        department: _departmentController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        designation: _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        createdAt: DateTime.now(),
      );

      await widget.hostService.addHost(host);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[850],
      title: const Text('Add New Host', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departmentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Department',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter department';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _designationController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Designation (Optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addHost,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Add Host'),
        ),
      ],
    );
  }
}

class EditHostDialog extends StatefulWidget {
  final Host host;
  final HostService hostService;

  const EditHostDialog({super.key, required this.host, required this.hostService});

  @override
  State<EditHostDialog> createState() => _EditHostDialogState();
}

class _EditHostDialogState extends State<EditHostDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _departmentController;
  late final TextEditingController _phoneController;
  late final TextEditingController _designationController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.host.name);
    _emailController = TextEditingController(text: widget.host.email);
    _departmentController = TextEditingController(text: widget.host.department);
    _phoneController = TextEditingController(text: widget.host.phone ?? '');
    _designationController = TextEditingController(text: widget.host.designation ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _updateHost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedHost = widget.host.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        department: _departmentController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        designation: _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await widget.hostService.updateHost(updatedHost);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[850],
      title: const Text('Edit Host', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departmentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Department',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter department';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _designationController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Designation (Optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateHost,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
