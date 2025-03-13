import 'package:flutter/material.dart';
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
}
