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
        selectedItemColor: Colors.orange.shade700,
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

    final isMobile = MediaQuery.of(context).size.width < 600;

    return SizedBox(
      height: MediaQuery.of(context).size.height - (isMobile ? 120 : 160),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? 500 : 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 60 : 80,
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
                            color: Colors.orange.shade700,
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
                  style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(user?.email ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 15 : 17)),
                const SizedBox(height: 20),

                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            const Text("Información Personal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 10),
                        _buildField("DNI", _dniController, Icons.credit_card, isMobile),
                        const SizedBox(height: 10),
                        _buildField("Celular", _phoneController, Icons.phone, isMobile),
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
                      return GestureDetector(
                        onTap: () => _mostrarInformacionPuntaje(context, puntos),
                        child: Card(
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Tipo de usuario: ${status['tipo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text("Puntaje actual: $puntos", style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.info_outline, color: Colors.orange.shade700),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final isPasswordUser = user?.providerData.any((p) => p.providerId == 'password') ?? false;
                      if (!isPasswordUser) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tu cuenta se autenticó con Google. El cambio de contraseña no está disponible aquí.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      _mostrarDialogoCambiarContrasena();
                    },
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Cambiar Contraseña'),
                  ),
                ),
                const SizedBox(height: 10),
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
                      textStyle: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, bool isMobile) {
    return _isEditing
        ? TextField(
            controller: controller,
            keyboardType: label == "DNI" ? TextInputType.number : TextInputType.phone,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: Colors.orange.shade700),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.orange.shade50,
              contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 18, horizontal: 16),
            ),
            style: TextStyle(fontSize: isMobile ? 15 : 17),
          )
        : Row(
            children: [
              Icon(icon, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              Text(
                "$label: ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 15 : 17),
              ),
              Expanded(
                child: Text(
                  controller.text.isEmpty ? 'No registrado' : controller.text,
                  style: TextStyle(fontSize: isMobile ? 15 : 17, color: Colors.grey.shade800),
                ),
              ),
            ],
          );
  }

  bool _passwordCumplePolitica(String value) {
    if (value.length < 8) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasNumber = RegExp(r'\\d').hasMatch(value);
    final hasSpecial = RegExp(r'[^\\w\\s]').hasMatch(value);
    return hasUpper && hasNumber && hasSpecial;
  }

  Future<void> _mostrarDialogoCambiarContrasena() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;
    String? errorText;

    if (user == null || user!.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el usuario actual.'), backgroundColor: Colors.red),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Cambiar Contraseña'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'La nueva contraseña debe incluir:\n- Mínimo 8 caracteres\n- 1 letra mayúscula\n- 1 número\n- 1 caracter especial',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(errorText!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final actual = currentController.text.trim();
                          final nueva = newController.text.trim();
                          final confirma = confirmController.text.trim();

                          if (actual.isEmpty || nueva.isEmpty || confirma.isEmpty) {
                            setState(() => errorText = 'Completa todos los campos.');
                            return;
                          }
                          if (nueva != confirma) {
                            setState(() => errorText = 'La confirmación no coincide.');
                            return;
                          }
                          if (!_passwordCumplePolitica(nueva)) {
                            setState(() => errorText = 'La contraseña no cumple los requisitos.');
                            return;
                          }

                          setState(() {
                            errorText = null;
                            loading = true;
                          });

                          try {
                            final cred = EmailAuthProvider.credential(
                              email: user!.email!,
                              password: actual,
                            );
                            await user!.reauthenticateWithCredential(cred);
                            await user!.updatePassword(nueva);

                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Contraseña actualizada correctamente.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            String msg = 'Error al actualizar la contraseña.';
                            if (e.code == 'wrong-password') {
                              msg = 'La contraseña actual es incorrecta.';
                            } else if (e.code == 'weak-password') {
                              msg = 'La nueva contraseña es demasiado débil.';
                            } else if (e.code == 'requires-recent-login') {
                              msg = 'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.';
                            }
                            setState(() {
                              errorText = msg;
                              loading = false;
                            });
                          } catch (_) {
                            setState(() {
                              errorText = 'Ocurrió un error inesperado.';
                              loading = false;
                            });
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para mostrar información detallada del sistema de puntajes
  void _mostrarInformacionPuntaje(BuildContext context, int puntosActuales) {
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
                      Icon(Icons.star, color: Colors.orange.shade700, size: 32),
                      const SizedBox(width: 10),
                      const Text('Sistema de Puntajes',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Tu puntaje actual: $puntosActuales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 20),
                  _buildPuntajeInfo('Usuario Premium', 20, Colors.blue, 'Máximo nivel. Acceso a equipos premium y beneficios especiales.'),
                  const SizedBox(height: 12),
                  _buildPuntajeInfo('Buen Usuario', '10-19', Colors.green, 'Acceso completo a equipos estándar.'),
                  const SizedBox(height: 12),
                  _buildPuntajeInfo('Usuario Regular', '5-9', Colors.yellow.shade700, 'Acceso limitado a equipos básicos.'),
                  const SizedBox(height: 12),
                  _buildPuntajeInfo('Usuario en Riesgo', '1-4', Colors.orange, 'Acceso muy limitado. Se recomienda mejorar comportamiento.'),
                  const SizedBox(height: 12),
                  _buildPuntajeInfo('Usuario Bloqueado', 0, Colors.red, 'Sin acceso a equipos. Contacta al administrador.'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text('Información Importante', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('• Con 0 puntos no podrás solicitar equipos', style: TextStyle(fontSize: 14)),
                        Text('• Con 20 puntos tendrás acceso a equipos premium', style: TextStyle(fontSize: 14)),
                        Text('• Los puntos se ganan/perden según el uso responsable', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Entendido'),
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

  // Widget para mostrar información de cada nivel de puntaje
  Widget _buildPuntajeInfo(String tipo, dynamic puntos, Color color, String descripcion) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 15,
            child: const Icon(Icons.star, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  'Puntos: $puntos',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  descripcion,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
