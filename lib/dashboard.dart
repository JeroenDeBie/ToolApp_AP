import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';

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
              title: 'Reservations',
              icon: Icons.list,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReservationsPage(),
                  ),
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Add Reservation',
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

class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        backgroundColor: Colors.lightGreen,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('reservations')
                .where('userId', isEqualTo: userId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Geen reserveringen gevonden.'));
          }
          final reservations = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation =
                  reservations[index].data() as Map<String, dynamic>;
              final String? toolId = reservation['toolId'];
              return FutureBuilder<DocumentSnapshot>(
                future:
                    toolId != null
                        ? FirebaseFirestore.instance
                            .collection('tools')
                            .doc(toolId)
                            .get()
                        : Future.value(null),
                builder: (context, toolSnapshot) {
                  String description = 'Geen beschrijving';
                  String price = '0.0';
                  if (toolSnapshot.hasData &&
                      toolSnapshot.data != null &&
                      toolSnapshot.data!.exists) {
                    final toolData =
                        toolSnapshot.data!.data() as Map<String, dynamic>;
                    description =
                        toolData['description'] ?? 'Geen beschrijving';
                    price = toolData['price']?.toString() ?? '0.0';
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: ListTile(
                      leading:
                          reservation['image'] != null
                              // Use Uint8List for image bytes
                              ? Image.memory(
                                Uint8List.fromList(
                                  List<int>.from(reservation['image']),
                                ),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                              : const Icon(Icons.image_not_supported),
                      title: Text(description),
                      subtitle: Text('€$price'),
                      onTap:
                          toolSnapshot.hasData &&
                                  toolSnapshot.data != null &&
                                  toolSnapshot.data!.exists
                              ? () {
                                final toolData =
                                    toolSnapshot.data!.data()
                                        as Map<String, dynamic>;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ProductDetails(
                                          toolData: toolData,
                                          reservation: reservation,
                                          reservationId: reservations[index].id,
                                          toolId: toolId,
                                        ),
                                  ),
                                );
                              }
                              : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ProductDetails extends StatelessWidget {
  final Map<String, dynamic> toolData;
  final Map<String, dynamic> reservation;
  final String reservationId;
  final String? toolId;

  const ProductDetails({
    super.key,
    required this.toolData,
    required this.reservation,
    required this.reservationId,
    required this.toolId,
  });

  @override
  Widget build(BuildContext context) {
    // Parse end date if present
    DateTime? endDate;
    if (reservation['reservationEnd'] != null) {
      try {
        endDate =
            (reservation['reservationEnd'] is Timestamp)
                ? (reservation['reservationEnd'] as Timestamp).toDate()
                : DateTime.tryParse(reservation['reservationEnd'].toString());
      } catch (_) {}
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Replace the image display with error handling
            Builder(
              builder: (context) {
                final imageData = toolData['image'];
                if (imageData != null) {
                  try {
                    Uint8List bytes;
                    if (imageData is String) {
                      // Try to decode as base64 string
                      bytes = base64Decode(imageData);
                    } else if (imageData is List<int>) {
                      bytes = Uint8List.fromList(imageData);
                    } else if (imageData is List<dynamic>) {
                      bytes = Uint8List.fromList(imageData.cast<int>());
                    } else {
                      throw Exception('Unknown image format');
                    }
                    return Image.memory(
                      bytes,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    );
                  } catch (e) {
                    return const Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.grey,
                    );
                  }
                } else {
                  return const Icon(
                    Icons.image_not_supported,
                    size: 100,
                    color: Colors.grey,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              toolData['description'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '€${toolData['price']?.toString() ?? '0.0'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (endDate != null)
              Text(
                'Einde reservatie: ${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  // Cancel reservation and set tool available
                  await FirebaseFirestore.instance
                      .collection('reservations')
                      .doc(reservationId)
                      .delete();
                  if (toolId != null) {
                    await FirebaseFirestore.instance
                        .collection('tools')
                        .doc(toolId)
                        .update({
                          'availability': true,
                          'reservedBy': null,
                          'reservationEnd': null,
                          'reservationStart': null,
                        });
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reservering geannuleerd')),
                  );
                },
                child: const Text('Annuleer reservering'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
