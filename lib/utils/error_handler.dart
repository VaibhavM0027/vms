import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audit_service.dart';

class ErrorHandler {
  static final AuditService _auditService = AuditService();

  // Error types
  static const String errorAuth = 'AUTH_ERROR';
  static const String errorNetwork = 'NETWORK_ERROR';
  static const String errorFirestore = 'FIRESTORE_ERROR';
  static const String errorValidation = 'VALIDATION_ERROR';
  static const String errorPermission = 'PERMISSION_ERROR';
  static const String errorUnknown = 'UNKNOWN_ERROR';

  static Future<void> handleError({
    required BuildContext context,
    required dynamic error,
    String? userId,
    String? action,
    String? entityType,
    String? entityId,
    bool showSnackBar = true,
    VoidCallback? onRetry,
  }) async {
    String errorType = _getErrorType(error);
    String userMessage = _getUserMessage(error, errorType);
    String technicalMessage = error.toString();

    // Log error for audit
    if (userId != null) {
      await _auditService.logAction(
        userId: userId,
        action: 'ERROR',
        entityType: entityType ?? 'SYSTEM',
        entityId: entityId ?? 'N/A',
        description: 'Error occurred: $errorType',
        metadata: {
          'errorType': errorType,
          'technicalMessage': technicalMessage,
          'action': action,
        },
      );
    }

    // Show user-friendly message
    if (showSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: _getErrorColor(errorType),
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: onRetry,
                  textColor: Colors.white,
                )
              : null,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // Log to console for debugging
    debugPrint('Error [$errorType]: $technicalMessage');
  }

  static String _getErrorType(dynamic error) {
    if (error is FirebaseAuthException) {
      return errorAuth;
    } else if (error is FirebaseException) {
      return errorFirestore;
    } else if (error.toString().contains('network') || 
               error.toString().contains('connection') ||
               error.toString().contains('timeout')) {
      return errorNetwork;
    } else if (error.toString().contains('permission') ||
               error.toString().contains('unauthorized')) {
      return errorPermission;
    } else if (error.toString().contains('validation') ||
               error.toString().contains('invalid')) {
      return errorValidation;
    } else {
      return errorUnknown;
    }
  }

  static String _getUserMessage(dynamic error, String errorType) {
    switch (errorType) {
      case errorAuth:
        return _getAuthErrorMessage(error as FirebaseAuthException);
      case errorNetwork:
        return 'Network connection issue. Please check your internet connection and try again.';
      case errorFirestore:
        return 'Database error occurred. Please try again later.';
      case errorValidation:
        return 'Invalid data provided. Please check your input and try again.';
      case errorPermission:
        return 'You don\'t have permission to perform this action.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static String _getAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Authentication error: ${error.message ?? 'Unknown error'}';
    }
  }

  static Color _getErrorColor(String errorType) {
    switch (errorType) {
      case errorAuth:
        return Colors.red[700]!;
      case errorNetwork:
        return Colors.orange[700]!;
      case errorFirestore:
        return Colors.purple[700]!;
      case errorValidation:
        return Colors.amber[700]!;
      case errorPermission:
        return Colors.red[800]!;
      default:
        return Colors.grey[700]!;
    }
  }

  // Specific error handlers for common scenarios
  static Future<void> handleAuthError({
    required BuildContext context,
    required FirebaseAuthException error,
    String? userId,
    VoidCallback? onRetry,
  }) async {
    await handleError(
      context: context,
      error: error,
      userId: userId,
      action: 'AUTHENTICATION',
      entityType: 'AUTH',
      onRetry: onRetry,
    );
  }

  static Future<void> handleFirestoreError({
    required BuildContext context,
    required FirebaseException error,
    String? userId,
    String? collection,
    String? documentId,
    VoidCallback? onRetry,
  }) async {
    await handleError(
      context: context,
      error: error,
      userId: userId,
      action: 'FIRESTORE_OPERATION',
      entityType: collection?.toUpperCase(),
      entityId: documentId,
      onRetry: onRetry,
    );
  }

  static Future<void> handleNetworkError({
    required BuildContext context,
    required dynamic error,
    String? userId,
    String? operation,
    VoidCallback? onRetry,
  }) async {
    await handleError(
      context: context,
      error: error,
      userId: userId,
      action: operation ?? 'NETWORK_OPERATION',
      entityType: 'NETWORK',
      onRetry: onRetry,
    );
  }

  static Future<void> handleValidationError({
    required BuildContext context,
    required String message,
    String? userId,
    String? field,
  }) async {
    await handleError(
      context: context,
      error: Exception(message),
      userId: userId,
      action: 'VALIDATION',
      entityType: 'FORM',
      entityId: field,
    );
  }

  // Error boundary for widgets
  static Widget errorBoundary({
    required Widget child,
    Widget? fallback,
    Function(dynamic error)? onError,
  }) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error) {
          onError?.call(error);
          return fallback ?? _defaultErrorWidget(error);
        }
      },
    );
  }

  static Widget _defaultErrorWidget(dynamic error) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  // Retry mechanism with exponential backoff
  static Future<T> retryOperation<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }

    throw Exception('Max retries exceeded');
  }

  // Safe async operation wrapper
  static Future<T?> safeAsyncOperation<T>({
    required Future<T> Function() operation,
    BuildContext? context,
    String? userId,
    String? operationName,
    T? fallbackValue,
    bool showError = true,
  }) async {
    try {
      return await operation();
    } catch (error) {
      if (context != null && showError) {
        await handleError(
          context: context,
          error: error,
          userId: userId,
          action: operationName,
        );
      }
      return fallbackValue;
    }
  }
}
