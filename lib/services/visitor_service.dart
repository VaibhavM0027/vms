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
          'status': 'pending',
          'visitDate': visitor.visitDate,
          'purpose': visitor.purpose,
          'hostId': visitor.hostId,
          'hostName': visitor.hostName,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // Add to visit history
        List<Map<String, dynamic>> history = existingRegisteredVisitor.visitHistory != null 
            ? List.from(existingRegisteredVisitor.visitHistory!)
            : [];
        history.add(visitData);
        
        await _firestore.collection('visitors').doc(existingRegisteredVisitor.id).update({
          'visitHistory': history,
          'checkIn': visitor.checkIn,
          'checkOut': null,
          'status': 'pending',
          'visitDate': visitor.visitDate,
          'purpose': visitor.purpose,
          'hostId': visitor.hostId,
          'hostName': visitor.hostName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return existingRegisteredVisitor.id!;
      } else {
        // New visitor registration
        final docRef = _firestore.collection('visitors').doc();
        final visitorId = docRef.id;
        
        // Ensure QR code is always set
        final qrCode = visitor.qrCode ?? visitorId;
        
        final visitorData = {
          'name': visitor.name,
          'contact': visitor.contact,
          'email': visitor.email,
          'purpose': visitor.purpose,
          'hostId': visitor.hostId,
          'hostName': visitor.hostName,
          'idImageUrl': visitor.idImageUrl,
          'photoUrl': visitor.photoUrl,
          'visitDate': visitor.visitDate,
          'checkIn': visitor.checkIn,
          'checkOut': null,
          'meetingNotes': visitor.meetingNotes,
          'status': visitor.status,
          'qrCode': qrCode, // Always set QR code
          'isRegistered': visitor.isRegistered,
          'visitHistory': [{
            'checkIn': visitor.checkIn,
            'checkOut': null,
            'status': visitor.status,
            'visitDate': visitor.visitDate,
            'purpose': visitor.purpose,
            'hostId': visitor.hostId,
            'hostName': visitor.hostName,
          }],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        await docRef.set(visitorData, SetOptions(merge: true));
        return visitorId;
      }
    } catch (e) {
      print('Error adding visitor: $e');
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Registration requires proper permissions. Please contact reception or try again.');
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

  // Update visitor
  Future<void> updateVisitor(Visitor visitor) async {
    try {
      if (visitor.id == null) {
        throw Exception('Visitor ID is required for update');
      }
      
      await _firestore.collection('visitors').doc(visitor.id).update(visitor.toMap());
    } catch (e) {
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('You do not have permission to update visitor information. Please contact an administrator.');
      }
      throw Exception('Failed to update visitor: $e');
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
      if (!doc.exists) {
        throw Exception('Visitor not found');
      }
      
      final data = doc.data()!;
      final now = Timestamp.now();
      
      // Create new visit entry
      final newVisit = {
        'checkIn': now,
        'checkOut': null,
        'status': 'pending',
        'visitDate': now,
        'purpose': newPurpose ?? data['purpose'],
        'hostId': newHostId ?? data['hostId'],
        'hostName': newHostName ?? data['hostName'],
      };
      
      // Update visit history
      List<Map<String, dynamic>> history = data['visitHistory'] != null 
          ? List.from(data['visitHistory'])
          : [];
      history.add(newVisit);
      
      // Update visitor document
      await _firestore.collection('visitors').doc(visitorId).update({
        'checkIn': now,
        'checkOut': null,
        'status': 'pending',
        'visitDate': now,
        'purpose': newPurpose ?? data['purpose'],
        'hostId': newHostId ?? data['hostId'],
        'hostName': newHostName ?? data['hostName'],
        'visitHistory': history,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error starting new visit: $e');
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Registration requires proper permissions. Please contact reception or try again.');
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
      print('Uploading photo for visitor ID: $visitorId from path: $filePath');
      
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No internet connection available for photo upload');
        throw Exception('No internet connection. Please check your network and try again.');
      }
      
      final file = File(filePath);
      // Check if file exists
      if (!await file.exists()) {
        print('Photo file does not exist at path: $filePath');
        throw Exception('Photo file not found. Please try capturing the photo again.');
      }
      
      print('File exists, proceeding with upload');
      final ref = _storage.ref().child('visitor_photos/$visitorId.jpg');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      print('Photo uploaded successfully. Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading visitor photo: $e');
      // Handle permission errors specifically
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Registration requires proper permissions. Please contact reception or try again.');
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

  // Missing methods that need to be implemented
  
  // Get all visitors sorted by visit date (newest first)
  Stream<List<Visitor>> getAllVisitors() {
    try {
      return _firestore.collection('visitors')
          .orderBy('visitDate', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs
                  .map((doc) => Visitor.fromMap(doc.data(), doc.id))
                  .toList());
    } catch (e) {
      throw Exception('Failed to get visitors: $e');
    }
  }

  // Get visitors by host sorted by visit date (newest first)
  Stream<List<Visitor>> getVisitorsByHost(String hostId) {
    try {
      return _firestore
          .collection('visitors')
          .where('hostId', isEqualTo: hostId)
          .orderBy('visitDate', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Visitor.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      throw Exception('Failed to get visitors by host: $e');
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
      throw Exception('Failed to get visitor by QR code: $e');
    }
  }

  // Check out visitor
  Future<void> checkOutVisitor(String visitorId, String notes) async {
    try {
      final now = Timestamp.now();
      
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
          history.last['checkOut'] = now;
          history.last['status'] = 'completed';
          history.last['meetingNotes'] = notes;
        }
        
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkOut': now,
          'status': 'completed',
          'meetingNotes': notes,
          'visitHistory': history,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // For non-registered visitors
        await _firestore.collection('visitors').doc(visitorId).update({
          'checkOut': now,
          'status': 'completed',
          'meetingNotes': notes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to check-out visitor: $e');
    }
  }

  // Get all pending visitors
  Stream<List<Visitor>> getAllPendingVisitors() {
    try {
      return _firestore
          .collection('visitors')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Visitor.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      throw Exception('Failed to get pending visitors: $e');
    }
  }

  // Update visitor status
  Future<void> updateVisitorStatus(String visitorId, String status) async {
    try {
      await _firestore.collection('visitors').doc(visitorId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update visitor status: $e');
    }
  }

  // Get pending visitors by host
  Stream<List<Visitor>> getPendingVisitorsByHost(String hostId) {
    try {
      return _firestore
          .collection('visitors')
          .where('hostId', isEqualTo: hostId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Visitor.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      throw Exception('Failed to get pending visitors by host: $e');
    }
  }

  // Approve visitor
  Future<void> approveVisitor(String visitorId) async {
    try {
      await _firestore.collection('visitors').doc(visitorId).update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to approve visitor: $e');
    }
  }

  // Get visitors for reports
  Future<List<Visitor>> getVisitorsForReports(DateTime startDate, DateTime endDate) async {
    try {
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);
      
      final snapshot = await _firestore
          .collection('visitors')
          .where('visitDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('visitDate', isLessThanOrEqualTo: endTimestamp)
          .get();
      
      return snapshot.docs
          .map((doc) => Visitor.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get visitors for reports: $e');
    }
  }
}