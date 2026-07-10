import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pg_management/core/utils.dart';
import 'package:pg_management/providers/providers.dart';
import 'package:pg_management/widgets/custom_card.dart';
import 'package:pg_management/screens/guest_list_screen.dart';
import 'package:pg_management/screens/room_list_screen.dart';
import 'package:pg_management/screens/income_screen.dart';
import 'package:pg_management/screens/expense_screen.dart';
import 'package:pg_management/screens/reports_screen.dart';
import 'package:pg_management/screens/settings_screen.dart';
import 'package:pg_management/services/google_signin_service.dart';
import 'package:pg_management/screens/login_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardHome(),
    const GuestListScreen(),
    const RoomListScreen(),
    const IncomeScreen(),
    const ExpenseScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Guests'),
          NavigationDestination(icon: Icon(Icons.meeting_room), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Income'),
          NavigationDestination(icon: Icon(Icons.money_off), label: 'Expense'),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.house, size: 40, color: Colors.white),
                  SizedBox(height: 10),
                  Text('PG Management', style: TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await GoogleSignInService().signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHome extends ConsumerWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardData = ref.watch(dashboardDataProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: dashboardData.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  CustomCard(
                    title: 'Total Guests',
                    value: data['totalGuests'].toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  CustomCard(
                    title: 'Occupied Rooms',
                    value: data['occupiedRooms'].toString(),
                    icon: Icons.meeting_room,
                    color: Colors.green,
                  ),
                  CustomCard(
                    title: 'Vacant Rooms',
                    value: data['vacantRooms'].toString(),
                    icon: Icons.room_preferences,
                    color: Colors.orange,
                  ),
                  CustomCard(
                    title: 'Monthly Income',
                    value: AppUtils.formatCurrency((data['monthlyIncome'])?.toDouble() ?? 0.0),
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
                  CustomCard(
                    title: 'Monthly Expense',
                    value: AppUtils.formatCurrency((data['monthlyExpense'])?.toDouble() ?? 0.0),
                    icon: Icons.money_off,
                    color: Colors.red,
                  ),
                  CustomCard(
                    title: 'Pending Rent',
                    value: AppUtils.formatCurrency((data['pendingRent'])?.toDouble() ?? 0.0),
                    icon: Icons.pending,
                    color: Colors.purple,
                  ),
                  CustomCard(
                    title: 'Profit',
                    value: AppUtils.formatCurrency((data['profit'])?.toDouble() ?? 0.0),
                    icon: Icons.trending_up,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.warning),
                  title: const Text('Rent Due Soon'),
                  subtitle: const Text('Check guest payments'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to pending rent list
                  },
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}