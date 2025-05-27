import 'package:app_comu/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompletarDatosScreen extends StatefulWidget {
  final User user;
  const CompletarDatosScreen({super.key, required this.user});

  @override
  State<CompletarDatosScreen> createState() => _CompletarDatosScreenState();
}

class _CompletarDatosScreenState extends State<CompletarDatosScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _celularController = TextEditingController();
  bool _acceptTerms = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _dniController.dispose();
    _celularController.dispose();
    super.dispose();
  }

  Future<void> _guardarDatos() async {
    if (!_formKey.currentState!.validate() || !_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos y acepta los términos.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(widget.user.uid).set({
        'nombre': widget.user.displayName ?? '',
        'email': widget.user.email,
        'foto': widget.user.photoURL,
        'TipoUser': 'Buen Usuario',
        'dni': _dniController.text.trim(),
        'celular': _celularController.text.trim(),
        'rol': 'estudiante',
        'uid': widget.user.uid,
        'acepto_terminos': true,
        'puntos': 10,
      });

      // Después de guardar, navega a AuthWrapper (recarga el flujo)
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()), // Importa AuthWrapper
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar datos: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _mostrarTerminos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Completa tu registro"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text("Bienvenido, ${widget.user.displayName ?? widget.user.email}.\nPor favor, completa los siguientes datos para terminar tu registro.", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _dniController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "DNI"),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Ingresa tu DNI";
                  if (value.length != 8) return "DNI inválido";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _celularController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Celular"),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Ingresa tu celular";
                  if (value.length < 9) return "Celular inválido";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _mostrarTerminos,
                      child: const Text(
                        "Acepto los términos y condiciones.",
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Guardar y Continuar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _guardarDatos,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
