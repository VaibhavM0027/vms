import 'package:flutter/material.dart';
import 'scan_id_screen.dart';
import 'visitor_list_screen.dart';
import 'checkout_screen.dart';
import 'reports_screen.dart';
import 'guard_scan_screen.dart';
import 'settings_screen.dart';
import 'host_approval_screen.dart';
import 'visitor_self_register_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'pre_register_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthService>(context).role ?? 'admin';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Visitor Management'),
        backgroundColor: Colors.black,
        elevation: 0,
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
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(20),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            if (role == 'admin' || role == 'receptionist')
              _buildDashboardItem(
                context,
                Icons.person_add,
                'Register Visitor',
                const ScanIdScreen(),
              ),
            if (role == 'admin' || role == 'receptionist')
              _buildDashboardItem(
                context,
                Icons.calendar_today,
                'Pre-register',
                const PreRegisterScreen(),
              ),
            if (role == 'admin' || role == 'receptionist')
              _buildDashboardItem(
                context,
                Icons.people,
                'Visitor List',
                const VisitorListScreen(),
              ),
            if (role == 'admin' || role == 'receptionist')
              _buildDashboardItem(
                context,
                Icons.exit_to_app,
                'Check-out',
                const CheckoutScreen(),
              ),
            if (role == 'guard' || role == 'admin')
              _buildDashboardItem(
                context,
                Icons.qr_code_scanner,
                'Guard Scan',
                const GuardScanScreen(),
              ),
            if (role == 'admin' || role == 'host')
              _buildDashboardItem(
                context,
                Icons.verified_user,
                'Approvals',
                const HostApprovalScreen(),
              ),
            if (role == 'admin')
              _buildDashboardItem(
                context,
                Icons.analytics,
                'Reports',
                const ReportsScreen(),
              ),
            if (role == 'admin')
              _buildDashboardItem(
                context,
                Icons.settings,
                'Settings',
                const SettingsScreen(),
              ),
            // Add visitor self-registration option for all roles
            _buildDashboardItem(
              context,
              Icons.qr_code,
              'Self Register',
              const VisitorSelfRegisterScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem(
      BuildContext context, IconData icon, String title, Widget screen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850]!,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[800]!.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800]!,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: Colors.grey[300]!,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[100]!,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
