// providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/pg_details.dart';
import 'package:pg_management/models/guest.dart';
import 'package:pg_management/models/room.dart';
import 'package:pg_management/repositories/guest_repository.dart';
import 'package:pg_management/repositories/room_repository.dart';

// Theme provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// Database provider
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

// Repositories
final guestRepositoryProvider = Provider<GuestRepository>((ref) {
  return GuestRepository(ref.read(databaseHelperProvider));
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(ref.read(databaseHelperProvider));
});

// Dashboard data provider
final dashboardDataProvider = FutureProvider((ref) async {
  final db = ref.read(databaseHelperProvider);
  final guests = await db.getAllGuests();
  final rooms = await db.getAllRooms();
  final currentMonth = DateTime.now();
  final monthlyIncome = await db.getTotalIncomeByMonth(currentMonth);
  final monthlyExpense = await db.getTotalExpenseByMonth(currentMonth);
  final pendingRent = await db.getPendingRent();

  return {
    'totalGuests': guests.length,
    'occupiedRooms': rooms.where((r) => r.status == 'Occupied').length,
    'vacantRooms': rooms.where((r) => r.status == 'Available').length,
    'monthlyIncome': monthlyIncome,
    'monthlyExpense': monthlyExpense,
    'pendingRent': pendingRent,
    'profit': monthlyIncome - monthlyExpense,
  };
});

// Guest list provider
final guestListProvider = FutureProvider<List<Guest>>((ref) async {
  final repo = ref.read(guestRepositoryProvider);
  return await repo.getAllGuests();
});

// Room list provider
final roomListProvider = FutureProvider<List<Room>>((ref) async {
  final repo = ref.read(roomRepositoryProvider);
  return await repo.getAllRooms();
});

// PG Details provider
final pgDetailsProvider = FutureProvider<PGDetails?>((ref) async {
  final db = ref.read(databaseHelperProvider);
  return await db.getPGDetails();
});

// Backup status provider
final backupStatusProvider = StateProvider<bool>((ref) => false);
