import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'productDetails.dart';


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
              onPressed: () {
                String description = descriptionController.text;
                String price = currencyFormat.format(
                  (double.tryParse(
                        priceController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                      ) ??
                      0) / 100
                ); // Ensure proper formatting
                Navigator.pop(context, {
                  'description': description,
                  'price': price,
                  'image': _imageBytes,
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

