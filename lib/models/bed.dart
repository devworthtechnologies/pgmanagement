// bed.dart
class Bed {
  final int? bedId;
  final int roomId;
  final String bedNumber;
  final String status;
  final int? guestId;

  Bed({
    this.bedId,
    required this.roomId,
    required this.bedNumber,
    required this.status,
    this.guestId,
  });

  Map<String, dynamic> toMap() {
    return {
      'bed_id': bedId,
      'room_id': roomId,
      'bed_number': bedNumber,
      'status': status,
      'guest_id': guestId,
    };
  }

  factory Bed.fromMap(Map<String, dynamic> map) {
    return Bed(
      bedId: map['bed_id'],
      roomId: map['room_id'],
      bedNumber: map['bed_number'],
      status: map['status'],
      guestId: map['guest_id'],
    );
  }
}