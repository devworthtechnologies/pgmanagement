// room_add_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/models/room.dart';
import 'package:pg_management/models/bed.dart';
import 'package:pg_management/database/database_helper.dart';

class RoomAddEditScreen extends StatefulWidget {
  final Room? room;

  const RoomAddEditScreen({super.key, this.room});

  @override
  State<RoomAddEditScreen> createState() => _RoomAddEditScreenState();
}

class _RoomAddEditScreenState extends State<RoomAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _roomTypeController = TextEditingController();
  final _capacityController = TextEditingController();
  final _notesController = TextEditingController();
  final List<Bed> _beds = [];

  @override
  void initState() {
    super.initState();
    if (widget.room != null) {
      _roomNumberController.text = widget.room!.roomNumber;
      _roomTypeController.text = widget.room!.roomType;
      _capacityController.text = widget.room!.capacity.toString();
      _notesController.text = widget.room!.notes ?? '';
      _loadBeds();
    }
  }

  Future<void> _loadBeds() async {
    final db = DatabaseHelper.instance;
    final maps = await db
        .query('Beds', where: 'room_id = ?', whereArgs: [widget.room!.roomId]);
    setState(() {
      _beds.clear();
      _beds.addAll(maps.map((m) => Bed.fromMap(m)));
    });
  }

  void _addBed() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bed'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Bed Number'),
          onSubmitted: (value) async {
            if (value.isNotEmpty) {
              final bed = Bed(
                roomId: widget.room!.roomId!,
                bedNumber: value,
                status: AppConstants.roomAvailable,
              );
              final db = DatabaseHelper.instance;
              await db.insert('Beds', bed.toMap());
              _loadBeds();
              Navigator.pop(ctx);
            }
          },
        ),
      ),
    );
  }

  Future<void> _removeBed(Bed bed) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bed'),
        content: const Text(
            'Are you sure? This will also remove any guest assigned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm == true) {
      final db = DatabaseHelper.instance;
      await db.delete('Beds', 'bed_id = ?', [bed.bedId]);
      _loadBeds();
    }
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;

    final room = Room(
      roomId: widget.room?.roomId,
      roomNumber: _roomNumberController.text,
      roomType: _roomTypeController.text,
      capacity: int.parse(_capacityController.text),
      occupiedCount: widget.room?.occupiedCount ?? 0,
      status: AppConstants.roomAvailable,
      notes: _notesController.text,
    );

    final db = DatabaseHelper.instance;
    if (widget.room == null) {
      await db.insert('Rooms', room.toMap());
      // Optionally create default beds based on capacity? Not here, manual.
    } else {
      await db
          .update('Rooms', room.toMap(), 'room_id = ?', [widget.room!.roomId]);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.room == null ? 'Room added' : 'Room updated')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room == null ? 'Add Room' : 'Edit Room'),
        actions: [
          if (widget.room != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Room'),
                    content: const Text(
                        'This will delete the room and all beds. Guests must be moved first.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  final db = DatabaseHelper.instance;
                  await db
                      .delete('Rooms', 'room_id = ?', [widget.room!.roomId]);
                  if (mounted) Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomTypeController,
                decoration: const InputDecoration(
                    labelText: 'Room Type (e.g., Single, Double)'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity (beds)'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _saveRoom, child: const Text('Save Room')),
              if (widget.room != null) ...[
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Beds',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: _addBed, icon: const Icon(Icons.add)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._beds.map((bed) => ListTile(
                      title: Text('Bed ${bed.bedNumber}'),
                      subtitle: Text('Status: ${bed.status}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeBed(bed),
                      ),
                    )),
                if (_beds.isEmpty) const Text('No beds added yet.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
