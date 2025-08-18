import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/host_model.dart';

class HostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new host
  Future<String> addHost(Host host) async {
    try {
      final docRef = _firestore.collection('hosts').doc();
      final data = host.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add host: $e');
    }
  }

  // Get all active hosts
  Stream<List<Host>> getAllActiveHosts() {
    return _firestore
        .collection('hosts')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Host.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get all hosts (including inactive)
  Stream<List<Host>> getAllHosts() {
    return _firestore
        .collection('hosts')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Host.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get hosts by department
  Stream<List<Host>> getHostsByDepartment(String department) {
    return _firestore
        .collection('hosts')
        .where('department', isEqualTo: department)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Host.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get host by ID
  Future<Host?> getHostById(String hostId) async {
    try {
      final doc = await _firestore.collection('hosts').doc(hostId).get();
      if (doc.exists) {
        return Host.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get host: $e');
    }
  }

  // Update host
  Future<void> updateHost(Host host) async {
    try {
      if (host.id == null) throw Exception('Host ID is required for update');
      
      final data = host.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection('hosts').doc(host.id).update(data);
    } catch (e) {
      throw Exception('Failed to update host: $e');
    }
  }

  // Deactivate host (soft delete)
  Future<void> deactivateHost(String hostId) async {
    try {
      await _firestore.collection('hosts').doc(hostId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to deactivate host: $e');
    }
  }

  // Activate host
  Future<void> activateHost(String hostId) async {
    try {
      await _firestore.collection('hosts').doc(hostId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to activate host: $e');
    }
  }

  // Delete host permanently
  Future<void> deleteHost(String hostId) async {
    try {
      await _firestore.collection('hosts').doc(hostId).delete();
    } catch (e) {
      throw Exception('Failed to delete host: $e');
    }
  }

  // Search hosts by name or email
  Future<List<Host>> searchHosts(String query) async {
    try {
      final nameQuery = await _firestore
          .collection('hosts')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .startAt([query])
          .endAt([query + '\uf8ff'])
          .get();

      final emailQuery = await _firestore
          .collection('hosts')
          .where('isActive', isEqualTo: true)
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      final hosts = <Host>[];
      final seenIds = <String>{};

      // Add results from name search
      for (final doc in nameQuery.docs) {
        if (!seenIds.contains(doc.id)) {
          hosts.add(Host.fromMap(doc.data(), doc.id));
          seenIds.add(doc.id);
        }
      }

      // Add results from email search
      for (final doc in emailQuery.docs) {
        if (!seenIds.contains(doc.id)) {
          hosts.add(Host.fromMap(doc.data(), doc.id));
          seenIds.add(doc.id);
        }
      }

      return hosts;
    } catch (e) {
      throw Exception('Failed to search hosts: $e');
    }
  }

  // Get departments list
  Future<List<String>> getDepartments() async {
    try {
      final snapshot = await _firestore
          .collection('hosts')
          .where('isActive', isEqualTo: true)
          .get();

      final departments = <String>{};
      for (final doc in snapshot.docs) {
        final department = doc.data()['department'] as String?;
        if (department != null && department.isNotEmpty) {
          departments.add(department);
        }
      }

      final sortedDepartments = departments.toList()..sort();
      return sortedDepartments;
    } catch (e) {
      throw Exception('Failed to get departments: $e');
    }
  }

  // Get host statistics
  Future<Map<String, dynamic>> getHostStatistics() async {
    try {
      final snapshot = await _firestore.collection('hosts').get();
      final hosts = snapshot.docs
          .map((doc) => Host.fromMap(doc.data(), doc.id))
          .toList();

      final total = hosts.length;
      final active = hosts.where((h) => h.isActive).length;
      final inactive = total - active;

      // Count by department
      final departmentCounts = <String, int>{};
      for (final host in hosts.where((h) => h.isActive)) {
        departmentCounts[host.department] = 
            (departmentCounts[host.department] ?? 0) + 1;
      }

      return {
        'total': total,
        'active': active,
        'inactive': inactive,
        'departmentCounts': departmentCounts,
      };
    } catch (e) {
      throw Exception('Failed to get host statistics: $e');
    }
  }
}
