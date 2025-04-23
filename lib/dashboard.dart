import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.lightGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildDashboardCard(
              context,
              title: 'Items',
              icon: Icons.list,
              onTap: () {
                // Navigate to items page
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Add Item',
              icon: Icons.add,
              onTap: () {
                // Navigate to add item page
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Profile',
              icon: Icons.person,
              onTap: () {
                // Navigate to profile page
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Settings',
              icon: Icons.settings,
              onTap: () {
                // Navigate to settings page
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.lightGreen),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
