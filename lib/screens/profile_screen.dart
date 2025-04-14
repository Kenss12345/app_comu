import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'equipos_disponibles_screen.dart';
import 'equipos_a_cargo_screen.dart';
import 'solicitud_equipos_screen.dart';

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
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Solicitud',
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
    if (puntos >= 15 && puntos <= 20) {
      return {
        'tipo': 'Usuario Premium',
        'color': Colors.blue,
      };
    } else if (puntos >= 8 && puntos <= 14) {
      return {
        'tipo': 'Buen Usuario',
        'color': Colors.green,
      };
    } else if (puntos >= 5 && puntos <= 7) {
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!) as ImageProvider
                      : const AssetImage('assets/user.png'),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
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
            
            const SizedBox(height: 10),
            _isEditing
                ? TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Nombre y Apellidos"),
                  )
                : Text(userData?['nombre'] ?? "Usuario sin nombre", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 5),
            Text(user?.email ?? "Correo no disponible"),

            const SizedBox(height: 5),            
            _isEditing
                ? TextField(
                    controller: _dniController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "DNI"),
                  )
                : Text("DNI: ${userData?['dni'] ?? 'No registrado'}"),

            const SizedBox(height: 5),
            _isEditing
                ? TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Celular"),
                  )
                : Text("Celular: ${userData?['celular'] ?? 'No registrado'}"),

            const SizedBox(height: 10),
            if (userData?['puntos'] != null) ...[
              Builder(
                builder: (_) {
                  final puntos = userData!['puntos'] as int;
                  final status = getUserStatus(puntos);
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: status['color'],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Tipo de usuario: ${status['tipo']}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text("Puntaje actual: $puntos", style: const TextStyle(fontSize: 16)),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 20),
            _isEditing
                ? ElevatedButton(
                    onPressed: _updateUserData,
                    child: const Text("Guardar Cambios"),
                  )
                : ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    child: const Text("Cerrar Sesión"),
                  ),
          ],
        ),
      ),
    );
  }
}

// Widget que contiene el contenido de la pantalla de perfil
/*class ProfileContent extends StatelessWidget {
  const ProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!) as ImageProvider
                      : const AssetImage('assets/user.png'), // Imagen de perfil
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        // Acción para cambiar la foto
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              user?.displayName ?? "Usuario sin nombre",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(user?.email ?? "Correo no disponible"),
            const SizedBox(height: 5),
            const Text("Código: 2020123456"), // Esto debería obtenerse desde Firestore si es dinámico
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Buen Usuario", // Este estado debería venir desde Firestore si cambia
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text("Cerrar Sesión"),
            ),
          ],
        ),
      ),
    );
  }
}*/

/*class ProfileScreen extends StatefulWidget {
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
    ProfileContent(), 
    EquiposDisponiblesScreen(),
    EquiposACargoScreen(),
    SolicitudEquiposScreen(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Solicitud',
          ),
        ],
      ),
    );
  }
}

// Widget que contiene el contenido de la pantalla de perfil
class ProfileContent extends StatelessWidget {
  const ProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/user.png'), // Imagen de perfil
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        // Acción para cambiar la foto
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Juan Pérez",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text("Ingeniería de Sistemas"),
            const SizedBox(height: 5),
            const Text("Código: 2020123456"),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Buen Usuario",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}*/
