// guest.dart
class Guest {
  final int? guestId;
  final String fullName;
  final String phone;
  final String gender;
  final String idProofType;
  final String idProofNumber;
  final String emergencyContact;
  final DateTime joiningDate;
  final int? roomId;
  final int? bedId;
  final double depositAmount;
  final double monthlyRent;
  final int dueDate; // Day of month (1-31)
  final String status;
  final String? notes;
  final String? photoPath;
  final String? idProofPath;

  Guest({
    this.guestId,
    required this.fullName,
    required this.phone,
    required this.gender,
    required this.idProofType,
    required this.idProofNumber,
    required this.emergencyContact,
    required this.joiningDate,
    this.roomId,
    this.bedId,
    required this.depositAmount,
    required this.monthlyRent,
    required this.dueDate,
    required this.status,
    this.notes,
    this.photoPath,
    this.idProofPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'guest_id': guestId,
      'full_name': fullName,
      'phone': phone,
      'gender': gender,
      'id_proof_type': idProofType,
      'id_proof_number': idProofNumber,
      'emergency_contact': emergencyContact,
      'joining_date': joiningDate.toIso8601String(),
      'room_id': roomId,
      'bed_id': bedId,
      'deposit_amount': depositAmount,
      'monthly_rent': monthlyRent,
      'due_date': dueDate,
      'status': status,
      'notes': notes,
      'photo_path': photoPath,
      'id_proof_path': idProofPath,
    };
  }

  factory Guest.fromMap(Map<String, dynamic> map) {
    return Guest(
      guestId: map['guest_id'],
      fullName: map['full_name'],
      phone: map['phone'],
      gender: map['gender'],
      idProofType: map['id_proof_type'],
      idProofNumber: map['id_proof_number'],
      emergencyContact: map['emergency_contact'],
      joiningDate: DateTime.parse(map['joining_date']),
      roomId: map['room_id'],
      bedId: map['bed_id'],
      depositAmount: map['deposit_amount'],
      monthlyRent: map['monthly_rent'],
      dueDate: map['due_date'],
      status: map['status'],
      notes: map['notes'],
      photoPath: map['photo_path'],
      idProofPath: map['id_proof_path'],
    );
  }
}
