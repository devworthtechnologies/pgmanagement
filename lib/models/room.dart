// lib/models/room.dart
class Room {
  final int? roomId;
  final String roomNumber;
  final String roomType;
  final int capacity;
  final int occupiedCount;
  final String status;
  final String? notes;

  Room({
    this.roomId,
    required this.roomNumber,
    required this.roomType,
    required this.capacity,
    required this.occupiedCount,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'room_number': roomNumber,
      'room_type': roomType,
      'capacity': capacity,
      'occupied_count': occupiedCount,
      'status': status,
      'notes': notes,
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      roomId: map['room_id'],
      roomNumber: map['room_number'],
      roomType: map['room_type'],
      capacity: map['capacity'],
      occupiedCount: map['occupied_count'],
      status: map['status'],
      notes: map['notes'],
    );
  }
}