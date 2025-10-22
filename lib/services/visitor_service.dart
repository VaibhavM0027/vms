import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/visitor_model.dart';

class FirebaseServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Authentication
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Visitor Operations
  Future<String> addVisitor(Visitor visitor) async {
    try {
      // Check if a registered visitor already exists by contact number
      final existingRegisteredVisitor = await findVisitorByContact(visitor.contact);
      
      if (existingRegisteredVisitor != null && existingRegisteredVisitor.isRegistered) {
        // Update existing registered visitor with new visit
        final visitData = {
          'checkIn': visitor.checkIn,
          'checkOut': null,
          'purpose': visitor.purpose,
          'hostId': visitor.hostId,
          'hostName': visitor.hostName,
          'status': 'pending',
          'visitDate': visitor.visitDate,
        };
        
        // Add new visit to history
        List<Map<String, dynamic>> history = existingRegisteredVisitor.visitHistory != null 
            ? List.from(existingRegisteredVisitor.visitHistory!)
            : [];
        history.add(visitData);
        
        // Update visitor document
        await _firestore.collection('visitors').doc(existingRegisteredVisitor.id).update({
          'visitHistory': history,
          'visitDate': visitor.visitDate,
          'checkIn': visitor.checkIn,
          'checkOut': null,
          'purpose': visitor.purpose,
          'hostId': visitor.hostId,
          'hostName': visitor.hostName,
          'status': 'pending',
        });
        
        return existingRegisteredVisitor.id!;
      } else {
        // If a visitor exists by contact (but not registered), upgrade to registered when requested
        final existingByContactAny = await _firestore
            .collection('visitors')
            .where('contact', isEqualTo: visitor.contact)
            .limit(1)
            .get();

        if (existingByContactAny.docs.isNotEmpty) {
          final doc = existingByContactAny.docs.first;
          final data = doc.data();
          final bool wasRegistered = (data['isRegistered'] ?? false) as bool;

          if (!wasRegistered && visitor.isRegistered) {
            // Upgrade existing document to a permanent registered visitor, keep the same id as QR code
            List<Map<String, dynamic>> history = [];
            history.add({
              'checkIn': visitor.checkIn,
              'checkOut': null,
              'purpose': visitor.purpose,
              'hostId': visitor.hostId,
              'hostName': visitor.hostName,
              'status': 'pending',
              'visitDate': visitor.visitDate,
            });

            await _firestore.collection('visitors').doc(doc.id).update({
              'name': visitor.name,
              'email': visitor.email,
              'purpose': visitor.purpose,
              'hostId': visitor.hostId,
              'hostName': visitor.hostName,
              'visitDate': visitor.visitDate,
              'checkIn': visitor.checkIn,
              'checkOut': null,
              'status': 'pending',
              'isRegistered': true,
              'qrCode': data['qrCode'] ?? doc.id,
              'visitHistory': history,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return doc.id;
          }
        }

        // Create new visitor document
        final docRef = _firestore.collection('visitors').doc();
        final data = visitor.toMap();

        // Generate permanent QR code only for registered visitors; for temporary, still assign id (useful for scanning during the visit)
        data['qrCode'] = data['qrCode'] ?? docRef.id;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['isRegistered'] = visitor.isRegistered;

        if (visitor.isRegistered) {
          data['visitHistory'] = [{
            'checkIn': visitor.checkIn,
            'checkOut': null,
            'purpose': visitor.purpose,
            'hostId': visitor.hostId,
            'hostName': visitor.hostName,
            'status': 'pending',
            'visitDate': visitor.visitDate,
          }];
        }

        await docRef.set(data);
        return docRef.id;
      }
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to register visitors. Please contact an administrator.');
      }
      throw Exception('Failed to add visitor: $e');
    }
  }
  
  // Find visitor by contact number
  Future<Visitor?> findVisitorByContact(String contact) async {
    try {
      final snapshot = await _firestore
          .collection('visitors')
          .where('contact', isEqualTo: contact)
          .where('isRegistered', isEqualTo: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return Visitor.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to search for visitors. Please contact an administrator.');
      }
      throw Exception('Failed to find visitor: $e');
    }
  }

  Future<void> approveVisitor(String visitorId) async {
    try {
      await _firestore.collection('visitors').doc(visitorId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to approve visitors. Please contact an administrator.');
      }
      throw Exception('Failed to approve visitor: $e');
    }
  }

  Future<void> rejectVisitor(String visitorId) async {
    try {
      await _firestore.collection('visitors').doc(visitorId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to reject visitors. Please contact an administrator.');
      }
      throw Exception('Failed to reject visitor: $e');
    }
  }

  Future<void> checkInVisitor(String visitorId) async {
    try {
      // Get the visitor document
      final visitorDoc = await _firestore.collection('visitors').doc(visitorId).get();
      final visitorData = visitorDoc.data();
      final now = Timestamp.now();
      
      if (visitorData != null && visitorData['isRegistered'] == true) {
        // For registered visitors, update the current visit in history
        List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
            ? List.from(visitorData['visitHistory'])
            : [];
            
        if (history.isNotEmpty) {
          // Update the most recent visit
          history.last['checkIn'] = now;
          history.last['status'] = 'checked-in';
        }
        
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkIn': FieldValue.serverTimestamp(),
          'status': 'checked-in',
          'visitHistory': history,
        });
      } else {
        // For non-registered visitors
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkIn': FieldValue.serverTimestamp(),
          'status': 'checked-in',
        });
      }
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to check in visitors. Please contact an administrator.');
      }
      throw Exception('Failed to check-in visitor: $e');
    }
  }

  Future<void> checkOutVisitor(String visitorId, String? meetingNotes) async {
    try {
      // Get the visitor document
      final visitorDoc = await _firestore.collection('visitors').doc(visitorId).get();
      final visitorData = visitorDoc.data();
      final checkOutTime = FieldValue.serverTimestamp();
      final now = Timestamp.now();
      
      if (visitorData != null && visitorData['isRegistered'] == true) {
        // For registered visitors, update the current visit in history
        List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
            ? List.from(visitorData['visitHistory'])
            : [];
            
        if (history.isNotEmpty) {
          // Update the most recent visit
          history.last['checkOut'] = now;
          history.last['status'] = 'completed';
          history.last['meetingNotes'] = meetingNotes;
        }
        
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkOut': checkOutTime,
          'status': 'completed',
          'meetingNotes': meetingNotes,
          'visitHistory': history,
        });
      } else {
        // For non-registered visitors
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkOut': checkOutTime,
          'status': 'completed',
          'meetingNotes': meetingNotes,
        });
      }
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to check out visitors. Please contact an administrator.');
      }
      throw Exception('Failed to check-out visitor: $e');
    }
  }

  Stream<List<Visitor>> getAllPendingVisitors() {
    return _firestore
        .collection('visitors')
        .where('status', isEqualTo: 'pending')
        .orderBy('checkIn', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Visitor.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Visitor>> getAllVisitors() {
    return _firestore
        .collection('visitors')
        .orderBy('checkIn', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Visitor.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateVisitor(Visitor visitor) async {
    try {
      await _firestore
          .collection('visitors')
          .doc(visitor.id)
          .update(visitor.toMap());
    } catch (e) {
      throw Exception('Failed to update visitor: $e');
    }
  }

  Future<void> updateVisitorStatus(String visitorId, String status) async {
    try {
      await _firestore
          .collection('visitors')
          .doc(visitorId)
          .update({'status': status});
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  Stream<List<Visitor>> getVisitorsByHost(String hostId) {
    return _firestore
        .collection('visitors')
        .where('hostId', isEqualTo: hostId)
        .orderBy('checkIn', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Visitor.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Visitor>> getPendingVisitorsByHost(String hostId) {
    return _firestore
        .collection('visitors')
        .where('hostId', isEqualTo: hostId)
        .where('status', isEqualTo: 'pending')
        .orderBy('checkIn', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Visitor.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get visitors for reports with date filtering
  Future<List<Visitor>> getVisitorsForReports(DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _firestore
          .collection('visitors')
          .where('checkIn',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('checkIn',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate.add(const Duration(days: 1))))
          .get();

      return snapshot.docs
          .map((doc) => Visitor.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch visitors for reports: $e');
    }
  }

  // Get visitor by QR code with visit context
  Future<Visitor?> getVisitorByQRCode(String qrCode) async {
    try {
      final snapshot = await _firestore
          .collection('visitors')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final visitor = Visitor.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        return visitor;
      }
      return null;
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to search for visitors by QR code. Please contact an administrator.');
      }
      throw Exception('Failed to fetch visitor by QR code: $e');
    }
  }
  
  // Check if visitor can start new visit
  Future<bool> canStartNewVisit(String visitorId) async {
    try {
      final doc = await _firestore.collection('visitors').doc(visitorId).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      final isRegistered = data['isRegistered'] ?? false;
      final status = data['status'] ?? 'pending';
      final checkOut = data['checkOut'];
      
      // Registered visitors can always start new visits if their last visit is completed
      if (isRegistered && (status == 'completed' || checkOut != null)) {
        return true;
      }
      
      // Non-registered visitors can start new visit only if status is completed
      return status == 'completed';
    } catch (e) {
      throw Exception('Failed to check visit eligibility: $e');
    }
  }
  
  // Start new visit for existing visitor
  Future<void> startNewVisit(String visitorId, {
    String? newPurpose,
    String? newHostId,
    String? newHostName,
  }) async {
    try {
      final doc = await _firestore.collection('visitors').doc(visitorId).get();
      if (!doc.exists) throw Exception('Visitor not found');
      
      final data = doc.data()!;
      final isRegistered = data['isRegistered'] ?? false;
      
      if (isRegistered) {
        // For registered visitors, add new visit to history
        List<Map<String, dynamic>> history = data['visitHistory'] != null 
            ? List.from(data['visitHistory'])
            : [];
            
        final now = Timestamp.now();
        final newVisit = {
          'checkIn': now,
          'checkOut': null,
          'purpose': newPurpose ?? data['purpose'] ?? 'Visit',
          'hostId': newHostId ?? data['hostId'],
          'hostName': newHostName ?? data['hostName'],
          'status': 'pending', // New visits start as pending
          'visitDate': now,
        };
        history.add(newVisit);
        
        // Update visitor document with new visit info
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkIn': FieldValue.serverTimestamp(),
          'checkOut': null,
          'status': 'pending',
          'visitDate': FieldValue.serverTimestamp(),
          'purpose': newPurpose ?? data['purpose'],
          'hostId': newHostId ?? data['hostId'],
          'hostName': newHostName ?? data['hostName'],
          'visitHistory': history,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // For non-registered visitors, just update the document
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkIn': FieldValue.serverTimestamp(),
          'checkOut': null,
          'status': 'pending',
          'visitDate': FieldValue.serverTimestamp(),
          'purpose': newPurpose ?? data['purpose'],
          'hostId': newHostId ?? data['hostId'],
          'hostName': newHostName ?? data['hostName'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to start a new visit. Please contact an administrator.');
      }
      throw Exception('Failed to start new visit: $e');
    }
  }

  // Image Upload
  Future<String> uploadIdImage(String visitorId, String filePath) async {
    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection. Please check your network and try again.');
      }
      
      final file = File(filePath);
      final ref = _storage.ref().child('visitor_ids/$visitorId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to upload ID images. Please contact an administrator.');
      }
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<String> uploadVisitorPhoto(String visitorId, String filePath) async {
    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection. Please check your network and try again.');
      }
      
      final file = File(filePath);
      final ref = _storage.ref().child('visitor_photos/$visitorId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to upload visitor photos. Please contact an administrator.');
      }
      // Handle unauthenticated access
      if (e.toString().contains('unauthenticated') || e.toString().contains('auth')) {
        throw Exception('Authentication required. Please contact reception for assistance.');
      }
      throw Exception('Failed to upload photo: $e');
    }
  }

  // Notifications
  Future<void> sendNotificationToHost(String hostId, String visitorName) async {
    try {
      await _firestore.collection('notifications').add({
        'hostId': hostId,
        'visitorName': visitorName,
        'message': 'New visitor $visitorName is waiting for approval',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }

  // Get notifications for a host
  Stream<List<Map<String, dynamic>>> getNotificationsForHost(String hostId) {
    return _firestore
        .collection('notifications')
        .where('hostId', isEqualTo: hostId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Delete visitor
  Future<void> deleteVisitor(String visitorId) async {
    try {
      await _firestore.collection('visitors').doc(visitorId).delete();
    } catch (e) {
      throw Exception('Failed to delete visitor: $e');
    }
  }

  // Get visitor statistics
  Future<Map<String, dynamic>> getVisitorStatistics() async {
    try {
      final snapshot = await _firestore.collection('visitors').get();
      final visitors = snapshot.docs
          .map((doc) => Visitor.fromMap(doc.data(), doc.id))
          .toList();

      final total = visitors.length;
      final pending = visitors.where((v) => v.status == 'pending').length;
      final approved = visitors.where((v) => v.status == 'approved').length;
      final completed = visitors.where((v) => v.status == 'completed').length;
      final rejected = visitors.where((v) => v.status == 'rejected').length;

      return {
        'total': total,
        'pending': pending,
        'approved': approved,
        'completed': completed,
        'rejected': rejected,
      };
    } catch (e) {
      throw Exception('Failed to get visitor statistics: $e');
    }
  }
}
