import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  static bool? _cachedRequireApproval;

  static Future<bool> requireApproval() async {
    if (_cachedRequireApproval != null) return _cachedRequireApproval!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('site')
          .get();
      final value = (doc.data()?['requireApproval'] as bool?) ?? true;
      _cachedRequireApproval = value;
      return value;
    } catch (_) {
      // default safe behavior: require approval
      _cachedRequireApproval = true;
      return true;
    }
  }
}


