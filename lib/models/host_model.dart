import 'package:cloud_firestore/cloud_firestore.dart';

class Host {
  final String? id;
  final String name;
  final String email;
  final String department;
  final String? phone;
  final String? designation;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Host({
    this.id,
    required this.name,
    required this.email,
    required this.department,
    this.phone,
    this.designation,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'department': department,
      'phone': phone,
      'designation': designation,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Host.fromMap(Map<String, dynamic> map, String id) {
    return Host(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      department: map['department'] ?? '',
      phone: map['phone'],
      designation: map['designation'],
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Host copyWith({
    String? id,
    String? name,
    String? email,
    String? department,
    String? phone,
    String? designation,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Host(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      phone: phone ?? this.phone,
      designation: designation ?? this.designation,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Host(id: $id, name: $name, email: $email, department: $department)';
  }
}
