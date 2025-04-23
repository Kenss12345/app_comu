/*import 'package:flutter/material.dart';
import 'mapa_screen.dart';
import 'detalle_prestamo_screen.dart';

class UsuariosConEquiposScreen extends StatelessWidget {
  UsuariosConEquiposScreen({super.key});

  final List<Map<String, dynamic>> estudiantes = [
    {
      'nombre': 'Carlos Pérez',
      'tiempo_restante': Duration(hours: 2), // Positivo: aún le queda tiempo
    },
    {
      'nombre': 'Andrea Gómez',
      'tiempo_restante': Duration(hours: -1, minutes: -30), // Negativo: ya se pasó
    },
    {
      'nombre': 'Luis Rodríguez',
      'tiempo_restante': Duration(hours: 5),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Usuarios con Equipos Prestados")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: estudiantes.length,
              itemBuilder: (context, index) {
                final estudiante = estudiantes[index];
                final tiempo = estudiante['tiempo_restante'] as Duration;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(estudiante['nombre']),
                    subtitle: Text(
                      tiempo.inSeconds.isNegative
                          ? "Tiempo excedido: ${-tiempo.inHours}h ${-tiempo.inMinutes.remainder(60)}m"
                          : "Tiempo restante: ${tiempo.inHours}h ${tiempo.inMinutes.remainder(60)}m",
                      style: TextStyle(
                        color: tiempo.inSeconds.isNegative ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      // Al presionar, se abre la pantalla de detalles
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DetallePrestamoScreen(estudiante: estudiante),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              // Abrir el mapa general
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MapaScreen()),
              );
            },
            child: const Text("Ver Mapa General"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'detalle_prestamo_screen.dart';
import 'mapa_screen.dart';

class UsuariosConEquiposScreen extends StatefulWidget {
  const UsuariosConEquiposScreen({super.key});

  @override
  State<UsuariosConEquiposScreen> createState() => _UsuariosConEquiposScreenState();
}

class _UsuariosConEquiposScreenState extends State<UsuariosConEquiposScreen> {
  List<Map<String, dynamic>> estudiantes = [];
  List<Map<String, dynamic>> estudiantesFiltrados = [];
  String filtroNombre = "";
  bool filtrarMenosDe5Horas = false;

  @override
  void initState() {
    super.initState();
    obtenerUsuarios();
  }

  Future<void> obtenerUsuarios() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('TieneEquipo', isEqualTo: true)
        .get();

    final lista = snapshot.docs.map((doc) {
      final data = doc.data();
      final tiempoRestante = calcularTiempoRestante(data['fechaDevolucion']);
      return {
        'id': doc.id,
        'nombre': data['nombre'],
        'email': data['email'],
        'celular': data['celular'],
        'equipo': data['equipo'] ?? 'Equipo no registrado',
        'tiempo_restante': tiempoRestante,
        'fechaDevolucion': data['fechaDevolucion'],
      };
    }).toList();

    setState(() {
      estudiantes = lista;
      aplicarFiltros();
    });
  }

  Duration calcularTiempoRestante(Timestamp fechaDevolucion) {
    final ahora = DateTime.now();
    final devolucion = fechaDevolucion.toDate();
    return devolucion.difference(ahora);
  }

  void aplicarFiltros() {
    setState(() {
      estudiantesFiltrados = estudiantes.where((est) {
        final nombreMatch = est['nombre'].toLowerCase().contains(filtroNombre.toLowerCase());
        final tiempo = est['tiempo_restante'] as Duration;
        final tiempoMatch = !filtrarMenosDe5Horas || (tiempo > Duration.zero && tiempo < Duration(hours: 5));
        return nombreMatch && tiempoMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Usuarios con Equipos Prestados")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Buscar por nombre...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (valor) {
                filtroNombre = valor;
                aplicarFiltros();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                icon: Icon(filtrarMenosDe5Horas ? Icons.filter_alt : Icons.filter_alt_outlined),
                label: const Text("Menos de 5h"),
                onPressed: () {
                  filtrarMenosDe5Horas = !filtrarMenosDe5Horas;
                  aplicarFiltros();
                },
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: estudiantesFiltrados.length,
              itemBuilder: (context, index) {
                final estudiante = estudiantesFiltrados[index];
                final tiempo = estudiante['tiempo_restante'] as Duration;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(estudiante['nombre']),
                    subtitle: Text(
                      tiempo.inSeconds.isNegative
                          ? "Tiempo excedido: ${-tiempo.inHours}h ${-tiempo.inMinutes.remainder(60)}m"
                          : "Tiempo restante: ${tiempo.inHours}h ${tiempo.inMinutes.remainder(60)}m",
                      style: TextStyle(
                        color: tiempo.inSeconds.isNegative ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetallePrestamoScreen(estudiante: estudiante),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MapaScreen()));
            },
            child: const Text("Ver Mapa General"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
