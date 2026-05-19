import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

class CartProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> get items => _items;

  int get total => _items.fold(0, (sum, item) => sum + ((item['precio'] ?? 0) as num).toInt());

  void agregarItem(Map<String, dynamic> planta) {
    _items.add(planta);
    notifyListeners();
  }

  void eliminarItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void vaciarCarrito() {
    _items.clear();
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(),
      child: const ViveroApp(),
    ),
  );
}

class ViveroApp extends StatelessWidget {
  const ViveroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vivero Ceci',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// PANTALLA PRINCIPAL (Catálogo con Filtros)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variables para guardar el estado de la búsqueda y filtros
  String _searchQuery = '';
  String _selectedCategory = 'Todas';

  // Lista de categorías para los botones rápidos
  final List<String> _categorias = ['Todas', 'Interior', 'Exterior', 'Suculentas', 'Frutales'];

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Vivero Cecilia Hidalgo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Panel de Administración',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
        },
        backgroundColor: Colors.green.shade800,
        icon: const Icon(Icons.shopping_cart, color: Colors.white),
        label: Text('${cart.items.length} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ZONA DE BÚSQUEDA Y FILTROS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de Búsqueda
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar plantas...',
                    prefixIcon: const Icon(Icons.search, color: Colors.green),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Botones de Categorías (Scroll horizontal)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categorias.map((categoria) {
                      final isSelected = _selectedCategory == categoria;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(categoria, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: Colors.green.shade600,
                          backgroundColor: Colors.grey.shade200,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = categoria;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Título de la sección
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Catálogo disponible 🌿',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          
          // GRILLA DE PRODUCTOS
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('plantas').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Aún no hay plantas.'));

                // 1. Obtenemos todas las plantas
                var plantas = snapshot.data!.docs;

                // 2. Filtramos por búsqueda de texto
                if (_searchQuery.isNotEmpty) {
                  plantas = plantas.where((p) {
                    final data = p.data() as Map<String, dynamic>;
                    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                    return nombre.contains(_searchQuery);
                  }).toList();
                }

                // 3. Filtramos por categoría seleccionada
                if (_selectedCategory != 'Todas') {
                  plantas = plantas.where((p) {
                    final data = p.data() as Map<String, dynamic>;
                    final cat = (data['categoria'] ?? '').toString().toLowerCase();
                    return cat == _selectedCategory.toLowerCase();
                  }).toList();
                }

                if (plantas.isEmpty) {
                  return const Center(child: Text('No se encontraron plantas con esos filtros 🌵'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: plantas.length,
                  itemBuilder: (context, index) {
                    final plantaData = plantas[index].data() as Map<String, dynamic>;
                    
                    final nombre = plantaData['nombre'] ?? 'Sin nombre';
                    final precio = plantaData['precio'] ?? 0;
                    final imagenUrl = plantaData['imagen_url'] ?? '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => DetallePlantaScreen(plantaData: plantaData)));
                      },
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SizedBox(
                                width: double.infinity,
                                child: imagenUrl.toString().isNotEmpty
                                    ? Image.network(imagenUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                    : Container(color: Colors.green.shade100, child: const Icon(Icons.local_florist, size: 40, color: Colors.green)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Text('\$$precio', style: TextStyle(fontSize: 16, color: Colors.green.shade800, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA DE DETALLES
// ==========================================
class DetallePlantaScreen extends StatelessWidget {
  final Map<String, dynamic> plantaData;
  const DetallePlantaScreen({super.key, required this.plantaData});

  @override
  Widget build(BuildContext context) {
    final nombre = plantaData['nombre'] ?? 'Sin nombre';
    final precio = plantaData['precio'] ?? 0;
    final descripcion = plantaData['descripcion'] ?? 'Sin descripción.';
    final imagenUrl = plantaData['imagen_url'] ?? '';
    final stock = plantaData['stock'] ?? 0;

    final cuidados = plantaData['cuidados'] as Map<String, dynamic>? ?? {};
    final luz = cuidados['luz'] ?? 'No especificado';
    final riego = cuidados['riego'] ?? 'No especificado';

    return Scaffold(
      appBar: AppBar(title: Text(nombre), backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              width: double.infinity,
              child: imagenUrl.toString().isNotEmpty
                  ? Image.network(imagenUrl, fit: BoxFit.cover)
                  : Container(color: Colors.green.shade100, child: const Icon(Icons.local_florist, size: 80, color: Colors.green)),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('\$$precio', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                  const SizedBox(height: 10),
                  Text('Stock disponible: $stock unidades', style: TextStyle(color: stock > 0 ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(descripcion, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🌱 Guía de Cuidados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                        const Divider(),
                        ListTile(leading: const Icon(Icons.wb_sunny_outlined, color: Colors.orange), title: const Text('Luz'), subtitle: Text(luz.toString())),
                        ListTile(leading: const Icon(Icons.water_drop_outlined, color: Colors.blue), title: const Text('Riego'), subtitle: Text(riego.toString())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
                      onPressed: () {
                        context.read<CartProvider>().agregarItem(plantaData);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombre añadida 🛒'), backgroundColor: Colors.green.shade700));
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Añadir al carrito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA DEL CARRITO (Con WhatsApp)
// ==========================================
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _enviarPedidoPorWhatsApp(BuildContext context, List<Map<String, dynamic>> items, int total) async {
    const numeroTelefono = "56912345678"; 
    String mensaje = "Hola Vivero Cecilia Hidalgo 🌱\nQuisiera solicitar un pedido con los siguientes productos:\n\n";
    for (var item in items) {
      mensaje += "🪴 1x ${item['nombre']} (\$${item['precio']})\n";
    }
    mensaje += "\n*Total a pagar: \$$total*";

    final url = Uri.parse("https://wa.me/$numeroTelefono?text=${Uri.encodeComponent(mensaje)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tu Carrito'), backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
      body: cart.items.isEmpty
          ? const Center(child: Text('El carrito está vacío 🪴', style: TextStyle(fontSize: 18)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        leading: const Icon(Icons.grass, color: Colors.green),
                        title: Text(item['nombre'] ?? 'Planta'),
                        subtitle: Text('\$${item['precio']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => context.read<CartProvider>().eliminarItem(index),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -5))]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('\$${cart.total}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                          onPressed: () => _enviarPedidoPorWhatsApp(context, cart.items, cart.total),
                          icon: const Icon(Icons.send),
                          label: const Text('Completar pedido por WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ==========================================
// PANEL DE ADMINISTRACIÓN
// ==========================================
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _imagenUrlCtrl = TextEditingController();
  final _luzCtrl = TextEditingController();
  final _riegoCtrl = TextEditingController();

  bool _guardando = false;

  Future<void> _guardarPlanta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      await FirebaseFirestore.instance.collection('plantas').add({
        'nombre': _nombreCtrl.text.trim(),
        'precio': int.parse(_precioCtrl.text.trim()),
        'categoria': _categoriaCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'stock': int.parse(_stockCtrl.text.trim()),
        'imagen_url': _imagenUrlCtrl.text.trim(),
        'cuidados': {
          'luz': _luzCtrl.text.trim(),
          'riego': _riegoCtrl.text.trim(),
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Nueva planta añadida con éxito! 🌿'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _categoriaCtrl.dispose();
    _descripcionCtrl.dispose();
    _stockCtrl.dispose();
    _imagenUrlCtrl.dispose();
    _luzCtrl.dispose();
    _riegoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir al Catálogo'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: _guardando
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre de la planta *'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _precioCtrl, decoration: const InputDecoration(labelText: 'Precio (\$) *'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _categoriaCtrl, decoration: const InputDecoration(labelText: 'Categoría (ej: Interior, Exterior) *'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _descripcionCtrl, decoration: const InputDecoration(labelText: 'Descripción'), maxLines: 2),
                    const SizedBox(height: 12),
                    TextFormField(controller: _stockCtrl, decoration: const InputDecoration(labelText: 'Stock Inicial *'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _imagenUrlCtrl, decoration: const InputDecoration(labelText: 'URL de la imagen (Postimages)'), keyboardType: TextInputType.url),
                    const SizedBox(height: 24),
                    
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⚙️ Parámetros de Cuidado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            TextFormField(controller: _luzCtrl, decoration: const InputDecoration(labelText: 'Recomendación de Luz')),
                            TextFormField(controller: _riegoCtrl, decoration: const InputDecoration(labelText: 'Frecuencia de Riego')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
                        onPressed: _guardarPlanta,
                        child: const Text('Publicar Planta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}