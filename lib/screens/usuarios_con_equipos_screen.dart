import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'detalle_prestamo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // si usas Google Sign-In
import '../main.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:intl/intl.dart';

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
    return Stack(
      children: [
        Container(color: const Color(0xFFF7F7FA)), // Fondo suave
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
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 900),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.deepOrange, size: 32),
                  const SizedBox(width: 14),
                  Text(
                    "Usuarios con equipos en uso",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Filtro por nombre
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Buscar por nombre...",
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (valor) {
                            filtroNombre = valor;
                            aplicarFiltros();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filtro por DNI
                      SizedBox(
                        width: 180,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Buscar por DNI...",
                            prefixIcon: const Icon(Icons.credit_card),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Ordenar por tiempo restante
                      const Text("Ordenar por: "),
                      DropdownButton<bool>(
                        value: ordenarTiempoRestanteAsc,
                        items: const [
                          DropdownMenuItem(
                              value: true, child: Text("Tiempo restante asc")),
                          DropdownMenuItem(
                              value: false,
                              child: Text("Tiempo restante desc")),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            ordenarTiempoRestanteAsc = val;
                            aplicarFiltros();
                          });
                        },
                      ),
                      const SizedBox(width: 18),
                      // Filtrar solo excedidos
                      Checkbox(
                        value: mostrarSoloExcedidos,
                        onChanged: (val) {
                          setState(() {
                            mostrarSoloExcedidos = val ?? false;
                            aplicarFiltros();
                          });
                        },
                      ),
                      const Text("Mostrar solo excedidos"),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: estudiantesFiltrados.isEmpty
                    ? const Center(
                        child: Text("No hay usuarios con equipos en uso."))
                    : ListView.separated(
                        itemCount: estudiantesFiltrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final estudiante = estudiantesFiltrados[index];
                          final tiempo =
                              estudiante['tiempo_restante'] as Duration;

                          return Card(
                            color: tiempo.inSeconds.isNegative
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            child: ListTile(
                              leading: const Icon(Icons.person,
                                  size: 38, color: Colors.blueGrey),
                              title: Text(estudiante['nombre'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "DNI: ${estudiante['dni'] ?? '---'}",
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[700]),
                                    ),
                                    Text(
                                      estudiante['tiempo_restante']
                                              .inSeconds
                                              .isNegative
                                          ? "Tiempo excedido: ${-_dias(estudiante['tiempo_restante'])} días"
                                          : "Tiempo restante: ${_dias(estudiante['tiempo_restante'])} días",
                                      style: TextStyle(
                                        color: estudiante['tiempo_restante']
                                                .inSeconds
                                                .isNegative
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "Debe devolver: ${estudiante['fechaDevolucion'] ?? '---'}",
                                      style: const TextStyle(
                                          fontSize: 15, color: Colors.blueGrey),
                                    ),
                                    Text(
                                      "Fecha de préstamo: ${estudiante['fechaPrestamo'] ?? '---'}",
                                      style: const TextStyle(
                                          fontSize: 15, color: Colors.blueGrey),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.chevron_right,
                                        color: Colors.orange.shade600,
                                        size: 32),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              DetallePrestamoScreen(
                                                  estudiante: estudiante),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.assignment_return,
                                        color: Colors.green.shade700),
                                    tooltip: 'Devolver equipo',
                                    onPressed: () async {
                                      final confirmar = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Devolver equipo'),
                                          content: Text(
                                              '¿Estás seguro de devolver este equipo? Esta acción no se puede deshacer.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text('Cancelar')),
                                            ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text('Devolver')),
                                          ],
                                        ),
                                      );
                                      if (confirmar == true) {
                                        // Ejecuta la devolución (ver función siguiente)
                                        if (estudiante['equipoId'] != null &&
                                            estudiante['id'] != null) {
                                          await _devolverEquipo(
                                              estudiante['equipoId'],
                                              estudiante['id']);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'No se encontró el ID del equipo.')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetallePrestamoScreen(
                                        estudiante: estudiante),
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
        ),
      ),
    );
  }

  // Pestaña de Solicitudes
  Widget _buildSolicitudesTab() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1100),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment,
                      color: Colors.deepOrange, size: 32),
                  const SizedBox(width: 14),
                  Text(
                    "Solicitudes pendientes",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const Spacer(),
                  const Text("Antiguos", style: TextStyle(fontSize: 15)),
                  Switch(
                    value: ordenarRecientesPrimero,
                    onChanged: (val) =>
                        setState(() => ordenarRecientesPrimero = val),
                  ),
                  const Text("Recientes", style: TextStyle(fontSize: 15)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Buscar por nombre del solicitante...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (valor) {
                        setState(() {
                          filtroNombreSolicitante = valor.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Buscar por DNI...",
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('solicitudes')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text("Error al cargar solicitudes."));
                    }
                    var solicitudes = snapshot.data?.docs ?? [];

                    // FILTRO POR NOMBRE DE SOLICITANTE y por DNI
                    if (filtroNombreSolicitante.isNotEmpty) {
                      solicitudes = solicitudes.where((doc) {
                        final nombre =
                            (doc['nombre'] ?? '').toString().toLowerCase();
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
                      return ordenarRecientesPrimero
                          ? dtB.compareTo(dtA)
                          : dtA.compareTo(dtB);
                    });

                    // Tabla estilo CRUD
                    return solicitudes.isEmpty
                        ? const Center(
                            child: Text("No hay solicitudes pendientes."))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columnSpacing: 18,
                              columns: const [
                                DataColumn(
                                    label: Text("Solicitante",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text("Equipo",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text("Fecha solicitud",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text("Acciones",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                              ],
                              rows: solicitudes.map<DataRow>((solicitud) {
                                final data =
                                    solicitud.data() as Map<String, dynamic>;
                                final nombre = data['nombre'] ?? '---';
                                final equipo =
                                    data['equipos']?[0]?['nombre'] ?? '---';
                                final fechaEnvio =
                                    data['fecha_envio'] is Timestamp
                                        ? DateFormat('dd/MM/yyyy').format(
                                            (data['fecha_envio'] as Timestamp)
                                                .toDate())
                                        : '---';
                                return DataRow(
                                  cells: [
                                    DataCell(Text(nombre)),
                                    DataCell(Text(equipo)),
                                    DataCell(Text(fechaEnvio)),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.visibility,
                                              color: Colors.blue.shade600),
                                          tooltip: "Visualizar",
                                          onPressed: () =>
                                              _mostrarDetallesSolicitud(
                                                  context, solicitud),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.check_circle,
                                              color: Colors.green.shade600),
                                          tooltip: "Aceptar",
                                          onPressed: () => _gestionarSolicitud(
                                              solicitud, "Aceptada"),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.cancel,
                                              color: Colors.red.shade600),
                                          tooltip: "Rechazar",
                                          onPressed: () => _gestionarSolicitud(
                                              solicitud, "Rechazada"),
                                        ),
                                      ],
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
