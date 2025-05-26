import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'detalle_prestamo_screen.dart';
import 'mapa_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';      // si usas Google Sign-In
import '../main.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class UsuariosConEquiposScreen extends StatefulWidget {
  const UsuariosConEquiposScreen({super.key});

  @override
  State<UsuariosConEquiposScreen> createState() => _UsuariosConEquiposScreenState();
}

class _UsuariosConEquiposScreenState extends State<UsuariosConEquiposScreen> {
  List<Map<String, dynamic>> estudiantes = [];
  List<Map<String, dynamic>> estudiantesFiltrados = [];
  String filtroNombre = "";
  bool filtrarMenosDe5Horas = false;
  bool _procesandoSolicitud = false;


  @override
  void initState() {
    super.initState();
    obtenerUsuarios();
  }

  Future<void> obtenerUsuarios() async {

     // 1. Obtener todos los usuarios
    final usuariosSnap = await FirebaseFirestore.instance.collection('usuarios').get();

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
        final equipo = equiposACargoSnap.docs.first.data();
        // Calcula tiempo restante si tienes fechas en el doc
        DateTime? fechaDevolucion;
        if (equipo['fecha_devolucion'] != null) {
          try {
            fechaDevolucion = DateTime.parse(equipo['fecha_devolucion']);
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
          'equipo': equipo['nombre'] ?? 'Equipo no registrado',
          'tiempo_restante': tiempoRestante,
          'fechaDevolucion': equipo['fecha_devolucion'],
        });
      }
    }
    setState(() {
      estudiantes = lista;
      aplicarFiltros();
    });
  }

  // Método para enviar correo de notificación al estudiante
  Future<void> _enviarCorreoNotificacion(String destinatario, String estado, Map<String, dynamic> solicitud) async {
    // Configura tu correo SMTP (Gmail en este ejemplo)
    String username = 'kenss12345@gmail.com'; // Reemplaza por tu correo Gmail
    String password = 'qsex cejw glnq namr'; // Contraseña de aplicación de Gmail

    final smtpServer = gmail(username, password);

    // Construir el contenido del correo
    String contenidoEquipos = (solicitud['equipos'] as List).map((e) => "- ${e['nombre']}").join("\n");

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
    setState(() {
      estudiantesFiltrados = estudiantes.where((est) {
        final nombreMatch = est['nombre'].toLowerCase().contains(filtroNombre.toLowerCase());
        final tiempo = est['tiempo_restante'] as Duration;
        final tiempoMatch = !filtrarMenosDe5Horas || (tiempo > Duration.zero && tiempo < Duration(hours: 5));
        return nombreMatch && tiempoMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Gestión de Equipos'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar sesión',
                  onPressed: () => _mostrarConfirmacionCerrarSesion(),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: "Usuarios con Equipos"),
                  Tab(text: "Solicitudes"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildUsuariosConEquiposTab(),
                _buildSolicitudesTab(),
              ],
            ),
          ),
        ),
        if (_procesandoSolicitud)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 24),
                      Text(
                        "Procesando solicitud...",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
              onPressed: () => Navigator.of(context).pop(), // Cerrar el diálogo sin hacer nada
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

  // Pestaña de Usuarios con Equipos
  Widget _buildUsuariosConEquiposTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: "Buscar por nombre...",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (valor) {
              filtroNombre = valor;
              aplicarFiltros();
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: estudiantesFiltrados.length,
            itemBuilder: (context, index) {
              final estudiante = estudiantesFiltrados[index];
              final tiempo = estudiante['tiempo_restante'] as Duration;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(estudiante['nombre']),
                  subtitle: Text(
                    tiempo.inSeconds.isNegative
                        ? "Tiempo excedido: ${-tiempo.inHours}h ${-tiempo.inMinutes.remainder(60)}m"
                        : "Tiempo restante: ${tiempo.inHours}h ${tiempo.inMinutes.remainder(60)}m",
                    style: TextStyle(
                      color: tiempo.inSeconds.isNegative ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
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
    );
  }

  // Pestaña de Solicitudes
  Widget _buildSolicitudesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('solicitudes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar solicitudes."));
        }

        final solicitudes = snapshot.data?.docs ?? [];
        return ListView.builder(
          itemCount: solicitudes.length,
          itemBuilder: (context, index) {
            final solicitud = solicitudes[index];
            final data = solicitud.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(data['nombre'] ?? "Sin nombre"),
                subtitle: Text("Equipo: ${data['equipos']?[0]?['nombre'] ?? '---'}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.visibility, color: Colors.blue),
                      tooltip: "Visualizar",
                      onPressed: () => _mostrarDetallesSolicitud(context, solicitud),
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      tooltip: "Aceptar",
                      onPressed: () => _gestionarSolicitud(solicitud, "Aceptada"),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      tooltip: "Rechazar",
                      onPressed: () => _gestionarSolicitud(solicitud, "Rechazada"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Mostrar detalles de la solicitud
  void _mostrarDetallesSolicitud(BuildContext context, QueryDocumentSnapshot solicitud) {
    final data = solicitud.data() as Map<String, dynamic>;
    final equipos = data['equipos'] as List? ?? [];
    final equiposList = equipos.map((e) => e['nombre']).join(', ');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Detalles de la Solicitud"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Nombre: ${data['nombre']}"),
              Text("Equipo(s): $equiposList"),
              Text("Fecha/hora de solicitud: ${data['fecha_envio'] != null && data['fecha_envio'] is Timestamp ? (data['fecha_envio'] as Timestamp).toDate().toString() : '---'}"),
              Text("Fecha/hora de devolución: ${data['fecha_devolucion'] ?? '---'}"),
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

    Future<void> _gestionarSolicitud(QueryDocumentSnapshot solicitud, String accion) async {
      setState(() => _procesandoSolicitud = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No estás autenticado. Inicia sesión nuevamente.")),
          );
          return;
        }

        // Verifica que el usuario es gestor
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        if (userData == null || userData['rol'] != "gestor") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No tienes permisos para gestionar esta solicitud.")),
          );
          return;
        }

        final equipos = solicitud['equipos'] as List;
        final uidSolicitante = solicitud['uid'] as String;

        for (var equipo in equipos) {
          await FirebaseFirestore.instance.collection('equipos').doc(equipo['id']).update({
            'estado': accion == "Aceptada" ? "En Uso" : "Disponible",
            if (accion == "Aceptada")
              'fecha_devolucion': solicitud['fecha_devolucion'],
            if (accion == "Rechazada")
              'fecha_devolucion': null,
          });

          final docRef = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uidSolicitante)
            .collection('equipos_a_cargo')
            .doc(equipo['id']);

          if (accion == "Aceptada") {
            await docRef.update({
              'estado_prestamo': "En uso",
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