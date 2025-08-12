import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  bool _requireApproval = true;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Site'),
            Tab(text: 'Users'),
            Tab(text: 'FAQs'),
            Tab(text: 'Gadgets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          _SiteTab(requireApproval: _requireApproval, onChanged: (v) async {
            setState(() => _requireApproval = v);
            // Persist to Firestore config/site
            try {
              await FirebaseFirestore.instance
                  .collection('config')
                  .doc('site')
                  .set({'requireApproval': v}, SetOptions(merge: true));
            } catch (_) {}
          }),
          const _UsersTab(),
          const _FaqsTab(),
          const _GadgetsTab(),
        ],
      ),
    );
  }
}

class _SiteTab extends StatelessWidget {
  final bool requireApproval;
  final ValueChanged<bool> onChanged;
  const _SiteTab({required this.requireApproval, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Site Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Require host/admin approval before entry'),
            value: requireApproval,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _usernameController = TextEditingController();
  String _selectedRole = 'receptionist';

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _addOrUpdateUser() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .set({'role': _selectedRole}, SetOptions(merge: true));
      _usernameController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage Users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username (unique)', prefixIcon: Icon(Icons.person)),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
                  DropdownMenuItem(value: 'host', child: Text('Host')),
                  DropdownMenuItem(value: 'guard', child: Text('Guard')),
                  DropdownMenuItem(value: 'visitor', child: Text('Visitor')),
                ],
                onChanged: (v) => setState(() => _selectedRole = v ?? _selectedRole),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _addOrUpdateUser, child: const Text('Save')),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Existing Users'),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No users'));
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(d.id),
                      subtitle: Text('Role: ${d.data()['role'] ?? 'unknown'}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('users').doc(d.id).delete();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqsTab extends StatelessWidget {
  const _FaqsTab();

  @override
  Widget build(BuildContext context) {
    const faqs = [
      {
        'q': 'How to register a visitor?',
        'a': 'Use Register flow on Dashboard.'
      },
      {'q': 'How to check-out a visitor?', 'a': 'Open Check-out and confirm.'},
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: faqs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final item = faqs[index];
        return ListTile(
          title: Text(item['q']!),
          subtitle: Text(item['a']!),
        );
      },
    );
  }
}

class _GadgetsTab extends StatelessWidget {
  const _GadgetsTab();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gadget Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text(
              'No hardware configured. You can add printers, RFID, camera, and signature devices later.'),
        ],
      ),
    );
  }
}
