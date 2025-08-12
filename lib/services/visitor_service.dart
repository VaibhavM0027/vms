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

  // Visitor Operations
  Future<String> addVisitor(Visitor visitor) async {
    try {
      // Ensure qrCode is the Firestore document ID to prevent forged QR payloads
      final docRef = _firestore.collection('visitors').doc();
      final data = visitor.toMap();
      data['qrCode'] = data['qrCode'] ?? docRef.id;
      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add visitor: $e');
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

  // Image Upload
  Future<String> uploadIdImage(String visitorId, String filePath) async {
    try {
      Reference ref = _storage.ref().child('visitor_ids/$visitorId.jpg');
      await ref.putFile(File(filePath));
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Notifications
  Future<void> sendNotificationToHost(String hostId, String visitorName) async {
    try {
      await _firestore.collection('notifications').add({
        'hostId': hostId,
        'title': 'Visitor arrived',
        'body': '$visitorName is at reception',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      throw Exception('Failed to send notification: $e');
    }
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}
