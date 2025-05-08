import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app_comu/screens/usuarios_con_equipos_screen.dart';

import '../main.dart';

class GestorLoginScreen extends StatefulWidget {
  const GestorLoginScreen({super.key});

  @override
  _GestorLoginScreenState createState() => _GestorLoginScreenState();
}

class _GestorLoginScreenState extends State<GestorLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        bool esGestor = await _verificarRolGestor(user.uid);
        if (esGestor) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => UsuariosConEquiposScreen()),
          );
        } else {
          FirebaseAuth.instance.signOut();
          _showError("No tienes permisos para acceder como gestor.");
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Error al iniciar sesión");
    }

    setState(() => _isLoading = false);
  }

  Future<bool> _verificarRolGestor(String uid) async {
    DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

    if (snapshot.exists) {
      String? rol = snapshot['rol'];
      return rol == "gestor";
    }
    return false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Acceso de Gestores")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/UC.png', width: 100), // Logo
            const SizedBox(height: 20),
            const Text(
              "Inicio de Sesión - Gestores",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Iniciar Sesión"),
            ),
          ],
        ),
      ),
    );
  }
}
