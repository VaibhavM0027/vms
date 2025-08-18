import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/visitor_model.dart';
import '../models/host_model.dart';

class OfflineDatabaseService {
  static Database? _database;
  static final OfflineDatabaseService _instance = OfflineDatabaseService._internal();
  
  factory OfflineDatabaseService() => _instance;
  OfflineDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vms_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Visitors table
    await db.execute('''
      CREATE TABLE visitors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact TEXT NOT NULL,
        email TEXT NOT NULL,
        purpose TEXT NOT NULL,
        hostId TEXT NOT NULL,
        hostName TEXT NOT NULL,
        visitDate TEXT NOT NULL,
        checkIn TEXT NOT NULL,
        checkOut TEXT,
        status TEXT NOT NULL,
        idPhotoUrl TEXT,
        qrCode TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Hosts table
    await db.execute('''
      CREATE TABLE hosts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        department TEXT NOT NULL,
        phone TEXT NOT NULL,
        designation TEXT NOT NULL,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Sync queue table for pending operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Audit logs table
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        action TEXT NOT NULL,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        oldData TEXT,
        newData TEXT,
        timestamp TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // Visitor operations
  Future<String> insertVisitor(Visitor visitor) async {
    final db = await database;
    final id = visitor.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    await db.insert('visitors', {
      'id': id,
      'name': visitor.name,
      'contact': visitor.contact,
      'email': visitor.email,
      'purpose': visitor.purpose,
      'hostId': visitor.hostId,
      'hostName': visitor.hostName,
      'visitDate': visitor.visitDate.toIso8601String(),
      'checkIn': visitor.checkIn.toIso8601String(),
      'checkOut': visitor.checkOut?.toIso8601String(),
      'status': visitor.status,
      'idPhotoUrl': null,
      'qrCode': visitor.qrCode,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Add to sync queue if online
    await _addToSyncQueue('INSERT', 'visitors', id, jsonEncode(visitor.toMap()));
    
    return id;
  }

  Future<void> updateVisitor(String id, Map<String, dynamic> updates) async {
    final db = await database;
    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['synced'] = 0;
    
    await db.update('visitors', updates, where: 'id = ?', whereArgs: [id]);
    await _addToSyncQueue('UPDATE', 'visitors', id, jsonEncode(updates));
  }

  Future<List<Visitor>> getAllVisitors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('visitors');
    
    return List.generate(maps.length, (i) {
      return Visitor(
        id: maps[i]['id'],
        name: maps[i]['name'],
        contact: maps[i]['contact'],
        email: maps[i]['email'],
        purpose: maps[i]['purpose'],
        hostId: maps[i]['hostId'],
        hostName: maps[i]['hostName'],
        visitDate: DateTime.parse(maps[i]['visitDate']),
        checkIn: DateTime.parse(maps[i]['checkIn']),
        checkOut: maps[i]['checkOut'] != null ? DateTime.parse(maps[i]['checkOut']) : null,
        status: maps[i]['status'],
        // idPhotoUrl: maps[i]['idPhotoUrl'],
        qrCode: maps[i]['qrCode'],
      );
    });
  }

  Future<Visitor?> getVisitorById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'visitors',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      final map = maps.first;
      return Visitor(
        id: map['id'],
        name: map['name'],
        contact: map['contact'],
        email: map['email'],
        purpose: map['purpose'],
        hostId: map['hostId'],
        hostName: map['hostName'],
        visitDate: DateTime.parse(map['visitDate']),
        checkIn: DateTime.parse(map['checkIn']),
        checkOut: map['checkOut'] != null ? DateTime.parse(map['checkOut']) : null,
        status: map['status'],
        // idPhotoUrl: map['idPhotoUrl'],
        qrCode: map['qrCode'],
      );
    }
    return null;
  }

  // Host operations
  Future<String> insertHost(Host host) async {
    final db = await database;
    final id = host.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    await db.insert('hosts', {
      'id': id,
      'name': host.name,
      'email': host.email,
      'department': host.department,
      'phone': host.phone,
      'designation': host.designation,
      'isActive': host.isActive ? 1 : 0,
      'createdAt': host.createdAt.toIso8601String(),
      'updatedAt': host.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'synced': 0,
    });

    await _addToSyncQueue('INSERT', 'hosts', id, jsonEncode(host.toMap()));
    return id;
  }

  Future<List<Host>> getAllActiveHosts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hosts',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    
    return List.generate(maps.length, (i) {
      return Host(
        id: maps[i]['id'],
        name: maps[i]['name'],
        email: maps[i]['email'],
        department: maps[i]['department'],
        phone: maps[i]['phone'],
        designation: maps[i]['designation'],
        isActive: maps[i]['isActive'] == 1,
        createdAt: DateTime.parse(maps[i]['createdAt']),
        updatedAt: DateTime.parse(maps[i]['updatedAt']),
      );
    });
  }

  // Sync queue operations
  Future<void> _addToSyncQueue(String operation, String tableName, String recordId, String data) async {
    final db = await database;
    await db.insert('sync_queue', {
      'operation': operation,
      'table_name': tableName,
      'record_id': recordId,
      'data': data,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<void> markSyncItemCompleted(int syncId) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [syncId]);
  }

  Future<void> markRecordSynced(String tableName, String recordId) async {
    final db = await database;
    await db.update(
      tableName,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  // Audit logging
  Future<void> logAudit({
    required String userId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    final db = await database;
    await db.insert('audit_logs', {
      'userId': userId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'oldData': oldData != null ? jsonEncode(oldData) : null,
      'newData': newData != null ? jsonEncode(newData) : null,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    String? entityType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    }

    if (entityType != null) {
      whereClause += ' AND entityType = ?';
      whereArgs.add(entityType);
    }

    if (startDate != null) {
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND timestamp <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    return await db.query(
      'audit_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
  }

  // Connectivity and sync management
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> syncWithFirestore() async {
    if (!await isOnline()) return;

    final pendingItems = await getPendingSyncItems();
    
    for (final item in pendingItems) {
      try {
        // Here you would implement the actual sync logic with Firestore
        // This is a placeholder for the sync implementation
        print('Syncing ${item['operation']} on ${item['table_name']} for ${item['record_id']}');
        
        // Mark as completed after successful sync
        await markSyncItemCompleted(item['id']);
        await markRecordSynced(item['table_name'], item['record_id']);
      } catch (e) {
        print('Sync failed for item ${item['id']}: $e');
        // Keep in queue for retry
      }
    }
  }

  // Database maintenance
  Future<void> clearOldData({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    // Clear old synced visitors
    await db.delete(
      'visitors',
      where: 'synced = 1 AND created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );

    // Clear old audit logs
    await db.delete(
      'audit_logs',
      where: 'synced = 1 AND timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    
    final visitorsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM visitors')
    ) ?? 0;
    
    final hostsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM hosts')
    ) ?? 0;
    
    final pendingSyncCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_queue')
    ) ?? 0;
    
    final auditLogsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM audit_logs')
    ) ?? 0;

    return {
      'visitors': visitorsCount,
      'hosts': hostsCount,
      'pendingSync': pendingSyncCount,
      'auditLogs': auditLogsCount,
    };
  }
}
