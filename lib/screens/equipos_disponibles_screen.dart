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
        return {
          'id': doc.id,
          'nombre': data['nombre'],
          'descripcion': data['descripcion'],
          'imagenes': List<String>.from(data['imagenes']),
          'estado': data['estado'],
          'tiempoMax': data['tiempoMax'],
          'categoria': data['categoria'],
        };
      }).toList();
    });
  }

  /*final Map<String, List<Map<String, dynamic>>> categorias = {
    "Video": [
      {
        "nombre": "Cámara Sony Alpha",
        "descripcion": "Cámara profesional para grabaciones en 4K.",
        "imagenes": [
          "assets/camara_sony.png",
          "assets/camara_sony2.png",
          "assets/camara_sony3.png"
        ],
        "estado": "Disponible",
        "tiempoMax": "4 horas"
      },
      {
        "nombre": "Cámara Canon EOS",
        "descripcion": "Cámara DSLR con lente intercambiable.",
        "imagenes": [
          "assets/camara_canon1.png",
          "assets/camara_canon2.png",
          "assets/camara_canon3.png"
        ],
        "estado": "En Uso",
        "tiempoMax": "3 horas"
      }
    ],
    "Accesorios": [
      {
        "nombre": "Trípode Manfrotto",
        "descripcion": "Trípode de aluminio con cabezal fluido.",
        "imagenes": [
          "assets/tripode_manfrotto.png",
          "assets/tripode2.png",
          "assets/tripode3.png"
        ],
        "estado": "Disponible",
        "tiempoMax": "2 horas"
      }
    ]
    /*"Iluminación": [
      {
        "nombre": "Luz Neewer",
        "descripcion": "Iluminación LED ajustable para videos.",
        "imagenes": [
          "assets/luz_neewer",
          "assets/luz_neewer"
        ],
        "estado": "Disponible",
        "tiempoMax": "2 horas"
      }
    ],
    "Audio": [
      {
        "nombre": "Microfono Rode",
        "descripcion": "Micrófono condensador de alta calidad.",
        "imagenes": [
          "assets/microfono_rode.png",
          "assets/microfono_rode.png"
        ],
        "estado": "Disponible",
        "tiempoMax": "3 horas"
      }
    ]*/
  };*/

  /*void _anadirAEquiposACargo(Map<String, dynamic> equipo) {
    setState(() {
      equiposACargo.add(equipo);
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${equipo["nombre"]} añadido a equipos a cargo.")),
    );
  }*/

  void _anadirAEquiposACargo(Map<String, dynamic> equipo) {
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
}

  // Lista de equipos simulados (por ahora sin base de datos)
  /*final List<Map<String, dynamic>> equipos = [

    {
      "nombre": "Cámara Sony Alpha",
      "descripcion": "Cámara profesional para grabaciones en 4K.",
      "imagen": "assets/camara_sony.png",
      "estado": "Disponible"
    },
    {
      "nombre": "Micrófono Rode NT1",
      "descripcion": "Micrófono condensador de alta calidad.",
      "imagen": "assets/microfono_rode.png",
      "estado": "En Mantenimiento"
    },
    {
      "nombre": "Trípode Manfrotto",
      "descripcion": "Trípode de aluminio con cabezal fluido.",
      "imagen": "assets/tripode_manfrotto.png",
      "estado": "Disponible"
    },
    {
      "nombre": "Luz LED Neewer",
      "descripcion": "Iluminación LED ajustable para videos.",
      "imagen": "assets/luz_neewer.png",
      "estado": "Disponible"
    },
  ];*/

  /*void _mostrarDetalles(BuildContext context, Map<String, dynamic> equipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  CarouselSlider(
                    options: CarouselOptions(height: 250.0, autoPlay: true),
                    items: equipo["imagenes"].map<Widget>((img) {
                      return Image.asset(img, fit: BoxFit.cover);
                    }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipo["nombre"],
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text(equipo["descripcion"]),
                        SizedBox(height: 10),
                        Text("Estado: ${equipo["estado"]}",
                            style: TextStyle(color: equipo["estado"] == "Disponible" ? Colors.green : Colors.red)),
                        Text("Tiempo Máximo: ${equipo["tiempoMax"]}"),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _anadirAEquiposACargo(equipo),
                          child: Text("Añadir Equipo"),
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }*/

  void _mostrarDetalles(BuildContext context, Map<String, dynamic> equipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  CarouselSlider(
                    options: CarouselOptions(height: 250.0, autoPlay: true),
                    items: (equipo["imagenes"] as List).isNotEmpty
                      ? equipo["imagenes"].map<Widget>((img) {
                          return Image.network(img, fit: BoxFit.cover);
                        }).toList()
                      : [Icon(Icons.broken_image, size: 200)],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipo["nombre"],
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(equipo["descripcion"]),
                        const SizedBox(height: 10),
                        Text("Estado: ${equipo["estado"]}",
                            style: TextStyle(
                              color: equipo["estado"] == "Disponible"
                                  ? Colors.green
                                  : equipo["estado"] == "En Uso"
                                      ? Colors.orange
                                      : Colors.red,
                            )),
                        Text("Tiempo Máximo: ${equipo["tiempoMax"]}"),
                        const SizedBox(height: 20),
                        if (equipo["estado"] == "Disponible") 
                          ElevatedButton(
                            onPressed: () => _anadirAEquiposACargo(equipo),
                            child: const Text("Añadir Equipo"),
                          )
                      ],
                    ),
                  )
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
          backgroundColor: Colors.orange,
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

    // Obtener categorías únicas
    final categoriasUnicas = equipos.map((e) => e["categoria"] as String).toSet().toList();

    // Filtrar equipos según búsqueda, categoría y disponibilidad
    final equiposFiltrados = equipos.where((equipo) {
      final coincideBusqueda = equipo["nombre"].toLowerCase().contains(searchQuery.toLowerCase());
      final coincideCategoria = categoriaSeleccionada == null || equipo["categoria"] == categoriaSeleccionada;
      final esDisponible = equipo["estado"] == "Disponible";
      final coincideDisponibilidad = disponibilidadSeleccionada == null ||
          (disponibilidadSeleccionada == "Disponible" && esDisponible) ||
          (disponibilidadSeleccionada == "No disponible" && !esDisponible);
      return coincideBusqueda && coincideCategoria && coincideDisponibilidad;
    }).toList();

    // Agrupar equipos filtrados por categoría
    Map<String, List<Map<String, dynamic>>> categoriasAgrupadas = {};
    for (var equipo in equiposFiltrados) {
      final categoria = equipo["categoria"];
      categoriasAgrupadas[categoria] = categoriasAgrupadas[categoria] ?? [];
      categoriasAgrupadas[categoria]!.add(equipo);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos Disponibles"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar equipos...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Dropdown de categorías
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(labelText: "Categoría"),
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
                // Dropdown de disponibilidad
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: disponibilidadSeleccionada,
                    decoration: const InputDecoration(labelText: "Disponibilidad"),
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
                            return ExpansionTile(
                              title: Text(
                                categoria.key,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              children: categoria.value.map((equipo) {
                                return ListTile(
                                  leading: equipo["imagenes"].isNotEmpty
                                      ? Image.network(
                                          equipo["imagenes"][0],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                  title: Text(equipo["nombre"]),
                                  subtitle: Text(equipo["descripcion"]),
                                  trailing: Chip(
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
                                  onTap: () => _mostrarDetalles(context, equipo),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /*@override
  Widget build(BuildContext context) {
    // Agrupar equipos por categoría
    Map<String, List<Map<String, dynamic>>> categorias = {};
    for (var equipo in equipos) {
      if (equipo["nombre"].toLowerCase().contains(searchQuery.toLowerCase())) {
        final categoria = equipo["categoria"];
        categorias[categoria] = categorias[categoria] ?? [];
        categorias[categoria]!.add(equipo);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos Disponibles"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar equipos...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: equipos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: categorias.entries.map((categoria) {
                        return ExpansionTile(
                          title: Text(
                            categoria.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: categoria.value.map((equipo) {
                            return ListTile(
                              leading: equipo["imagenes"].isNotEmpty
                              ? Image.network(
                                equipo["imagenes"][0],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Icon(Icons.broken_image, size: 50, color: Colors.grey),

                              title: Text(equipo["nombre"]),
                              subtitle: Text(equipo["descripcion"]),
                              trailing: Chip(
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
                              onTap: () => _mostrarDetalles(context, equipo),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }*/

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos Disponibles"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar equipos...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: categorias.entries.map((categoria) {
                  List<Map<String, dynamic>> equiposFiltrados = categoria.value.where((equipo) {
                    return equipo["nombre"].toLowerCase().contains(searchQuery.toLowerCase());
                  }).toList();

                  if (equiposFiltrados.isEmpty) return SizedBox.shrink();

                  return ExpansionTile(
                    title: Text(categoria.key, style: TextStyle(fontWeight: FontWeight.bold)),
                    children: equiposFiltrados.map((equipo) {
                      return ListTile(
                        leading: Image.asset(equipo["imagenes"][0], width: 50, height: 50, fit: BoxFit.cover),
                        title: Text(equipo["nombre"]),
                        subtitle: Text(equipo["descripcion"]),
                        trailing: Chip(
                          label: Text(equipo["estado"], style: TextStyle(color: Colors.white)),
                          backgroundColor: equipo["estado"] == "Disponible" ? Colors.green : Colors.red,
                        ),
                        onTap: () => _mostrarDetalles(context, equipo),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }*/

  /*@override
  Widget build(BuildContext context) {
    // Filtrar equipos según la búsqueda
    List<Map<String, dynamic>> equiposFiltrados = equipos.where((equipo) {
      return equipo["nombre"].toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos Disponibles"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // Barra de búsqueda
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar equipos...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 10),

            // Lista desplazable de equipos
            Expanded(
              child: ListView.builder(
                itemCount: equiposFiltrados.length,
                itemBuilder: (context, index) {
                  var equipo = equiposFiltrados[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    child: ListTile(
                      leading: Image.asset(
                        equipo["imagen"],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(
                        equipo["nombre"],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(equipo["descripcion"]),
                      trailing: Chip(
                        label: Text(
                          equipo["estado"],
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor:
                            equipo["estado"] == "Disponible" ? Colors.green : Colors.red,
                      ),
                      onTap: () {
                        // Aquí se puede agregar navegación a más detalles del equipo
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }*/
}