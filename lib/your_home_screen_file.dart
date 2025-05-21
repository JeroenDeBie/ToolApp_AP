import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const ProductDetailPage({super.key, required this.item});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Map<String, dynamic> item;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item);
  }

  Future<void> _pickReservationDate(BuildContext context) async {
    // Set time to midnight for consistency
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = today.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: lastDay,
      helpText: 'Selecteer de einddatum van de reservering (max 7 dagen)',
      // locale: const Locale('nl', 'NL'), // Remove this line for compatibility
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _reserveItem(BuildContext context) async {
    if (_selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecteer eerst een einddatum!')),
      );
      return;
    }
    try {
      // Get the current user
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gebruiker niet ingelogd!')),
        );
        return;
      }

      // Update the item's availability in the tools collection
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('tools')
              .where('description', isEqualTo: item['description'])
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        for (var doc in querySnapshot.docs) {
          // Add reservation info to a subcollection or a separate collection
          await FirebaseFirestore.instance
              .collection('tools')
              .doc(doc.id)
              .update({
                'availability': false,
                'reservedBy': user.uid,
                'reservationStart': Timestamp.fromDate(DateTime.now()),
                'reservationEnd': Timestamp.fromDate(_selectedEndDate!),
              });
          // Optionally, add a reservation record for tracking
          await FirebaseFirestore.instance.collection('reservations').add({
            'toolId': doc.id,
            'userId': user.uid,
            'reservationStart': Timestamp.fromDate(DateTime.now()),
            'reservationEnd': Timestamp.fromDate(_selectedEndDate!),
            'toolDescription': item['description'],
          });
        }
        // Update local state so UI updates instantly
        setState(() {
          item['availability'] = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item niet gevonden in tools!')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item gereserveerd! Beschikbaarheid bijgewerkt.'),
        ),
      );

      // Optionally, do not pop immediately so user sees the update
      // Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fout bij reserveren: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.lightGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item['image'] != null
                ? Image.memory(item['image'], height: 200)
                : const Icon(Icons.image_not_supported, size: 100),
            const SizedBox(height: 16),
            Text(
              'Beschrijving:',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(item['description']!, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text(
              'Prijs:',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('€${item['price']}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text(
              'Beschikbaarheid:',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              item['availability'] ? 'Beschikbaar' : 'Niet Beschikbaar',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Categorie:',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              item['category'] ?? 'Geen categorie',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Reservering tot:',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedEndDate != null
                        ? DateFormat('dd-MM-yyyy').format(_selectedEndDate!)
                        : 'Geen einddatum geselecteerd',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      item['availability']
                          ? () => _pickReservationDate(context)
                          : null,
                  child: const Text('Kies datum'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  item['availability']
                      ? () => _reserveItem(context)
                      : null, // Disable button if not available
              child: const Text('Reserveer Item'),
            ),
          ],
        ),
      ),
    );
  }
}
