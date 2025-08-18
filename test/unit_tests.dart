import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management_system/models/visitor_model.dart';
import 'package:visitor_management_system/models/host_model.dart';
import 'package:visitor_management_system/utils/validation_helper.dart';

void main() {
  group('Visitor Model Tests', () {
    test('should create visitor with valid data', () {
      final visitor = Visitor(
        name: 'John Doe',
        contact: '+1234567890',
        email: 'john@example.com',
        purpose: 'Business meeting',
        hostId: 'host123',
        hostName: 'Jane Smith',
        visitDate: DateTime.now(),
        checkIn: DateTime.now(),
        status: 'pending',
      );

      expect(visitor.name, 'John Doe');
      expect(visitor.contact, '+1234567890');
      expect(visitor.email, 'john@example.com');
      expect(visitor.status, 'pending');
    });

    test('should convert visitor to map', () {
      final visitor = Visitor(
        name: 'John Doe',
        contact: '+1234567890',
        email: 'john@example.com',
        purpose: 'Business meeting',
        hostId: 'host123',
        hostName: 'Jane Smith',
        visitDate: DateTime.now(),
        checkIn: DateTime.now(),
        status: 'pending',
      );

      final map = visitor.toMap();
      expect(map['name'], 'John Doe');
      expect(map['contact'], '+1234567890');
      expect(map['status'], 'pending');
    });

    test('should create visitor from map', () {
      final map = {
        'name': 'John Doe',
        'contact': '+1234567890',
        'email': 'john@example.com',
        'purpose': 'Business meeting',
        'hostId': 'host123',
        'hostName': 'Jane Smith',
        'visitDate': DateTime.now().toIso8601String(),
        'checkIn': DateTime.now().toIso8601String(),
        'status': 'pending',
      };

      final visitor = Visitor.fromMap(map);
      expect(visitor.name, 'John Doe');
      expect(visitor.contact, '+1234567890');
      expect(visitor.status, 'pending');
    });
  });

  group('Host Model Tests', () {
    test('should create host with valid data', () {
      final host = Host(
        name: 'Jane Smith',
        email: 'jane@company.com',
        department: 'Engineering',
        phone: '+1234567890',
        designation: 'Senior Manager',
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(host.name, 'Jane Smith');
      expect(host.email, 'jane@company.com');
      expect(host.department, 'Engineering');
      expect(host.isActive, true);
    });

    test('should convert host to map', () {
      final host = Host(
        name: 'Jane Smith',
        email: 'jane@company.com',
        department: 'Engineering',
        phone: '+1234567890',
        designation: 'Senior Manager',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final map = host.toMap();
      expect(map['name'], 'Jane Smith');
      expect(map['email'], 'jane@company.com');
      expect(map['isActive'], true);
    });
  });

  group('Validation Helper Tests', () {
    group('Email Validation', () {
      test('should validate correct email', () {
        expect(ValidationHelper.validateEmail('test@example.com'), null);
        expect(ValidationHelper.validateEmail('user.name@domain.co.uk'), null);
      });

      test('should reject invalid email', () {
        expect(ValidationHelper.validateEmail(''), 'Email is required');
        expect(ValidationHelper.validateEmail('invalid-email'), 'Please enter a valid email address');
        expect(ValidationHelper.validateEmail('test@'), 'Please enter a valid email address');
        expect(ValidationHelper.validateEmail('@domain.com'), 'Please enter a valid email address');
      });
    });

    group('Phone Validation', () {
      test('should validate correct phone numbers', () {
        expect(ValidationHelper.validatePhone('+1234567890'), null);
        expect(ValidationHelper.validatePhone('1234567890'), null);
        expect(ValidationHelper.validatePhone('+91 9876543210'), null);
      });

      test('should reject invalid phone numbers', () {
        expect(ValidationHelper.validatePhone(''), 'Phone number is required');
        expect(ValidationHelper.validatePhone('123'), 'Phone number must be at least 10 digits');
        expect(ValidationHelper.validatePhone('abc1234567'), 'Please enter a valid phone number');
      });
    });

    group('Name Validation', () {
      test('should validate correct names', () {
        expect(ValidationHelper.validateName('John Doe'), null);
        expect(ValidationHelper.validateName('Mary-Jane Smith'), null);
        expect(ValidationHelper.validateName('O\'Connor'), null);
      });

      test('should reject invalid names', () {
        expect(ValidationHelper.validateName(''), 'Name is required');
        expect(ValidationHelper.validateName('A'), 'Name must be at least 2 characters long');
        expect(ValidationHelper.validateName('John123'), 'Name can only contain letters, spaces, hyphens, and dots');
      });
    });

    group('Password Validation', () {
      test('should validate strong passwords', () {
        expect(ValidationHelper.validatePassword('Password123'), null);
        expect(ValidationHelper.validatePassword('MySecure1Pass'), null);
      });

      test('should reject weak passwords', () {
        expect(ValidationHelper.validatePassword(''), 'Password is required');
        expect(ValidationHelper.validatePassword('weak'), 'Password must be at least 8 characters long');
        expect(ValidationHelper.validatePassword('password'), 'Password must contain at least one uppercase letter, one lowercase letter, and one number');
        expect(ValidationHelper.validatePassword('PASSWORD123'), 'Password must contain at least one uppercase letter, one lowercase letter, and one number');
      });
    });

    group('Purpose Validation', () {
      test('should validate correct purpose', () {
        expect(ValidationHelper.validatePurpose('Business meeting with the team'), null);
        expect(ValidationHelper.validatePurpose('Interview for software engineer position'), null);
      });

      test('should reject invalid purpose', () {
        expect(ValidationHelper.validatePurpose(''), 'Purpose of visit is required');
        expect(ValidationHelper.validatePurpose('Hi'), 'Purpose must be at least 5 characters long');
      });
    });
  });

  group('Input Sanitization Tests', () {
    test('should sanitize input text', () {
      expect(ValidationHelper.sanitizeInput('  Hello World  '), 'Hello World');
      expect(ValidationHelper.sanitizeInput('Test<script>alert("xss")</script>'), 'Testalert("xss")');
      expect(ValidationHelper.sanitizeInput('Multiple   spaces'), 'Multiple spaces');
    });

    test('should sanitize phone numbers', () {
      expect(ValidationHelper.sanitizePhone('+1 (234) 567-8900'), '+12345678900');
      expect(ValidationHelper.sanitizePhone('123-456-7890'), '1234567890');
    });

    test('should sanitize email addresses', () {
      expect(ValidationHelper.sanitizeEmail('  TEST@EXAMPLE.COM  '), 'test@example.com');
      expect(ValidationHelper.sanitizeEmail('User.Name@Domain.Com'), 'user.name@domain.com');
    });
  });

  group('Date Validation Tests', () {
    test('should validate future dates', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(ValidationHelper.validateFutureDate(tomorrow), null);
    });

    test('should reject past dates', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(ValidationHelper.validateFutureDate(yesterday), 'Please select a future date');
    });

    test('should reject dates too far in future', () {
      final farFuture = DateTime.now().add(const Duration(days: 400));
      expect(ValidationHelper.validateFutureDate(farFuture), 'Date cannot be more than 1 year in the future');
    });
  });
}
