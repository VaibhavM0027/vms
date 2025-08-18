import 'package:cloud_firestore/cloud_firestore.dart';
import 'offline_database_service.dart';

class AuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineDatabaseService _offlineDb = OfflineDatabaseService();

  // Audit actions
  static const String actionCreate = 'CREATE';
  static const String actionUpdate = 'UPDATE';
  static const String actionDelete = 'DELETE';
  static const String actionLogin = 'LOGIN';
  static const String actionLogout = 'LOGOUT';
  static const String actionApprove = 'APPROVE';
  static const String actionReject = 'REJECT';
  static const String actionCheckIn = 'CHECK_IN';
  static const String actionCheckOut = 'CHECK_OUT';

  // Entity types
  static const String entityVisitor = 'VISITOR';
  static const String entityHost = 'HOST';
  static const String entityUser = 'USER';
  static const String entityAuth = 'AUTH';

  Future<void> logAction({
    required String userId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final auditLog = {
      'userId': userId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'oldData': oldData,
      'newData': newData,
      'description': description,
      'metadata': metadata,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': await _getClientIP(),
      'userAgent': await _getUserAgent(),
    };

    try {
      // Try to save to Firestore first
      await _firestore.collection('audit_logs').add(auditLog);
    } catch (e) {
      // If Firestore fails, save to local database
      await _offlineDb.logAudit(
        userId: userId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        oldData: oldData,
        newData: newData,
      );
    }
  }

  Future<void> logVisitorAction({
    required String userId,
    required String action,
    required String visitorId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    String? description,
  }) async {
    await logAction(
      userId: userId,
      action: action,
      entityType: entityVisitor,
      entityId: visitorId,
      oldData: oldData,
      newData: newData,
      description: description,
    );
  }

  Future<void> logHostAction({
    required String userId,
    required String action,
    required String hostId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    String? description,
  }) async {
    await logAction(
      userId: userId,
      action: action,
      entityType: entityHost,
      entityId: hostId,
      oldData: oldData,
      newData: newData,
      description: description,
    );
  }

  Future<void> logAuthAction({
    required String userId,
    required String action,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    await logAction(
      userId: userId,
      action: action,
      entityType: entityAuth,
      entityId: userId,
      description: description,
      metadata: metadata,
    );
  }

  Stream<QuerySnapshot> getAuditLogs({
    String? userId,
    String? entityType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) {
    Query query = _firestore.collection('audit_logs');

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (entityType != null) {
      query = query.where('entityType', isEqualTo: entityType);
    }

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: endDate);
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getOfflineAuditLogs({
    String? userId,
    String? entityType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _offlineDb.getAuditLogs(
      userId: userId,
      entityType: entityType,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<Map<String, int>> getAuditStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('audit_logs');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final logs = snapshot.docs;

      final stats = <String, int>{};
      
      for (final doc in logs) {
        final data = doc.data() as Map<String, dynamic>;
        final action = data['action'] as String;
        stats[action] = (stats[action] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      // Fallback to offline data
      final offlineLogs = await _offlineDb.getAuditLogs(
        startDate: startDate,
        endDate: endDate,
      );

      final stats = <String, int>{};
      for (final log in offlineLogs) {
        final action = log['action'] as String;
        stats[action] = (stats[action] ?? 0) + 1;
      }

      return stats;
    }
  }

  Future<String> _getClientIP() async {
    // In a real app, you might get this from a service
    return 'Unknown';
  }

  Future<String> _getUserAgent() async {
    // In a real app, you might get this from device info
    return 'Flutter App';
  }

  Future<void> cleanupOldLogs({int daysToKeep = 90}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    try {
      // Clean up Firestore logs
      final oldLogs = await _firestore
          .collection('audit_logs')
          .where('timestamp', isLessThan: cutoffDate)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Failed to cleanup Firestore audit logs: $e');
    }

    // Clean up offline logs
    await _offlineDb.clearOldData(daysToKeep: daysToKeep);
  }
}
