import 'package:flutter/material.dart';
import 'mapa_screen.dart';

class DetallePrestamoScreen extends StatelessWidget {
  final Map<String, dynamic> estudiante;

  const DetallePrestamoScreen({super.key, required this.estudiante});

  @override
  Widget build(BuildContext context) {
    final tiempo = estudiante['tiempo_restante'] as Duration;

    return Scaffold(
      appBar: AppBar(title: Text("Detalles de ${estudiante['nombre']}")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nombre: ${estudiante['nombre']}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              tiempo.inSeconds.isNegative
                  ? "Tiempo excedido: ${-tiempo.inHours}h ${-tiempo.inMinutes.remainder(60)}m"
                  : "Tiempo restante: ${tiempo.inHours}h ${tiempo.inMinutes.remainder(60)}m",
              style: TextStyle(
                color: tiempo.inSeconds.isNegative ? Colors.red : Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Abrir el mapa con la ubicación del estudiante
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MapaScreen()),
                  );
                },
                child: const Text("Buscar en el Mapa"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
