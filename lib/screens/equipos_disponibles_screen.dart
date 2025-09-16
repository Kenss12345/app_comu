import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_comu/utils/carrito_equipos.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:app_comu/utils/temporizador_reserva.dart';

class EquiposDisponiblesScreen extends StatefulWidget {
  const EquiposDisponiblesScreen({super.key});

  @override
  _EquiposDisponiblesScreenState createState() =>
      _EquiposDisponiblesScreenState();
}

class _EquiposDisponiblesScreenState extends State<EquiposDisponiblesScreen> {
  int? _puntosUsuario;
  bool _cargandoUsuario = true;
  bool _operacionEnCurso = false;
  bool _mostrandoDialogoCarga = false;

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  List<Map<String, dynamic>> equipos = [];
  final List<Map<String, dynamic>> equiposACargo = [];

  // Función para validar si una URL de imagen es válida
  bool _esImagenValida(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    // Verificar que sea una URL válida de red (http o https)
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // Función para obtener la primera imagen válida de un equipo
  String? _obtenerPrimeraImagenValida(List<dynamic>? imagenes) {
    if (imagenes == null || imagenes.isEmpty) return null;
    for (var img in imagenes) {
      if (_esImagenValida(img?.toString())) {
        return img.toString();
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _obtenerUsuarioYPuntos();
    _loadEquiposDesdeFirestore();
  }

  String calcularTiempoRestante(dynamic fechaDevolucion) {
    if (fechaDevolucion == null) return "No disponible";
    DateTime? fecha;
    if (fechaDevolucion is String) {
      // Primero intenta como ISO (yyyy-MM-dd), luego como dd/MM/yyyy
      try {
        fecha = DateTime.parse(fechaDevolucion);
      } catch (_) {
        try {
          fecha = DateFormat('dd/MM/yyyy').parse(fechaDevolucion);
        } catch (_) {}
      }
    } else if (fechaDevolucion is Timestamp) {
      fecha = fechaDevolucion.toDate();
    }
    if (fecha == null) return "No disponible";

    final diferencia = fecha.difference(DateTime.now());
    if (diferencia.isNegative) return "Venció";

    if (diferencia.inDays == 0) return "Menos de 1 día";
    return "${diferencia.inDays} día(s)";
  }

  Future<void> _obtenerUsuarioYPuntos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      if (mounted) {
      setState(() {
        _puntosUsuario = data?['puntos'] ?? 0;
        _cargandoUsuario = false;
      });
      }
    } else {
      if (mounted) {
      setState(() {
        _cargandoUsuario = false;
      });
      }
    }
  }

  Future<void> _loadEquiposDesdeFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('equipos').get();

    // Verificar si el widget aún está montado antes de llamar setState
    if (mounted) {
    setState(() {
      equipos = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final tipoEquipo = data['tipoEquipo'] ?? 'normal';

            // Filtra equipos según los puntos del usuario
            if ((_puntosUsuario ?? 0) == 0) {
              // No debe mostrarse ningún equipo
              return null;
            }
            if (tipoEquipo == 'premium' && (_puntosUsuario ?? 0) < 20) {
              // Solo los de 20 puntos o más ven premium
              return null;
            }
            if (tipoEquipo == 'normal' && (_puntosUsuario ?? 0) < 1) {
              // Solo los de 1 o más puntos ven normal
              return null;
            }

            return {
              'id': doc.id,
              'nombre': data['nombre'],
              'descripcion': data['descripcion'],
              'imagenes': List<String>.from(data['imagenes']),
              'estado': data['estado'],
              'tiempoMax': data['tiempoMax'],
              'categoria': data['categoria'],
              'tipoEquipo': tipoEquipo,
              'fecha_devolucion': data['fecha_devolucion'],
            };
          })
          .where((equipo) => equipo != null)
          .cast<Map<String, dynamic>>()
          .toList();
    });
    }
  }

  void _mostrarDialogoBloqueante(String mensaje) {
    if (_mostrandoDialogoCarga) return;
    setState(() {
      _mostrandoDialogoCarga = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    const SizedBox(width: 12),
                    Text(mensaje, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _cerrarDialogoBloqueante() {
    if (!_mostrandoDialogoCarga) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (mounted) {
      setState(() {
        _mostrandoDialogoCarga = false;
      });
    } else {
      _mostrandoDialogoCarga = false;
    }
  }

  void _anadirAEquiposACargo(Map<String, dynamic> equipo) async {
    final equipoId = equipo['id'];

    try {
      if (_operacionEnCurso) return;
      setState(() {
        _operacionEnCurso = true;
      });
      _mostrarDialogoBloqueante("Añadiendo equipo...");

      // Inicia una transacción
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Obtén el documento del equipo dentro de la transacción
        final equipoDocRef =
            FirebaseFirestore.instance.collection('equipos').doc(equipoId);
        final snapshot = await transaction.get(equipoDocRef);

        if (!snapshot.exists) {
          throw Exception("El equipo ya no está disponible.");
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final estadoActual = data['estado'];

        // Verifica si el equipo aún está disponible
        if (estadoActual != "Disponible") {
          throw Exception("El equipo ya no está disponible.");
        }

        // Cambia el estado a "Pendiente"
        transaction.update(equipoDocRef, {
          'estado': 'Pendiente',
        });
      });

      // Si la transacción fue exitosa, añade el equipo a equipos a cargo
      final equipoConFechas = {
        ...equipo,
        "estado_prestamo": "Pendiente",
        "imagen": _obtenerPrimeraImagenValida(equipo['imagenes']) ?? "",
      };

      CarritoEquipos().agregarEquipo(equipoConFechas);

      // Guardar equipo en firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('equipos_a_cargo')
            .doc(equipo['id'])
            .set(equipoConFechas);
      }

      // Iniciar temporizador global si no está activo
      TemporizadorReservas.instance.iniciarSiNoActivo();

      _cerrarDialogoBloqueante();
      if (mounted) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("${equipo["nombre"]} añadido a equipos a cargo.")),
      );
    } catch (e) {
      // Si ocurre un error (por ejemplo, equipo ya en uso)
      _cerrarDialogoBloqueante();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _operacionEnCurso = false;
        });
      } else {
        _operacionEnCurso = false;
      }
    }
    if (mounted) {
    _loadEquiposDesdeFirestore();
    }
  }

  void _mostrarDetalles(BuildContext context, Map<String, dynamic> equipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carrusel con bordes
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CarouselSlider(
                      options: CarouselOptions(
                        height: 250,
                        autoPlay: true,
                        viewportFraction: 1,
                        enlargeCenterPage: false,
                      ),
                      items: () {
                        final imagenesValidas = (equipo["imagenes"] as List)
                            .where((img) => _esImagenValida(img?.toString()))
                            .toList();
                        
                        if (imagenesValidas.isNotEmpty) {
                          return imagenesValidas.map<Widget>((img) {
                            return Image.network(img,
                                fit: BoxFit.cover, width: double.infinity);
                          }).toList();
                        } else {
                          return [
                            Container(
                              width: double.infinity,
                              height: 250,
                              color: Colors.grey.shade100,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported, 
                                       size: 80, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text("Sin imagen",
                                       style: TextStyle(
                                         fontSize: 18,
                                         fontWeight: FontWeight.w500,
                                         color: Colors.grey)),
                                ],
                              ),
                            )
                          ];
                        }
                      }(),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipo["nombre"],
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          equipo["descripcion"],
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 20),

                        // Estado y tiempo máximo
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                equipo["estado"],
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: equipo["estado"] == "Disponible"
                                  ? Colors.green
                                  : equipo["estado"] == "En Uso"
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.timer, color: Colors.grey),
                            const SizedBox(width: 4),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Botón para añadir
                        if (equipo["estado"] == "Disponible")
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _operacionEnCurso
                                  ? null
                                  : () => _anadirAEquiposACargo(equipo),
                              icon: _operacionEnCurso
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.add),
                              label: Text(
                                  _operacionEnCurso ? "Procesando…" : "Añadir equipo"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? categoriaSeleccionada;
  String? disponibilidadSeleccionada;

  @override
  Widget build(BuildContext context) {
    if (_cargandoUsuario) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_puntosUsuario == 0) {
      return Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text("Equipos Disponibles"),
              backgroundColor: Colors.orange.shade600,
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Usuario bloqueado, no puede solicitar equipos. Acérquese a la oficina de equipos para regular su estado.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const TemporizadorReservaBanner(),
        ],
      );
    }

    final categoriasUnicas =
        equipos.map((e) => e["categoria"] as String).toSet().toList();

    final equiposFiltrados = equipos.where((equipo) {
      final coincideBusqueda =
          equipo["nombre"].toLowerCase().contains(searchQuery.toLowerCase());
      final coincideCategoria = categoriaSeleccionada == null ||
          equipo["categoria"] == categoriaSeleccionada;
      final esDisponible = equipo["estado"] == "Disponible";
      final coincideDisponibilidad = disponibilidadSeleccionada == null ||
          (disponibilidadSeleccionada == "Disponible" && esDisponible) ||
          (disponibilidadSeleccionada == "No disponible" && !esDisponible);
      return coincideBusqueda && coincideCategoria && coincideDisponibilidad;
    }).toList();

    Map<String, List<Map<String, dynamic>>> categoriasAgrupadas = {};
    for (var equipo in equiposFiltrados) {
      final categoria = equipo["categoria"];
      categoriasAgrupadas[categoria] = categoriasAgrupadas[categoria] ?? [];
      categoriasAgrupadas[categoria]!.add(equipo);
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Equipos Disponibles"),
            backgroundColor: Colors.orange.shade600,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Buscar equipos...",
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: "Categoría",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Todas")),
                      ...categoriasUnicas.map((categoria) {
                        return DropdownMenuItem(
                          value: categoria,
                          child: Text(categoria),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        categoriaSeleccionada = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: disponibilidadSeleccionada,
                    decoration: const InputDecoration(
                      labelText: "Disponibilidad",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text("Todas")),
                      DropdownMenuItem(
                          value: "Disponible", child: Text("Disponible")),
                      DropdownMenuItem(
                          value: "No disponible", child: Text("No disponible")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        disponibilidadSeleccionada = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: equipos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : categoriasAgrupadas.isEmpty
                      ? const Center(child: Text("No se encontraron equipos."))
                      : ListView(
                          children:
                              categoriasAgrupadas.entries.map((categoria) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    categoria.key,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                ...categoria.value.map((equipo) {
                                  return Card(
                                    elevation: 3,
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () =>
                                          _mostrarDetalles(context, equipo),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: () {
                                                final primeraImagenValida = 
                                                    _obtenerPrimeraImagenValida(equipo["imagenes"]);
                                                
                                                if (primeraImagenValida != null) {
                                                  return Image.network(
                                                    primeraImagenValida,
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        width: 60,
                                                        height: 60,
                                                        color: Colors.grey.shade100,
                                                        child: const Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(Icons.image_not_supported,
                                                                 size: 24, color: Colors.grey),
                                                            Text("Sin imagen",
                                                                 style: TextStyle(
                                                                   fontSize: 8,
                                                                   color: Colors.grey)),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  return Container(
                                                    width: 60,
                                                    height: 60,
                                                    color: Colors.grey.shade100,
                                                    child: const Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.image_not_supported,
                                                             size: 24, color: Colors.grey),
                                                        Text("Sin imagen",
                                                             style: TextStyle(
                                                               fontSize: 8,
                                                               color: Colors.grey)),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              }(),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          equipo["nombre"],
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                      if (equipo["tipoEquipo"] ==
                                                              "premium" &&
                                                          (_puntosUsuario ??
                                                                  0) >=
                                                              15)
                                                        const Icon(Icons.star,
                                                            color: Colors.amber,
                                                            size: 18),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    equipo["descripcion"],
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.black54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    equipo["estado"],
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                  backgroundColor:
                                                      equipo["estado"] ==
                                                              "Disponible"
                                                          ? Colors.green
                                                          : equipo["estado"] ==
                                                                  "En Uso"
                                                              ? Colors.orange
                                                              : Colors.red,
                                                ),
                                                // Solo muestra el tiempo si está en uso y tiene fecha_devolucion
                                                if (equipo["estado"] ==
                                                        "En Uso" &&
                                                    equipo["fecha_devolucion"] !=
                                                        null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 4),
                                                    child: Text(
                                                      "Días restantes: ${calcularTiempoRestante(equipo["fecha_devolucion"])}",
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.orange,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          }).toList(),
                        ),
            ),
              ],
            ),
          ),
        ),
        const TemporizadorReservaBanner(),
      ],
    );
  }
}
