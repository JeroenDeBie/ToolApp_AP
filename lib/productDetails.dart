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
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isCheckingReservation = false;

  // Store reserved date ranges as pairs: [start, end]
  List<List<DateTime>> _reservedRanges = [];

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item);
    _fetchLatestItemData();
    _fetchReservedRanges();
  }

  Future<void> _fetchLatestItemData() async {
    final querySnapshot =
        await FirebaseFirestore.instance
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

  Future<void> _fetchReservedRanges() async {
    final reservations =
        await FirebaseFirestore.instance
            .collection('reservations')
            .where('toolDescription', isEqualTo: item['description'])
            .get();

    List<List<DateTime>> ranges = [];
    for (var doc in reservations.docs) {
      final data = doc.data();
      DateTime? start;
      DateTime? end;
      final reservationStart = data['reservationStart'];
      final reservationEnd = data['reservationEnd'];
      if (reservationStart is Timestamp) {
        start = reservationStart.toDate();
      } else if (reservationStart is DateTime) {
        start = reservationStart;
      } else if (reservationStart is String) {
        start = DateTime.tryParse(reservationStart);
      }
      if (reservationEnd is Timestamp) {
        end = reservationEnd.toDate();
      } else if (reservationEnd is DateTime) {
        end = reservationEnd;
      } else if (reservationEnd is String) {
        end = DateTime.tryParse(reservationEnd);
      }
      if (start != null && end != null) {
        // Only add if end is in the future
        if (end.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
          ranges.add([start, end]);
        }
      }
    }
    setState(() {
      _reservedRanges = ranges;
    });
  }

  // Helper to check if a date is in any reserved range
  bool _isDateReserved(DateTime day) {
    for (final range in _reservedRanges) {
      final start = DateTime(range[0].year, range[0].month, range[0].day);
      final end = DateTime(range[1].year, range[1].month, range[1].day);
      if (!day.isBefore(start) && !day.isAfter(end)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _isItemCurrentlyReserved() async {
    final querySnapshot =
        await FirebaseFirestore.instance
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

  /// Checks if the selected reservation period overlaps with any existing reservation.
  Future<bool> _isItemReservedForPeriod(
    DateTime selectedStart,
    DateTime selectedEnd,
  ) async {
    final reservations = await FirebaseFirestore.instance
        .collection('reservations')
        .where('toolDescription', isEqualTo: item['description'])
        .get();

    for (var doc in reservations.docs) {
      final data = doc.data();
      DateTime? start;
      DateTime? end;
      final reservationStart = data['reservationStart'];
      final reservationEnd = data['reservationEnd'];
      if (reservationStart is Timestamp) {
        start = reservationStart.toDate();
      } else if (reservationStart is DateTime) {
        start = reservationStart;
      } else if (reservationStart is String) {
        start = DateTime.tryParse(reservationStart);
      }
      if (reservationEnd is Timestamp) {
        end = reservationEnd.toDate();
      } else if (reservationEnd is DateTime) {
        end = reservationEnd;
      } else if (reservationEnd is String) {
        end = DateTime.tryParse(reservationEnd);
      }
      if (start != null && end != null) {
        // Check for overlap: (startA <= endB) && (endA >= startB)
        if (selectedStart.isBefore(end.add(const Duration(days: 1))) &&
            selectedEnd.isAfter(start.subtract(const Duration(days: 1)))) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _pickReservationStartDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = today.add(const Duration(days: 30));
    // Use first available day as initial date
    final initial = _selectedStartDate != null && !_isDateReserved(_selectedStartDate!)
        ? _selectedStartDate!
        : _findFirstAvailableDay(today);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: lastDay,
      helpText: 'Selecteer de startdatum van de reservering',
      selectableDayPredicate: (day) {
        // Disable reserved days only
        return !_isDateReserved(day);
      },
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
        // Reset end date if it's before start date
        if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
          _selectedEndDate = null;
        }
      });
    }
  }

  Future<void> _pickReservationEndDate(BuildContext context) async {
    if (_selectedStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecteer eerst een startdatum!')),
      );
      return;
    }
    final lastDay = _selectedStartDate!.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? _selectedStartDate!,
      firstDate: _selectedStartDate!,
      lastDate: lastDay,
      helpText: 'Selecteer de einddatum van de reservering (max 7 dagen)',
      selectableDayPredicate: (day) {
        // Disable reserved days and days before start
        if (day.isBefore(_selectedStartDate!)) return false;
        return !_isDateReserved(day);
      },
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _reserveItem(BuildContext context) async {
    if (_selectedStartDate == null || _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecteer eerst een start- en einddatum!'),
        ),
      );
      return;
    }
    setState(() {
      _isCheckingReservation = true;
    });
    try {
      final selectedStart = DateTime(
        _selectedStartDate!.year,
        _selectedStartDate!.month,
        _selectedStartDate!.day,
      );
      final selectedEnd = DateTime(
        _selectedEndDate!.year,
        _selectedEndDate!.month,
        _selectedEndDate!.day,
      );

      // Check if item is already reserved for the selected period
      if (await _isItemReservedForPeriod(selectedStart, selectedEnd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dit item is al gereserveerd voor (een deel van) deze periode!',
            ),
          ),
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

      // Check Firestore security rules: try-catch for permission errors
      try {
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
                  'reservationStart': Timestamp.fromDate(selectedStart),
                  'reservationEnd': Timestamp.fromDate(selectedEnd),
                });
            await FirebaseFirestore.instance.collection('reservations').add({
              'toolId': doc.id,
              'userId': user.uid,
              'reservationStart': Timestamp.fromDate(selectedStart),
              'reservationEnd': Timestamp.fromDate(selectedEnd),
              'toolDescription': item['description'],
            });
          }
          setState(() {
            item['availability'] = false;
            item['reservationEnd'] = Timestamp.fromDate(selectedEnd);
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
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Onvoldoende rechten om deze actie uit te voeren.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fout bij reserveren: ${e.message}')),
          );
        }
        setState(() {
          _isCheckingReservation = false;
        });
        return;
      }
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
    // Always allow picking a future reservation, unless the selected period overlaps
    return true;
  }

  // Helper to find the first available day after today
  DateTime _findFirstAvailableDay(DateTime from) {
    DateTime day = from;
    while (_isDateReserved(day)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  // Helper: is every day in the next 7 days reserved?
  bool get _isFullyReservedNext7Days {
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      if (!_isDateReserved(day)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.lightGreen,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item['image'] != null && item['image'] is Uint8List
                  ? Container(
                      height: 200,
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.memory(
                        item['image'],
                        fit: BoxFit.cover,
                      ),
                    )
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
                _isFullyReservedNext7Days ? 'Niet Beschikbaar' : 'Beschikbaar',
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
                'Reservering van:',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedStartDate != null
                          ? DateFormat('dd-MM-yyyy').format(_selectedStartDate!)
                          : 'Geen startdatum geselecteerd',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        _canReserve && !_isCheckingReservation
                            ? () => _pickReservationStartDate(context)
                            : null,
                    child: const Text('Kies startdatum'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                        _canReserve && !_isCheckingReservation
                            ? () => _pickReservationEndDate(context)
                            : null,
                    child: const Text('Kies einddatum'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    _canReserve && !_isCheckingReservation
                        ? () => _reserveItem(context)
                        : null,
                child: const Text('Reserveer Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
