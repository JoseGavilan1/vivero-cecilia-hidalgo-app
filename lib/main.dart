import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // NUEVO: Importamos Provider
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';

// ==========================================
// 1. EL MOTOR DEL CARRITO (Estado Global)
// ==========================================
class CartProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  // Calcula el total sumando los precios
  int get total => _items.fold(0, (sum, item) => sum + ((item['precio'] ?? 0) as num).toInt());

  void agregarItem(Map<String, dynamic> planta) {
    _items.add(planta);
    notifyListeners(); // Avisa a todas las pantallas que se actualicen
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
  
  // 2. ENVOLVEMOS LA APP CON EL PROVEEDOR
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
// PANTALLA PRINCIPAL (Catálogo)
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el carrito para saber cuántos items hay
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Vivero Cecilia Hidalgo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // BOTÓN FLOTANTE DEL CARRITO
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Catálogo disponible 🌿',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('plantas').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Aún no hay plantas.'));

                final plantas = snapshot.data!.docs;

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

    final cuidados = plantaData['cuidados'] as Map<String, dynamic>? ?? {};
    final luz = cuidados['luz'] ?? 'No especificado';
    final riego = cuidados['riego'] ?? 'No especificado';

    return Scaffold(
      appBar: AppBar(
        title: Text(nombre),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
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
                        ListTile(leading: const Icon(Icons.wb_sunny_outlined, color: Colors.orange), title: const Text('Luz'), subtitle: Text(luz.toString().toUpperCase())),
                        ListTile(leading: const Icon(Icons.water_drop_outlined, color: Colors.blue), title: const Text('Riego'), subtitle: Text(riego.toString().toUpperCase())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // BOTÓN DE AÑADIR AL CARRITO
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
                      onPressed: () {
                        // Llamamos al proveedor para guardar la planta
                        context.read<CartProvider>().agregarItem(plantaData);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombre añadida al carrito 🛒'), backgroundColor: Colors.green.shade700));
                        Navigator.pop(context); // Volvemos al catálogo
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
// NUEVA PANTALLA DEL CARRITO
// ==========================================
// ==========================================
// PANTALLA DEL CARRITO (Con WhatsApp)
// ==========================================
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  // Función mágica para armar y enviar el mensaje
  Future<void> _enviarPedidoPorWhatsApp(BuildContext context, List<Map<String, dynamic>> items, int total) async {
    // Aquí pondrás el número real del vivero (con código de país, por ejemplo 569 para Chile)
    const numeroTelefono = "56912345678"; 
    
    // Armamos el texto del mensaje
    String mensaje = "Hola Vivero Cecilia Hidalgo 🌱\nQuisiera solicitar un pedido para Curacaví con los siguientes productos:\n\n";
    
    for (var item in items) {
      mensaje += "🪴 1x ${item['nombre']} (\$${item['precio']})\n";
    }
    
    mensaje += "\n*Total a pagar: \$$total*";

    // Codificamos el texto para que funcione en un enlace web
    final url = Uri.parse("https://wa.me/$numeroTelefono?text=${Uri.encodeComponent(mensaje)}");

    // Intentamos abrir la aplicación o la web de WhatsApp
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp. Verifica tu conexión.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu Carrito'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
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
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -5))]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Para que la caja se ajuste al contenido
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('\$${cart.total}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // NUEVO BOTÓN DE WHATSAPP
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // Verde oficial de WhatsApp
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            _enviarPedidoPorWhatsApp(context, cart.items, cart.total);
                          },
                          icon: const Icon(Icons.send),
                          label: const Text(
                            'Completar pedido por WhatsApp', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
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