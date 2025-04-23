import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_comu/utils/carrito_equipos.dart';

class EquiposACargoScreen extends StatefulWidget {
  const EquiposACargoScreen({super.key});

  @override
  _EquiposACargoScreenState createState() => _EquiposACargoScreenState();
}

class _EquiposACargoScreenState extends State<EquiposACargoScreen> {
  

  /*List<Map<String, dynamic>> equiposACargo = [
    {
      "nombre": "Cámara Sony Alpha",
      "fecha_prestamo": "2025-03-10",
      "fecha_devolucion": "2025-03-17",
      "imagen": "assets/camara_sony.png",
    },
    {
      "nombre": "Micrófono Rode NT1",
      "fecha_prestamo": "2025-03-05",
      "fecha_devolucion": "2025-03-12",
      "imagen": "assets/microfono_rode.png",
    },
    {
      "nombre": "Luz LED Neewer",
      "fecha_prestamo": "2025-03-15",
      "fecha_devolucion": "2025-03-22",
      "imagen": "assets/luz_neewer.png",
    },
  ];*/

  List<Map<String, dynamic>> get equiposACargo => CarritoEquipos().equipos;

  //bool solicitando = false;
  bool solicitudRealizada = false;

  /*Duration tiempoRestante = Duration(hours: 48); // Tiempo de ejemplo
  Timer? _timer;

  void _iniciarContador() {
  _timer = Timer.periodic(Duration(seconds: 1), (timer) {
    if (mounted) {  // Verifica si el widget sigue en el árbol
      setState(() {
        if (tiempoRestante.inSeconds > 0) {
          tiempoRestante = tiempoRestante - Duration(seconds: 1);
        } else {
          _timer?.cancel();
        }
      });
    } else {
      _timer?.cancel(); // Cancela el timer si el widget ya no está montado
    }
  });
}*/

  void _eliminarEquipo(int index) {
    setState(() {
      CarritoEquipos().eliminarEquipo(index);
    });
  }

  Future<void> _navegarYSolicitarEquipos() async {
    final resultado = await Navigator.pushNamed(context, '/solicitud_equipos');

    // Si se envió la solicitud, refrescar pantalla
    if (resultado == true) {
      setState(() {});
    }
  }

  bool _hayEquiposEnUso() {
    return equiposACargo.any((equipo) => equipo["estado_prestamo"] == "en uso");
  }

