import 'package:app_comu/screens/gestion_estudiantes_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'detalle_prestamo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // si usas Google Sign-In
import '../main.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
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

  @override
  void initState() {
    super.initState();
    obtenerUsuarios();
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
          if (equipoId == null || equipoId.isEmpty) continue;

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

  // Método para enviar correo de notificación al estudiante
  Future<void> _enviarCorreoNotificacion(String destinatario, String estado,
      Map<String, dynamic> solicitud) async {
    // Configura tu correo SMTP (Gmail en este ejemplo)
    String username = 'kenss12345@gmail.com'; // Reemplaza por tu correo Gmail
    String password =
        'qsex cejw glnq namr'; // Contraseña de aplicación de Gmail

    final smtpServer = gmail(username, password);

    // Construir el contenido del correo
    String contenidoEquipos = (solicitud['equipos'] as List)
        .map((e) => "- ${e['nombre']}")
        .join("\n");

    final message = Message()
      ..from = Address(username, 'Soporte Audiovisual')
      ..recipients.add(destinatario)
      ..subject = 'Estado de tu solicitud de préstamo - $estado'
      ..text = '''
  Hola ${solicitud['nombre']},

  Tu solicitud de préstamo ha sido $estado.

  Detalles de tu solicitud:
  - Asignatura: ${solicitud['asignatura']}
  - Trabajo a realizar: ${solicitud['trabajo']}
  - Docente: ${solicitud['docente']}
  - Lugar: ${solicitud['lugar']}
  - Fecha de entrega: ${solicitud['fecha_prestamo']}
  - Fecha de devolución: ${solicitud['fecha_devolucion']}
  - Hora de salida: ${solicitud['hora_salida']}

  Equipos solicitados:
  $contenidoEquipos

  Gracias por utilizar nuestro sistema.

  Atentamente,
  Soporte Audiovisual
  ''';

    try {
      final sendReport = await send(message, smtpServer);
      print('Correo enviado: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('Fallo al enviar correo: $e');
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
                  // Barra lateral mejorada - responsive
                  if (!isMobile) ...[
                    Container(
                      width: isTablet ? 250 : 300,
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
                          // Header del contenido mejorado - responsive
                          Container(
                            padding: EdgeInsets.all(isMobile ? 16 : 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(isMobile ? 16 : 24),
                                topRight: Radius.circular(isMobile ? 16 : 24),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: isMobile 
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: _selectedSection == 0
                                                  ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                                  : _selectedSection == 1
                                                      ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                                                      : _selectedSection == 2
                                                          ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
                                                          : [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            _selectedSection == 0
                                                ? Icons.people_alt
                                                : _selectedSection == 1
                                                    ? Icons.assignment_turned_in
                                                    : _selectedSection == 2
                                                        ? Icons.school
                                                        : Icons.devices,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedSection == 0
                                                ? 'Usuarios con Equipos'
                                                : _selectedSection == 1
                                                    ? 'Solicitudes'
                                                    : _selectedSection == 2
                                                        ? 'Gestionar Estudiantes'
                                                        : 'Gestionar Equipos',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedSection == 0
                                          ? 'Gestiona los préstamos activos de equipos'
                                          : _selectedSection == 1
                                              ? 'Revisa y aprueba solicitudes de préstamo'
                                              : _selectedSection == 2
                                                  ? 'Administra la información de estudiantes'
                                                  : 'Administra la información de equipos',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_selectedSection == 0 || _selectedSection == 1) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F9FF),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFF0EA5E9),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0EA5E9),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Tiempo Real',
                                              style: TextStyle(
                                                color: const Color(0xFF0EA5E9),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _selectedSection == 0
                                              ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                              : _selectedSection == 1
                                                  ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                                                  : _selectedSection == 2
                                                      ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
                                                      : [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _selectedSection == 0
                                            ? Icons.people_alt
                                            : _selectedSection == 1
                                                ? Icons.assignment_turned_in
                                                : _selectedSection == 2
                                                    ? Icons.school
                                                    : Icons.devices,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedSection == 0
                                                ? 'Usuarios con Equipos'
                                                : _selectedSection == 1
                                                    ? 'Solicitudes'
                                                    : _selectedSection == 2
                                                        ? 'Gestionar Estudiantes'
                                                        : 'Gestionar Equipos',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          Text(
                                            _selectedSection == 0
                                                ? 'Gestiona los préstamos activos de equipos'
                                                : _selectedSection == 1
                                                    ? 'Revisa y aprueba solicitudes de préstamo'
                                                    : _selectedSection == 2
                                                        ? 'Administra la información de estudiantes'
                                                        : 'Administra la información de equipos',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_selectedSection == 0 || _selectedSection == 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F9FF),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: const Color(0xFF0EA5E9),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0EA5E9),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Tiempo Real',
                                              style: TextStyle(
                                                color: const Color(0xFF0EA5E9),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                          ),
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
      child: Column(
        children: [
          // Header de la barra lateral mejorado
          Container(
            padding: const EdgeInsets.all(28),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
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
            ),
          ),
          // Menú de navegación mejorado
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              children: [
                _SidebarButton(
                  icon: Icons.people_alt,
                  label: 'Usuarios con Equipos',
                  selected: _selectedSection == 0,
                  onTap: () => setState(() => _selectedSection = 0),
                ),
                const SizedBox(height: 12),
                _SidebarButton(
                  icon: Icons.assignment_turned_in,
                  label: 'Solicitudes',
                  selected: _selectedSection == 1,
                  onTap: () => setState(() => _selectedSection = 1),
                ),
                const SizedBox(height: 12),
                _SidebarButton(
                  icon: Icons.school,
                  label: 'Gestionar Estudiantes',
                  selected: _selectedSection == 2,
                  onTap: () => setState(() => _selectedSection = 2),
                ),
                const SizedBox(height: 12),
                _SidebarButton(
                  icon: Icons.devices,
                  label: 'Gestionar Equipos',
                  selected: _selectedSection == 3,
                  onTap: () => setState(() => _selectedSection = 3),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Botón Cerrar Sesión mejorado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              child: ElevatedButton.icon(
                onPressed: () => _mostrarConfirmacionCerrarSesion(),
                icon: Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                label: Text(
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
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
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
                  child: Icon(
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
        ],
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

  Future<void> _devolverEquipo(String equipoId, String userId) async {
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipo devuelto correctamente.')),
      );
      await obtenerUsuarios(); // refresca la lista
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
              // Header de la sección - responsive
              isMobile 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.people, color: Colors.orange.shade700, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Usuarios con Equipos",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  "Gestiona los préstamos activos",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "${estudiantesFiltrados.length} usuarios activos",
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.people, color: Colors.orange.shade700, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Usuarios con Equipos",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            "Gestiona los préstamos activos",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "${estudiantesFiltrados.length} usuarios activos",
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          SizedBox(height: isMobile ? 16 : 24),
          
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
                Text(
                  "Filtros y Búsqueda",
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
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
                        // Filtro por nombre
                        Expanded(
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
                          width: 200,
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
                      ],
                    ),
                if (!isMobile) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Ordenar por tiempo restante
                      Text(
                        "Ordenar por: ",
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
                              child: Text("Tiempo restante ↑"),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text("Tiempo restante ↓"),
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
                      const SizedBox(width: 24),
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
                            "Mostrar solo excedidos",
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Lista de usuarios
          Expanded(
            child: estudiantesFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No hay usuarios con equipos en uso",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: estudiantesFiltrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final estudiante = estudiantesFiltrados[index];
                      final tiempo = estudiante['tiempo_restante'] as Duration;
                      final esExcedido = tiempo.inSeconds.isNegative;

                      return Container(
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
                          border: Border.all(
                            color: esExcedido ? Colors.red.shade200 : Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: esExcedido ? Colors.red.shade100 : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person,
                              color: esExcedido ? Colors.red.shade700 : Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            estudiante['nombre'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.credit_card, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      "DNI: ${estudiante['dni'] ?? '---'}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      esExcedido ? Icons.warning : Icons.access_time,
                                      size: 16,
                                      color: esExcedido ? Colors.red : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      esExcedido
                                          ? "Tiempo excedido: ${(-_dias(estudiante['tiempo_restante'])).toString()} días"
                                          : "Tiempo restante: ${(_dias(estudiante['tiempo_restante'])).toString()} días",
                                      style: TextStyle(
                                        color: esExcedido ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.event, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Devolución: ${estudiante['fechaDevolucion'] ?? '---'}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botón Ver Detalles
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.visibility, color: Colors.blue.shade700),
                                  tooltip: 'Ver detalles',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetallePrestamoScreen(
                                          estudiante: estudiante,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botón Devolver Equipo
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.assignment_return, color: Colors.green.shade700),
                                  tooltip: 'Devolver equipo',
                                  onPressed: () async {
                                    final confirmar = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        title: Row(
                                          children: [
                                            Icon(Icons.assignment_return, color: Colors.green.shade700),
                                            const SizedBox(width: 8),
                                            const Text('Devolver equipo'),
                                          ],
                                        ),
                                        content: const Text(
                                          '¿Estás seguro de devolver este equipo? Esta acción no se puede deshacer.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade700,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Devolver'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmar == true) {
                                      if (estudiante['equipoId'] != null && estudiante['id'] != null) {
                                        await _devolverEquipo(estudiante['equipoId'], estudiante['id']);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('No se encontró el ID del equipo.'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetallePrestamoScreen(estudiante: estudiante),
                              ),
                            );
                          },
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

  // Pestaña de Solicitudes
  Widget _buildSolicitudesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        
        return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la sección
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment, color: Colors.orange.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Solicitudes Pendientes",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    "Gestiona las solicitudes de préstamo",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
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
          const SizedBox(height: 24),
          
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
                // Filtro por nombre
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre del solicitante...",
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
                SizedBox(
                  width: 200,
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
                    : Container(
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
                                  "Equipo",
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
                              final equipo = data['equipos']?[0]?['nombre'] ?? '---';
                              final fechaEnvio = data['fecha_envio'] is Timestamp
                                  ? DateFormat('dd/MM/yyyy').format(
                                      (data['fecha_envio'] as Timestamp).toDate())
                                  : '---';
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
                                      equipo,
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Botón Visualizar
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
                                        // Botón Aceptar
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
                                        // Botón Rechazar
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
    final equiposList = equipos.map((e) => e['nombre']).join(', ');

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
    String descripcion = "---";
    if (equipos.isNotEmpty && equipos[0]?['id'] != null) {
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
          descripcion = equipoData?['descripcion'] ?? "---";
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Detalles de la Solicitud"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.person, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text("Nombre: ", style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text(data['nombre'] ?? '---')),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.devices, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text("Equipo(s): ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text(equiposList)),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.event, color: Colors.orange),
                SizedBox(width: 8),
                Text("Fecha solicitud: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text(fechaEnvioStr)),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.event_available, color: Colors.green),
                SizedBox(width: 8),
                Text("Fecha devolución: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text(fechaDevolucionStr)),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.category, color: Colors.brown),
                SizedBox(width: 8),
                Text("Categoría: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text(categoria)),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.qr_code, color: Colors.black45),
                SizedBox(width: 8),
                Text("Código UC: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text(codigoUC)),
              ]),
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.description, color: Colors.teal),
                SizedBox(width: 8),
                Text("Descripción: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Flexible(child: Text(descripcion)),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cerrar"),
            ),
          ],
        );
      },
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

      final fechaPrestamo = DateTime.now();
      final fechaDevolucion = fechaPrestamo.add(Duration(days: diasPrestamo));
      final fechaDevolucionStr =
          DateFormat('dd/MM/yyyy').format(fechaDevolucion);
      final fechaDevolucionTS = Timestamp.fromDate(fechaDevolucion);

      final equipos = solicitud['equipos'] as List;
      final uidSolicitante = solicitud['uid'] as String;

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
  final VoidCallback onTap;
  
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                child: Row(
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