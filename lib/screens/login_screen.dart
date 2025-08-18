import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'guard_scan_screen.dart';
import 'visitor_self_register_screen.dart';
import 'host_approval_screen.dart';
import 'admin_register_user_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _showForgotPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final auth = Provider.of<AuthService>(context, listen: false);
    
    try {
      final error = await auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      } else {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${auth.username ?? 'User'}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        // Navigate based on role
        Widget next;
        switch (auth.role) {
          case 'guard':
            next = const GuardScanScreen();
            break;
          case 'visitor':
            next = const VisitorSelfRegisterScreen();
            break;
          case 'host':
            next = const HostApprovalScreen();
            break;
          case 'admin':
          case 'receptionist':
          default:
            next = const DashboardScreen();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => next),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _showForgotPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  // Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[850]!,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey[800]!.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.login,
                      size: 60,
                      color: Colors.grey[300]!,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: Colors.grey[100]!,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      color: Colors.grey[400]!,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Colors.grey[100]!),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email, color: Colors.grey[400]!),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter email address';
                      }
                      final email = value.trim();
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: TextStyle(color: Colors.grey[100]!),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock, color: Colors.grey[400]!),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey[400]!,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Forgot password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() => _showForgotPassword = !_showForgotPassword);
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  if (_showForgotPassword) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800]!,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Enter your email address to receive a password reset link',
                            style: TextStyle(color: Colors.grey[300]!),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _resetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Send Reset Email'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() => _showForgotPassword = false);
                                },
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  // Login button
                  Consumer<AuthService>(
                    builder: (context, auth, child) {
                      return SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800]!,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: auth.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Visitor Registration Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[600]!, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VisitorSelfRegisterScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[300]!,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, color: Colors.grey[400]!),
                          const SizedBox(width: 8),
                          const Text(
                            'NEW VISITOR? REGISTER HERE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Admin Register Button (Development only)
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange[600]!, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminRegisterUserScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[300]!,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.orange[400]!, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'REGISTER ADMIN/STAFF USER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Help text
                  Text(
                    'Staff members use email/password login above.\nVisitors use self-registration button.',
                    style: TextStyle(
                      color: Colors.grey[500]!,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
