import 'package:flutter/material.dart';
import 'scan_id_screen.dart';
import 'visitor_list_screen.dart';
import 'checkout_screen.dart';
import 'reports_screen.dart';
import 'guard_scan_screen.dart';
import 'settings_screen.dart';
import 'host_approval_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'pre_register_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthService>(context).role ?? 'admin';
    return Scaffold(
      appBar: AppBar(title: const Text('Visitor Management')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        children: [
          if (role == 'admin' || role == 'receptionist') _buildDashboardItem(
            context,
            Icons.person_add,
            'Register Visitor',
            const ScanIdScreen(),
          ),
          if (role == 'admin' || role == 'receptionist') _buildDashboardItem(
            context,
            Icons.calendar_today,
            'Pre-register',
            const PreRegisterScreen(),
          ),
          if (role == 'admin' || role == 'receptionist') _buildDashboardItem(
            context,
            Icons.people,
            'Visitor List',
            const VisitorListScreen(),
          ),
          if (role == 'admin' || role == 'receptionist') _buildDashboardItem(
            context,
            Icons.exit_to_app,
            'Check-out',
            const CheckoutScreen(),
          ),
          if (role == 'guard' || role == 'admin') _buildDashboardItem(
            context,
            Icons.qr_code_scanner,
            'Guard Scan',
            const GuardScanScreen(),
          ),
          if (role == 'admin' || role == 'host') _buildDashboardItem(
            context,
            Icons.verified_user,
            'Approvals',
            const HostApprovalScreen(),
          ),
          if (role == 'admin') _buildDashboardItem(
            context,
            Icons.analytics,
            'Reports',
            const ReportsScreen(),
          ),
          if (role == 'admin') _buildDashboardItem(
            context,
            Icons.settings,
            'Settings',
            const SettingsScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(
      BuildContext context, IconData icon, String title, Widget screen) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Theme.of(context).primaryColor),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
