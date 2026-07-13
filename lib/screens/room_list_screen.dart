// room_list_screen.dart
import 'package:flutter/material.dart';
import 'package:pg_management/models/room.dart';
import 'package:pg_management/screens/room_add_edit_screen.dart';
import 'package:pg_management/widgets/empty_state.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/core/constants.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  List<Room> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final rooms = await db.getAllRooms();
    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.roomAvailable: return Colors.green;
      case AppConstants.roomOccupied: return Colors.red;
      case AppConstants.roomMaintenance: return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomAddEditScreen()));
          if (result == true) _loadRooms();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? EmptyState(
                  title: 'No Rooms',
                  message: 'Tap + to add a room',
                  icon: Icons.meeting_room,
                  onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomAddEditScreen())),
                  actionLabel: 'Add Room',
                )
              : ListView.builder(
                  itemCount: _rooms.length,
                  itemBuilder: (ctx, i) {
                    final room = _rooms[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(room.status),
                          child: Text(room.roomNumber),
                        ),
                        title: Text('Room ${room.roomNumber} (${room.roomType})'),
                        subtitle: Text('${room.occupiedCount}/${room.capacity} occupied • ${room.status}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomAddEditScreen(room: room)));
                            if (result == true) _loadRooms();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}