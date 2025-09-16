import 'package:app_comu/screens/gestion_estudiantes_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // si usas Google Sign-In
import '../main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'gestion_equipos_screen.dart';

class UsuariosConEquiposScreen extends StatefulWidget {
  const UsuariosConEquiposScreen({super.key});

  @override
  State<UsuariosConEquiposScreen> createState() =>
      _UsuariosConEquiposScreenState();
}

class _UsuariosConEquiposScreenState extends State<UsuariosConEquiposScreen> {
  List<Map<String, dynamic>> estudiantes = [];
  List<Map<String, dynamic>> estudiantesFiltrados = [];
  String filtroNombre = "";
  bool filtrarMenosDe5Horas = false;
  String filtroDni = "";
  bool ordenarTiempoRestanteAsc = true;
  bool mostrarSoloExcedidos = false;
  bool _procesandoSolicitud = false;
  String filtroNombreSolicitante = "";
  bool ordenarRecientesPrimero = true;
  int _selectedSection = 0; // 0: Usuarios, 1: Solicitudes, 2: Gestionar Estudiantes, 3: Gestionar Equipos
  bool _sidebarCollapsed = false; // Controla si el panel lateral está colapsado
  final ScrollController _sidebarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    obtenerUsuarios();
  }

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    super.dispose();
  }

  Future<void> obtenerUsuarios() async {
    // 1. Obtener todos los usuarios
    final usuariosSnap =
        await FirebaseFirestore.instance.collection('usuarios').get();

    List<Map<String, dynamic>> lista = [];

    for (final doc in usuariosSnap.docs) {
      // 2. Busca equipos en uso para cada usuario
      final equiposACargoSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(doc.id)
          .collection('equipos_a_cargo')
          .where('estado_prestamo', isEqualTo: "En uso")
          .get();

      if (equiposACargoSnap.docs.isNotEmpty) {
        final data = doc.data();
        // Para simplificar, solo muestra el primero (puedes mostrar todos si quieres)
        for (final equipoDoc in equiposACargoSnap.docs) {
          final equipo = equipoDoc.data();
          final equipoId = equipoDoc.id;
          if (equipoId.isEmpty) continue;

          // Calcula tiempo restante si tienes fechas en el doc
          DateTime? fechaDevolucion;
          if (equipo['fecha_devolucion'] != null) {
            try {
              fechaDevolucion =
                  DateFormat('dd/MM/yyyy').parse(equipo['fecha_devolucion']);
            } catch (_) {}
          }
          final tiempoRestante = fechaDevolucion != null
              ? fechaDevolucion.difference(DateTime.now())
              : Duration.zero;

          lista.add({
            'id': doc.id,
            'nombre': data['nombre'],
            'email': data['email'],
            'celular': data['celular'],
            'dni': data['dni'],
            'equipo': equipo['nombre'] ?? 'Equipo no registrado',
            'equipoId': equipoId,
            'tiempo_restante': tiempoRestante,
            'fechaDevolucion': equipo['fecha_devolucion'],
            'fechaPrestamo': equipo['fecha_prestamo'],
          });
        }
      }
    }
    setState(() {
      estudiantes = lista;
      aplicarFiltros();
    });
  }

  // EmailJS - Configuración (rellenar con tus valores reales)
  static const String _emailJsServiceId = 'service_g9z5wq1';
  static const String _emailJsTemplateIdSolicitudEstado = 'template_vprkgmd';
  static const String _emailJsPublicKey = '1YM2-UMljnkfRuBmm';

  // Método para enviar correo de notificación al estudiante con EmailJS
  Future<void> _enviarCorreoNotificacion(
    String destinatario,
    String estado,
    Map<String, dynamic> solicitud,
  ) async {
    final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    // Usar un único template; el contenido varía por {{estado}}
    final templateId = _emailJsTemplateIdSolicitudEstado;

    // Construir listado de equipos en texto
    final equipos = (solicitud['equipos'] as List?) ?? [];
    final contenidoEquipos = equipos
        .map((e) => "- ${e['nombre'] ?? ''}")
        .join("\n");

    // Fechas formateadas dd/MM/yyyy
    String _fmt(dynamic v) {
      if (v == null) return '';
      if (v is Timestamp) return DateFormat('dd/MM/yyyy').format(v.toDate());
      if (v is DateTime) return DateFormat('dd/MM/yyyy').format(v);
      return v.toString();
    }
    final fechaPrestamoStr = _fmt(solicitud['fecha_prestamo']);
    final fechaDevolucionStr = _fmt(solicitud['fecha_devolucion']);

    final payload = {
      'service_id': _emailJsServiceId,
      'template_id': templateId,
      'user_id': _emailJsPublicKey,
      'template_params': {
        'to_email': destinatario,
        'to_name': '${solicitud['nombre'] ?? ''} ${solicitud['apellidos'] ?? ''}',
        'nombre': solicitud['nombre'] ?? '',
        'apellidos': solicitud['apellidos'] ?? '',
        'dni': (solicitud['dni'] ?? '').toString(),
        'asignatura': solicitud['asignatura'] ?? '',
        'trabajo': solicitud['trabajo'] ?? '',
        'docente': solicitud['docente'] ?? '',
        'lugar': solicitud['lugar'] ?? '',
        'fecha_prestamo': fechaPrestamoStr,
        'fecha_devolucion': fechaDevolucionStr,
        'equipos': contenidoEquipos,
        'estado': estado,
      },
    };

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('EmailJS error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      // Registrar error pero sin bloquear el flujo
      // Puedes mostrar SnackBar si lo deseas
    }
  }

  Duration calcularTiempoRestante(Timestamp fechaDevolucion) {
    final ahora = DateTime.now();
    final devolucion = fechaDevolucion.toDate();
    return devolucion.difference(ahora);
  }

  void aplicarFiltros() {
    List<Map<String, dynamic>> lista = estudiantes.where((est) {
      final nombreMatch =
          est['nombre'].toLowerCase().contains(filtroNombre.toLowerCase());
      final dniMatch = filtroDni.isEmpty ||
          (est['dni'] ?? '').toString().contains(filtroDni);
      final tiempo = est['tiempo_restante'] as Duration;
      final esExcedido = tiempo.inSeconds.isNegative;

      // Filtro por excedidos o no
      final filtroExcedido = !mostrarSoloExcedidos || esExcedido;

      return nombreMatch && dniMatch && filtroExcedido;
    }).toList();

    // Ordenamiento
    lista.sort((a, b) {
      final ta = a['tiempo_restante'] as Duration;
      final tb = b['tiempo_restante'] as Duration;
      if (ordenarTiempoRestanteAsc) {
        return ta.compareTo(tb);
      } else {
        return tb.compareTo(ta);
      }
    });

    setState(() {
      estudiantesFiltrados = lista;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1200;
        
        return Stack(
          children: [
            // Fondo con gradiente mejorado
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFF1F5F9),
                    const Color(0xFFFEF3C7),
                    const Color(0xFFFFF7ED),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            // Layout principal con barra lateral
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: isMobile ? AppBar(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E40AF),
                            const Color(0xFF3B82F6),
                            const Color(0xFF60A5FA),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text("Panel de Control"),
                  ],
                ),
                backgroundColor: Colors.white,
                elevation: 1,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    onPressed: () => _mostrarConfirmacionCerrarSesion(),
                  ),
                ],
              ) : null,
              drawer: isMobile ? Drawer(
                child: _buildSidebarContent(),
              ) : null,
              body: Row(
                children: [
                  // Barra lateral mejorada - responsive y colapsable
                  if (!isMobile) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _sidebarCollapsed ? 80 : (isTablet ? 250 : 300),
                      child: _buildSidebarContent(),
                    ),
                  ],
                                    // Contenido principal mejorado - responsive
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.all(isMobile ? 12 : 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 60,
                            offset: const Offset(0, 16),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Contenido dinámico
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(isMobile ? 16 : 24),
                                  bottomRight: Radius.circular(isMobile ? 16 : 24),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(isMobile ? 16 : 24),
                                  bottomRight: Radius.circular(isMobile ? 16 : 24),
                                ),
                                child: _selectedSection == 0
                                    ? _buildUsuariosConEquiposTab()
                                    : _selectedSection == 1
                                        ? _buildSolicitudesTab()
                                        : _selectedSection == 2
                                            ? const GestionEstudiantesScreen()
                                            : GestionEquiposScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Overlay de procesamiento mejorado
            if (_procesandoSolicitud)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF60A5FA),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Procesando solicitud...",
                            style: TextStyle(
                              color: const Color(0xFF1E293B),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Por favor espera un momento",
                            style: TextStyle(
                              color: const Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSidebarContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(4, 0),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(8, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Scrollbar(
        controller: _sidebarScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 6,
        radius: const Radius.circular(12),
        child: SingleChildScrollView(
          controller: _sidebarScrollController,
          padding: EdgeInsets.zero,
          child: Column(
        children: [
          // Header de la barra lateral mejorado
          Container(
            padding: EdgeInsets.all(_sidebarCollapsed ? 16 : 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E40AF),
                  const Color(0xFF3B82F6),
                  const Color(0xFF60A5FA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_sidebarCollapsed ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(_sidebarCollapsed ? 8 : 12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: _sidebarCollapsed ? 20 : 28,
                  ),
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panel de Control',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gestión de Equipos',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Botón para colapsar/expandir
                if (!_sidebarCollapsed)
                  IconButton(
                    onPressed: () => setState(() => _sidebarCollapsed = true),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    tooltip: 'Colapsar panel',
                  ),
              ],
            ),
          ),
          // Menú de navegación mejorado
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: 32, 
              horizontal: _sidebarCollapsed ? 8 : 16
            ),
            child: Column(
              children: [
                _SidebarButton(
                  icon: Icons.people_alt,
                  label: 'Usuarios con Equipos',
                  selected: _selectedSection == 0,
                  collapsed: _sidebarCollapsed,
                  onTap: () => setState(() => _selectedSection = 0),
                ),
                const SizedBox(height: 12),
                _SidebarButton(
                  icon: Icons.assignment_turned_in,
                  label: 'Solicitudes',
                  selected: _selectedSection == 1,
                  collapsed: _sidebarCollapsed,
                  onTap: () => setState(() => _selectedSection = 1),
                ),
                const SizedBox(height: 12),
                _SidebarButton(
                  icon: Icons.school,
                  label: 'Gestionar Estudiantes',
                  selected: _selectedSection == 2,
                  collapsed: _sidebarCollapsed,
                  onTap: () => setState(() => _selectedSection = 2),
                ),
                const SizedBox(height: 12),
                _SidebarButton(
                  icon: Icons.devices,
                  label: 'Gestionar Equipos',
                  selected: _selectedSection == 3,
                  collapsed: _sidebarCollapsed,
                  onTap: () => setState(() => _selectedSection = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Botón Cerrar Sesión mejorado
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarCollapsed ? 8 : 20, 
              vertical: 16
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444),
                    const Color(0xFFDC2626),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _sidebarCollapsed
                  ? IconButton(
                      onPressed: () => _mostrarConfirmacionCerrarSesion(),
                      icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      tooltip: 'Cerrar Sesión',
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _mostrarConfirmacionCerrarSesion(),
                      icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ),
          // Footer de la barra lateral mejorado
          Container(
            margin: EdgeInsets.all(_sidebarCollapsed ? 8 : 20),
            padding: EdgeInsets.all(_sidebarCollapsed ? 8 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(_sidebarCollapsed ? 8 : 16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: _sidebarCollapsed
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6),
                          const Color(0xFF60A5FA),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF3B82F6),
                              const Color(0xFF60A5FA),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Administrador',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Soporte Audiovisual',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          // Botón para expandir cuando está colapsado
          if (_sidebarCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => setState(() => _sidebarCollapsed = false),
                  icon: Icon(Icons.chevron_right, color: Colors.grey.shade700, size: 20),
                  tooltip: 'Expandir panel',
                ),
              ),
            ),
        ],
          ),
        ),
      ),
    );
  }

  // Método para mostrar el diálogo de confirmación
  void _mostrarConfirmacionCerrarSesion() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Cerrar Sesión"),
          content: const Text("¿Estás seguro de que deseas cerrar sesión?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(), // Cerrar el diálogo sin hacer nada
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cierra el diálogo
                await _cerrarSesion();
              },
              child: const Text("Cerrar Sesión"),
            ),
          ],
        );
      },
    );
  }

  String _formateaFecha(dynamic fecha) {
    if (fecha == null) return "---";
    if (fecha is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm').format(fecha.toDate());
    }
    if (fecha is String) {
      return fecha;
    }
    return fecha.toString();
  }

  // Método para cerrar sesión
  Future<void> _cerrarSesion() async {
    // Desconectar Google (si procede)
    final googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }

    // Cerrar sesión de Firebase
    await FirebaseAuth.instance.signOut();

    // Reiniciar el stack y volver a AuthWrapper
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  Future<void> _devolverEquipo(String equipoId, String userId, {String? docUsuariosConEquipos, List<String> integrantesDnis = const [], String? fechaDevolucionStr}) async {
    try {
      // Cambia estado a Disponible y elimina fechas en colección equipos
      await FirebaseFirestore.instance
          .collection('equipos')
          .doc(equipoId)
          .update({
        'estado': 'Disponible',
        'fecha_devolucion': null,
        'fecha_prestamo': null,
        'fecha_solicitud': null,
        'uid_prestamo': null,
      });
      // 2. Elimina subcolección equipos_a_cargo
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('equipos_a_cargo')
          .doc(equipoId)
          .delete();

      // 3. Ajuste de puntos (usuario y, si aplica, integrantes). Basado en fechaDevolucionStr
      if (fechaDevolucionStr != null && fechaDevolucionStr.isNotEmpty) {
        DateTime? fechaDev;
        try { fechaDev = DateFormat('dd/MM/yyyy').parse(fechaDevolucionStr); } catch (_) {}
        final ahora = DateTime.now();
        final aTiempo = fechaDev != null && !ahora.isAfter(fechaDev);
        // Carga documento de usuario para puntos
        final userDocRef = FirebaseFirestore.instance.collection('usuarios').doc(userId);
        final userSnap = await userDocRef.get();
        if (userSnap.exists) {
          final puntos = (userSnap.data()?['puntos'] ?? 0) as int;
          final nuevo = aTiempo ? (puntos + 1).clamp(0, 20) : (puntos - 1).clamp(0, 20);
          await userDocRef.update({'puntos': nuevo});
        }
        // Integrantes penalización si fuera tarde
        if (!aTiempo) {
          for (final dni in integrantesDnis) {
            if (dni.toString().isEmpty) continue;
            final q = await FirebaseFirestore.instance
                .collection('usuarios')
                .where('dni', isEqualTo: dni)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final doc = q.docs.first.reference;
              final pts = (q.docs.first.data()['puntos'] ?? 0) as int;
              final nuevo = (pts - 1).clamp(0, 20);
              await doc.update({'puntos': nuevo});
            }
          }
        }
      }

      // 4. No eliminar el documento completo; este flujo ahora será manejado por el modal de devolución por equipo

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipo devuelto correctamente.')),
      );
      // No necesario recargar manualmente; StreamBuilder actualiza en vivo
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al devolver: $e')),
      );
    }
  }

  int _dias(Duration dur) => dur.inDays.abs();

  // Pestaña de Usuarios con Equipos
  Widget _buildUsuariosConEquiposTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        
        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
          
          // Panel de filtros - responsive
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isMobile ? 12 : 16),
                isMobile 
                  ? Column(
                      children: [
                        // Filtro por nombre
                        TextField(
                          decoration: InputDecoration(
                            hintText: "Buscar por nombre...",
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onChanged: (valor) {
                            filtroNombre = valor;
                            aplicarFiltros();
                          },
                        ),
                        const SizedBox(height: 12),
                        // Filtro por DNI
                        TextField(
                          decoration: InputDecoration(
                            hintText: "Buscar por DNI...",
                            prefixIcon: const Icon(Icons.credit_card),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (valor) {
                            filtroDni = valor;
                            aplicarFiltros();
                          },
                        ),
                        const SizedBox(height: 12),
                        // Controles móviles
                        Row(
                          children: [
                            Text(
                              "Ordenar: ",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: DropdownButton<bool>(
                                value: ordenarTiempoRestanteAsc,
                                underline: Container(),
                                items: const [
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text("↑", style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text("↓", style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    ordenarTiempoRestanteAsc = val;
                                    aplicarFiltros();
                                  });
                                },
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Checkbox(
                                  value: mostrarSoloExcedidos,
                                  activeColor: Colors.orange.shade600,
                                  onChanged: (val) {
                                    setState(() {
                                      mostrarSoloExcedidos = val ?? false;
                                      aplicarFiltros();
                                    });
                                  },
                                ),
                                Text(
                                  "Solo excedidos",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Filtro por nombre - más compacto
                        SizedBox(
                          width: 250,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Buscar por nombre...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (valor) {
                              filtroNombre = valor;
                              aplicarFiltros();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Filtro por DNI
                        SizedBox(
                          width: 180,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Buscar por DNI...",
                              prefixIcon: const Icon(Icons.credit_card),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (valor) {
                              filtroDni = valor;
                              aplicarFiltros();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Ordenar por tiempo restante
                        Text(
                          "Ordenar: ",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<bool>(
                            value: ordenarTiempoRestanteAsc,
                            underline: Container(),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text("↑"),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text("↓"),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                ordenarTiempoRestanteAsc = val;
                                aplicarFiltros();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Filtrar solo excedidos
                        Row(
                          children: [
                            Checkbox(
                              value: mostrarSoloExcedidos,
                              activeColor: Colors.orange.shade600,
                              onChanged: (val) {
                                setState(() {
                                  mostrarSoloExcedidos = val ?? false;
                                  aplicarFiltros();
                                });
                              },
                            ),
                            Text(
                              "Solo excedidos",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Lista en vivo desde 'usuarios_con_equipos'
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('usuarios_con_equipos').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                // Un documento por préstamo (no aplanar por equipo)
                var visibles = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final dni = (data['dni'] ?? '').toString();
                  final nombreMatch = nombre.contains(filtroNombre.toLowerCase());
                  final dniMatch = filtroDni.isEmpty || dni.contains(filtroDni);
                  return nombreMatch && dniMatch;
                }).toList();
                // Orden por fecha de devolución
                visibles.sort((a, b) {
                  final ad = (a.data() as Map<String, dynamic>)['fecha_devolucion'];
                  final bd = (b.data() as Map<String, dynamic>)['fecha_devolucion'];
                  DateTime pa, pb;
                  if (ad is Timestamp) {
                    pa = ad.toDate();
                  } else if (ad is String) {
                    try { pa = DateFormat('dd/MM/yyyy').parse(ad); } catch (_) { pa = DateTime.now(); }
                  } else { pa = DateTime.now(); }
                  if (bd is Timestamp) {
                    pb = bd.toDate();
                  } else if (bd is String) {
                    try { pb = DateFormat('dd/MM/yyyy').parse(bd); } catch (_) { pb = DateTime.now(); }
                  } else { pb = DateTime.now(); }
                  return ordenarTiempoRestanteAsc ? pa.compareTo(pb) : pb.compareTo(pa);
                });
                if (visibles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No hay usuarios con equipos en uso', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: visibles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                    final doc = visibles[index];
                    final data = doc.data() as Map<String, dynamic>;
                    // final uid = (data['uid'] ?? '').toString();
                    final nombre = (data['nombre'] ?? '---').toString();
                    final dni = (data['dni'] ?? '---').toString();
                    final equipos = (data['equipos'] as List?) ?? [];
                    final equiposTexto = equipos.isEmpty ? '---' : equipos.map((e) => (e['nombre'] ?? '---').toString()).join(', ');
                    final fd = data['fecha_devolucion'];
                    // Calcular tiempo restante
                    Duration tiempo = Duration.zero;
                    DateTime? fechaLim;
                    if (fd is Timestamp) {
                      fechaLim = fd.toDate();
                    } else if (fd is String) {
                      try { fechaLim = DateFormat('dd/MM/yyyy').parse(fd); } catch (_) {}
                    }
                    if (fechaLim != null) {
                      tiempo = fechaLim.difference(DateTime.now());
                    }
                      final esExcedido = tiempo.inSeconds.isNegative;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                        border: Border.all(color: esExcedido ? Colors.red.shade200 : Colors.green.shade200, width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: esExcedido ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          child: Icon(Icons.person, color: esExcedido ? Colors.red.shade700 : Colors.green.shade700, size: 24),
                        ),
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.credit_card, size: 16, color: Colors.grey.shade600), const SizedBox(width: 8),
                              Text('DNI: $dni', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                            ]),
                                const SizedBox(height: 4),
                            Row(children: [
                              Icon(esExcedido ? Icons.warning : Icons.access_time, size: 16, color: esExcedido ? Colors.red : Colors.green),
                                    const SizedBox(width: 8),
                              Text(esExcedido ? 'Tiempo excedido' : 'Tiempo restante: ${_dias(tiempo)} días',
                                  style: TextStyle(color: esExcedido ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                            ]),
                                const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.devices, size: 16, color: Colors.grey.shade600), const SizedBox(width: 8),
                              Expanded(child: Text('Equipo(s): $equiposTexto', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.event, size: 16, color: Colors.grey.shade600), const SizedBox(width: 8),
                              Text('Devolución: ${fd is Timestamp ? DateFormat('dd/MM/yyyy').format(fd.toDate()) : (fd?.toString() ?? '---')}',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                            ]),
                          ]),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
                                child: IconButton(
                                  icon: Icon(Icons.visibility, color: Colors.blue.shade700),
                                  tooltip: 'Ver detalles',
                              onPressed: () => _mostrarDetallePrestamoDoc(doc.id),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                child: IconButton(
                                  icon: Icon(Icons.assignment_return, color: Colors.green.shade700),
                                  tooltip: 'Devolver equipo',
                              onPressed: () => _mostrarDevolverEquiposModal(doc.id),
                                ),
                              ),
                        ]),
                              ),
                            );
                          },
                      );
                    },
                  ),
          ),
        ],
      ),
        );
      },
    );
  }

  // Pestaña de Solicitudes
  Widget _buildSolicitudesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        
        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          
          // Panel de filtros
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Filtro por nombre - más compacto
                SizedBox(
                  width: 250,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (valor) {
                      setState(() {
                        filtroNombreSolicitante = valor.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Filtro por DNI
                SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar por DNI...",
                      prefixIcon: const Icon(Icons.credit_card),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (valor) {
                      setState(() {
                        filtroDni = valor.trim();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Switch de ordenamiento
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Antiguos",
                        style: TextStyle(
                          fontSize: 14,
                          color: ordenarRecientesPrimero ? Colors.grey.shade600 : Colors.orange.shade700,
                          fontWeight: ordenarRecientesPrimero ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: ordenarRecientesPrimero,
                        onChanged: (val) => setState(() => ordenarRecientesPrimero = val),
                        activeColor: Colors.orange.shade600,
                      ),
                      Text(
                        "Recientes",
                        style: TextStyle(
                          fontSize: 14,
                          color: ordenarRecientesPrimero ? Colors.orange.shade700 : Colors.grey.shade600,
                          fontWeight: ordenarRecientesPrimero ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Tabla de solicitudes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('solicitudes').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.orange.shade600),
                        const SizedBox(height: 16),
                        Text(
                          "Cargando solicitudes...",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          "Error al cargar solicitudes",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                var solicitudes = snapshot.data?.docs ?? [];

                // FILTRO POR NOMBRE DE SOLICITANTE y por DNI
                if (filtroNombreSolicitante.isNotEmpty) {
                  solicitudes = solicitudes.where((doc) {
                    final nombre = (doc['nombre'] ?? '').toString().toLowerCase();
                    return nombre.contains(filtroNombreSolicitante);
                  }).toList();
                }
                if (filtroDni.isNotEmpty) {
                  solicitudes = solicitudes.where((doc) {
                    final dni = (doc['dni'] ?? '').toString();
                    return dni.contains(filtroDni);
                  }).toList();
                }
                // ORDENAR POR FECHA ENVIO
                solicitudes.sort((a, b) {
                  final tsA = a['fecha_envio'];
                  final tsB = b['fecha_envio'];
                  DateTime dtA, dtB;
                  if (tsA is Timestamp) {
                    dtA = tsA.toDate();
                  } else {
                    dtA = DateTime.now();
                  }
                  if (tsB is Timestamp) {
                    dtB = tsB.toDate();
                  } else {
                    dtB = DateTime.now();
                  }
                  return ordenarRecientesPrimero ? dtB.compareTo(dtA) : dtA.compareTo(dtB);
                });

                return solicitudes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No hay solicitudes pendientes",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                              (states) => Colors.orange.shade50,
                            ),
                            dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                              (states) => Colors.white,
                            ),
                            border: TableBorder.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                            columns: [
                              DataColumn(
                                label: Text(
                                  "Solicitante",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                      "DNI",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      "Equipo(s)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Fecha solicitud",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                                  DataColumn(
                                    label: Text(
                                      "Fecha devolución",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Acciones",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                            rows: solicitudes.map<DataRow>((solicitud) {
                              final data = solicitud.data() as Map<String, dynamic>;
                              final nombre = data['nombre'] ?? '---';
                                  final dni = (data['dni'] ?? '---').toString();
                                  final equiposList = (data['equipos'] as List?) ?? [];
                                  final equiposTexto = equiposList.isEmpty
                                      ? '---'
                                      : equiposList.map((e) => (e['nombre'] ?? '---').toString()).join(', ');
                              final fechaEnvio = data['fecha_envio'] is Timestamp
                                  ? DateFormat('dd/MM/yyyy').format(
                                      (data['fecha_envio'] as Timestamp).toDate())
                                  : '---';
                                  final fechaDev = data['fecha_devolucion'];
                                  String fechaDevStr = '---';
                                  if (fechaDev is Timestamp) {
                                    fechaDevStr = DateFormat('dd/MM/yyyy').format(fechaDev.toDate());
                                  } else if (fechaDev is String) {
                                    fechaDevStr = fechaDev;
                                  }
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      nombre,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                          dni,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          equiposTexto,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      fechaEnvio,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                      DataCell(
                                        Text(
                                          fechaDevStr,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.visibility, color: Colors.blue.shade700),
                                            tooltip: "Visualizar",
                                            onPressed: () => _mostrarDetallesSolicitud(context, solicitud),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.check_circle, color: Colors.green.shade700),
                                            tooltip: "Aceptar",
                                            onPressed: () => _gestionarSolicitud(solicitud, "Aceptada"),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.cancel, color: Colors.red.shade700),
                                            tooltip: "Rechazar",
                                            onPressed: () => _gestionarSolicitud(solicitud, "Rechazada"),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                              ),
                            ),
                          ),
                        ),
                      );
              },
            ),
          ),
        ],
      ),
        );
      },
    );
  }

  // Mostrar detalles de la solicitud
  Future<void> _mostrarDetallesSolicitud(
      BuildContext context, QueryDocumentSnapshot solicitud) async {
    final data = solicitud.data() as Map<String, dynamic>;
    final equipos = data['equipos'] as List? ?? [];
    // final equiposList = equipos.map((e) => e['nombre']).join(', ');

    // Formatea fechas
    final fechaEnvio = data['fecha_envio'];
    String fechaEnvioStr = "---";
    if (fechaEnvio is Timestamp) {
      fechaEnvioStr = DateFormat('dd/MM/yyyy').format(fechaEnvio.toDate());
    } else if (fechaEnvio is String) {
      fechaEnvioStr = fechaEnvio;
    }

    final fechaDevolucion = data['fecha_devolucion'];
    String fechaDevolucionStr = "---";
    if (fechaDevolucion is Timestamp) {
      fechaDevolucionStr =
          DateFormat('dd/MM/yyyy').format(fechaDevolucion.toDate());
    } else if (fechaDevolucion is String) {
      fechaDevolucionStr = fechaDevolucion;
    }

    // Consulta datos extra del equipo
    String categoria = "---";
    String codigoUC = "---";
    // String descripcion = "---";
    if (equipos.isNotEmpty) {
      final equipoId = equipos[0]['id'];
      try {
        final equipoDoc = await FirebaseFirestore.instance
            .collection('equipos')
            .doc(equipoId)
            .get();
        if (equipoDoc.exists) {
          final equipoData = equipoDoc.data();
          categoria = equipoData?['categoria'] ?? "---";
          codigoUC = equipoData?['codigoUC'] ?? "---";
          // descripcion = equipoData?['descripcion'] ?? "---";
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.assignment, color: Colors.orange.shade700),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Detalles de la Solicitud',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoRow('Solicitante', data['nombre'] ?? '---', icon: Icons.person),
                  _infoRow('Apellidos', data['apellidos'] ?? '---', icon: Icons.person_outline),
                  _infoRow('DNI', (data['dni'] ?? '---').toString(), icon: Icons.credit_card),
                  _infoRow('Email', data['email'] ?? '---', icon: Icons.email),
                  _infoRow('Celular', data['celular'] ?? '---', icon: Icons.phone),
                  _infoRow('Tipo de usuario', data['tipoUsuario'] ?? '---', icon: Icons.badge),
                  const Divider(height: 24),
                  _infoRow('Asignatura', data['asignatura'] ?? '---', icon: Icons.class_),
                  _infoRow('Curso', data['curso'] ?? '---', icon: Icons.menu_book),
                  _infoRow('Docente', data['docente'] ?? '---', icon: Icons.person_pin),
                  _infoRow('Lugar', data['lugar'] ?? '---', icon: Icons.place),
                  _infoRow('Trabajo a realizar', data['trabajo'] ?? '---', icon: Icons.work_outline),
                  _infoRow('Nombre de grupo', data['nombre_grupo'] ?? '---', icon: Icons.group),
              Row(children: [
                    Expanded(child: _infoRow('Semestre', data['semestre'] ?? '---', icon: Icons.school)),
                    const SizedBox(width: 12),
                    Expanded(child: _infoRow('NRC', data['nrc'] ?? '---', icon: Icons.confirmation_number)),
                  ]),
                  const Divider(height: 24),
                  _infoRow('Fecha de entrega', data['fecha_prestamo']?.toString() ?? '---', icon: Icons.event),
                  _infoRow('Fecha de devolución', fechaDevolucionStr, icon: Icons.event_available),
                  _infoRow('Fecha de envío', fechaEnvioStr, icon: Icons.send_time_extension),
                  const SizedBox(height: 8),
                  Text('Integrantes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const SizedBox(height: 6),
                  Builder(builder: (_) {
                    final integrantes = (data['integrantes'] as List?)?.cast<String>() ?? const [];
                    if (integrantes.isEmpty) {
                      return Text('Único integrante: solicitante', style: TextStyle(color: Colors.grey.shade700));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: integrantes
                          .asMap()
                          .entries
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('${e.key + 2}. DNI: ${e.value}', style: TextStyle(color: Colors.grey.shade800)),
                              ))
                          .toList(),
                    );
                  }),
                  const Divider(height: 24),
                  Text('Equipos solicitados', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Column(
                      children: equipos.map((e) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: const Icon(Icons.devices_other, color: Colors.orange),
                          title: Text(e['nombre'] ?? '---', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              if ((e['descripcion'] ?? '').toString().isNotEmpty) (e['descripcion']).toString(),
                              if (categoria != '---') 'Categoría: $categoria',
                              if (codigoUC != '---') 'Código UC: $codigoUC',
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
            ),
          ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Mostrar detalle desde doc de 'usuarios_con_equipos' en modal profesional
  Future<void> _mostrarDetallePrestamoDoc(String docId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('usuarios_con_equipos').doc(docId).get();
      if (!snap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el detalle.')));
        }
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final equipos = (data['equipos'] as List?) ?? [];
      final integrantes = (data['integrantes'] as List?)?.cast<String>() ?? const [];
      String fechaPrestamoStr = (data['fecha_prestamo'] ?? '---').toString();
      String fechaDevolucionStr;
      final fd = data['fecha_devolucion'];
      if (fd is Timestamp) {
        fechaDevolucionStr = DateFormat('dd/MM/yyyy').format(fd.toDate());
      } else {
        fechaDevolucionStr = (fd ?? '---').toString();
      }

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
              Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.assignment_turned_in, color: Colors.green.shade700),
                      ),
                      const SizedBox(width: 12),
                      const Text('Detalle de Préstamo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 16),
                    _infoRow('Solicitante', (data['nombre'] ?? '---').toString(), icon: Icons.person),
                    _infoRow('Apellidos', (data['apellidos'] ?? '---').toString(), icon: Icons.person_outline),
                    _infoRow('DNI', (data['dni'] ?? '---').toString(), icon: Icons.credit_card),
                    _infoRow('Email', (data['email'] ?? '---').toString(), icon: Icons.email),
                    _infoRow('Celular', (data['celular'] ?? '---').toString(), icon: Icons.phone),
                    const Divider(height: 24),
                    _infoRow('Asignatura', (data['asignatura'] ?? '---').toString(), icon: Icons.class_),
                    _infoRow('Curso', (data['curso'] ?? '---').toString(), icon: Icons.menu_book),
                    _infoRow('Docente', (data['docente'] ?? '---').toString(), icon: Icons.person_pin),
                    _infoRow('Lugar', (data['lugar'] ?? '---').toString(), icon: Icons.place),
                    _infoRow('Trabajo a realizar', (data['trabajo'] ?? '---').toString(), icon: Icons.work_outline),
                    _infoRow('Nombre de grupo', (data['nombre_grupo'] ?? '---').toString(), icon: Icons.group),
              Row(children: [
                      Expanded(child: _infoRow('Semestre', (data['semestre'] ?? '---').toString(), icon: Icons.school)),
                      const SizedBox(width: 12),
                      Expanded(child: _infoRow('NRC', (data['nrc'] ?? '---').toString(), icon: Icons.confirmation_number)),
                    ]),
                    const Divider(height: 24),
                    _infoRow('Fecha de préstamo', fechaPrestamoStr, icon: Icons.event),
                    _infoRow('Fecha de devolución', fechaDevolucionStr, icon: Icons.event_available),
                    const SizedBox(height: 8),
                    Text('Integrantes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 6),
                    if (integrantes.isEmpty)
                      Text('Único integrante: solicitante', style: TextStyle(color: Colors.grey.shade700))
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: integrantes
                            .asMap()
                            .entries
                            .map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('${e.key + 2}. DNI: ${e.value}', style: TextStyle(color: Colors.grey.shade800)),
                                ))
                            .toList(),
                      ),
                    const Divider(height: 24),
                    Text('Equipos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade100)),
                      child: Column(
                        children: equipos.map((e) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            leading: const Icon(Icons.devices_other, color: Colors.green),
                            title: Text((e['nombre'] ?? '---').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text((e['descripcion'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
                    ])
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar detalle: $e')));
      }
    }
  }

  // Modal para devolver equipos uno por uno con condición/estado
  Future<void> _mostrarDevolverEquiposModal(String docId) async {
    final docRef = FirebaseFirestore.instance.collection('usuarios_con_equipos').doc(docId);
    final snap = await docRef.get();
    if (!snap.exists) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el préstamo.')));
      return;
    }
    final data = snap.data() as Map<String, dynamic>;
    final uid = (data['uid'] ?? '').toString();
    final equipos = (data['equipos'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final integrantes = (data['integrantes'] as List?)?.cast<String>() ?? const [];
    final fd = data['fecha_devolucion'];
    final fechaDevolucionStr = fd is Timestamp ? DateFormat('dd/MM/yyyy').format(fd.toDate()) : (fd?.toString() ?? '');

    // Estados locales para edición por equipo
    final condiciones = ['Nuevo', 'Bueno', 'Regular', 'Defectuoso'];

    final editedEquipos = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
              Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.assignment_return, color: Colors.red.shade700),
                      ),
                      const SizedBox(width: 12),
                      const Text('Devolver equipos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    ...equipos.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final eq = entry.value;
                      final nombre = (eq['nombre'] ?? '---').toString();
                      String condicion = (eq['condicion'] ?? 'Bueno').toString();
                      String estado = (eq['estado'] ?? 'Disponible').toString();
                      // Sin interacción del usuario, asegurar que los valores visibles queden persistidos
                      if (equipos[idx]['condicion'] == null) {
                        equipos[idx]['condicion'] = condicion;
                      }
                      if (equipos[idx]['estado'] == null) {
                        // Si la condición es Defectuoso, forzar Mantenimiento
                        equipos[idx]['estado'] = condicion == 'Defectuoso' ? 'Mantenimiento' : estado;
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
              Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: condicion,
                                  items: condiciones.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  decoration: const InputDecoration(labelText: 'Condición', border: OutlineInputBorder()),
                                  onChanged: (val) {
                                    setState(() {
                                      condicion = val ?? condicion;
                                      equipos[idx]['condicion'] = condicion;
                                      if (condicion == 'Defectuoso') {
                                        estado = 'Mantenimiento';
                                        equipos[idx]['estado'] = estado;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: estado,
                                  items: <String>['Disponible', 'Mantenimiento']
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                                  onChanged: (val) {
                                    setState(() {
                                      estado = val ?? estado;
                                      // Si es defectuoso debe ir a mantenimiento
                                      if ((equipos[idx]['condicion'] ?? '') == 'Defectuoso') {
                                        estado = 'Mantenimiento';
                                      }
                                      equipos[idx]['estado'] = estado;
                                    });
                                  },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                          ]),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancelar')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Persistir por si algún item quedó sin tocar: normalizar estados respecto a condición
                            final snapshotEquipos = List<Map<String, dynamic>>.from(equipos.map((e) {
                              final cond = (e['condicion'] ?? 'Bueno').toString();
                              final est = (e['estado'] ?? 'Disponible').toString();
                              return {
                                ...e,
                                'condicion': cond,
                                'estado': cond == 'Defectuoso' ? 'Mantenimiento' : est,
                              };
                            }));
                            Navigator.of(context).pop(snapshotEquipos);
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Devolver equipos'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
    );

    if (editedEquipos == null) {
      return;
    }

    // Confirmación final antes de ejecutar
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar devolución'),
        content: const Text('¿Deseas guardar los cambios y devolver los equipos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok != true) {
      // Reabrir modal si el usuario decide no confirmar
      await _mostrarDevolverEquiposModal(docId);
      return;
    }

    // Ejecutar devolución de todos los equipos editados sin más interacción
    for (var i = 0; i < editedEquipos.length; i++) {
      final eq = editedEquipos[i];
      final equipoId = (eq['id'] ?? '').toString();
      if (equipoId.isEmpty) continue;
      final condicionSel = (eq['condicion'] ?? 'Bueno').toString();
      final estadoSel = condicionSel == 'Defectuoso'
          ? 'Mantenimiento'
          : ((eq['estado'] ?? 'Disponible').toString());
      await FirebaseFirestore.instance.collection('equipos').doc(equipoId).update({
        'estado': estadoSel,
        'condicion': condicionSel,
      });
      await _devolverEquipo(
        equipoId,
        uid,
        integrantesDnis: integrantes,
        fechaDevolucionStr: fechaDevolucionStr,
      );
    }

    // Borra el documento completo de usuarios_con_equipos tras devolver todo
    await docRef.delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devolución completada.')));
    }
  }

  Widget _infoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 180,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? '---' : value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Future<void> _gestionarSolicitud(
      QueryDocumentSnapshot solicitud, String accion) async {
    setState(() => _procesandoSolicitud = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("No estás autenticado. Inicia sesión nuevamente.")),
        );
        return;
      }

      final diasPrestamo = (solicitud['dias_prestamo'] ?? 2)
          as int; // 2 como valor por defecto si no existe

      // Verifica que el usuario es gestor
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null || userData['rol'] != "gestor") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("No tienes permisos para gestionar esta solicitud.")),
        );
        return;
      }

      // final fechaPrestamo = DateTime.now();
      // final fechaDevolucion = fechaPrestamo.add(Duration(days: diasPrestamo));

      final equipos = solicitud['equipos'] as List;
      final uidSolicitante = solicitud['uid'] as String;

      // Si se acepta: persistir en usuarios_con_equipos
      if (accion == "Aceptada") {
        final dataSolicitud = solicitud.data() as Map<String, dynamic>;
        await FirebaseFirestore.instance.collection('usuarios_con_equipos').add({
          ...dataSolicitud,
        });
      }

      for (var equipo in equipos) {
        // Fecha de solicitud (del campo 'fecha_envio' de la solicitud)
        dynamic fechaSolicitud = solicitud['fecha_envio'];
        DateTime? dtSolicitud;
        if (fechaSolicitud is Timestamp) {
          dtSolicitud = fechaSolicitud.toDate();
        } else if (fechaSolicitud is String) {
          try {
            dtSolicitud = DateTime.parse(fechaSolicitud);
          } catch (_) {}
        }

        // Fechas
        final fechaPrestamoNow = DateTime.now();
        final fechaDevolucionNow =
            fechaPrestamoNow.add(Duration(days: diasPrestamo));
        final fechaPrestamoStr =
            DateFormat('dd/MM/yyyy').format(fechaPrestamoNow);
        final fechaDevolucionStr =
            DateFormat('dd/MM/yyyy').format(fechaDevolucionNow);

        // ACTUALIZA LA COLECCIÓN GLOBAL EQUIPOS
        await FirebaseFirestore.instance
            .collection('equipos')
            .doc(equipo['id'])
            .update({
          'estado': accion == "Aceptada" ? "En Uso" : "Disponible",
          if (accion == "Aceptada") ...{
            'fecha_solicitud': dtSolicitud != null
                ? DateFormat('dd/MM/yyyy').format(dtSolicitud)
                : null,
            'fecha_prestamo': fechaPrestamoStr,
            'fecha_devolucion': fechaDevolucionStr,
          },
          if (accion == "Rechazada") ...{
            'fecha_solicitud': null,
            'fecha_prestamo': null,
            'fecha_devolucion': null,
          },
        });

        // ACTUALIZA LA SUBCOLECCIÓN DEL USUARIO
        final docRef = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uidSolicitante)
            .collection('equipos_a_cargo')
            .doc(equipo['id']);

        if (accion == "Aceptada") {
          await docRef.update({
            'estado_prestamo': "En uso",
            'fecha_prestamo': fechaPrestamoStr,
            'fecha_devolucion': fechaDevolucionStr,
          });
        } else if (accion == "Rechazada") {
          await docRef.delete();
        }
      }

      await solicitud.reference.delete();

      final data = solicitud.data() as Map<String, dynamic>;
      final emailUsuario = data['email'] ?? "";
      await _enviarCorreoNotificacion(emailUsuario, accion, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Solicitud $accion."),
            backgroundColor: accion == "Aceptada" ? Colors.green : Colors.red,
          ),
        );
      }

      // Recarga usuarios si quieres refrescar la pantalla de inmediato
      await obtenerUsuarios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al procesar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoSolicitud = false);
    }
  }
}

// Widget para los botones de la barra lateral mejorado
class _SidebarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                });
                widget.onTap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  vertical: 16, 
                  horizontal: widget.collapsed ? 8 : 16
                ),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? const Color(0xFFEFF6FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: widget.selected
                      ? Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 2,
                        )
                      : null,
                ),
                child: widget.collapsed
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.selected
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    : Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.selected
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF94A3B8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                color: widget.selected
                                    ? const Color(0xFF1E40AF)
                                    : const Color(0xFF475569),
                                fontWeight: widget.selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (widget.selected)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}