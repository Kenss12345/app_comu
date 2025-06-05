import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_comu/utils/carrito_equipos.dart';
import 'package:intl/intl.dart';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

List<Map<String, dynamic>> equiposSeleccionados = CarritoEquipos().equipos;

class SolicitudEquiposScreen extends StatefulWidget {
  const SolicitudEquiposScreen({super.key});

  @override
  _SolicitudEquiposScreenState createState() => _SolicitudEquiposScreenState();
}

class _SolicitudEquiposScreenState extends State<SolicitudEquiposScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos del usuario
  String nombreUsuario = "";
  String dniUsuario = "";
  String tipoUsuario = "";
  String celularUsuario = "";
  String emailUsuario = "";
  String fechaPrestamo = "";
  String fechaDevolucion = "";
  String? trabajoSeleccionado = 'Trabajo a realizar 1';
  bool isLoading = true;
  bool _enviando = false;

  // Controladores para los campos editables
  final TextEditingController asignaturaController = TextEditingController();
  final TextEditingController trabajoController = TextEditingController();
  final TextEditingController docenteController = TextEditingController();
  final TextEditingController lugarController = TextEditingController();
  //final TextEditingController fechaEntregaController = TextEditingController();
  //final TextEditingController fechaDevolucionController = TextEditingController();
  final TextEditingController horaSalidaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
    _ajustarFechasPorTrabajo(trabajoSeleccionado ?? trabajos.first['nombre']);
  }

  void _ajustarFechasPorTrabajo(String? trabajoNombre) {
    final trabajo = trabajos.firstWhere((t) => t['nombre'] == trabajoNombre);
    final ahora = DateTime.now();
    final duracion = trabajo['duracion'] as Duration;
    final fechaDevolucionDT = ahora.add(duracion);

    final format = DateFormat('dd/MM/yyyy HH:mm');
    fechaPrestamo = format.format(ahora);

    if (duracion.inHours < 24) {
      fechaDevolucion = format.format(fechaDevolucionDT);
    } else {
      final formatDay = DateFormat('dd/MM/yyyy');
      fechaDevolucion = formatDay.format(fechaDevolucionDT);
    }
  }

  Future<void> _cargarDatosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          nombreUsuario = userDoc["nombre"] ?? "";
          celularUsuario = userDoc["celular"] ?? "";
          emailUsuario = userDoc["email"] ?? "";
          dniUsuario = userDoc["dni"] ?? "";
          tipoUsuario = userDoc["TipoUser"] ?? "";
          isLoading = false;
        });
      }
    }
  }

  Future<void> _enviarSolicitud() async {
    setState(() => _enviando = true);

      if (trabajoSeleccionado != null) {
        _ajustarFechasPorTrabajo(trabajoSeleccionado);
      }

  
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final equipos = CarritoEquipos().equipos;

          // Convierte la fecha a DateTime y luego a Timestamp
          Timestamp fechaDevolucionTS;
          try {
            // Usa el formato que generas en _ajustarFechasPorTrabajo
            fechaDevolucionTS = Timestamp.fromDate(
              DateFormat(fechaDevolucion.contains(':') ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy').parse(fechaDevolucion),
            );
          } catch (e) {
            fechaDevolucionTS = Timestamp.now(); // fallback de emergencia
          }

          await FirebaseFirestore.instance.collection('solicitudes').add({
            'uid': user.uid,
            'nombre': nombreUsuario,
            'email': emailUsuario,
            'dni': dniUsuario,
            'celular': celularUsuario,
            'tipoUsuario': tipoUsuario,
            'asignatura': asignaturaController.text,
            'trabajo': trabajoController.text,
            'docente': docenteController.text,
            'lugar': lugarController.text,
            'hora_salida': horaSalidaController.text,
            'fecha_prestamo': fechaPrestamo,
            'fecha_devolucion': fechaDevolucion,
            'fecha_envio': Timestamp.now(),
            'equipos': equipos,
          });

          // Enviar correo al usuario
          await _enviarCorreoConfirmacion(emailUsuario, equipos);

          // Solo muestra el mensaje de éxito cuando todo termina
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Solicitud enviada correctamente")),
          );
          Navigator.pop(context, true); // Volver atrás
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al enviar solicitud: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarCorreoConfirmacion(String destinatario, List<Map<String, dynamic>> equipos) async {
    // Usa tu correo institucional o de servicio habilitado para SMTP
    String username = 'kenss12345@gmail.com';
    String password = 'qsex cejw glnq namr';

    final smtpServer = gmail(username, password);

    // Construye el contenido de los equipos solicitados
    String contenidoEquipos = equipos.map((e) => "- ${e['nombre']} (${e['estado_prestamo']})").join("\n");

    // Construye el contenido del mensaje
    final message = Message()
      ..from = Address(username, 'Soporte Audiovisual')
      ..recipients.add(destinatario)
      ..subject = 'Confirmación de solicitud de préstamo'
      ..text = '''
    Hola $nombreUsuario,

    Tu solicitud de préstamo ha sido registrada con éxito.

    Detalles de tu solicitud:
    - Fecha de entrega: $fechaPrestamo
    - Fecha de devolución: $fechaDevolucion
    - Hora de salida: ${horaSalidaController.text}
    - Lugar de Trabajo: ${lugarController.text}
    - Asignatura: ${asignaturaController.text}
    - Trabajo a Realizar: ${trabajoController.text}
    - Docente a Cargo: ${docenteController.text}

  Equipos solicitados:
  $contenidoEquipos

  Gracias por usar nuestro sistema.

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

  final List<Map<String, dynamic>> trabajos = [
    {
      'nombre': 'Trabajo a realizar 1',
      'duracion': Duration(days: 2), // 2 días
    },
    {
      'nombre': 'Trabajo a realizar 2',
      'duracion': Duration(hours: 5), // 5 horas
    },
    {
      'nombre': 'Trabajo a realizar 3',
      'duracion': Duration(days: 1), // 1 día
    },
    {
      'nombre': 'Trabajo a realizar 4',
      'duracion': Duration(days: 5), // 5 días
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // La pantalla normal
        Scaffold(
          appBar: AppBar(
            title: const Text("Solicitud de Equipo"),
            backgroundColor: Colors.orange,
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : AbsorbPointer(
                absorbing: _enviando, // <- desactiva taps cuando está enviando
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionCard(
                            title: "Datos del Estudiante",
                            children: [
                              _buildTextField(label: "Nombre", initialValue: nombreUsuario, enabled: false),
                              _buildTextField(label: "DNI", initialValue: dniUsuario, enabled: false),
                              _buildTextField(label: "Celular", initialValue: celularUsuario, enabled: false),
                              _buildTextField(label: "Email", initialValue: emailUsuario, enabled: false),
                              _buildTextField(label: "Tipo de Usuario", initialValue: tipoUsuario, enabled: false),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSectionCard(
                            title: "Detalles de la Solicitud",
                            children: [
                              _buildTextField(label: "Asignatura", controller: asignaturaController),

                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DropdownButtonFormField<String>(
                                  value: trabajoSeleccionado,
                                  decoration: const InputDecoration(
                                    labelText: "Trabajo a Realizar",
                                    border: OutlineInputBorder(),
                                  ),
                                  items: trabajos.map((t) {
                                    return DropdownMenuItem<String>(
                                      value: t['nombre'] as String,
                                      child: Text(t['nombre'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      trabajoSeleccionado = value;
                                      _ajustarFechasPorTrabajo(value);
                                      trabajoController.text = value ?? "";
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Selecciona el trabajo a realizar";
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              _buildTextField(label: "Docente a Cargo", controller: docenteController),
                              _buildTextField(label: "Lugar de Trabajo", controller: lugarController),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Entrega: $fechaPrestamo", style: TextStyle(fontSize: 16)),
                                    SizedBox(height: 4),
                                    Text("Devolución: $fechaDevolucion", style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ),
                              _buildTextField(
                                label: "Hora de Salida del Equipo",
                                controller: horaSalidaController,
                                enabled: true,
                                onTap: () async {
                                  final timeOfDay = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );

                                  if (timeOfDay != null) {
                                    final formattedTime = timeOfDay.format(context);
                                    setState(() {
                                      horaSalidaController.text = formattedTime;
                                    });
                                  }
                                },
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSectionCard(
                            title: "Equipos Seleccionados",
                            children: equiposSeleccionados.map((equipo) {
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(equipo["imagen"], width: 50, height: 50, fit: BoxFit.cover),
                                  ),
                                  title: Text(equipo["nombre"]),
                                  subtitle: Text("Estado: ${equipo["estado_prestamo"]}"),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: _enviando /*ElevatedButton(*/
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _enviarSolicitud();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("Enviar Solicitud", style: TextStyle(fontSize: 16, color: Colors.white)),
                              ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),

        // Overlay que bloquea taps, muestra loader y oscurece la pantalla
        if (_enviando)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 24),
                    // Animación de puntos suspensivos:
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: 3),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        String dots = '.' * (value + 1);
                        return Text(
                          "Enviando solicitud$dots",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                      onEnd: () {
                        // Repite la animación
                        if (_enviando && mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Método reutilizable para construir los campos de entrada
  Widget _buildTextField({required String label, TextEditingController? controller, String? initialValue, bool enabled = true, VoidCallback? onTap,}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        enabled: enabled,
        readOnly: onTap != null,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Este campo es obligatorio";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800])),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}