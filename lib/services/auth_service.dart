import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  String? _role; // admin | receptionist | guard
  String? _username;

  String? get role => _role;
  String? get username => _username;

  void login({required String username, required String role}) {
    _username = username;
    _role = role;
    notifyListeners();
  }

  void logout() {
    _username = null;
    _role = null;
    notifyListeners();
  }
}
