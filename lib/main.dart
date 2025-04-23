import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Auth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: 'Tool App'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
  }

  Future<void> _register() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! You can now log in.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.lightGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _login, child: const Text('Login')),
            TextButton(
              onPressed: _register,
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}

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
                MaterialPageRoute(builder: (context) => const SecondPage()),
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

class SecondPage extends StatefulWidget {
  const SecondPage({super.key});

  @override
  _SecondPageState createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
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
                  double.tryParse(
                        priceController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                      ) ??
                      0,
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

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ProductDetailPage({super.key, required this.item});

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
            Text(item['price']!, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
