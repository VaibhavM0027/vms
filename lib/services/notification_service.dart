import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Track listeners and status to prevent duplicates and detect transitions
  bool _adminListenersStarted = false;
  final Map<String, String> _visitorStatusCache = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _completedListener;

  Future<void> initialize() async {
    // Request permission for notifications
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
      return;
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Get FCM token
    _fcmToken = await _messaging.getToken();
    debugPrint('FCM Token: $_fcmToken');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('FCM Token refreshed: $token');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');
    
    // Show local notification
    await _showLocalNotification(
      title: message.notification?.title ?? 'VMS Notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Notification tapped: ${message.messageId}');
    // Handle navigation based on notification data
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'vms_channel',
      'VMS Notifications',
      channelDescription: 'Visitor Management System notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Store notification in Firestore
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send FCM notification (requires server-side implementation)
      // For now, we'll just store in Firestore
      debugPrint('Notification sent to user: $userId');
    } catch (e) {
      debugPrint('Error sending notification: $e');
      throw Exception('Failed to send notification: $e');
    }
  }

  // Send notification to host about new visitor
  Future<void> notifyHostOfNewVisitor({
    required String hostId,
    required String visitorName,
    required String visitorPurpose,
    required String visitorId,
  }) async {
    await sendNotificationToUser(
      userId: hostId,
      title: 'New Visitor Waiting',
      body: '$visitorName is waiting for approval. Purpose: $visitorPurpose',
      data: {
        'type': 'visitor_approval',
        'visitorId': visitorId,
        'visitorName': visitorName,
      },
    );
  }

  // Send notification about visitor approval
  Future<void> notifyVisitorApproval({
    required String visitorId,
    required String visitorName,
    required bool approved,
  }) async {
    await sendNotificationToUser(
      userId: visitorId,
      title: approved ? 'Visit Approved' : 'Visit Rejected',
      body: approved 
          ? 'Your visit has been approved. Please proceed to reception.'
          : 'Your visit request has been rejected. Please contact the host.',
      data: {
        'type': 'visitor_status',
        'visitorId': visitorId,
        'approved': approved,
      },
    );
  }

  // Send notification to admin about system events
  Future<void> notifyAdmin({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Get all admin users
    final adminQuery = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    for (final doc in adminQuery.docs) {
      await sendNotificationToUser(
        userId: doc.id,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  // Get notifications for a user
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'read': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Mark all user notifications as read
  Future<void> markAllAsRead(String userId) async {
    final query = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // Delete a specific notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<void> clearAllForUser(String userId) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear notifications: $e');
    }
  }

  // Alias used by notifications_screen.dart
  Future<void> clearAllNotifications(String userId) => clearAllForUser(userId);

  // Start local pop-up notifications for admins to be alerted on pending approvals and checkouts
  Future<void> startAdminEventListeners() async {
    if (_adminListenersStarted) return;
    _adminListenersStarted = true;

    // Seed cache with current statuses to detect transitions
    _firestore.collection('visitors').get().then((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? 'pending';
        _visitorStatusCache[doc.id] = status;
      }
    }).catchError((e, st) {
      debugPrint('Failed to prime status cache: $e');
      return null;
    });

    // Listen for newly added pending visitors
    _pendingListener = _firestore
        .collection('visitors')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final name = data['name']?.toString() ?? 'Visitor';
          final purpose = data['purpose']?.toString() ?? '';
          _showLocalNotification(
            title: 'Visitor waiting for approval',
            body: '$name • $purpose',
            payload: 'visitorId=${change.doc.id}',
          );
          _visitorStatusCache[change.doc.id] = 'pending';
        }
      }
    }, onError: (e) {
      debugPrint('Pending listener error: $e');
    });

    // Listen for transitions to completed (checkout)
    _completedListener = _firestore
        .collection('visitors')
        .orderBy('checkOut', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        final newStatus = data['status']?.toString();
        final previousStatus = _visitorStatusCache[change.doc.id];
        if (newStatus == 'completed' && previousStatus != 'completed') {
          final name = data['name']?.toString() ?? 'Visitor';
          _showLocalNotification(
            title: 'Visitor checked out',
            body: '$name has checked out.',
            payload: 'visitorId=${change.doc.id}',
          );
        }
        if (newStatus != null) {
          _visitorStatusCache[change.doc.id] = newStatus;
        }
      }
    }, onError: (e) {
      debugPrint('Completed listener error: $e');
    });
  }

  Future<void> stopAdminEventListeners() async {
    await _pendingListener?.cancel();
    await _completedListener?.cancel();
    _pendingListener = null;
    _completedListener = null;
    _adminListenersStarted = false;
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}
