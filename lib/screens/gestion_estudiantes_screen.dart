import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GestionEstudiantesScreen extends StatelessWidget {
  const GestionEstudiantesScreen({super.key});

  void _mostrarDialogoRegistro(BuildContext context) {
    final nombreController = TextEditingController();
    final dniController = TextEditingController();
    final emailController = TextEditingController();
    final celularController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.orange.shade700, size: 32),
                      const SizedBox(width: 10),
                      const Text('Registrar nuevo estudiante',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _inputField(nombreController, 'Nombre', Icons.person),
                  const SizedBox(height: 12),
                  _inputField(dniController, 'DNI', Icons.credit_card, tipo: TextInputType.number),
                  const SizedBox(height: 12),
                  _inputField(emailController, 'Email', Icons.email, tipo: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _inputField(celularController, 'Celular', Icons.phone, tipo: TextInputType.phone),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text('Registrar'),
                        onPressed: () async {
                          if (nombreController.text.trim().isEmpty ||
                              dniController.text.trim().isEmpty ||
                              emailController.text.trim().isEmpty ||
                              celularController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Completa todos los campos.")),
                            );
                            return;
                          }
                          final uid = await _registrarEstudianteFirestore(
                            nombre: nombreController.text.trim(),
                            dni: dniController.text.trim(),
                            email: emailController.text.trim(),
                            celular: celularController.text.trim(),
                          );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Estudiante registrado (uid: $uid)")),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget para campos de entrada estilizados
  Widget _inputField(TextEditingController controller, String label, IconData icon, {TextInputType tipo = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: tipo,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.orange.shade700),
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.orange.shade50,
      ),
    );
  }

  Future<String> _registrarEstudianteFirestore({
    required String nombre,
    required String dni,
    required String email,
    required String celular,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('usuarios').doc();
    final uid = docRef.id;

    await docRef.set({
      'TipoUser': "Buen Usuario",
      'acepto_terminos': true,
      'celular': celular,
      'dni': dni,
      'email': email,
      'nombre': nombre,
      'puntos': 10,
      'rol': "estudiante",
      'uid': uid,
    });
    return uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text('Gestión de Estudiantes'),
        backgroundColor: Colors.orange.shade700,
        elevation: 2,
      ),
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group, color: Colors.orange.shade700, size: 48),
                const SizedBox(height: 18),
                Text(
                  "Aquí va el CRUD para gestionar estudiantes (añadir, editar, eliminar, listar)",
                  style: TextStyle(fontSize: 20, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Divider(height: 32, thickness: 1.1),
                Text(
                  "Próximamente podrás ver la lista de estudiantes registrados y realizar acciones de edición/eliminación.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _mostrarDialogoRegistro(context);
        },
        icon: const Icon(Icons.add),
        label: const Text("Nuevo estudiante"),
        backgroundColor: Colors.orange.shade700,
        elevation: 4,
      ),
    );
  }
}
