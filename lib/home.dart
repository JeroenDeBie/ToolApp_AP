import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/map.dart';
import 'productDetails.dart';
import 'login.dart';
import 'addItems.dart';
import 'dashboard.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Map<String, dynamic>> _items =
      []; // Updated to include dynamic for image

  void _addItem(Map<String, dynamic> newItem) {
    setState(() {
      _items.add(newItem);
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: MapWidget()),
          Expanded(
            child:
                _items.isEmpty
                    ? const Center(child: Text('Geen items toegevoegd.'))
                    : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          leading: GestureDetector(
                            behavior:
                                HitTestBehavior
                                    .translucent, // Ensure taps are detected
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
                                      item['image'],
                                      width: 70,
                                      height: 200,
                                      fit:
                                          BoxFit
                                              .cover, // Ensure the image fits properly
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
                            item['price']!,
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
