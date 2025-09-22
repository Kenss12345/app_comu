import 'package:app_comu/main.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_comu/screens/gestor_login_screen.dart';
import 'package:app_comu/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Por favor, completa todos los campos.");
      return;
    }

    // Validar que el correo sea institucional
    if (!email.endsWith('@continental.edu.pe')) {
      _showError("Solo se permite el acceso con el correo institucional.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Si la autenticación es correcta, redirige a ProfileScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
      /*Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );*/
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Error desconocido");
    } finally {
      setState(() => _isLoading = false);
    }
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
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

  Future<void> _mostrarFormularioDatosAdicionales(User user) async {
    final TextEditingController dniController = TextEditingController();
    final TextEditingController celularController = TextEditingController();
    bool acceptTerms = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Completa tu Registro'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dniController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'DNI'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: celularController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Celular'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: acceptTerms,
                        onChanged: (value) {
                          setState(() => acceptTerms = value ?? false);
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showTermsDialog(), // Usar función local
                          child: const Text(
                            "Acepto los términos y condiciones.",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                child: const Text('Guardar'),
                onPressed: () async {
                  if (dniController.text.isEmpty ||
                      celularController.text.isEmpty ||
                      !acceptTerms) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              "Completa todos los campos y acepta los términos.")),
                    );
                    return;
                  }

                  // Guardar en Firestore
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(user.uid)
                      .set({
                    'nombre': user.displayName ?? '',
                    'email': user.email,
                    'foto': user.photoURL,
                    'TipoUser': 'Buen Usuario',
                    'dni': dniController.text.trim(),
                    'celular': celularController.text.trim(),
                    'rol': 'estudiante',
                    'uid': user.uid,
                    'acepto_terminos': true,
                    'puntos': 10,
                  });

                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                    (route) => false,
                  );
                },
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // Cancelado por el usuario
        setState(() => _isLoading = false);
        return;
      }

      // Verifica que el correo sea institucional
      if (!googleUser.email.endsWith('@continental.edu.pe')) {
        await GoogleSignIn().signOut();
        _showError("Solo se permite el acceso con el correo institucional.");
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Inicia sesión con Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Guarda los datos en Firestore si el usuario es nuevo
      final user = userCredential.user;
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user!.uid)
          .get();

      if (!userDoc.exists) {
        await _mostrarFormularioDatosAdicionales(user);

        // Espera activa hasta que se cree el documento en Firestore
        DocumentSnapshot nuevoDoc;
        int intentos = 0;
        do {
          await Future.delayed(const Duration(milliseconds: 300));
          nuevoDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get();
          intentos++;
        } while (!nuevoDoc.exists && intentos < 10);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );

        return; // Esperamos que el registro se complete desde el modal
      }

      // Redirige al perfil

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error en login con Google: $e');
      // Asegúrate de que el State sigue montado antes de mostrar un SnackBar
      if (mounted) _showError("Error al iniciar sesión con Google.");
    } finally {
      // Solo actualiza _isLoading si este State sigue montado
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/UC.png', width: 150), // Logo
              const SizedBox(height: 20),
              const Text(
                "Inicio de Sesión",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Aquí puedes agregar la navegación a la pantalla de recuperación de contraseña
                  },
                  child: const Text("¿Olvidaste tu contraseña?"),
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

              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Registrarse"),
              ),

              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: Image.asset('assets/google_logo.png', height: 24),
                label: const Text("Iniciar sesión con Google"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.black),
                  foregroundColor: Colors.black,
                ),
                onPressed: _isLoading ? null : _signInWithGoogle,
              ),

              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const GestorLoginScreen()),
                  );
                },
                child: const Text(
                  "Acceder como Gestor de Equipos",
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}