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


  bool solicitando = false;
  bool solicitudRealizada = false;
  Duration tiempoRestante = Duration(hours: 48); // Tiempo de ejemplo
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
}

  void _eliminarEquipo(int index) {
    setState(() {
      CarritoEquipos().eliminarEquipo(index);
    });
  }

  void _solicitarEquipos() {
    setState(() {
      solicitudRealizada = true;
      _iniciarContador();
    });
  }

  @override
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
