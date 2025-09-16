import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_comu/utils/carrito_equipos.dart';
import 'package:intl/intl.dart';
import 'package:app_comu/utils/temporizador_reserva.dart';

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
  String apellidosUsuario = "";
  String dniUsuario = "";
  String tipoUsuario = "";
  String celularUsuario = "";
  String emailUsuario = "";
  String fechaPrestamo = "";
  String fechaDevolucion = "";
  String? trabajoSeleccionado;
  bool isLoading = true;
  bool _enviando = false;

  // Controladores para los campos editables
  String? asignaturaSeleccionada;
  final List<String> _opcionesAsignatura = const [
    'AUDIOVISUAL',
    'FOTOGRAFÍA',
    'RADIO',
    'OTROS',
  ];
  final TextEditingController cursoController = TextEditingController();
  final TextEditingController trabajoController = TextEditingController();
  final TextEditingController docenteController = TextEditingController();
  final TextEditingController lugarController = TextEditingController();
  final TextEditingController nombreGrupoController = TextEditingController();
  final TextEditingController semestreController = TextEditingController();
  final TextEditingController nrcController = TextEditingController();
  int? cantidadIntegrantesSeleccionada;
  bool _unicoIntegrante = true;
  final List<TextEditingController> _integrantesControllers = [];
  final List<FocusNode> _integrantesFocusNodes = [];
  final List<List<Map<String, dynamic>>> _sugerenciasIntegrantes = [];
  final List<Timer?> _debounceIntegrantes = [];

  @override
  void initState() {
    super.initState();
    trabajoSeleccionado = trabajos.first['nombre'] as String;
    asignaturaSeleccionada = _opcionesAsignatura.first;
    cantidadIntegrantesSeleccionada = 1;
    _unicoIntegrante = true;
    _cargarDatosUsuario();
    _ajustarFechasPorTrabajo(trabajoSeleccionado!);
    // Asegura que el valor inicial del desplegable quede persistido
    trabajoController.text = trabajoSeleccionado ?? "";
    _rebuildIntegrantes(0);
  }

  @override
  void dispose() {
    for (final c in _integrantesControllers) {
      c.dispose();
    }
    for (final f in _integrantesFocusNodes) {
      f.dispose();
    }
    for (final t in _debounceIntegrantes) {
      t?.cancel();
    }
    cursoController.dispose();
    trabajoController.dispose();
    docenteController.dispose();
    lugarController.dispose();
    nombreGrupoController.dispose();
    semestreController.dispose();
    nrcController.dispose();
    super.dispose();
  }

  void _rebuildIntegrantes(int cantidad) {
    // Ajusta longitud de listas auxiliares
    while (_integrantesControllers.length < cantidad) {
      _integrantesControllers.add(TextEditingController());
      _integrantesFocusNodes.add(FocusNode());
      _sugerenciasIntegrantes.add(<Map<String, dynamic>>[]);
      _debounceIntegrantes.add(null);
    }
    while (_integrantesControllers.length > cantidad) {
      _integrantesControllers.removeLast().dispose();
      _integrantesFocusNodes.removeLast().dispose();
      _sugerenciasIntegrantes.removeLast();
      final lastTimer = _debounceIntegrantes.removeLast();
      lastTimer?.cancel();
    }
    // Limpia textos excedentes si fue reducción
    for (int i = 0; i < _integrantesControllers.length; i++) {
      // Mantener textos actuales
    }
    setState(() {});
  }

  Future<void> _fetchSugerenciasIntegrantes(int index, String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _sugerenciasIntegrantes[index] = [];
      });
      return;
    }
    try {
      // Buscar por DNI (prefijo) únicamente
      final qDni = await FirebaseFirestore.instance
          .collection('usuarios')
          .orderBy('dni')
          .startAt([query])
          .endAt([query + '\\uf8ff'])
          .limit(5)
          .get();
      final resultados = <Map<String, dynamic>>[];
      for (final d in qDni.docs) {
        final data = d.data();
        resultados.add({'dni': (data['dni'] ?? '').toString()});
      }
      if (mounted) {
        setState(() {
          _sugerenciasIntegrantes[index] = resultados;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sugerenciasIntegrantes[index] = [];
        });
      }
    }
  }

  List<Widget> _buildCamposIntegrantes() {
    if (_unicoIntegrante) return <Widget>[];
    final totalAdicionales = (cantidadIntegrantesSeleccionada ?? 1) - 1;
    final widgets = <Widget>[];
    for (int i = 0; i < totalAdicionales; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _integrantesControllers[i],
                focusNode: _integrantesFocusNodes[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Integrante ${i + 2} (DNI)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (text) {
                  _debounceIntegrantes[i]?.cancel();
                  _debounceIntegrantes[i] = Timer(const Duration(milliseconds: 250), () {
                    _fetchSugerenciasIntegrantes(i, text);
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Completa este integrante';
                  }
                  return null;
                },
              ),
              if (_sugerenciasIntegrantes[i].isNotEmpty && _integrantesFocusNodes[i].hasFocus)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sugerenciasIntegrantes[i].length,
                    itemBuilder: (context, j) {
                      final sug = _sugerenciasIntegrantes[i][j];
                      final dniSugerido = (sug['dni'] ?? '').toString();
                      return ListTile(
                        dense: true,
                        title: Text('DNI: $dniSugerido'),
                        onTap: () {
                          setState(() {
                            _integrantesControllers[i].text = dniSugerido;
                            _sugerenciasIntegrantes[i] = [];
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  void _ajustarFechasPorTrabajo(String? trabajoNombre) {
    final trabajo = trabajos.firstWhere(
      (t) => t['nombre'] == trabajoNombre,
      orElse: () => trabajos.first,
    );
    final ahora = DateTime.now();
    final duracion = trabajo['duracion'] as Duration;
    final fechaDevolucionDT = ahora.add(duracion);
    final format = DateFormat('dd/MM/yyyy');
    fechaPrestamo = format.format(ahora);
    fechaDevolucion = format.format(fechaDevolucionDT);
  }

  Future<void> _cargarDatosUsuario() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          nombreUsuario = userDoc["nombre"] ?? "";
          apellidosUsuario = userDoc["apellidos"] ?? "";
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

    // Busca el trabajo seleccionado para extraer la duración en días
    final trabajo = trabajos.firstWhere(
      (t) => t['nombre'] == trabajoSeleccionado,
      orElse: () => trabajos.first,
    );
    final diasPrestamo = (trabajo['duracion'] as Duration).inDays;

    if (trabajoSeleccionado != null) {
      _ajustarFechasPorTrabajo(trabajoSeleccionado);
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final equipos = CarritoEquipos().equipos;

        // Reunir DNIs de integrantes solo si NO es único integrante
        final List<String> integrantes = _unicoIntegrante
            ? <String>[]
            : _integrantesControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList();

        // Validación: todos los DNIs deben existir en 'usuarios'
        if (integrantes.isNotEmpty) {
          // whereIn permite hasta 10 elementos
          final snapshot = await FirebaseFirestore.instance
              .collection('usuarios')
              .where('dni', whereIn: integrantes)
              .get();
          final encontrados = snapshot.docs
              .map((d) => (d.data()['dni'] ?? '').toString())
              .toSet();
          final faltantes = integrantes.where((dni) => !encontrados.contains(dni)).toList();
          if (faltantes.isNotEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Los siguientes DNI no están registrados: ${faltantes.join(', ')}",
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            setState(() => _enviando = false);
            return;
          }
        }

        // Convierte la fecha a DateTime y luego a Timestamp
        Timestamp fechaDevolucionTS;
        try {
          fechaDevolucionTS = Timestamp.fromDate(
            DateFormat('dd/MM/yyyy').parse(fechaDevolucion),
          );
        } catch (e) {
          fechaDevolucionTS = Timestamp.now();
        }

        // Nota: 'integrantes' ya fue construido/validado arriba

        await FirebaseFirestore.instance.collection('solicitudes').add({
          'uid': user.uid,
          'nombre': nombreUsuario,
          'apellidos': apellidosUsuario,
          'email': emailUsuario,
          'dni': dniUsuario,
          'celular': celularUsuario,
          'tipoUsuario': tipoUsuario,
          'asignatura': asignaturaSeleccionada,
          'curso': cursoController.text,
          'trabajo': trabajoSeleccionado ?? trabajoController.text,
          'docente': docenteController.text,
          'lugar': lugarController.text,
          'nombre_grupo': nombreGrupoController.text,
          'semestre': semestreController.text,
          'nrc': nrcController.text,
          'cantidad_integrantes': cantidadIntegrantesSeleccionada,
          'integrantes': integrantes,
          'fecha_prestamo': fechaPrestamo,
          'fecha_devolucion': fechaDevolucionTS,
          'fecha_envio': Timestamp.now(),
          'equipos': equipos,
          'dias_prestamo': diasPrestamo,
        });

        for (final equipo in equipos) {
          await FirebaseFirestore.instance
              .collection('equipos')
              .doc(equipo['id'])
              .update({
            'fecha_solicitud':
                Timestamp.now(),
            'fecha_devolucion': fechaDevolucionTS,
            'uid_prestamo': user.uid,
          });
        }

        // Enviar correo al usuario
        await _enviarCorreoConfirmacion(emailUsuario, equipos, integrantes);

        // Solo muestra el mensaje de éxito cuando todo termina
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Solicitud enviada correctamente")),
          );
          // Cancelar temporizador global al enviar a tiempo
          TemporizadorReservas.instance.cancelarPorSolicitud();
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

  Future<void> _enviarCorreoConfirmacion(
      String destinatario, List<Map<String, dynamic>> equipos, List<String> integrantes) async {
    // Usa tu correo institucional o de servicio habilitado para SMTP
    String username = 'kenss12345@gmail.com';
    String password = 'qsex cejw glnq namr';

    final smtpServer = gmail(username, password);

    // Construye el contenido de los equipos solicitados
    String contenidoEquipos = equipos
        .map((e) => "- ${e['nombre']} (${e['estado_prestamo']})")
        .join("\n");

    // Construye integrantes
    String contenidoIntegrantes = integrantes.isEmpty
        ? 'No especificado'
        : integrantes.asMap().entries
            .map((e) => "${e.key + 1}. ${e.value}")
            .join("\n");

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
    - Asignatura: ${asignaturaSeleccionada ?? ''}
    - Curso: ${cursoController.text}
    - Docente: ${docenteController.text}
    - Nombre de grupo: ${nombreGrupoController.text}
    - Semestre: ${semestreController.text}
    - NRC: ${nrcController.text}
    - Cantidad de integrantes: ${cantidadIntegrantesSeleccionada ?? 0}
    - Integrantes:\n$contenidoIntegrantes
    - Lugar de Trabajo: ${lugarController.text}
    - Trabajo a Realizar: ${trabajoController.text}

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
      'nombre': 'Trabajo a realizar 1 (1 día)',
      'duracion': Duration(days: 1),
    },
    {
      'nombre': 'Trabajo a realizar 2 (2 días)',
      'duracion': Duration(days: 2),
    },
    {
      'nombre': 'Trabajo a realizar 3 (3 días)',
      'duracion': Duration(days: 3),
    },
    {
      'nombre': 'Trabajo a realizar 4 (5 días)',
      'duracion': Duration(days: 5),
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
                  absorbing:
                      _enviando, // <- desactiva taps cuando está enviando
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
                                _buildTextField(
                                    label: "Nombre",
                                    initialValue: nombreUsuario,
                                    enabled: false),
                                _buildTextField(
                                    label: "Apellidos",
                                    initialValue: apellidosUsuario,
                                    enabled: false),
                                _buildTextField(
                                    label: "DNI",
                                    initialValue: dniUsuario,
                                    enabled: false),
                                _buildTextField(
                                    label: "Celular",
                                    initialValue: celularUsuario,
                                    enabled: false),
                                _buildTextField(
                                    label: "Email",
                                    initialValue: emailUsuario,
                                    enabled: false),
                                _buildTextField(
                                    label: "Tipo de Usuario",
                                    initialValue: tipoUsuario,
                                    enabled: false),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              title: "Detalles de la Solicitud",
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: DropdownButtonFormField<String>(
                                    value: asignaturaSeleccionada,
                                    decoration: const InputDecoration(
                                      labelText: "Asignatura",
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _opcionesAsignatura
                                        .map((asig) => DropdownMenuItem(
                                              value: asig,
                                              child: Text(asig),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        asignaturaSeleccionada = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Selecciona una asignatura";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                _buildTextField(
                                    label: "Curso",
                                    controller: cursoController),
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
                                _buildTextField(
                                    label: "Docente",
                                    controller: docenteController),
                                _buildTextField(
                                    label: "Nombre de grupo",
                                    controller: nombreGrupoController),
                                _buildTextField(
                                    label: "Semestre",
                                    controller: semestreController),
                                _buildTextField(
                                    label: "NRC",
                                    controller: nrcController),
                                _buildTextField(
                                    label: "Lugar de Trabajo",
                                    controller: lugarController),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: DropdownButtonFormField<String>(
                                    value: _unicoIntegrante
                                        ? 'unico'
                                        : (cantidadIntegrantesSeleccionada?.toString() ?? 'unico'),
                                    decoration: const InputDecoration(
                                      labelText: "Cantidad de integrantes del grupo",
                                      border: OutlineInputBorder(),
                                    ),
                                    items: <DropdownMenuItem<String>>[
                                      const DropdownMenuItem(
                                        value: 'unico',
                                        child: Text('Único integrante'),
                                      ),
                                      ...List.generate(9, (i) => i + 2).map((n) => DropdownMenuItem<String>(
                                            value: n.toString(),
                                            child: Text(n.toString()),
                                          )),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == 'unico') {
                                          _unicoIntegrante = true;
                                          cantidadIntegrantesSeleccionada = 1;
                                          _rebuildIntegrantes(0);
                                        } else {
                                          _unicoIntegrante = false;
                                          final parsed = int.tryParse(value ?? '2') ?? 2;
                                          cantidadIntegrantesSeleccionada = parsed;
                                          _rebuildIntegrantes(parsed - 1);
                                        }
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Selecciona la cantidad de integrantes";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                ..._buildCamposIntegrantes(),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Entrega: $fechaPrestamo",
                                          style: TextStyle(fontSize: 16)),
                                      SizedBox(height: 4),
                                      Text("Devolución: $fechaDevolucion",
                                          style: TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                ),
                                
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSectionCard(
                              title: "Equipos Seleccionados",
                              children: equiposSeleccionados.map((equipo) {
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(equipo["imagen"],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover),
                                    ),
                                    title: Text(equipo["nombre"]),
                                    subtitle: Text(
                                        "Estado: ${equipo["estado_prestamo"]}"),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 40, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: const Text("Enviar Solicitud",
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.white)),
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
  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
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

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800])),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
