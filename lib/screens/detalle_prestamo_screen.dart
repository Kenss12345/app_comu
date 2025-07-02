import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'mapa_screen.dart';

class DetallePrestamoScreen extends StatelessWidget {
  final Map<String, dynamic> estudiante;

  const DetallePrestamoScreen({super.key, required this.estudiante});

  @override
  Widget build(BuildContext context) {
    final tiempo = estudiante['tiempo_restante'] as Duration?;

    // Utilidad para mostrar nulo o vacío
    String mostrar(dynamic campo) =>
        (campo == null || campo.toString().isEmpty) ? "---" : campo.toString();

    // Formatea fechaDevolucion y timestamp_solicitud si es Timestamp
    String formateaFecha(dynamic fecha) {
      if (fecha == null) return "---";
      if (fecha is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm').format(fecha.toDate());
      }
      return fecha.toString();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Regresar',
        ),
        title: Text(
          "Detalle de Préstamo",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          margin: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          child: Card(
            elevation: 10,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.assignment_turned_in,
                            color: Colors.orange.shade700, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        "Detalle de Préstamo",
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.orange.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                      child: Wrap(
                        spacing: 30,
                        runSpacing: 14,
                        children: [
                          _detalleDato("Nombre", mostrar(estudiante['nombre'])),
                          _detalleDato("DNI", mostrar(estudiante['dni'])),
                          _detalleDato(
                              "Tipo de Usuario", mostrar(estudiante['TipoUser'])),
                          _detalleDato("Puntos", mostrar(estudiante['puntos'])),
                          _detalleDato("Correo", mostrar(estudiante['email'])),
                          _detalleDato("Celular", mostrar(estudiante['celular'])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: Colors.blue.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                      child: Wrap(
                        spacing: 30,
                        runSpacing: 14,
                        children: [
                          _detalleDato("Equipo", mostrar(estudiante['equipo'])),
                          _detalleDato(
                              "Código UC", mostrar(estudiante['codigoUC'])),
                          _detalleDato(
                              "Condición", mostrar(estudiante['condicion'])),
                          _detalleDato(
                              "Tipo Equipo", mostrar(estudiante['tipoEquipo'])),
                          _detalleDato("Estado", mostrar(estudiante['estado'])),
                          _detalleDato("Estado préstamo",
                              mostrar(estudiante['estado_prestamo'])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: Colors.green.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                      child: Wrap(
                        spacing: 30,
                        runSpacing: 14,
                        children: [
                          _detalleDato("Fecha/hora solicitud",
                              formateaFecha(estudiante['timestamp_solicitud'])),
                          _detalleDato(
                              "Fecha/hora devolución",
                              formateaFecha(estudiante['fechaDevolucion'] ??
                                  estudiante['fecha_devolucion'])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: tiempo?.inSeconds.isNegative == true
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            tiempo?.inSeconds.isNegative == true
                                ? Icons.warning
                                : Icons.timer,
                            color: tiempo?.inSeconds.isNegative == true
                                ? Colors.red
                                : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              (tiempo == null)
                                  ? "No disponible"
                                  : tiempo.inSeconds.isNegative
                                      ? "Tiempo excedido: "+
                                          (-tiempo.inHours).toString()+"h "+
                                          (-tiempo.inMinutes.remainder(60)).toString()+"m"
                                      : "Tiempo restante: "+
                                          (tiempo.inHours).toString()+"h "+
                                          (tiempo.inMinutes.remainder(60)).toString()+"m",
                              style: TextStyle(
                                color: tiempo?.inSeconds.isNegative == true
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => MapaScreen()));
                        },
                        icon: const Icon(Icons.map),
                        label: const Text("Buscar en el Mapa"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper para mostrar cada campo con diseño uniforme
  Widget _detalleDato(String label, String valor) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          Expanded(
              child:
                  Text(valor, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}
