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

  @override
  void initState() {
    super.initState();
    obtenerUsuarios();
  }

  Future<void> obtenerUsuarios() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('TieneEquipo', isEqualTo: true)
        .get();

    final lista = snapshot.docs.map((doc) {
      final data = doc.data();
      final tiempoRestante = calcularTiempoRestante(data['fechaDevolucion']);
      return {
        'id': doc.id,
        'nombre': data['nombre'],
        'email': data['email'],
        'celular': data['celular'],
        'equipo': data['equipo'] ?? 'Equipo no registrado',
        'tiempo_restante': tiempoRestante,
        'fechaDevolucion': data['fechaDevolucion'],
      };
    }).toList();

    setState(() {
      estudiantes = lista;
      aplicarFiltros();
    });
  }

  // Método para enviar correo de notificación al estudiante
  Future<void> _enviarCorreoNotificacion(String destinatario, String estado, Map<String, dynamic> solicitud) async {
    // Configura tu correo SMTP (Gmail en este ejemplo)
    String username = 'tu_correo@gmail.com'; // Reemplaza por tu correo Gmail
    String password = 'tu_contraseña_de_aplicación'; // Contraseña de aplicación de Gmail

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
  /*Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
      title: const Text('Usuarios con Equipos'),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar sesión',
          onPressed: () async {
            //Desconectar Google (si procede)
            final googleSignIn = GoogleSignIn();
            if (await googleSignIn.isSignedIn()) {
              await googleSignIn.signOut();
            }
            //Cerrar sesión de Firebase
            await FirebaseAuth.instance.signOut();
            //Reiniciar el stack y volver a AuthWrapper
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
          },
        ),
      ],
    ),
      body: Column(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                icon: Icon(filtrarMenosDe5Horas ? Icons.filter_alt : Icons.filter_alt_outlined),
                label: const Text("Menos de 5h"),
                onPressed: () {
                  filtrarMenosDe5Horas = !filtrarMenosDe5Horas;
                  aplicarFiltros();
                },
              ),
            ],
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
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MapaScreen()));
            },
            child: const Text("Ver Mapa General"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }*/

  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
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
                subtitle: Text("Asignatura: ${data['asignatura']}"),
                trailing: Text(data['hora_salida'] ?? "Sin hora"),
                onTap: () => _mostrarDetallesSolicitud(context, solicitud),
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Detalles de la Solicitud"),
          content: Text("Asignatura: ${data['asignatura']}\nLugar: ${data['lugar']}"),
          actions: [
            TextButton(
              onPressed: () => _gestionarSolicitud(solicitud, "Aceptada"),
              child: const Text("Aceptar"),
            ),
            TextButton(
              onPressed: () => _gestionarSolicitud(solicitud, "Rechazada"),
              child: const Text("Rechazar"),
            ),
          ],
        );
      },
    );
  }

  // Gestionar solicitud (Aceptar o Rechazar)
  /*Future<void> _gestionarSolicitud(QueryDocumentSnapshot solicitud, String accion) async {
    final equipos = solicitud['equipos'] as List;
    for (var equipo in equipos) {
      await FirebaseFirestore.instance.collection('equipos').doc(equipo['id']).update({
        'estado': accion == "Aceptada" ? "En Uso" : "Disponible",
      });
    }

    // Enviar correo al usuario que realizó la solicitud
    final data = solicitud.data() as Map<String, dynamic>;
    final emailUsuario = data['email'] ?? "";
    await _enviarCorreoNotificacion(emailUsuario, accion, data);

    await solicitud.reference.delete(); // Elimina la solicitud

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Solicitud $accion.")),
    );
  }*/
    Future<void> _gestionarSolicitud(QueryDocumentSnapshot solicitud, String accion) async {
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

    // Ahora gestiona la solicitud
    final equipos = solicitud['equipos'] as List;
    final uidSolicitante = solicitud['uid'] as String;

    for (var equipo in equipos) {
      // Cambia el estado global
      await FirebaseFirestore.instance.collection('equipos').doc(equipo['id']).update({
        'estado': accion == "Aceptada" ? "En Uso" : "Disponible",
      });

      // Cambia el estado en la subcolección del usuario
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidSolicitante)
          .collection('equipos_a_cargo')
          .doc(equipo['id'])
          .update({
        'estado_prestamo': accion == "Aceptada" ? "En Uso" : "Disponible",
      });

    }

    await solicitud.reference.delete(); // Elimina la solicitud

    // Enviar correo al usuario que realizó la solicitud
    final data = solicitud.data() as Map<String, dynamic>;
    final emailUsuario = data['email'] ?? "";
    await _enviarCorreoNotificacion(emailUsuario, accion, data);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Solicitud $accion.")),
    );
  }

}
