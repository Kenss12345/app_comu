import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EstadisticasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _docFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayFormat = DateFormat('dd/MM');

  /// Incrementa los contadores del día actual en estadisticas_diarias.
  /// [accion]: 'solicitada' | 'aceptada' | 'rechazada'
  /// [equipos]: lista de equipos de la solicitud (solo para 'aceptada')
  /// [asignatura]: asignatura de la solicitud (solo para 'aceptada')
  Future<void> incrementarEstadisticasDia({
    required String accion,
    List<dynamic>? equipos,
    String? asignatura,
    int? cantidad,
  }) async {
    final fechaDoc = _docFormat.format(DateTime.now());
    final docRef = _firestore.collection('estadisticas_diarias').doc(fechaDoc);

    // Incrementa el contador numérico de forma atómica
    final Map<String, dynamic> updates = {};
    if (accion == 'solicitada') {
      updates['solicitadas'] = FieldValue.increment(1);
    } else if (accion == 'aceptada') {
      updates['aceptadas'] = FieldValue.increment(1);
    } else if (accion == 'rechazada') {
      updates['rechazadas'] = FieldValue.increment(1);
    } else if (accion == 'devuelta') {
      updates['devueltos'] = FieldValue.increment(cantidad ?? 1);
    }

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }

    // Para mapas (equipos, asignaturas) usa lectura-escritura
    if (accion == 'aceptada' &&
        ((equipos != null && equipos.isNotEmpty) || asignatura != null)) {
      final docSnap = await docRef.get();
      final existing =
          docSnap.exists ? (docSnap.data() as Map<String, dynamic>) : {};

      final Map<String, dynamic> mapUpdates = {};

      if (equipos != null && equipos.isNotEmpty) {
        final equiposMap = Map<String, dynamic>.from(
            existing['equipos'] as Map<String, dynamic>? ?? {});
        for (final equipo in equipos) {
          if (equipo is Map<String, dynamic>) {
            final nombre = (equipo['nombre'] as String?)?.trim() ?? 'Sin nombre';
            equiposMap[nombre] = ((equiposMap[nombre] as num?) ?? 0) + 1;
          }
        }
        mapUpdates['equipos'] = equiposMap;
      }

      if (asignatura != null && asignatura.isNotEmpty) {
        final asignaturasMap = Map<String, dynamic>.from(
            existing['asignaturas'] as Map<String, dynamic>? ?? {});
        asignaturasMap[asignatura] =
            ((asignaturasMap[asignatura] as num?) ?? 0) + 1;
        mapUpdates['asignaturas'] = asignaturasMap;
      }

      if (mapUpdates.isNotEmpty) {
        await docRef.set(mapUpdates, SetOptions(merge: true));
      }
    }
  }

  /// Obtiene todas las estadísticas acumuladas para un rango de fechas.
    /// Retorna un mapa con: solicitadas, aceptadas, rechazadas, devueltos,
  /// top5Equipos, asignaturas, prestamosPorDia.
  Future<Map<String, dynamic>> obtenerEstadisticasPorRango(
    DateTime inicio,
    DateTime fin,
  ) async {
    int solicitadas = 0;
    int aceptadas = 0;
    int rechazadas = 0;
    int devueltos = 0;
    final Map<String, int> equipos = {};
    final Map<String, int> asignaturas = {};
    final Map<String, int> prestamosPorDia = {};

    final startDoc = _docFormat.format(inicio);
    final endDoc = _docFormat.format(fin);

    // Una sola consulta para traer todos los documentos del rango
    final snapshot = await _firestore
        .collection('estadisticas_diarias')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDoc)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endDoc)
        .get();

    final docsMap = {for (final doc in snapshot.docs) doc.id: doc.data()};

    // Itera día a día para rellenar todos los días (incluso con 0)
    DateTime current = DateTime(inicio.year, inicio.month, inicio.day);
    final end = DateTime(fin.year, fin.month, fin.day);

    while (!current.isAfter(end)) {
      final fechaDoc = _docFormat.format(current);
      final displayKey = _displayFormat.format(current);
      final data = docsMap[fechaDoc];

      if (data != null) {
        final diaAceptadas = (data['aceptadas'] as num?)?.toInt() ?? 0;
        solicitadas += (data['solicitadas'] as num?)?.toInt() ?? 0;
        aceptadas += diaAceptadas;
        rechazadas += (data['rechazadas'] as num?)?.toInt() ?? 0;
        devueltos += (data['devueltos'] as num?)?.toInt() ?? 0;

        prestamosPorDia[displayKey] = diaAceptadas;

        final equiposData =
            data['equipos'] as Map<String, dynamic>? ?? {};
        for (final entry in equiposData.entries) {
          equipos[entry.key] =
              (equipos[entry.key] ?? 0) + ((entry.value as num).toInt());
        }

        final asignaturasData =
            data['asignaturas'] as Map<String, dynamic>? ?? {};
        for (final entry in asignaturasData.entries) {
          asignaturas[entry.key] =
              (asignaturas[entry.key] ?? 0) + ((entry.value as num).toInt());
        }
      } else {
        prestamosPorDia[displayKey] = 0;
      }

      current = current.add(const Duration(days: 1));
    }

    // Top 5 equipos ordenados por cantidad descendente
    final sortedEquipos = equipos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Equipos = Map.fromEntries(sortedEquipos.take(5));

    return {
      'solicitadas': solicitadas,
      'aceptadas': aceptadas,
      'rechazadas': rechazadas,
      'devueltos': devueltos,
      'top5Equipos': top5Equipos,
      'asignaturas': asignaturas,
      'prestamosPorDia': prestamosPorDia,
    };
  }

  /// Obtiene datos completos de solicitudes aceptadas para exportación a Excel.
  /// Usa la colección usuarios_con_equipos donde se guardan las solicitudes aceptadas.
  Future<List<Map<String, dynamic>>> obtenerDatosParaExportar(
    DateTime inicio,
    DateTime fin,
  ) async {
    final query = await _firestore
        .collection('usuarios_con_equipos')
        .where('fecha_envio',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_envio', isLessThanOrEqualTo: Timestamp.fromDate(fin))
        .get();

    final List<Map<String, dynamic>> datos = [];

    for (final doc in query.docs) {
      final data = doc.data();

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
        'estado': 'Aceptada',
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
