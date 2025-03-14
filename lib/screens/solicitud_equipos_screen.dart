import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SolicitudEquiposScreen extends StatefulWidget {
  const SolicitudEquiposScreen({super.key});

  @override
  _SolicitudEquiposScreenState createState() => _SolicitudEquiposScreenState();
}

class _SolicitudEquiposScreenState extends State<SolicitudEquiposScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos del usuario
  String nombreUsuario = "";
  String dniUsuario = "";
  String tipoUsuario = "";
  String celularUsuario = "";
  String emailUsuario = "";
  bool isLoading = true;

  // Controladores para los campos editables
  final TextEditingController asignaturaController = TextEditingController();
  final TextEditingController trabajoController = TextEditingController();
  final TextEditingController docenteController = TextEditingController();
  final TextEditingController lugarController = TextEditingController();
  final TextEditingController fechaEntregaController = TextEditingController();
  final TextEditingController fechaDevolucionController = TextEditingController();
  final TextEditingController horaSalidaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          nombreUsuario = userDoc["nombre"] ?? "";
          celularUsuario = userDoc["celular"] ?? "";
          emailUsuario = userDoc["email"] ?? "";
          dniUsuario = userDoc["dni"] ?? "";
          tipoUsuario = userDoc["TipoUser"] ?? "";
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Solicitud de Equipo"),
        backgroundColor: Colors.orange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Datos del Estudiante",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(label: "Nombre", initialValue: nombreUsuario, enabled: false),
                      _buildTextField(label: "DNI", initialValue: dniUsuario, enabled: false),
                      _buildTextField(label: "Celular", initialValue: celularUsuario, enabled: false),
                      _buildTextField(label: "Email", initialValue: emailUsuario, enabled: false),
                      _buildTextField(label: "Tipo de Usuario", initialValue: tipoUsuario, enabled: false),
                      const SizedBox(height: 16),
                      const Text(
                        "Detalles de la Solicitud",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(label: "Asignatura", controller: asignaturaController),
                      _buildTextField(label: "Trabajo a Realizar", controller: trabajoController),
                      _buildTextField(label: "Docente a Cargo", controller: docenteController),
                      _buildTextField(label: "Lugar de Trabajo", controller: lugarController),
                      _buildTextField(label: "Fecha de Entrega", controller: fechaEntregaController),
                      _buildTextField(label: "Fecha de Devolución", controller: fechaDevolucionController),
                      _buildTextField(label: "Hora de Salida del Equipo", controller: horaSalidaController),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Solicitud enviada correctamente")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          ),
                          child: const Text("Enviar Solicitud", style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Método reutilizable para construir los campos de entrada
  Widget _buildTextField({required String label, TextEditingController? controller, String? initialValue, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Este campo es obligatorio";
          }
          return null;
        },
      ),
    );
  }
}

