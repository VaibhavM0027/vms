import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/visitor_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Visitor>> fetchVisitorsBetween(
      DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('visitors')
        .where('checkIn', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('checkIn', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snapshot.docs
        .map((doc) => Visitor.fromMap(doc.data(), doc.id))
        .toList();
  }
}
