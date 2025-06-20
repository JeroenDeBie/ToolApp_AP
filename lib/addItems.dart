import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/map.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum Categories { Kitchen, Washing, Tools, Garden, Other }

class AddItems extends StatefulWidget {
  const AddItems({super.key});

  @override
  _AddItemsState createState() => _AddItemsState();
}

class _AddItemsState extends State<AddItems> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  bool _availability = true;
  Categories? _selectedCategory;
  Marker? marker;

  final NumberFormat currencyFormat = NumberFormat.currency(
    locale: 'nl_NL',
    symbol: '€',
  );

  void _formatPriceInput(String value) {
    String cleanedValue = value.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    ); // Verwijder alles behalve cijfers
    if (cleanedValue.isNotEmpty) {
      double parsedValue =
          double.parse(cleanedValue) / 100; // Zorg voor decimalen
      String formattedValue = currencyFormat.format(parsedValue);
      priceController.value = TextEditingValue(
        text: formattedValue,
        selection: TextSelection.collapsed(offset: formattedValue.length),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voeg item Toe'),
        backgroundColor: Colors.lightGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: MapWidget(
                markers: marker != null ? [marker!] : [],
                onTap: (latlng) {
                  setState(() {
                    marker = new Marker(
                      point: latlng,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    );
                  });
                },
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beschrijving',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Prijs',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              onChanged: _formatPriceInput,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<bool>(
              value: _availability,
              items: const [
                DropdownMenuItem(value: true, child: Text('Beschikbaar')),
                DropdownMenuItem(value: false, child: Text('Niet Beschikbaar')),
              ],
              onChanged: (value) {
                setState(() {
                  _availability = value!;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Beschikbaarheid',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Categories>(
              value: _selectedCategory,
              items:
                  Categories.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.name),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _imageBytes != null
                ? Image.memory(_imageBytes!, height: 150)
                : const Text('Geen afbeelding geselecteerd'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Selecteer Foto'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                String description = descriptionController.text;
                double price =
                    double.tryParse(
                      priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                    ) ??
                    0;
                String? imageBase64 =
                    _imageBytes != null ? base64Encode(_imageBytes!) : null;

                final user = FirebaseAuth.instance.currentUser;
                Navigator.pop(context, {
                  'description': description,
                  'price': price / 100,
                  'availability': _availability,
                  'category': _selectedCategory?.name,
                  'image': imageBase64,
                  'ownerId': user?.uid,
                  'longitude': marker?.point.longitude,
                  'latitude': marker?.point.latitude,
                });
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
