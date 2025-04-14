import 'package:flutter/material.dart';

Future<void> showTermsDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Términos y Condiciones"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Al registrarte en esta aplicación, aceptas que recopilaremos y almacenaremos "
                  "los siguientes datos personales:\n",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("- Nombres y Apellidos"),
                Text("- Correo Electrónico"),
                Text("- DNI"),
                Text("- Número de Celular"),
                Text("- Ubicación en tiempo real (si es necesario para la función de préstamos)"),
                SizedBox(height: 10),
                Text(
                  "Uso de la Ubicación:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Tu ubicación será utilizada únicamente para verificar la localización de los equipos prestados "
                  "y mejorar la seguridad de los préstamos. No se compartirá con terceros.",
                ),
                SizedBox(height: 10),
                Text(
                  "Si no estás de acuerdo con estas condiciones, por favor no continúes con el registro.",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }