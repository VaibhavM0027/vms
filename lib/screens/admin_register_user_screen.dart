import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AdminRegisterUserScreen extends StatefulWidget {
  const AdminRegisterUserScreen({super.key});

  @override
  State<AdminRegisterUserScreen> createState() => _AdminRegisterUserScreenState();
}

class _AdminRegisterUserScreenState extends State<AdminRegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _departmentController = TextEditingController();
  String _selectedRole = 'admin';

  final List<String> _roles = ['admin', 'receptionist', 'host', 'guard'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      role: _selectedRole,
      department: _departmentController.text.trim().isNotEmpty 
          ? _departmentController.text.trim() 
          : null,
    );

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
          content: Text('User registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Register New User'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
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
                      if (value == null || value.isEmpty) {
                        return 'Please enter email address';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: Colors.grey[100]!),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock, color: Colors.grey[400]!),
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
                  const SizedBox(height: 20),
                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    style: TextStyle(color: Colors.grey[100]!),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person, color: Colors.grey[400]!),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Role dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    style: TextStyle(color: Colors.grey[100]!),
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.work, color: Colors.grey[400]!),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    dropdownColor: Colors.grey[800],
                    items: _roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(color: Colors.grey[100]!),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // Department field (optional)
                  TextFormField(
                    controller: _departmentController,
                    style: TextStyle(color: Colors.grey[100]!),
                    decoration: InputDecoration(
                      labelText: 'Department (Optional)',
                      prefixIcon: Icon(Icons.business, color: Colors.grey[400]!),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Register button
                  Consumer<AuthService>(
                    builder: (context, auth, child) {
                      return SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: auth.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'REGISTER USER',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
