import 'package:flutter/material.dart';

class MapaScreen extends StatelessWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapa de Ubicación"),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text(
          "Aquí se mostrará el mapa con la ubicación de los estudiantes",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
