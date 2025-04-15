class CarritoEquipos {
  static final CarritoEquipos _instancia = CarritoEquipos._interna();
  factory CarritoEquipos() => _instancia;
  CarritoEquipos._interna();

  final List<Map<String, dynamic>> _equipos = [];

  List<Map<String, dynamic>> get equipos => _equipos;

  void agregarEquipo(Map<String, dynamic> equipo) {
    _equipos.add(equipo);
  }

  void eliminarEquipo(int index) {
    _equipos.removeAt(index);
  }

  void limpiarCarrito() {
    _equipos.clear();
  }
}
