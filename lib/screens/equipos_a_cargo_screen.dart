import 'package:flutter/material.dart';

class EquiposACargoScreen extends StatefulWidget {
  const EquiposACargoScreen({super.key});

  @override
  _EquiposACargoScreenState createState() => _EquiposACargoScreenState();
}

class _EquiposACargoScreenState extends State<EquiposACargoScreen> {
  // Lista simulada de equipos en préstamo
  final List<Map<String, dynamic>> equiposACargo = [
    {
      "nombre": "Cámara Sony Alpha",
      "fecha_prestamo": "2025-03-10",
      "fecha_devolucion": "2025-03-17",
      "imagen": "assets/camara_sony.png",
      "estado": "A tiempo"
    },
    {
      "nombre": "Micrófono Rode NT1",
      "fecha_prestamo": "2025-03-05",
      "fecha_devolucion": "2025-03-12",
      "imagen": "assets/microfono_rode.png",
      "estado": "Vencido"
    },
    {
      "nombre": "Luz LED Neewer",
      "fecha_prestamo": "2025-03-15",
      "fecha_devolucion": "2025-03-22",
      "imagen": "assets/luz_neewer.png",
      "estado": "A tiempo"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos a Cargo"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView.builder(
          itemCount: equiposACargo.length,
          itemBuilder: (context, index) {
            var equipo = equiposACargo[index];

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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Préstamo: ${equipo["fecha_prestamo"]}"),
                    Text("Devolución: ${equipo["fecha_devolucion"]}"),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    equipo["estado"],
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: equipo["estado"] == "A tiempo" ? Colors.green : Colors.red,
                ),
                onTap: () {
                  // Aquí se puede agregar más funcionalidad en el futuro
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
