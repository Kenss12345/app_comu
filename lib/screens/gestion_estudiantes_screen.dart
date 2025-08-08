import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/estudiante_service.dart';

class GestionEstudiantesScreen extends StatefulWidget {
  const GestionEstudiantesScreen({super.key});

  @override
  State<GestionEstudiantesScreen> createState() => _GestionEstudiantesScreenState();
}

class _GestionEstudiantesScreenState extends State<GestionEstudiantesScreen> {
  String _busqueda = '';
  int _rowsPerPage = 8;
  int _page = 0;
  String _filtroTipoUsuario = '';
  String _filtroPuntos = '';

  // Función para determinar el tipo de usuario basado en los puntos
  String _getTipoUsuario(int puntos) {
    if (puntos >= 20) {
      return 'Usuario Premium';
    } else if (puntos >= 10) {
      return 'Buen Usuario';
    } else if (puntos >= 5) {
      return 'Usuario Regular';
    } else if (puntos >= 1) {
      return 'Usuario en Riesgo';
    } else {
      return 'Usuario Bloqueado';
    }
  }

  Widget _getTipoUsuarioChip(int puntos) {
    Color color;
    String texto;
    
    if (puntos >= 20) {
      color = Colors.blue;
      texto = 'Usuario Premium';
    } else if (puntos >= 10) {
      color = Colors.green;
      texto = 'Buen Usuario';
    } else if (puntos >= 5) {
      color = Colors.yellow;
      texto = 'Usuario Regular';
    } else if (puntos >= 1) {
      color = Colors.orange;
      texto = 'Usuario en Riesgo';
    } else {
      color = Colors.red;
      texto = 'Usuario Bloqueado';
    }
    
    return Chip(
      label: Text(
        texto,
        style: TextStyle(
          color: color == Colors.yellow ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _mostrarDialogoRegistro(BuildContext context) {
    final nombreController = TextEditingController();
    final dniController = TextEditingController();
    final emailController = TextEditingController();
    final celularController = TextEditingController();
    final passwordController = TextEditingController();
    final puntosController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.transparent,
            ),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width > 600 ? 420 : MediaQuery.of(context).size.width * 0.95,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_add, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: const Text('Registrar nuevo estudiante',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _inputField(nombreController, 'Nombre', Icons.person, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(dniController, 'DNI', Icons.credit_card, tipo: TextInputType.number, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(emailController, 'Email', Icons.email, tipo: TextInputType.emailAddress, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(celularController, 'Celular', Icons.phone, tipo: TextInputType.phone, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(passwordController, 'Contraseña', Icons.lock, tipo: TextInputType.visiblePassword, isPassword: true, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(puntosController, 'Puntos', Icons.stars, tipo: TextInputType.number, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              icon: const Icon(Icons.save),
                              label: const Text('Registrar'),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                
                                // Mostrar indicador de carga
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                try {
                                  // Verificar permisos del gestor
                                  final tienePermisos = await EstudianteService.verificarPermisosGestor();
                                  if (!tienePermisos) {
                                    Navigator.of(context).pop(); // Cerrar loading
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No tienes permisos para crear estudiantes')),
                                    );
                                    return;
                                  }

                                  // Crear estudiante usando Cloud Function
                                  final resultado = await EstudianteService.crearEstudiante(
                                    nombre: nombreController.text.trim(),
                                    dni: dniController.text.trim(),
                                    email: emailController.text.trim(),
                                    celular: celularController.text.trim(),
                                    password: passwordController.text.trim(),
                                  );

                                  Navigator.of(context).pop(); // Cerrar loading

                                  if (resultado['success']) {
                                    // Actualizar los puntos después de crear el estudiante
                                    if (resultado['uid'] != null) {
                                      final puntos = int.tryParse(puntosController.text.trim()) ?? 10;
                                      await FirebaseFirestore.instance.collection('usuarios').doc(resultado['uid']).update({
                                        'puntos': puntos,
                                      });
                                    }
                                    
                                    Navigator.of(context).pop(); // Cerrar diálogo de registro
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Estudiante registrado exitosamente"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    setState(() {}); // Refrescar lista
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(resultado['error']),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  Navigator.of(context).pop(); // Cerrar loading
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarDialogoEditar(BuildContext context, Map<String, dynamic> estudiante, String docId) {
    final nombreController = TextEditingController(text: estudiante['nombre'] ?? '');
    final dniController = TextEditingController(text: estudiante['dni'] ?? '');
    final emailController = TextEditingController(text: estudiante['email'] ?? '');
    final celularController = TextEditingController(text: estudiante['celular'] ?? '');
    final passwordController = TextEditingController(text: estudiante['password'] ?? '');
    final puntosController = TextEditingController(text: (estudiante['puntos'] ?? 0).toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.transparent,
            ),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width > 600 ? 420 : MediaQuery.of(context).size.width * 0.95,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: const Text('Editar estudiante',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _inputField(nombreController, 'Nombre', Icons.person, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(dniController, 'DNI', Icons.credit_card, tipo: TextInputType.number, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(emailController, 'Email', Icons.email, tipo: TextInputType.emailAddress, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(celularController, 'Celular', Icons.phone, tipo: TextInputType.phone, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(passwordController, 'Contraseña', Icons.lock, tipo: TextInputType.visiblePassword, isPassword: true, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 16),
                        _inputField(puntosController, 'Puntos', Icons.stars, tipo: TextInputType.number, validator: (v) => v!.trim().isEmpty ? 'Campo requerido' : null),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              icon: const Icon(Icons.save),
                              label: const Text('Guardar'),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                await FirebaseFirestore.instance.collection('usuarios').doc(docId).update({
                                  'nombre': nombreController.text.trim(),
                                  'dni': dniController.text.trim(),
                                  'email': emailController.text.trim(),
                                  'celular': celularController.text.trim(),
                                  'password': passwordController.text.trim(),
                                  'puntos': int.tryParse(puntosController.text.trim()) ?? 0, // Mantener los puntos existentes
                                });
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Estudiante actualizado")),
                                );
                                setState(() {}); // Refrescar lista
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _eliminarEstudiante(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar estudiante'),
        content: const Text('¿Estás seguro de eliminar este estudiante? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('usuarios').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estudiante eliminado')),
      );
      setState(() {}); // Refrescar lista
    }
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon, {TextInputType tipo = TextInputType.text, bool isPassword = false, String? Function(String?)? validator, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: tipo,
      obscureText: isPassword,
      style: TextStyle(
        fontWeight: FontWeight.w500, 
        color: enabled ? const Color(0xFF1E293B) : const Color(0xFF64748B)
      ),
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        prefixIcon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF3F4F6) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: enabled ? const Color(0xFF8B5CF6) : const Color(0xFF9CA3AF)),
        ),
        labelText: label,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600, 
          color: enabled ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Color(0xFFE0E7EF)) ),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Color(0xFFE0E7EF)) ),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2)),
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1200;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            automaticallyImplyLeading: false, // Quita la flecha hacia atrás automática
            backgroundColor: Colors.white,
            elevation: 1,
            toolbarHeight: 0, // Reduce la altura del AppBar para aprovechar más espacio
          ),
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              children: [
                // Zona de búsqueda y botón nuevo estudiante
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Fila principal con búsqueda y botón
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "Buscar por nombre, email, DNI o puntos...",
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    _busqueda = v.trim().toLowerCase();
                                    _page = 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => _mostrarDialogoRegistro(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text("Nuevo estudiante"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Filtros adicionales en una sola línea
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filtroTipoUsuario.isEmpty ? null : _filtroTipoUsuario,
                                decoration: InputDecoration(
                                  hintText: "Filtrar por tipo de usuario",
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('Todos los tipos')),
                                  const DropdownMenuItem(value: 'Usuario Premium', child: Text('Usuario Premium')),
                                  const DropdownMenuItem(value: 'Buen Usuario', child: Text('Buen Usuario')),
                                  const DropdownMenuItem(value: 'Usuario Regular', child: Text('Usuario Regular')),
                                  const DropdownMenuItem(value: 'Usuario en Riesgo', child: Text('Usuario en Riesgo')),
                                  const DropdownMenuItem(value: 'Usuario Bloqueado', child: Text('Usuario Bloqueado')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _filtroTipoUsuario = value ?? '';
                                    _page = 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filtroPuntos.isEmpty ? null : _filtroPuntos,
                                decoration: InputDecoration(
                                  hintText: "Filtrar por puntos",
                                  prefixIcon: const Icon(Icons.stars),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E7EF)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('Todos los puntos')),
                                  const DropdownMenuItem(value: '20+', child: Text('20+ puntos')),
                                  const DropdownMenuItem(value: '10-19', child: Text('10-19 puntos')),
                                  const DropdownMenuItem(value: '5-9', child: Text('5-9 puntos')),
                                  const DropdownMenuItem(value: '1-4', child: Text('1-4 puntos')),
                                  const DropdownMenuItem(value: '0', child: Text('0 puntos')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _filtroPuntos = value ?? '';
                                    _page = 0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Contenido principal
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('usuarios')
                          .where('rol', isEqualTo: 'estudiante')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Error al cargar estudiantes.'));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        List<Map<String, dynamic>> estudiantes = docs
                            .map((e) => {...?e.data() as Map<String, dynamic>, '_id': e.id})
                            .toList();
                        
                        // Aplicar filtros
                        if (_busqueda.isNotEmpty) {
                          estudiantes = estudiantes.where((e) {
                            final nombre = (e['nombre'] ?? '').toString().toLowerCase();
                            final email = (e['email'] ?? '').toString().toLowerCase();
                            final dni = (e['dni'] ?? '').toString().toLowerCase();
                            final puntos = (e['puntos'] ?? 0).toString();
                            return nombre.contains(_busqueda) || email.contains(_busqueda) || dni.contains(_busqueda) || puntos.contains(_busqueda);
                          }).toList();
                        }
                        if (_filtroTipoUsuario.isNotEmpty) {
                          estudiantes = estudiantes.where((e) {
                            final tipoUsuario = _getTipoUsuario(e['puntos'] ?? 0);
                            return tipoUsuario == _filtroTipoUsuario;
                          }).toList();
                        }
                        if (_filtroPuntos.isNotEmpty) {
                          estudiantes = estudiantes.where((e) {
                            final puntosEstudiante = e['puntos'] ?? 0;
                            switch (_filtroPuntos) {
                              case '20+':
                                return puntosEstudiante >= 20;
                              case '10-19':
                                return puntosEstudiante >= 10 && puntosEstudiante <= 19;
                              case '5-9':
                                return puntosEstudiante >= 5 && puntosEstudiante <= 9;
                              case '1-4':
                                return puntosEstudiante >= 1 && puntosEstudiante <= 4;
                              case '0':
                                return puntosEstudiante == 0;
                              default:
                                return true;
                            }
                          }).toList();
                        }
                        
                        // Paginación
                        final total = estudiantes.length;
                        final start = _page * _rowsPerPage;
                        final end = (start + _rowsPerPage) > total ? total : (start + _rowsPerPage);
                        final pageItems = estudiantes.sublist(start, end);
                        
                        if (isMobile) {
                          // Vista de cards para móviles
                          return Column(
                            children: [
                              Expanded(
                                child: pageItems.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                                            SizedBox(height: 16),
                                            Text('No se encontraron estudiantes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                            SizedBox(height: 8),
                                            Text('Intenta ajustar la búsqueda', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: pageItems.length,
                                        itemBuilder: (context, index) {
                                          final estudiante = pageItems[index];
                                          return Card(
                                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            child: ListTile(
                                              title: Text(
                                                estudiante['nombre'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('DNI: ${estudiante['dni'] ?? ''}'),
                                                  Text('Email: ${estudiante['email'] ?? ''}'),
                                                  Text('Celular: ${estudiante['celular'] ?? ''}'),
                                                  Text('Puntos: ${estudiante['puntos'] ?? 0}'),
                                                  const SizedBox(height: 4),
                                                  _getTipoUsuarioChip(estudiante['puntos'] ?? 0),
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
                                                    onPressed: () => _mostrarDialogoEditar(context, estudiante, estudiante['_id']),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red),
                                                    onPressed: () => _eliminarEstudiante(context, estudiante['_id']),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              // Paginación móvil
                              if (total > _rowsPerPage)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: _page > 0 ? () => setState(() => _page--) : null,
                                      ),
                                      Text('${_page + 1} de ${((total - 1) / _rowsPerPage).floor() + 1}'),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: end < total ? () => setState(() => _page++) : null,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        } else {
                          // Vista de tabla para desktop/tablet
                          return Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: MaterialStateProperty.resolveWith<Color?>((states) => const Color(0xFFEFF6FF)),
                                      dataRowColor: MaterialStateProperty.resolveWith<Color?>((states) => Colors.white),
                                      columnSpacing: isTablet ? 16 : 24,
                                      border: TableBorder.all(color: const Color(0xFFE0E7EF), width: 1),
                                      columns: [
                                        const DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('DNI', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Celular', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Puntos', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Tipo de Usuario', style: TextStyle(fontWeight: FontWeight.bold))),
                                        const DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: pageItems.map((e) {
                                        final puntos = e['puntos'] ?? 0;
                                        return DataRow(cells: [
                                          DataCell(Text(e['nombre'] ?? '')),
                                          DataCell(Text(e['dni'] ?? '')),
                                          DataCell(Text(e['email'] ?? '')),
                                          DataCell(Text(e['celular'] ?? '')),
                                          DataCell(Text(puntos.toString())),
                                          DataCell(_getTipoUsuarioChip(puntos)),
                                          DataCell(Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
                                                tooltip: 'Editar',
                                                onPressed: () => _mostrarDialogoEditar(context, e, e['_id']),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                tooltip: 'Eliminar',
                                                onPressed: () => _eliminarEstudiante(context, e['_id']),
                                              ),
                                            ],
                                          )),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              // Paginación desktop
                              if (total > _rowsPerPage)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Mostrando ${start + 1}-$end de $total estudiantes'),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chevron_left),
                                            onPressed: _page > 0 ? () => setState(() => _page--) : null,
                                          ),
                                          Text('Página ${_page + 1} de ${((total - 1) / _rowsPerPage).floor() + 1}'),
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right),
                                            onPressed: end < total ? () => setState(() => _page++) : null,
                                          ),
                                          const SizedBox(width: 16),
                                          DropdownButton<int>(
                                            value: _rowsPerPage,
                                            items: const [8, 12, 20, 40]
                                                .map((e) => DropdownMenuItem(value: e, child: Text('$e filas')))
                                                .toList(),
                                            onChanged: (v) => setState(() {
                                              _rowsPerPage = v!;
                                              _page = 0;
                                            }),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
