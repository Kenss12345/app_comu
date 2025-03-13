import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text("Usuarios con Equipos")),
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
}
