import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EstadisticasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene solicitudes en un rango de fechas
  Future<List<QueryDocumentSnapshot>> obtenerSolicitudesRango(
    DateTime inicio,
    DateTime fin,
  ) async {
    final query = await _firestore
        .collection('solicitudes')
        .where('fecha_envio',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_envio', isLessThanOrEqualTo: Timestamp.fromDate(fin))
        .get();
    return query.docs;
  }

  /// Calcula estadísticas generales de solicitudes
  Map<String, int> calcularEstadisticasSolicitudes(
      List<QueryDocumentSnapshot> docs) {
    int total = docs.length;
    int aceptadas = 0;
    int rechazadas = 0;
    int pendientes = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final estado = data?['estado'];

      if (estado == 'Aceptada') {
        aceptadas++;
      } else if (estado == 'Rechazada') {
        rechazadas++;
      } else {
        pendientes++;
      }
    }

    return {
      'total': total,
      'aceptadas': aceptadas,
      'rechazadas': rechazadas,
      'pendientes': pendientes,
    };
  }

  /// Cuenta equipos prestados actualmente
  Future<int> contarEquiposPrestados() async {
    int totalEquipos = 0;

    // Obtener todos los usuarios
    final usuariosSnap = await _firestore.collection('usuarios').get();

    for (var usuario in usuariosSnap.docs) {
      // Contar equipos en uso por cada usuario
      final equiposSnap = await _firestore
          .collection('usuarios')
          .doc(usuario.id)
          .collection('equipos_a_cargo')
          .where('estado_prestamo', isEqualTo: 'En uso')
          .get();

      totalEquipos += equiposSnap.docs.length;
    }

    return totalEquipos;
  }

  /// Cuenta total de equipos en el sistema
  Future<int> contarTotalEquipos() async {
    final equiposSnap = await _firestore.collection('equipos').get();
    return equiposSnap.docs.length;
  }

  /// Obtiene equipos más solicitados en un rango de fechas
  Future<Map<String, int>> obtenerEquiposMasSolicitados(
    List<QueryDocumentSnapshot> solicitudes,
  ) async {
    Map<String, int> conteoEquipos = {};

    for (var solicitud in solicitudes) {
      final data = solicitud.data() as Map<String, dynamic>?;
      final equipos = data?['equipos'] as List<dynamic>? ?? [];

      for (var equipo in equipos) {
        if (equipo is Map<String, dynamic>) {
          final nombre = equipo['nombre'] as String? ?? 'Sin nombre';
          conteoEquipos[nombre] = (conteoEquipos[nombre] ?? 0) + 1;
        }
      }
    }

    // Ordenar por cantidad (descendente)
    final sorted = conteoEquipos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted.take(10)); // Top 10
  }

  /// Obtiene estadísticas por asignatura
  Map<String, int> obtenerEstadisticasPorAsignatura(
      List<QueryDocumentSnapshot> solicitudes) {
    Map<String, int> conteoAsignaturas = {};

    for (var solicitud in solicitudes) {
      final data = solicitud.data() as Map<String, dynamic>?;
      final asignatura = data?['asignatura'] as String? ?? 'Sin asignatura';
      conteoAsignaturas[asignatura] =
          (conteoAsignaturas[asignatura] ?? 0) + 1;
    }

    return conteoAsignaturas;
  }

  /// Obtiene préstamos agrupados por día
  Map<String, int> obtenerPrestamosPorDia(
      List<QueryDocumentSnapshot> solicitudes) {
    Map<String, int> prestamosPorDia = {};
    final dateFormat = DateFormat('dd/MM');

    for (var solicitud in solicitudes) {
      final data = solicitud.data() as Map<String, dynamic>?;
      final fechaEnvio = data?['fecha_envio'] as Timestamp?;

      if (fechaEnvio != null) {
        final fecha = fechaEnvio.toDate();
        final fechaStr = dateFormat.format(fecha);
        prestamosPorDia[fechaStr] = (prestamosPorDia[fechaStr] ?? 0) + 1;
      }
    }

    return prestamosPorDia;
  }

  /// Cuenta equipos devueltos en un rango (basado en solicitudes aceptadas que ya pasaron su fecha de devolución)
  Future<int> contarEquiposDevueltos(DateTime inicio, DateTime fin) async {
    final ahora = DateTime.now();
    
    // Obtener solicitudes del rango usando el método existente
    final solicitudes = await obtenerSolicitudesRango(inicio, fin);

    int totalEquipos = 0;
    for (var doc in solicitudes) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      
      // Solo contar si está aceptada y ya pasó la fecha de devolución
      if (data['estado'] == 'Aceptada') {
        final fechaDevolucion = data['fecha_devolucion'];
        if (fechaDevolucion != null) {
          DateTime fechaDev;
          if (fechaDevolucion is Timestamp) {
            fechaDev = fechaDevolucion.toDate();
          } else {
            continue;
          }
          
          // Si la fecha de devolución ya pasó, contarlo como devuelto
          if (fechaDev.isBefore(ahora)) {
            final equipos = data['equipos'] as List<dynamic>? ?? [];
            totalEquipos += equipos.length;
          }
        }
      }
    }

    return totalEquipos;
  }

  /// Obtiene datos completos para exportación
  Future<List<Map<String, dynamic>>> obtenerDatosParaExportar(
    DateTime inicio,
    DateTime fin,
  ) async {
    final solicitudes = await obtenerSolicitudesRango(inicio, fin);
    List<Map<String, dynamic>> datos = [];

    for (var doc in solicitudes) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final equipos = data['equipos'] as List<dynamic>? ?? [];
      final equiposNombres =
          equipos.map((e) => e['nombre'] ?? 'Sin nombre').join(', ');

      String formatearFecha(dynamic fecha) {
        if (fecha == null) return 'N/A';
        if (fecha is Timestamp) {
          return DateFormat('dd/MM/yyyy').format(fecha.toDate());
        }
        if (fecha is String) return fecha;
        return 'N/A';
      }

      datos.add({
        'fecha_envio': formatearFecha(data['fecha_envio']),
        'nombre': data['nombre'] ?? 'Sin nombre',
        'dni': data['dni']?.toString() ?? 'N/A',
        'email': data['email'] ?? 'N/A',
        'celular': data['celular'] ?? 'N/A',
        'equipos': equiposNombres,
        'cantidad_equipos': equipos.length,
        'estado': data['estado'] ?? 'Pendiente',
        'asignatura': data['asignatura'] ?? 'N/A',
        'trabajo': data['trabajo'] ?? 'N/A',
        'docente': data['docente'] ?? 'N/A',
        'lugar': data['lugar'] ?? 'N/A',
        'fecha_prestamo': formatearFecha(data['fecha_prestamo']),
        'fecha_devolucion': formatearFecha(data['fecha_devolucion']),
        'dias_prestamo': data['dias_prestamo']?.toString() ?? 'N/A',
      });
    }

    return datos;
  }
}
