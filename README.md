# Visitor Management System (VMS)

A comprehensive Flutter-based Visitor Management System with Firebase backend integration, designed for real-time production deployment.

## 🚀 Features

### Core Functionality
- **Visitor Registration**: Complete visitor onboarding with ID photo capture and QR code generation
- **Real-time Check-in/Check-out**: QR code scanning for seamless visitor tracking
- **Host Management**: Dynamic host assignment and approval workflows
- **Multi-role Access**: Support for Admin, Receptionist, Host, Guard, and Visitor roles
- **Real-time Notifications**: Firebase Cloud Messaging integration with local notifications
- **Offline Support**: SQLite local database with automatic sync when online
- **Audit Logging**: Comprehensive activity tracking and audit trails

### Advanced Features
- **Search & Filtering**: Advanced visitor list filtering and search capabilities
- **Form Validation**: Comprehensive input validation and sanitization
- **Error Handling**: Robust error management with user-friendly messages
- **Reports & Analytics**: Detailed reporting with charts and export functionality
- **User Management**: Admin interface for managing system users

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **Local Database**: SQLite (sqflite)
- **State Management**: Provider pattern
- **UI Framework**: Material 3 with dark theme

### Project Structure
```
lib/
├── models/           # Data models (Visitor, Host, User)
├── screens/          # UI screens and pages
├── services/         # Business logic and API services
├── utils/            # Utilities and helpers
└── widgets/          # Reusable UI components
```

## 📱 Screens & Navigation

### Authentication
- **Login Screen**: Email/password authentication with role-based access
- **User Registration**: Admin interface for adding new users

### Main Features
- **Dashboard**: Role-based navigation and quick actions
- **Visitor Registration**: Complete visitor onboarding form
- **Visitor List**: Searchable and filterable visitor management
- **Host Management**: CRUD operations for host management
- **Notifications**: Real-time notification center
- **Reports**: Analytics and export functionality

### Specialized Screens
- **QR Scanner**: ID and visitor QR code scanning
- **Check-in/Check-out**: Visitor status management
- **Settings**: System configuration and preferences

## 🔧 Setup & Installation

### Prerequisites
- Flutter SDK (>=3.0.0)
- Firebase project with enabled services
- Android Studio / VS Code
- Git

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd VMS3
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project
   - Enable Authentication, Firestore, Storage, and Messaging
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place configuration files in respective platform folders

4. **Configure Firebase**
   ```bash
   flutter packages pub run build_runner build
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

## 🔐 User Roles & Permissions

### Admin
- Full system access
- User management
- Host management
- System configuration
- All visitor operations
- Reports and analytics

### Receptionist
- Visitor registration
- Check-in/check-out operations
- Visitor list management
- Basic reporting

### Host
- Approve/reject visitor requests
- View assigned visitors
- Receive notifications
- Basic visitor management

### Guard
- QR code scanning
- Check-in/check-out operations
- Visitor verification
- Security monitoring

### Visitor
- Self-registration
- View own visit history
- QR code access
- Status tracking

## 🗄️ Database Schema

### Firestore Collections

#### Users
```json
{
  "uid": "string",
  "email": "string",
  "name": "string",
  "role": "admin|receptionist|host|guard|visitor",
  "department": "string",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### Visitors
```json
{
  "id": "string",
  "name": "string",
  "contact": "string",
  "email": "string",
  "purpose": "string",
  "hostId": "string",
  "hostName": "string",
  "visitDate": "timestamp",
  "checkIn": "timestamp",
  "checkOut": "timestamp",
  "status": "pending|approved|checked-in|completed|rejected",
  "idPhotoUrl": "string",
  "qrCode": "string"
}
```

#### Hosts
```json
{
  "id": "string",
  "name": "string",
  "email": "string",
  "department": "string",
  "phone": "string",
  "designation": "string",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### Notifications
```json
{
  "id": "string",
  "userId": "string",
  "title": "string",
  "body": "string",
  "type": "string",
  "data": "object",
  "isRead": "boolean",
  "createdAt": "timestamp"
}
```

### SQLite Tables (Offline Support)
- `visitors` - Local visitor cache
- `hosts` - Local host cache
- `sync_queue` - Pending sync operations
- `audit_logs` - Local audit trail

## 🔄 Offline Support

The app includes comprehensive offline functionality:

- **Local Database**: SQLite for offline data storage
- **Sync Queue**: Automatic synchronization when online
- **Connectivity Detection**: Real-time network status monitoring
- **Data Persistence**: Critical data cached locally
- **Conflict Resolution**: Smart merge strategies for data conflicts

## 📊 Monitoring & Analytics

### Audit Logging
- User actions tracking
- Data modification logs
- Authentication events
- System access logs
- Error tracking

### Error Handling
- Comprehensive error categorization
- User-friendly error messages
- Automatic retry mechanisms
- Offline error queuing
- Debug logging

## 🚀 Deployment

### Development
```bash
flutter run --debug
```

### Production Build
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release
```

### Firebase Deployment
1. Configure Firebase Hosting (optional)
2. Set up Cloud Functions for server-side logic
3. Configure FCM for push notifications
4. Set up Firestore security rules

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

### Test Coverage
- Model validation tests
- Service layer tests
- Widget tests
- Integration tests

## 📋 Configuration

### Environment Variables
- Firebase configuration
- API endpoints
- Feature flags
- Debug settings

### App Settings
- Theme configuration
- Notification preferences
- Offline sync settings
- Security policies

## 🔒 Security Features

- **Firebase Authentication**: Secure user authentication
- **Role-based Access**: Granular permission system
- **Data Validation**: Input sanitization and validation
- **Audit Trail**: Complete activity logging
- **Secure Storage**: Encrypted local data storage
- **Network Security**: HTTPS/TLS encryption

## 🐛 Troubleshooting

### Common Issues
1. **Firebase Connection**: Check configuration files
2. **Permission Errors**: Verify Firestore security rules
3. **Build Failures**: Run `flutter clean` and `flutter pub get`
4. **Sync Issues**: Check network connectivity

### Debug Mode
Enable debug logging in development:
```dart
const bool kDebugMode = true;
```

## 📞 Support

For technical support or feature requests:
- Create an issue in the repository
- Contact the development team
- Check documentation and FAQs

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📈 Roadmap

### Upcoming Features
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] Biometric authentication
- [ ] Advanced reporting
- [ ] API integrations
- [ ] Mobile app optimization

### Version History
- **v1.0.0**: Initial release with core features
- **v1.1.0**: Added offline support and audit logging
- **v1.2.0**: Enhanced notifications and error handling

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
