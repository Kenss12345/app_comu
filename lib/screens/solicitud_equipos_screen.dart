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
  bool isLoading = true;

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
    _calcularFechas();
  }

  void _calcularFechas() {
    final hoy = DateTime.now();
    final dosDiasDespues = hoy.add(Duration(days: 2));
    final format = DateFormat('dd/MM/yyyy');
    fechaPrestamo = format.format(hoy);
    fechaDevolucion = format.format(dosDiasDespues);
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
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final equipos = CarritoEquipos().equipos;

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

        //CarritoEquipos().limpiarCarrito();

        // Cambiar estado de cada equipo a "en uso"
        final carrito = CarritoEquipos();
        for (int i = 0; i < carrito.equipos.length; i++) {
          carrito.equipos[i]["estado_prestamo"] = "en uso";
        }



        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Solicitud enviada correctamente")));

        Navigator.pop(context); // Volver atrás
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al enviar solicitud: $e")));
    }
  }

  Future<void> _enviarCorreoConfirmacion(String destinatario, List<Map<String, dynamic>> equipos) async {
    // Usa tu correo institucional o de servicio habilitado para SMTP
    String username = '72195486@continental.edu.pe';
    String password = 'tkqttcarvdixwzf';

    final smtpServer = gmail(username, password);

    String contenidoEquipos = equipos.map((e) => "- ${e['nombre']} (${e['estado_prestamo']})").join("\n");

    final message = Message()
      ..from = Address(username, 'Soporte Audiovisual')
      //..recipients.add(destinatario)
      ..recipients.add('kenss12345@gmail.com') // para pruebas
      ..subject = 'Confirmación de solicitud de préstamo'
      ..text = '''
  Hola $nombreUsuario,

  Tu solicitud de préstamo ha sido registrada con éxito.

  Detalles de tu solicitud:
  - Fecha de entrega: $fechaPrestamo
  - Fecha de devolución: $fechaDevolucion
  - Hora de salida: ${horaSalidaController.text}

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

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Solicitud de Equipo"),
      backgroundColor: Colors.orange,
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
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
                        _buildTextField(label: "Trabajo a Realizar", controller: trabajoController),
                        _buildTextField(label: "Docente a Cargo", controller: docenteController),
                        _buildTextField(label: "Lugar de Trabajo", controller: lugarController),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Entrega: $fechaPrestamo", style: TextStyle(fontSize: 16)),
                              Text("Devolución: $fechaDevolucion", style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        _buildTextField(label: "Hora de Salida del Equipo", controller: horaSalidaController),
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
                      child: ElevatedButton(
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
  );
}

  // Método reutilizable para construir los campos de entrada
  Widget _buildTextField({required String label, TextEditingController? controller, String? initialValue, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        enabled: enabled,
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