import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pg_management/core/constants.dart';
import 'package:pg_management/database/database_helper.dart';
import 'package:pg_management/models/pg_details.dart';
import 'package:pg_management/screens/dashboard_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pgNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _totalRoomsController = TextEditingController();
  final _totalFloorsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PG Setup Wizard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Icon(Icons.house, size: 80),
              const SizedBox(height: 20),
              const Text('Welcome! Let\'s set up your PG', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _pgNameController,
                decoration: const InputDecoration(labelText: 'PG Name', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalRoomsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Rooms', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalFloorsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Floors', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _savePGDetails,
                child: const Text('Complete Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePGDetails() async {
    if (_formKey.currentState!.validate()) {
      final pgDetails = PGDetails(
        pgName: _pgNameController.text,
        ownerName: _ownerNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        address: _addressController.text,
        totalRooms: int.parse(_totalRoomsController.text),
        totalFloors: int.parse(_totalFloorsController.text),
        createdDate: DateTime.now(),
      );
      
      final db = DatabaseHelper.instance;
      await db.insert('PG_Details', pgDetails.toMap());
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SharedPrefKeys.hasPGSetup, true);
      
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    }
  }
}