import 'dart:io';
import 'package:flutter/material.dart';

class ValidationHelper {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  // Phone number validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    
    final phoneRegex = RegExp(r'^[\+]?[1-9][\d]{0,15}$');
    if (!phoneRegex.hasMatch(cleanPhone)) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }

  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    final trimmedValue = value.trim();
    if (trimmedValue.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    
    if (trimmedValue.length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    final nameRegex = RegExp(r'^[a-zA-Z\s\-\.]+$');
    if (!nameRegex.hasMatch(trimmedValue)) {
      return 'Name can only contain letters, spaces, hyphens, and dots';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    if (value.length > 128) {
      return 'Password must be less than 128 characters';
    }
    
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter, one lowercase letter, and one number';
    }
    
    return null;
  }

  // Purpose validation
  static String? validatePurpose(String? value) {
    if (value == null || value.isEmpty) {
      return 'Purpose of visit is required';
    }
    
    final trimmedValue = value.trim();
    if (trimmedValue.length < 5) {
      return 'Purpose must be at least 5 characters long';
    }
    
    if (trimmedValue.length > 200) {
      return 'Purpose must be less than 200 characters';
    }
    
    return null;
  }

  // Company validation
  static String? validateCompany(String? value) {
    if (value == null || value.isEmpty) {
      return 'Company name is required';
    }
    
    final trimmedValue = value.trim();
    if (trimmedValue.length < 2) {
      return 'Company name must be at least 2 characters long';
    }
    
    if (trimmedValue.length > 100) {
      return 'Company name must be less than 100 characters';
    }
    
    return null;
  }

  // Generic required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Sanitize input text
  static String sanitizeInput(String input) {
    return input.trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[^\w\s\-\.\@\+\(\)\/]'), '') // Remove special chars except common ones
        .replaceAll(RegExp(r'\s+'), ' '); // Replace multiple spaces with single space
  }

  // Sanitize phone number
  static String sanitizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d\+]'), '');
  }

  // Sanitize email
  static String sanitizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  // File validation
  static String? validateImageFile(File? file) {
    if (file == null) {
      return 'Image is required';
    }
    
    final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
    final extension = file.path.split('.').last.toLowerCase();
    
    if (!allowedExtensions.contains(extension)) {
      return 'Only JPG, JPEG, PNG, and GIF files are allowed';
    }
    
    // Check file size (5MB limit)
    final fileSizeInBytes = file.lengthSync();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    
    if (fileSizeInMB > 5) {
      return 'Image size must be less than 5MB';
    }
    
    return null;
  }

  // Date validation
  static String? validateFutureDate(DateTime? date) {
    if (date == null) {
      return 'Date is required';
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    
    if (selectedDate.isBefore(today)) {
      return 'Please select a future date';
    }
    
    // Don't allow dates more than 1 year in the future
    final oneYearFromNow = today.add(const Duration(days: 365));
    if (selectedDate.isAfter(oneYearFromNow)) {
      return 'Date cannot be more than 1 year in the future';
    }
    
    return null;
  }
}
