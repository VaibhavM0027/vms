import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _departmentController = TextEditingController();
  
  String _selectedRole = 'receptionist';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      role: _selectedRole,
      department: _departmentController.text.trim().isEmpty 
          ? null 
          : _departmentController.text.trim(),
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
      
      // Clear form
      _formKey.currentState!.reset();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _usernameController.clear();
      _departmentController.clear();
      setState(() => _selectedRole = 'receptionist');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Register New User'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[800]!.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_add, size: 32, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Add New User',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.grey[100],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a new user account for the system',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Fields
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[800]!.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Information',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[100],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.person, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.email, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter email address';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Role Selection
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Role',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.work, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        dropdownColor: Colors.grey[850],
                        items: kRoles.map((role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(color: Colors.grey[100]),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedRole = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Department Field (Optional)
                      TextFormField(
                        controller: _departmentController,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Department (Optional)',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.business, color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.lock, color: Colors.grey[400]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey[400],
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
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(value)) {
                            return 'Password must contain letters and numbers';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        style: TextStyle(color: Colors.grey[100]),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm password';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Register Button
                Consumer<AuthService>(
                  builder: (context, auth, child) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
    );
  }
}
