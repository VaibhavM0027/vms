import 'package:flutter/material.dart';
import 'scan_id_screen.dart';
import 'visitor_list_screen.dart';
import 'checkout_screen.dart';
import 'reports_screen.dart';
import 'guard_scan_screen.dart';
import 'settings_screen.dart';
import 'host_approval_screen.dart';
import 'visitor_self_register_screen.dart';
import 'host_management_screen.dart';
import 'notifications_screen.dart';
import 'user_registration_screen.dart';
import 'guard_register_visitor_screen.dart';
import 'all_visitor_history_screen.dart';
import 'entry_exit_history_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/visitor_service.dart';
import 'pre_register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _buildNotificationButton(BuildContext context, String role) {
    final FirebaseServices _firebaseServices = FirebaseServices();
    
    if (role == 'admin' || role == 'host') {
      return StreamBuilder(
        stream: _firebaseServices.getAllPendingVisitors(),
        builder: (context, snapshot) {
          int pendingCount = 0;
          if (snapshot.hasData) {
            pendingCount = snapshot.data?.length ?? 0;
          }
          
          return Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                },
                tooltip: 'Notifications',
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
        tooltip: 'Notifications',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final role = auth.role ?? 'admin';

    // Ensure notification listeners are initialized and start admin event popups
    NotificationService().initialize();
    if (role == 'admin') {
      NotificationService().startAdminEventListeners();
    } else {
      NotificationService().stopAdminEventListeners();
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('VMS Dashboard'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          _buildNotificationButton(context, role),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigate to login screen instead of just popping
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/login', 
                (route) => false
              );
            },
            tooltip: 'Logout',
          ),
        ],
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
                Icons.history,
                'Visitor History',
                const AllVisitorHistoryScreen(),
              ),
            if (role == 'admin' || role == 'receptionist')
              _buildDashboardItem(
                context,
                Icons.timeline,
                'Entry/Exit History',
                const EntryExitHistoryScreen(),
              ),
            // Checkout button for all roles (admin, receptionist, visitor)
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
            if (role == 'guard' || role == 'admin')
              _buildDashboardItem(
                context,
                Icons.app_registration,
                'Register Visitor',
                const GuardRegisterVisitorScreen(),
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
                Icons.people_alt,
                'Host Management',
                const HostManagementScreen(),
              ),
            if (role == 'admin')
              _buildDashboardItem(
                context,
                Icons.person_add_alt,
                'Add User',
                const UserRegistrationScreen(),
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
            // Add visitor list for visitors to see their own visits
            if (role == 'visitor')
              _buildDashboardItem(
                context,
                Icons.list_alt,
                'My Visits',
                const VisitorListScreen(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem(
      BuildContext context, IconData icon, String title, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.blue[300]),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[100],
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
