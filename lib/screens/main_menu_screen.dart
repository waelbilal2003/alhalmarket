import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'program_basics_screen.dart'; // استيراد شاشة أساسيات البرنامج

class MainMenuScreen extends StatelessWidget {
  final String selectedDate;
  final String storeName;

  const MainMenuScreen({
    super.key,
    required this.selectedDate,
    required this.storeName,
  });

  void _navigateToBasics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProgramBasicsScreen(),
      ),
    );
  }

  void _exit(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'القائمة الرئيسية - $storeName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // عمودان
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.5, // نسبة العرض إلى الارتفاع
          children: [
            _buildMenuButton(
              context,
              title: 'أساسيات البرنامج',
              icon: Icons.settings_applications,
              color: Colors.teal,
              onPressed: () => _navigateToBasics(context),
            ),
            _buildMenuButton(
              context,
              title: 'حركة الحسابات',
              icon: Icons.account_balance_wallet,
              color: Colors.blueGrey,
              onPressed: () {}, // زر مظهر فقط
            ),
            _buildMenuButton(
              context,
              title: 'الخدمات',
              icon: Icons.miscellaneous_services,
              color: Colors.deepOrange,
              onPressed: () {}, // زر مظهر فقط
            ),
            _buildMenuButton(
              context,
              title: 'تغيير المحل',
              icon: Icons.store_mall_directory,
              color: Colors.purple,
              onPressed: () {}, // زر مظهر فقط
            ),
            _buildMenuButton(
              context,
              title: 'خروج',
              icon: Icons.exit_to_app,
              color: Colors.red,
              onPressed: () => _exit(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact(); // اهتزاز خفيف عند الضغط
        onPressed();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
