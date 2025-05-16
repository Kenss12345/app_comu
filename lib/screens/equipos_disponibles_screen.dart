import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_comu/utils/carrito_equipos.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EquiposDisponiblesScreen extends StatefulWidget {
  const EquiposDisponiblesScreen({super.key});

  @override
  _EquiposDisponiblesScreenState createState() => _EquiposDisponiblesScreenState();
}

class _EquiposDisponiblesScreenState extends State<EquiposDisponiblesScreen> {

  User? _usuarioActual;
  int? _puntosUsuario;
  bool _cargandoUsuario = true;

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  List<Map<String, dynamic>> equipos = [];
  final List<Map<String, dynamic>> equiposACargo = [];

  @override
  void initState() {
    super.initState();
    _obtenerUsuarioYPuntos();
    _loadEquiposDesdeFirestore();
  }

  Future<void> _obtenerUsuarioYPuntos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final data = snapshot.data();
      setState(() {
        _usuarioActual = user;
        _puntosUsuario = data?['puntos'] ?? 0;
        _cargandoUsuario = false;
      });
    } else {
      setState(() {
        _cargandoUsuario = false;
      });
    }
  }

  Future<void> _loadEquiposDesdeFirestore() async {
  final snapshot = await FirebaseFirestore.instance.collection('equipos').get();

  setState(() {
    equipos = snapshot.docs.map((doc) {
      final data = doc.data();
      final tipoEquipo = data['tipoEquipo'] ?? 'normal';

      // Si el equipo es premium y el usuario no tiene suficientes puntos, se omite
      if (tipoEquipo == 'premium' && (_puntosUsuario ?? 0) < 15) {
        return null;
      }

      return {
        'id': doc.id,
        'nombre': data['nombre'],
        'descripcion': data['descripcion'],
        'imagenes': List<String>.from(data['imagenes']),
        'estado': data['estado'],
        'tiempoMax': data['tiempoMax'],
        'categoria': data['categoria'],
        'tipoEquipo': tipoEquipo,
      };
    }).where((equipo) => equipo != null).cast<Map<String, dynamic>>().toList();
  });
}

  /*void _anadirAEquiposACargo(Map<String, dynamic> equipo) {
  final DateTime ahora = DateTime.now();
  final DateTime devolucion = ahora.add(Duration(days: 2));

  final equipoConFechas = {
    ...equipo,
    "fecha_prestamo": ahora.toString().split(' ')[0],
    "fecha_devolucion": devolucion.toString().split(' ')[0],
    "estado_prestamo": "Pendiente",
    "imagen": equipo['imagenes'].isNotEmpty ? equipo['imagenes'][0] : "", // para mostrarlo en la otra pantalla
  };

  CarritoEquipos().agregarEquipo(equipoConFechas);

  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("${equipo["nombre"]} añadido a equipos a cargo.")),
  );
}*/

  void _anadirAEquiposACargo(Map<String, dynamic> equipo) async {
    final equipoId = equipo['id'];

    try {
      // Inicia una transacción
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Obtén el documento del equipo dentro de la transacción
        final equipoDocRef = FirebaseFirestore.instance.collection('equipos').doc(equipoId);
        final snapshot = await transaction.get(equipoDocRef);

        if (!snapshot.exists) {
          throw Exception("El equipo ya no está disponible.");
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final estadoActual = data['estado'];

        // Verifica si el equipo aún está disponible
        if (estadoActual != "Disponible") {
          throw Exception("El equipo ya no está disponible.");
        }

        // Cambia el estado a "Pendiente" y añade el timestamp
        transaction.update(equipoDocRef, {
          'estado': 'Pendiente',
          'timestamp_solicitud': FieldValue.serverTimestamp(), // Marca el momento de la solicitud
        });
      });

      // Si la transacción fue exitosa, añade el equipo a equipos a cargo
      final DateTime ahora = DateTime.now();
      final DateTime devolucion = ahora.add(Duration(days: 2));

      final equipoConFechas = {
        ...equipo,
        "fecha_prestamo": ahora.toString().split(' ')[0],
        "fecha_devolucion": devolucion.toString().split(' ')[0],
        "estado_prestamo": "Pendiente",
        "imagen": equipo['imagenes'].isNotEmpty ? equipo['imagenes'][0] : "",
      };

      CarritoEquipos().agregarEquipo(equipoConFechas);

      // Guardar equipo en firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('equipos_a_cargo')
          .doc(equipo['id'])
          .set(equipoConFechas);
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${equipo["nombre"]} añadido a equipos a cargo.")),
      );
    } catch (e) {
      // Si ocurre un error (por ejemplo, equipo ya en uso)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
    _loadEquiposDesdeFirestore();
  }


  void _mostrarDetalles(BuildContext context, Map<String, dynamic> equipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carrusel con bordes
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CarouselSlider(
                      options: CarouselOptions(
                        height: 250,
                        autoPlay: true,
                        viewportFraction: 1,
                        enlargeCenterPage: false,
                      ),
                      items: (equipo["imagenes"] as List).isNotEmpty
                          ? equipo["imagenes"].map<Widget>((img) {
                              return Image.network(img, fit: BoxFit.cover, width: double.infinity);
                            }).toList()
                          : [const Icon(Icons.broken_image, size: 200)],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipo["nombre"],
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          equipo["descripcion"],
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 20),

                        // Estado y tiempo máximo
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                equipo["estado"],
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: equipo["estado"] == "Disponible"
                                  ? Colors.green
                                  : equipo["estado"] == "En Uso"
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.timer, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              "Máx. ${equipo["tiempoMax"]} horas",
                              style: const TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Botón para añadir
                        if (equipo["estado"] == "Disponible")
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _anadirAEquiposACargo(equipo),
                              icon: const Icon(Icons.add),
                              label: const Text("Añadir equipo"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? categoriaSeleccionada;
  String? disponibilidadSeleccionada;

  @override
  Widget build(BuildContext context) {
    if (_cargandoUsuario) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_puntosUsuario == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Equipos Disponibles"),
          backgroundColor: Colors.orange.shade600,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Usuario bloqueado, no puede solicitar equipos. Acérquese a la oficina de equipos para regular su estado.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    final categoriasUnicas = equipos.map((e) => e["categoria"] as String).toSet().toList();

    final equiposFiltrados = equipos.where((equipo) {
      final coincideBusqueda = equipo["nombre"].toLowerCase().contains(searchQuery.toLowerCase());
      final coincideCategoria = categoriaSeleccionada == null || equipo["categoria"] == categoriaSeleccionada;
      final esDisponible = equipo["estado"] == "Disponible";
      final coincideDisponibilidad = disponibilidadSeleccionada == null ||
          (disponibilidadSeleccionada == "Disponible" && esDisponible) ||
          (disponibilidadSeleccionada == "No disponible" && !esDisponible);
      return coincideBusqueda && coincideCategoria && coincideDisponibilidad;
    }).toList();

    Map<String, List<Map<String, dynamic>>> categoriasAgrupadas = {};
    for (var equipo in equiposFiltrados) {
      final categoria = equipo["categoria"];
      categoriasAgrupadas[categoria] = categoriasAgrupadas[categoria] ?? [];
      categoriasAgrupadas[categoria]!.add(equipo);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos Disponibles"),
        backgroundColor: Colors.orange.shade600,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar equipos...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: "Categoría",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Todas")),
                      ...categoriasUnicas.map((categoria) {
                        return DropdownMenuItem(
                          value: categoria,
                          child: Text(categoria),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        categoriaSeleccionada = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: disponibilidadSeleccionada,
                    decoration: const InputDecoration(
                      labelText: "Disponibilidad",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text("Todas")),
                      DropdownMenuItem(value: "Disponible", child: Text("Disponible")),
                      DropdownMenuItem(value: "No disponible", child: Text("No disponible")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        disponibilidadSeleccionada = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: equipos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : categoriasAgrupadas.isEmpty
                      ? const Center(child: Text("No se encontraron equipos."))
                      : ListView(
                          children: categoriasAgrupadas.entries.map((categoria) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    categoria.key,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                ...categoria.value.map((equipo) {
                                  return Card(
                                    elevation: 3,
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _mostrarDetalles(context, equipo),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: equipo["imagenes"].isNotEmpty
                                                  ? Image.network(
                                                      equipo["imagenes"][0],
                                                      width: 60,
                                                      height: 60,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          equipo["nombre"],
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                      if (equipo["tipoEquipo"] == "premium" &&
                                                          (_puntosUsuario ?? 0) >= 15)
                                                        const Icon(Icons.star, color: Colors.amber, size: 18),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    equipo["descripcion"],
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Colors.black54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Chip(
                                              label: Text(
                                                equipo["estado"],
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                              backgroundColor: equipo["estado"] == "Disponible"
                                                  ? Colors.green
                                                  : equipo["estado"] == "En Uso"
                                                      ? Colors.orange
                                                      : Colors.red,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}