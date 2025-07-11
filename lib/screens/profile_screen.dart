import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'equipos_disponibles_screen.dart';
import 'equipos_a_cargo_screen.dart';
import 'solicitud_equipos_screen.dart';

import 'package:google_sign_in/google_sign_in.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 0; // Índice actual del BottomNavigationBar

  // Método para cambiar de pantalla según el ítem seleccionado en la barra de navegación
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Lista de pantallas disponibles en la navegación
  final List<Widget> _screens = [
    const ProfileContent(), 
    const EquiposDisponiblesScreen(),
    const EquiposACargoScreen(),
    const SolicitudEquiposScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // Cambia entre las pantallas según el índice
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Mantiene los íconos visibles siempre
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Equipos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'A cargo',
          ),

        ],
      ),
    );
  }
}

// Widget que contiene el contenido de la pantalla de perfil
class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  _ProfileContentState createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user!.uid)
            .get();

        if (!userDoc.exists) {
          // El documento no existe, cerrar sesión y redirigir
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        } else {
          if (mounted) {
            setState(() {
              userData = userDoc.data() as Map<String, dynamic>;
              _nameController.text = userData?['nombre'] ?? '';
              _dniController.text = userData?['dni'] ?? '';
              _phoneController.text = userData?['celular'] ?? '';
            });
          }
        }
      } catch (e) {
        debugPrint('Error al obtener datos del usuario: $e');
        // Si ocurre un error inesperado, también puedes cerrar sesión por seguridad
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    }
  }

  Future<void> _updateUserData() async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).update({
        'nombre': _nameController.text.trim(),
        'dni': _dniController.text.trim(),
        'celular': _phoneController.text.trim(),
      });
      setState(() {
        _isEditing = false;
        userData?['nombre'] = _nameController.text.trim();
        userData?['dni'] = _dniController.text.trim();
        userData?['celular'] = _phoneController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil actualizado correctamente"), backgroundColor: Colors.green),
      );
    }
  }

  Map<String, dynamic> getUserStatus(int puntos) {
    if (puntos == 20) {
      return {
        'tipo': 'Usuario Premium',
        'color': Colors.blue,
      };
    } else if (puntos >= 10 && puntos <= 19) {
      return {
        'tipo': 'Buen Usuario',
        'color': Colors.green,
      };
    } else if (puntos >= 5 && puntos <= 10) {
      return {
        'tipo': 'Usuario Regular',
        'color': Colors.yellow.shade700,
      };
    } else if (puntos >= 1 && puntos <= 4) {
      return {
        'tipo': 'Usuario en Riesgo',
        'color': Colors.orange,
      };
    } else {
      return {
        'tipo': 'Usuario Bloqueado',
        'color': Colors.red,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!) as ImageProvider
                      : const AssetImage('assets/user.png'),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade700,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                      onPressed: () {
                        setState(() {
                          _isEditing = !_isEditing;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _nameController.text,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(user?.email ?? '', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Información Personal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Divider(),

                  const SizedBox(height: 10),
                  _buildField("DNI", _dniController, Icons.credit_card),
                  const SizedBox(height: 10),
                  _buildField("Celular", _phoneController, Icons.phone),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          if (userData?['puntos'] != null) ...[
            Builder(
              builder: (_) {
                final puntos = userData!['puntos'] as int;
                final status = getUserStatus(puntos);
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: status['color'],
                          radius: 25,
                          child: const Icon(Icons.star, color: Colors.white),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Tipo de usuario: ${status['tipo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("Puntaje actual: $puntos", style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isEditing ? _updateUserData : () async {
                // Desconecta la sesión de Google
                final googleSignIn = GoogleSignIn();
                if (await googleSignIn.isSignedIn()) {
                  await googleSignIn.signOut();
                }
                // Cierra la sesión de Firebase
                await FirebaseAuth.instance.signOut();
                // Vuelve al login
                if (!mounted) return;
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: Icon(_isEditing ? Icons.save : Icons.logout),
              label: Text(_isEditing ? "Guardar Cambios" : "Cerrar Sesión"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: _isEditing ? Colors.green : Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon) {
  return _isEditing
      ? TextField(
          controller: controller,
          keyboardType: label == "DNI" ? TextInputType.number : TextInputType.phone,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
          ),
        )
      : Row(
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Text(
              "$label: ${controller.text.isEmpty ? 'No registrado' : controller.text}",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        );
  }
}
