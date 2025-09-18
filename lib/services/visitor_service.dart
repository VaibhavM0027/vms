import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
      // Check if visitor already exists by contact number
      final existingVisitor = await findVisitorByContact(visitor.contact);
      
      if (existingVisitor != null && existingVisitor.isRegistered) {
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
        List<Map<String, dynamic>> history = existingVisitor.visitHistory != null 
            ? List.from(existingVisitor.visitHistory!)
            : [];
        history.add(visitData);
        
        // Update visitor document
        await _firestore.collection('visitors').doc(existingVisitor.id).update({
          'visitHistory': history,
          'visitDate': visitor.visitDate,
          'checkIn': visitor.checkIn,
          'checkOut': null,
          'purpose': visitor.purpose,
          'hostId': visitor.hostId,
          'hostName': visitor.hostName,
          'status': 'pending',
        });
        
        return existingVisitor.id!;
      } else {
        // Create new visitor
        final docRef = _firestore.collection('visitors').doc();
        final data = visitor.toMap();
        
        // Generate permanent QR code for the visitor
        data['qrCode'] = data['qrCode'] ?? docRef.id;
        data['createdAt'] = FieldValue.serverTimestamp();
        data['isRegistered'] = visitor.isRegistered;
        
        // Initialize visit history if this is a registered visitor
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
      throw Exception('Failed to reject visitor: $e');
    }
  }

  Future<void> checkInVisitor(String visitorId) async {
    try {
      // Get the visitor document
      final visitorDoc = await _firestore.collection('visitors').doc(visitorId).get();
      final visitorData = visitorDoc.data();
      
      if (visitorData != null && visitorData['isRegistered'] == true) {
        // For registered visitors, update the current visit in history
        List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
            ? List.from(visitorData['visitHistory'])
            : [];
            
        if (history.isNotEmpty) {
          // Update the most recent visit
          history.last['checkIn'] = FieldValue.serverTimestamp();
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
      throw Exception('Failed to check-in visitor: $e');
    }
  }

  Future<void> checkOutVisitor(String visitorId, String? meetingNotes) async {
    try {
      // Get the visitor document
      final visitorDoc = await _firestore.collection('visitors').doc(visitorId).get();
      final visitorData = visitorDoc.data();
      final checkOutTime = FieldValue.serverTimestamp();
      
      if (visitorData != null && visitorData['isRegistered'] == true) {
        // For registered visitors, update the current visit in history
        List<Map<String, dynamic>> history = visitorData['visitHistory'] != null 
            ? List.from(visitorData['visitHistory'])
            : [];
            
        if (history.isNotEmpty) {
          // Update the most recent visit
          history.last['checkOut'] = checkOutTime;
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

  // Get visitor by QR code
  Future<Visitor?> getVisitorByQRCode(String qrCode) async {
    try {
      final snapshot = await _firestore
          .collection('visitors')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Visitor.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch visitor by QR code: $e');
    }
  }

  // Image Upload
  Future<String> uploadIdImage(String visitorId, String filePath) async {
    try {
      final file = File(filePath);
      final ref = _storage.ref().child('visitor_ids/$visitorId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<String> uploadVisitorPhoto(String visitorId, String filePath) async {
    try {
      final file = File(filePath);
      final ref = _storage.ref().child('visitor_photos/$visitorId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
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
