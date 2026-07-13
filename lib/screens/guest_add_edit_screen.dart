// guest_add_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/models/guest.dart';
import 'package:pg_management/models/room.dart';
import 'package:pg_management/models/bed.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/widgets/loading_indicator.dart';

class GuestAddEditScreen extends StatefulWidget {
  final Guest? guest;

  const GuestAddEditScreen({super.key, this.guest});

  @override
  State<GuestAddEditScreen> createState() => _GuestAddEditScreenState();
}

class _GuestAddEditScreenState extends State<GuestAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _idProofNumberController = TextEditingController();
  final _depositController = TextEditingController();
  final _rentController = TextEditingController();
  final _notesController = TextEditingController();

  String _gender = AppConstants.genders.first;
  String _idProofType = AppConstants.idProofTypes.first;
  int _dueDate = 1;
  int? _selectedRoomId;
  int? _selectedBedId;
  List<Room> _rooms = [];
  final Map<int, List<Bed>> _bedsByRoom = {};
  File? _photoFile;
  File? _idProofFile;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    if (widget.guest != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final g = widget.guest!;
    _fullNameController.text = g.fullName;
    _phoneController.text = g.phone;
    _emergencyController.text = g.emergencyContact;
    _idProofNumberController.text = g.idProofNumber;
    _depositController.text = g.depositAmount.toString();
    _rentController.text = g.monthlyRent.toString();
    _notesController.text = g.notes ?? '';
    _gender = g.gender;
    _idProofType = g.idProofType;
    _dueDate = g.dueDate;
    _selectedRoomId = g.roomId;
    _selectedBedId = g.bedId;
  }

  Future<void> _loadRooms() async {
    final db = DatabaseHelper.instance;
    final rooms = await db.getAllRooms();
    setState(() {
      _rooms = rooms;
    });
    for (final room in rooms) {
      final beds = await _loadBedsForRoom(room.roomId!);
      _bedsByRoom[room.roomId!] = beds;
    }
  }

  Future<List<Bed>> _loadBedsForRoom(int roomId) async {
    final db = DatabaseHelper.instance;
    final maps = await db.query('Beds', where: 'room_id = ?', whereArgs: [roomId]);
    return maps.map((m) => Bed.fromMap(m)).toList();
  }

  Future<void> _pickImage(ImageSource source, bool isPhoto) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        if (isPhoto) {
          _photoFile = File(picked.path);
        } else {
          _idProofFile = File(picked.path);
        }
      });
    }
  }

  Future<void> _saveGuest() async {
    if (!_formKey.currentState!.validate()) return;

    final guest = Guest(
      guestId: widget.guest?.guestId,
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      gender: _gender,
      idProofType: _idProofType,
      idProofNumber: _idProofNumberController.text,
      emergencyContact: _emergencyController.text,
      joiningDate: widget.guest?.joiningDate ?? DateTime.now(),
      roomId: _selectedRoomId,
      bedId: _selectedBedId,
      depositAmount: double.parse(_depositController.text),
      monthlyRent: double.parse(_rentController.text),
      dueDate: _dueDate,
      status: AppConstants.guestActive,
      notes: _notesController.text,
      photoPath: _photoFile?.path,
      idProofPath: _idProofFile?.path,
    );

    final db = DatabaseHelper.instance;
    if (widget.guest == null) {
      // Add new guest
      final guestId = await db.insert('Guests', guest.toMap());
      // Update bed status
      if (_selectedBedId != null) {
        await db.update('Beds', {'status': 'Occupied', 'guest_id': guestId}, 'bed_id = ?', [_selectedBedId]);
      }
      // Update room occupied count
      if (_selectedRoomId != null) {
        await _updateRoomOccupancy(_selectedRoomId!);
      }
    } else {
      // Update existing
      await db.update('Guests', guest.toMap(), 'guest_id = ?', [widget.guest!.guestId]);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.guest == null ? 'Guest added successfully' : 'Guest updated successfully')),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _updateRoomOccupancy(int roomId) async {
    final db = DatabaseHelper.instance;
    final beds = await _loadBedsForRoom(roomId);
    final occupiedCount = beds.where((b) => b.status == 'Occupied').length;
    await db.update('Rooms', {'occupied_count': occupiedCount}, 'room_id = ?', [roomId]);
    final status = occupiedCount == 0 ? AppConstants.roomAvailable :
                   (occupiedCount >= _rooms.firstWhere((r) => r.roomId == roomId).capacity ? AppConstants.roomOccupied : 'Partial');
    await db.update('Rooms', {'status': status}, 'room_id = ?', [roomId]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.guest == null ? 'Add Guest' : 'Edit Guest'),
        actions: [
          if (widget.guest != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Guest'),
                    content: const Text('Are you sure? This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  final db = DatabaseHelper.instance;
                  await db.delete('Guests', 'guest_id = ?', [widget.guest!.guestId]);
                  if (_selectedBedId != null) {
                    await db.update('Beds', {'status': 'Available', 'guest_id': null}, 'bed_id = ?', [_selectedBedId]);
                  }
                  if (mounted) Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: _rooms.isEmpty
          ? const LoadingIndicator(message: 'Loading rooms...')
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Photo & ID proof pickers
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickImage(ImageSource.gallery, true),
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _photoFile != null
                                  ? Image.file(_photoFile!, fit: BoxFit.cover)
                                  : const Icon(Icons.camera_alt, size: 40),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickImage(ImageSource.gallery, false),
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _idProofFile != null
                                  ? Image.file(_idProofFile!, fit: BoxFit.cover)
                                  : const Icon(Icons.assignment_ind, size: 40),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      items: AppConstants.genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                      decoration: const InputDecoration(labelText: 'Gender'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _idProofType,
                      items: AppConstants.idProofTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _idProofType = v!),
                      decoration: const InputDecoration(labelText: 'ID Proof Type'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idProofNumberController,
                      decoration: const InputDecoration(labelText: 'ID Proof Number'),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emergencyController,
                      decoration: const InputDecoration(labelText: 'Emergency Contact'),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _depositController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Deposit Amount', prefixText: '₹ '),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Monthly Rent', prefixText: '₹ '),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _dueDate,
                            items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('Due Day ${i + 1}'))),
                            onChanged: (v) => setState(() => _dueDate = v!),
                            decoration: const InputDecoration(labelText: 'Rent Due Date'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedRoomId,
                      hint: const Text('Select Room'),
                      items: _rooms.map((room) {
                        return DropdownMenuItem(
                          value: room.roomId,
                          child: Text('${room.roomNumber} (${room.capacity - room.occupiedCount} beds left)'),
                        );
                      }).toList(),
                      onChanged: (roomId) {
                        setState(() {
                          _selectedRoomId = roomId;
                          _selectedBedId = null;
                        });
                      },
                    ),
                    if (_selectedRoomId != null && _bedsByRoom[_selectedRoomId] != null)
                      Column(
                        children: [
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedBedId,
                            hint: const Text('Select Bed'),
                            items: _bedsByRoom[_selectedRoomId]!
                                .where((b) => b.status == 'Available')
                                .map((bed) => DropdownMenuItem(
                                      value: bed.bedId,
                                      child: Text('Bed ${bed.bedNumber}'),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedBedId = v),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveGuest,
                      child: const Text('Save Guest'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}