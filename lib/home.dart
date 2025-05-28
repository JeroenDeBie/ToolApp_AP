import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/map.dart';
import 'productDetails.dart';
import 'login.dart';
import 'addItems.dart';
import 'package:latlong2/latlong.dart';
import 'dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum Categories { Kitchen, Washing, Tools, Garden, Other, All }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Map<String, dynamic>> _items = [];
  bool isAvailable = false;
  Categories? selectedCategory = Categories.All;
  List<Marker> markers = [];
  Marker? currentPosition;
  double allowedDistance = 32;
  double maxDistance = 64;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Marker? createMarker(double? latitude, double? longitude) {
    if (longitude != null && latitude != null) {
      return Marker(
        point: LatLng(latitude, longitude),
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: Icon(Icons.location_pin, color: Colors.red, size: 50),
      );
    }

    return null;
  }

  Future<void> _fetchItems() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('tools').get();
      final fetchedItems =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final longitude = data['longitude'];
            final latitude = data['latitude'];

            // addMarker(latitude, longitude);

            return {
              'marker': createMarker(latitude, longitude),
              'description': data['description'] ?? 'No description',
              'availability': data['availability'] ?? false, // Ensure bool
              'image':
                  data['image'] != null
                      ? base64Decode(
                        data['image'] as String,
                      ) // Decode base64 string
                      : null,
              'price':
                  (data['price'] != null)
                      ? (data['price'] as num).toDouble()
                      : 0.0, // Ensure double
              'category':
                  data['category'] ?? 'Geen categorie', // Fetch category
            };
          }).toList();
      setState(() {
        _items.addAll(fetchedItems);
      });
    } catch (e) {
      print('Error fetching items from Firebase: $e');
    }
  }

  void _addItem(Map<String, dynamic> newItem) async {
    try {
      if (newItem['image'] != null && newItem['image'] is Uint8List) {
        newItem['image'] = base64Encode(newItem['image']);
      }

      final longitude = newItem['longitude'];
      final latitude = newItem['latitude'];

      // addMarker(latitude, longitude);
      await FirebaseFirestore.instance.collection('tools').add(newItem);

      setState(() {
        _items.add({
          ...newItem,
          'marker': createMarker(latitude, longitude),
          'image':
              newItem['image'] != null ? base64Decode(newItem['image']) : null,
        });
      });
    } catch (e) {
      print('Error adding item to Firebase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Distance getDistance = Distance();
    final filteredItems =
        _items
            .where((item) => item['availability'] || !isAvailable)
            .where(
              (item) =>
                  item['category'] == selectedCategory?.name ||
                  selectedCategory == Categories.All,
            )
            .where((item) {
              if (currentPosition == null ||
                  item['marker'] == null ||
                  allowedDistance == maxDistance)
                return true;

              final distance = getDistance(
                item['marker']!.point,
                currentPosition!.point,
              );

              return distance <= allowedDistance * 1000;
            })
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.lightGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MapWidget(
              markers: [
                ...filteredItems
                    .map((item) => item['marker'])
                    .where((marker) => marker != null)
                    .cast<Marker>(),
                if (currentPosition != null) currentPosition!,
              ],
              onTap: (latlng) {
                setState(() {
                  currentPosition = Marker(
                    point: latlng,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.blue,
                      size: 50,
                    ),
                  );
                });
              },
            ),
          ),
          Slider(
            value: allowedDistance,
            min: 0,
            max: maxDistance,
            divisions: 32,
            label:
                "${(allowedDistance != maxDistance) ? allowedDistance.round().toString() : 'Infinite'} km",
            onChanged: (double value) {
              setState(() {
                allowedDistance = value;
              });
            },
          ),

          Row(
            children: [
              Text("Show available items"),
              Checkbox(
                value: isAvailable,
                onChanged: (bool? newValue) {
                  setState(() {
                    isAvailable = newValue!;
                  });
                },
              ),

              Expanded(
                child: DropdownButtonFormField<Categories>(
                  value: selectedCategory,
                  items:
                      Categories.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category.name),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child:
                _items.isEmpty
                    ? const Center(child: Text('Geen items toegevoegd.'))
                    : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          leading: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          ProductDetailPage(item: item),
                                ),
                              );
                            },
                            child:
                                item['image'] != null
                                    ? Image.memory(
                                      item['image'] as Uint8List,
                                      width: 70,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    )
                                    : const Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                    ),
                          ),
                          title: Text(
                            item['description']!,
                            style: const TextStyle(fontSize: 18),
                          ),
                          subtitle: Text(
                            '€${item['price']!.toString()}${currentPosition != null? " - ${Distance()(item["marker"]?.point, currentPosition!.point)} meters": ""}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      },
                    ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newItem = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(builder: (context) => const AddItems()),
              );
              if (newItem != null) {
                _addItem(newItem);
              }
            },
            child: const Text('Voeg item Toe'),
          ),
        ],
      ),
    );
  }
}
