import 'package:cloud_firestore/cloud_firestore.dart';

class Visitor {
  final String? id;
  final String name;
  final String contact;
  final String email;
  final String purpose;
  final String hostId;
  final String hostName;
  final String? idImageUrl;
  final String? photoUrl;
  final DateTime visitDate;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? meetingNotes;
  final String status; // 'pending', 'approved', 'rejected', 'completed'
  final String? qrCode; // encoded visitor id/payload

  Visitor({
    this.id,
    required this.name,
    required this.contact,
    required this.email,
    required this.purpose,
    required this.hostId,
    required this.hostName,
    this.idImageUrl,
    this.photoUrl,
    required this.visitDate,
    required this.checkIn,
    this.checkOut,
    this.meetingNotes,
    this.status = 'pending',
    this.qrCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact': contact,
      'email': email,
      'purpose': purpose,
      'hostId': hostId,
      'hostName': hostName,
      'idImageUrl': idImageUrl,
      'photoUrl': photoUrl,
      'visitDate': visitDate,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'meetingNotes': meetingNotes,
      'status': status,
      'qrCode': qrCode,
    };
  }

  factory Visitor.fromMap(Map<String, dynamic> map, String id) {
    return Visitor(
      id: id,
      name: map['name'] ?? '',
      contact: map['contact'] ?? '',
      email: map['email'] ?? '',
      purpose: map['purpose'] ?? '',
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? '',
      idImageUrl: map['idImageUrl'],
      photoUrl: map['photoUrl'],
      visitDate: map['visitDate'] != null 
          ? (map['visitDate'] as Timestamp).toDate()
          : DateTime.now(),
      checkIn: map['checkIn'] != null 
          ? (map['checkIn'] as Timestamp).toDate()
          : DateTime.now(),
      checkOut: map['checkOut'] != null
          ? (map['checkOut'] as Timestamp).toDate()
          : null,
      meetingNotes: map['meetingNotes'],
      status: map['status'] ?? 'pending',
      qrCode: map['qrCode'],
    );
  }
}
