import 'package:app_comu/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:app_comu/screens/profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _acceptTerms = false; // Checkbox de Términos y Condiciones

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      _showError("Las contraseñas no coinciden");
      return;
    }

    if (!email.endsWith('@continental.edu.pe')) {
      _showError("Solo se permite el registro con el correo institucional.");
      return;
    }

    if (!_acceptTerms) {
      _showError("Debes aceptar los Términos y Condiciones");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Registrar usuario en Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Guardar usuario en Firestore con el rol de "estudiante"
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
          'TipoUser': 'Buen Usuario',
          'nombre': _nameController.text.trim(),
          'dni': _dniController.text.trim(),
          'celular': _phoneController.text.trim(),
          'email': user.email,
          'rol': 'estudiante', // Asignar rol predeterminado
          'uid': user.uid,
          'acepto_terminos': _acceptTerms,
          'puntos': 10,
        });

        // Redirigir a la pantalla de perfil
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Error desconocido");
    } on FirebaseException catch (e) {
      _showError("Error al guardar los datos: ${e.message}");
    }

    setState(() => _isLoading = false);

  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showTermsDialog() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro de Usuario")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/UC.png', width: 100), // Logo
            const SizedBox(height: 20),
            const Text(
              "Crear Cuenta",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombres y Apellidos',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dniController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'DNI',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptTerms = value!;
                    });
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTermsDialog,
                    child: const Text(
                      "Acepto los términos y condiciones, incluyendo el uso de mi ubicación.",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Registrarse"),
            ),
          ],
        ),
      ),
    );
  }
}