// pg_details.dart
class PGDetails {
  final int? pgId;
  final String pgName;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final int totalRooms;
  final int totalFloors;
  final DateTime createdDate;

  PGDetails({
    this.pgId,
    required this.pgName,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.totalRooms,
    required this.totalFloors,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'pg_id': pgId,
      'pg_name': pgName,
      'owner_name': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'total_rooms': totalRooms,
      'total_floors': totalFloors,
      'created_date': createdDate.toIso8601String(),
    };
  }

  factory PGDetails.fromMap(Map<String, dynamic> map) {
    return PGDetails(
      pgId: map['pg_id'],
      pgName: map['pg_name'],
      ownerName: map['owner_name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      totalRooms: map['total_rooms'],
      totalFloors: map['total_floors'],
      createdDate: DateTime.parse(map['created_date']),
    );
  }
}
