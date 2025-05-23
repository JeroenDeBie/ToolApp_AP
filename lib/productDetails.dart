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
  bool _isCheckingReservation = false;

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item);
    _fetchLatestItemData();
  }

  Future<void> _fetchLatestItemData() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('tools')
        .where('description', isEqualTo: item['description'])
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      setState(() {
        // Preserve the original image if present
        final originalImage = item['image'];
        item = Map<String, dynamic>.from(data);
        if (originalImage != null) {
          item['image'] = originalImage;
        }
        // Defensive: ensure required fields exist and are the right type
        if (!item.containsKey('availability') || item['availability'] == null) {
          item['availability'] = true;
        }
        if (item['reservationEnd'] != null) {
          final val = item['reservationEnd'];
          if (val is Timestamp) {
            _selectedEndDate = val.toDate();
          } else if (val is DateTime) {
            _selectedEndDate = val;
          } else if (val is String) {
            _selectedEndDate = DateTime.tryParse(val);
          } else {
            _selectedEndDate = null;
          }
        } else {
          _selectedEndDate = null;
        }
      });
    }
  }

  Future<bool> _isItemCurrentlyReserved() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('tools')
        .where('description', isEqualTo: item['description'])
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final reserved = data['availability'] == false;
      final reservationEnd = data['reservationEnd'];
      if (reserved && reservationEnd != null) {
        DateTime? end;
        if (reservationEnd is Timestamp) {
          end = reservationEnd.toDate();
        } else if (reservationEnd is DateTime) {
          end = reservationEnd;
        } else if (reservationEnd is String) {
          end = DateTime.tryParse(reservationEnd);
        }
        if (end != null && end.isAfter(DateTime.now())) {
          return true;
        }
      }
    }
    return false;
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
    setState(() {
      _isCheckingReservation = true;
    });
    try {
      // Check if item is already reserved for the future
      if (await _isItemCurrentlyReserved()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dit item is al gereserveerd!')),
        );
        setState(() {
          _isCheckingReservation = false;
        });
        return;
      }

      // Get the current user
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gebruiker niet ingelogd!')),
        );
        setState(() {
          _isCheckingReservation = false;
        });
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
          await FirebaseFirestore.instance
              .collection('tools')
              .doc(doc.id)
              .update({
                'availability': false,
                'reservedBy': user.uid,
                'reservationStart': Timestamp.fromDate(DateTime.now()),
                'reservationEnd': Timestamp.fromDate(_selectedEndDate!),
              });
          await FirebaseFirestore.instance.collection('reservations').add({
            'toolId': doc.id,
            'userId': user.uid,
            'reservationStart': Timestamp.fromDate(DateTime.now()),
            'reservationEnd': Timestamp.fromDate(_selectedEndDate!),
            'toolDescription': item['description'],
          });
        }
        setState(() {
          item['availability'] = false;
          item['reservationEnd'] = Timestamp.fromDate(_selectedEndDate!);
          _isCheckingReservation = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item niet gevonden in tools!')),
        );
        setState(() {
          _isCheckingReservation = false;
        });
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
      setState(() {
        _isCheckingReservation = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fout bij reserveren: $e')));
    }
  }

  bool get _canReserve {
    // Defensive: ensure availability is a bool
    final availability = item['availability'] is bool ? item['availability'] : true;
    if (availability == false && item['reservationEnd'] != null) {
      DateTime? end;
      final val = item['reservationEnd'];
      if (val is Timestamp) {
        end = val.toDate();
      } else if (val is DateTime) {
        end = val;
      } else if (val is String) {
        end = DateTime.tryParse(val);
      }
      if (end != null && end.isAfter(DateTime.now())) {
        return false;
      }
    }
    return availability == true;
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
            item['image'] != null && item['image'] is Uint8List
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
              item['availability'] == true ? 'Beschikbaar' : 'Niet Beschikbaar',
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
                    (() {
                      DateTime? displayDate = _selectedEndDate;
                      if (displayDate == null && item['reservationEnd'] != null) {
                        final val = item['reservationEnd'];
                        if (val is Timestamp) {
                          displayDate = val.toDate();
                        } else if (val is DateTime) {
                          displayDate = val;
                        } else if (val is String) {
                          displayDate = DateTime.tryParse(val);
                        }
                      }
                      return displayDate != null
                          ? DateFormat('dd-MM-yyyy').format(displayDate)
                          : 'Geen einddatum geselecteerd';
                    })(),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      _canReserve && !_isCheckingReservation
                          ? () => _pickReservationDate(context)
                          : null,
                  child: const Text('Kies datum'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _canReserve && !_isCheckingReservation
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
