class Visit {
  final String id;
  final String visitorId;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? notes;
  final String status; // active, completed, cancelled

  Visit({
    required this.id,
    required this.visitorId,
    required this.checkIn,
    this.checkOut,
    this.notes,
    this.status = 'active',
  });
}
