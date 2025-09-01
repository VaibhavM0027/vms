import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  String? _role;
  String? _username;
  String? _department;
  bool _isLoading = false;

  // Getters
  User? get user => _user;
  String? get role => _role;
  String? get username => _username;
  String? get department => _department;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    try {
      _user = user;
      if (user != null) {
        await _loadUserData();
      } else {
        _clearUserData();
      }
    } catch (e) {
      debugPrint('Error in auth state change: $e');
      _clearUserData();
    }
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;

    try {
      debugPrint('Loading user data for UID: ${_user!.uid}');

      // Add retry logic for Firestore read
      DocumentSnapshot? doc;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          doc = await _firestore.collection('users').doc(_user!.uid).get();
          break;
        } catch (e) {
          retryCount++;
          debugPrint('Firestore read attempt $retryCount failed: $e');
          if (retryCount >= maxRetries) rethrow;
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }

      if (doc != null && doc.exists) {
        final data = doc.data();
        if (data != null && data is Map<String, dynamic>) {
          _role = data['role']?.toString();
          _username = data['username']?.toString() ?? _user!.displayName ?? _user!.email;
          _department = data['department']?.toString();
          debugPrint('User data loaded - Role: $_role, Username: $_username');
        } else {
          debugPrint('Warning: Invalid user document data format');
          _clearUserData();
        }
      } else {
        debugPrint('Warning: User document does not exist in Firestore for UID: ${_user!.uid}');
        _clearUserData();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _clearUserData();
    }
  }

  void _clearUserData() {
    _role = null;
    _username = null;
    _department = null;
  }

  Future<String?> signIn({required String email, required String password}) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('Attempting login for email: $email');

      // Validate input
      if (email.trim().isEmpty || password.isEmpty) {
        return 'Please enter both email and password';
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        debugPrint('Firebase Auth login successful: ${credential.user!.uid}');

        // Wait a moment for auth state to settle and ensure Firebase is ready
        await Future.delayed(const Duration(milliseconds: 1000));

        // Load user data and verify Firestore document exists
        await _loadUserData();

        if (_role == null) {
          debugPrint('Warning: User role not found in Firestore');
          // Create a basic user profile if missing
          try {
            await _createMissingUserProfile(credential.user!);
            await _loadUserData();

            if (_role == null) {
              await _auth.signOut();
              return 'Unable to load user profile. Your account may need to be set up by an administrator. Please contact support.';
            }
          } catch (profileError) {
            debugPrint('Failed to create user profile: $profileError');
            await _auth.signOut();
            return 'Account setup failed. Please try again or contact administrator if the problem persists.';
          }
        }

        debugPrint('Login successful with role: $_role');
        return null; // Success
      }
      return 'Login failed - no user credential returned';
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during login: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email address';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'user-disabled':
          return 'This account has been disabled. Contact administrator.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please wait and try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'invalid-credential':
          return 'Invalid email or password. Please check your credentials.';
        case 'channel-error':
          return 'Connection error. Please try again.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled. Contact administrator.';
        default:
          return 'Login failed: ${e.message ?? 'Unknown error occurred'}';
      }
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException during login: ${e.code} - ${e.message}');
      return 'Database connection error. Please try again.';
    } catch (e, stackTrace) {
      debugPrint('Unexpected error during login: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'Connection error. Please check your internet and try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createMissingUserProfile(User user) async {
    try {
      debugPrint('Creating missing user profile for: ${user.uid}');
      
      // Check if document already exists but has invalid data
      final existingDoc = await _firestore.collection('users').doc(user.uid).get();
      
      final userData = <String, dynamic>{
        'email': user.email ?? '',
        'username': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'role': 'admin', // Default role for missing profiles
        'department': null,
        'createdAt': existingDoc.exists && existingDoc.data() != null && existingDoc.data()!['createdAt'] != null 
            ? existingDoc.data()!['createdAt'] 
            : FieldValue.serverTimestamp(),
        'isActive': true,
        'profileCreated': 'auto-generated',
        'uid': user.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Use multiple attempts with exponential backoff
      int attempts = 0;
      const maxAttempts = 5;
      
      while (attempts < maxAttempts) {
        try {
          await _firestore.collection('users').doc(user.uid).set(
            userData,
            SetOptions(merge: true),
          );
          
          // Wait a moment for Firestore to process
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Verify the document was created with proper data
          final verifyDoc = await _firestore.collection('users').doc(user.uid).get();
          if (verifyDoc.exists) {
            final data = verifyDoc.data();
            if (data != null && data['role'] != null && data['email'] != null) {
              debugPrint('Missing user profile created successfully with role: ${data['role']}');
              return; // Success
            }
          }
          
          throw Exception('Document created but verification failed');
        } catch (e) {
          attempts++;
          debugPrint('Attempt $attempts failed: $e');
          if (attempts >= maxAttempts) {
            rethrow;
          }
          // Exponential backoff
          await Future.delayed(Duration(milliseconds: 1000 * attempts));
        }
      }
    } catch (e) {
      debugPrint('Error creating missing user profile after all attempts: $e');
      rethrow;
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String role,
    String? department,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('Starting user registration for email: $email, role: $role');

      // Validate inputs
      if (email.trim().isEmpty || password.isEmpty || username.trim().isEmpty) {
        return 'Please fill in all required fields';
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        debugPrint('Firebase Auth user created successfully: ${credential.user!.uid}');

        try {
          // Create user document in Firestore with proper error handling
          final userData = <String, dynamic>{
            'email': email.trim(),
            'username': username.trim(),
            'role': role,
            'department': department?.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'uid': credential.user!.uid,
          };

          debugPrint('Creating Firestore document with data: $userData');

          // Use set with merge option for better reliability
          await _firestore.collection('users').doc(credential.user!.uid).set(
            userData,
            SetOptions(merge: true),
          );
          debugPrint('Firestore document created successfully');

          // Update display name
          await credential.user!.updateDisplayName(username.trim());
          debugPrint('Display name updated successfully');

          // Verify the document was created
          final verifyDoc = await _firestore.collection('users').doc(credential.user!.uid).get();
          if (!verifyDoc.exists) {
            throw Exception('Failed to verify user document creation');
          }

          // Sign out the user after registration so they can login normally
          await _auth.signOut();
          debugPrint('User signed out after registration');

          return null; // Success
        } catch (firestoreError) {
          debugPrint('Error creating user profile: $firestoreError');
          // If Firestore fails, delete the auth user to prevent orphaned accounts
          try {
            await credential.user!.delete();
            debugPrint('Cleaned up orphaned auth user');
          } catch (deleteError) {
            debugPrint('Failed to cleanup auth user: $deleteError');
          }
          return 'Failed to create user profile in database. Please try again.';
        }
      }
      return 'Registration failed - no user credential returned';
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during registration: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'weak-password':
          return 'Password is too weak (minimum 6 characters required)';
        case 'email-already-in-use':
          return 'An account already exists with this email address';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'operation-not-allowed':
          return 'Email/password registration is not enabled. Please contact administrator.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection and try again.';
        case 'channel-error':
          return 'Connection error. Please check your internet connection and try again.';
        default:
          return 'Registration failed: ${e.message ?? e.code}';
      }
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException during registration: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Permission denied. Please check Firestore security rules.';
      }
      return 'Database error: ${e.message ?? e.code}';
    } catch (e, stackTrace) {
      debugPrint('Unexpected error during registration: $e');
      debugPrint('Stack trace: $stackTrace');
      return 'An unexpected error occurred during registration. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return 'Failed to send reset email: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  Future<String?> updateProfile({
    String? username,
    String? department,
  }) async {
    if (_user == null) return 'Not authenticated';

    try {
      final updates = <String, dynamic>{};
      if (username != null) {
        updates['username'] = username;
        await _user!.updateDisplayName(username);
      }
      if (department != null) updates['department'] = department;

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('users').doc(_user!.uid).update(updates);
        await _loadUserData();
      }

      return null; // Success
    } catch (e) {
      return 'Failed to update profile: $e';
    }
  }

  // Legacy method for backward compatibility
  void login({required String username, required String role}) {
    // This method is deprecated - use signIn instead
    debugPrint('Warning: Using deprecated login method');
  }

  // Legacy method for backward compatibility
  void logout() {
    signOut();
  }
}
