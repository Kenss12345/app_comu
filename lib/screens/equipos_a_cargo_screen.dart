import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_comu/utils/carrito_equipos.dart';

class EquiposACargoScreen extends StatefulWidget {
  const EquiposACargoScreen({super.key});

  @override
  _EquiposACargoScreenState createState() => _EquiposACargoScreenState();
}

class _EquiposACargoScreenState extends State<EquiposACargoScreen> {
  
  List<Map<String, dynamic>> equiposACargo = [];
  bool _cargando = true;

  //bool solicitando = false;
  bool solicitudRealizada = false;
  bool haySolicitudPendiente = false;
  bool hayEquiposEnUso = false;

  //cargar desde Firestore:
  Future<void> _cargarEquiposDesdeFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('equipos_a_cargo')
          .get();
      
      final equipos = snapshot.docs.map((doc) => doc.data()).cast<Map<String, dynamic>>().toList();

      bool solicitudPendiente = await _tieneSolicitudPendiente();
      bool enUso = equipos.any((e) => (e['estado_prestamo'] ?? "").toLowerCase() == "en uso");

      setState(() {
        equiposACargo = equipos;
        haySolicitudPendiente = solicitudPendiente;
        hayEquiposEnUso = enUso;
        _cargando = false;
      });
    } else {
      setState(() {
        equiposACargo = [];
        haySolicitudPendiente = false;
        hayEquiposEnUso = false;
        _cargando = false;
      });
    }
  }

  void _eliminarEquipo(int index) async {
    final equipo = equiposACargo[index];
    final equipoId = equipo['id'];
    final user = FirebaseAuth.instance.currentUser;

    try {
      // Transacción para cambiar el estado a "Disponible" en Firestore
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final equipoDocRef = FirebaseFirestore.instance.collection('equipos').doc(equipoId);
        final snapshot = await transaction.get(equipoDocRef);

        if (!snapshot.exists) {
          throw Exception("El equipo ya no existe en Firestore.");
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final estadoActual = data['estado'];

        // Solo permite cambiar si el estado es "Pendiente"
        if (estadoActual != "Pendiente") {
          throw Exception("El equipo no está en estado 'Pendiente'.");
        }

        // Actualiza el estado a "Disponible"
        transaction.update(equipoDocRef, {
          'estado': 'Disponible',
        });
      });

      // Si la transacción fue exitosa, lo eliminamos del carrito local
      setState(() {
        CarritoEquipos().eliminarEquipo(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${equipo["nombre"]} eliminado y disponible nuevamente.")),
      );

      // Elimina del Firestore del usuario
      if (user != null) {
        await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('equipos_a_cargo')
          .doc(equipoId)
          .delete();
      }

      // Elimina de la lista local
      setState(() {
        equiposACargo.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${equipo["nombre"]} eliminado y disponible nuevamente.")),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al eliminar: ${e.toString()}")),
      );
    }
  }

  Future<bool> _tieneSolicitudPendiente() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // Busca una solicitud en la colección 'solicitudes' donde uid sea igual al del usuario actual
    final snapshot = await FirebaseFirestore.instance
        .collection('solicitudes')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _navegarYSolicitarEquipos() async {
    final resultado = await Navigator.pushNamed(context, '/solicitud_equipos');
    if (resultado == true) {
      await _cargarEquiposDesdeFirestore();
    }
  }

  bool _hayEquiposEnUso() {
    return equiposACargo.any((equipo) => equipo["estado"] == "En Uso");
  }

  @override
  void initState() {
    super.initState();
    _cargarEquiposDesdeFirestore();
  }

  @override
  Widget build(BuildContext context) {

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final hayEquiposEnUso = _hayEquiposEnUso();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos a Cargo"),
        backgroundColor: Colors.orange.shade600,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              child: const Row(
                children: [
                  Icon(Icons.access_time, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Horario de devolución: Lunes a viernes de 8:00 am a 1:00 pm y sábado de 9:00 am a 1:00 pm",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            if (equiposACargo.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    "📭 Ningún equipo a cargo",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: equiposACargo.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    var equipo = equiposACargo[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            equipo["imagen"],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          equipo["nombre"],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("📅 Préstamo: ${equipo["fecha_prestamo"]}"),
                              Text("📆 Devolución: ${equipo["fecha_devolucion"]}"),
                              const SizedBox(height: 4),
                              Text(
                                "🟠 Estado: ${equipo["estado_prestamo"]}",
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: (!haySolicitudPendiente && !hayEquiposEnUso)
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _eliminarEquipo(index),
                            )
                          : null,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            if (equiposACargo.isNotEmpty && !haySolicitudPendiente && !hayEquiposEnUso)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navegarYSolicitarEquipos,
                  icon: const Icon(Icons.send),
                  label: const Text("Solicitar Equipos"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (haySolicitudPendiente)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "⏳ Tu solicitud está en espera de confirmación.",
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (hayEquiposEnUso)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "⚠️ No puedes solicitar nuevos equipos mientras tienes equipos en uso.",
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
