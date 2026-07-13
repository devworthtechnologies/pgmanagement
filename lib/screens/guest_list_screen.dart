// guest_list_screen.dart
import 'package:flutter/material.dart';
import 'package:pg_management/models/guest.dart';
import 'package:pg_management/screens/guest_add_edit_screen.dart';
import 'package:pg_management/widgets/empty_state.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pg_management/screens/payment_screen.dart';
class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  List<Guest> _guests = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final guests = await db.getAllGuests();
    setState(() {
      _guests = guests;
      _loading = false;
    });
  }

  List<Guest> get _filteredGuests {
    if (_searchQuery.isEmpty) return _guests;
    return _guests.where((g) =>
      g.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      g.phone.contains(_searchQuery)
    ).toList();
  }

  Future<void> _checkoutGuest(Guest guest) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkout Guest'),
        content: Text('Checkout ${guest.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Checkout')),
        ],
      ),
    );
    if (confirm == true) {
      final db = DatabaseHelper.instance;
      await db.update('Guests', {'status': 'Checked Out'}, 'guest_id = ?', [guest.guestId]);
      if (guest.bedId != null) {
        await db.update('Beds', {'status': 'Available', 'guest_id': null}, 'bed_id = ?', [guest.bedId]);
      }
      if (guest.roomId != null) {
        final beds = await db.query('Beds', where: 'room_id = ?', whereArgs: [guest.roomId]);
        final occupiedCount = beds.where((b) => b['status'] == 'Occupied').length;
        await db.update('Rooms', {'occupied_count': occupiedCount}, 'room_id = ?', [guest.roomId]);
      }
      _loadGuests();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guest checked out')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestAddEditScreen()));
          if (result == true) _loadGuests();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredGuests.isEmpty
              ? EmptyState(
                  title: _searchQuery.isEmpty ? 'No Guests' : 'No matches',
                  message: _searchQuery.isEmpty ? 'Tap + to add a new guest' : 'Try a different search',
                  icon: Icons.people_outline,
                  onAction: _searchQuery.isEmpty
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestAddEditScreen()))
                      : null,
                  actionLabel: 'Add Guest',
                )
              : ListView.builder(
                  itemCount: _filteredGuests.length,
                  itemBuilder: (ctx, i) {
                    final guest = _filteredGuests[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(guest.fullName[0])),
                        title: Text(guest.fullName),
                        subtitle: Text('${guest.phone} | Rent: ${AppUtils.formatCurrency(guest.monthlyRent)}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => GuestAddEditScreen(guest: guest)));
                              if (result == true) _loadGuests();
                            } else if (value == 'checkout') {
                              _checkoutGuest(guest);
                            } else if (value == 'payments') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(guest: guest)));
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'checkout', child: Text('Checkout')),
                            const PopupMenuItem(value: 'payments', child: Text('Payments')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}