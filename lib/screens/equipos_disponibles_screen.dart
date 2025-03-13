import 'package:flutter/material.dart';

class EquiposDisponiblesScreen extends StatefulWidget {
  const EquiposDisponiblesScreen({super.key});

  @override
  _EquiposDisponiblesScreenState createState() => _EquiposDisponiblesScreenState();
}

class _EquiposDisponiblesScreenState extends State<EquiposDisponiblesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  // Lista de equipos simulados (por ahora sin base de datos)
  final List<Map<String, dynamic>> equipos = [
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
  ];

  @override
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
  }
}
