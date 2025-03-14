import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class EquiposDisponiblesScreen extends StatefulWidget {
  const EquiposDisponiblesScreen({super.key});

  @override
  _EquiposDisponiblesScreenState createState() => _EquiposDisponiblesScreenState();
}

class _EquiposDisponiblesScreenState extends State<EquiposDisponiblesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  final List<Map<String, dynamic>> equiposACargo = [];

  final Map<String, List<Map<String, dynamic>>> categorias = {
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
  };

  void _anadirAEquiposACargo(Map<String, dynamic> equipo) {
    setState(() {
      equiposACargo.add(equipo);
    });
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
  }

  @override
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
  }

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