  /*void _solicitarEquipos() {
    setState(() {
      solicitudRealizada = true;
      //_iniciarContador();
    });
  }*/

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos a Cargo"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: equiposACargo.length,
                itemBuilder: (context, index) {
                  var equipo = equiposACargo[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    child: ListTile(
                      leading: Image.network(
                        equipo["imagen"],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(
                        equipo["nombre"],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Préstamo: ${equipo["fecha_prestamo"]}"),
                          Text("Devolución: ${equipo["fecha_devolucion"]}"),
                          Text("Estado: ${equipo["estado_prestamo"]}", style: TextStyle(color: Colors.orange)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => _eliminarEquipo(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!solicitudRealizada)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    solicitudRealizada = true;
                    _iniciarContador();
                  });
                  Navigator.pushNamed(context, '/solicitud_equipos');
                },
                child: Text("Solicitar Equipos"),
              )

            else
              Column(
                children: [
                  Text(
                    "Tiempo restante de entrega:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${tiempoRestante.inHours}:${(tiempoRestante.inMinutes % 60).toString().padLeft(2, '0')}:${(tiempoRestante.inSeconds % 60).toString().padLeft(2, '0')}",
                    style: TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }*/

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos a Cargo"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Text(
                "🕒 Horario de devolución: Lunes a viernes de 8:00 am a 1:00 pm y sábado de 9:00 am a 1:00 pm",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),

            if (equiposACargo.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    "Ningún equipo a cargo",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: equiposACargo.length,
                  itemBuilder: (context, index) {
                    var equipo = equiposACargo[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 3,
                      child: ListTile(
                        leading: Image.network(
                          equipo["imagen"],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          equipo["nombre"],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Préstamo: ${equipo["fecha_prestamo"]}"),
                            Text("Devolución: ${equipo["fecha_devolucion"]}"),
                            Text(
                              "Estado: ${equipo["estado_prestamo"]}",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _eliminarEquipo(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            if (equiposACargo.isNotEmpty && !solicitudRealizada)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    solicitudRealizada = true;
                    //_iniciarContador();
                  });
                  Navigator.pushNamed(context, '/solicitud_equipos');
                },
                child: const Text("Solicitar Equipos"),
              )
            /*else if (solicitudRealizada)
              Column(
                children: [
                  const Text(
                    "Tiempo restante de entrega:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${tiempoRestante.inHours}:${(tiempoRestante.inMinutes % 60).toString().padLeft(2, '0')}:${(tiempoRestante.inSeconds % 60).toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),*/
          ],
        ),
      ),
    );
  }*/

  /*@override
  Widget build(BuildContext context) {
    final hayEquiposEnUso = _hayEquiposEnUso();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos a Cargo"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Text(
                "🕒 Horario de devolución: Lunes a viernes de 8:00 am a 1:00 pm y sábado de 9:00 am a 1:00 pm",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),
            if (equiposACargo.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    "Ningún equipo a cargo",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: equiposACargo.length,
                  itemBuilder: (context, index) {
                    var equipo = equiposACargo[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 3,
                      child: ListTile(
                        leading: Image.network(
                          equipo["imagen"],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          equipo["nombre"],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Préstamo: ${equipo["fecha_prestamo"]}"),
                            Text("Devolución: ${equipo["fecha_devolucion"]}"),
                            Text(
                              "Estado: ${equipo["estado_prestamo"]}",
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _eliminarEquipo(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            if (equiposACargo.isNotEmpty && !solicitudRealizada && !hayEquiposEnUso)
              ElevatedButton(
                onPressed: _navegarYSolicitarEquipos,
                child: const Text("Solicitar Equipos"),
              )
            else if (hayEquiposEnUso)
              const Text(
                "No puedes solicitar nuevos equipos mientras tienes equipos en uso.",
                style: TextStyle(color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }*/

  @override
  Widget build(BuildContext context) {
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _eliminarEquipo(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            if (equiposACargo.isNotEmpty && !solicitudRealizada && !hayEquiposEnUso)
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


/*class _EquiposACargoScreenState extends State<EquiposACargoScreen> {
  // Lista simulada de equipos en préstamo
  final List<Map<String, dynamic>> equiposACargo = [
    {
      "nombre": "Cámara Sony Alpha",
      "fecha_prestamo": "2025-03-10",
      "fecha_devolucion": "2025-03-17",
      "imagen": "assets/camara_sony.png",
      "estado": "A tiempo"
    },
    {
      "nombre": "Micrófono Rode NT1",
      "fecha_prestamo": "2025-03-05",
      "fecha_devolucion": "2025-03-12",
      "imagen": "assets/microfono_rode.png",
      "estado": "Vencido"
    },
    {
      "nombre": "Luz LED Neewer",
      "fecha_prestamo": "2025-03-15",
      "fecha_devolucion": "2025-03-22",
      "imagen": "assets/luz_neewer.png",
      "estado": "A tiempo"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipos a Cargo"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView.builder(
          itemCount: equiposACargo.length,
          itemBuilder: (context, index) {
            var equipo = equiposACargo[index];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              child: ListTile(
                leading: Image.asset(
                  equipo["imagen"],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
                title: Text(
                  equipo["nombre"],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Préstamo: ${equipo["fecha_prestamo"]}"),
                    Text("Devolución: ${equipo["fecha_devolucion"]}"),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    equipo["estado"],
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: equipo["estado"] == "A tiempo" ? Colors.green : Colors.red,
                ),
                onTap: () {
                  // Aquí se puede agregar más funcionalidad en el futuro
                },
              ),
            );
          },
        ),
      ),
    );
  }
}*/
