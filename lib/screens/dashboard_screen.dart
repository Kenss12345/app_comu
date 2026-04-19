import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/estadisticas_service.dart';
import '../utils/excel_exporter.dart';
import '../utils/responsive_breakpoints.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final EstadisticasService _estadisticasService = EstadisticasService();

  // Filtros temporales
  String _filtroSeleccionado = '7'; // '1', '7', '30', 'custom'
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaFin = DateTime.now();

  // Datos cargados
  bool _cargando = true;
  int _solicitadas = 0;
  int _aceptadas = 0;
  int _rechazadas = 0;
  int _devueltos = 0;
  Map<String, int> _equiposMasSolicitados = {};
  Map<String, int> _asignaturas = {};
  Map<String, int> _prestamosPorDia = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final resultado = await _estadisticasService.obtenerEstadisticasPorRango(
        _fechaInicio,
        _fechaFin,
      );

      setState(() {
        _solicitadas = resultado['solicitadas'] as int;
        _aceptadas = resultado['aceptadas'] as int;
        _rechazadas = resultado['rechazadas'] as int;
        _devueltos = resultado['devueltos'] as int;
        _equiposMasSolicitados =
            Map<String, int>.from(resultado['top5Equipos'] as Map);
        _asignaturas =
            Map<String, int>.from(resultado['asignaturas'] as Map);
        _prestamosPorDia =
            Map<String, int>.from(resultado['prestamosPorDia'] as Map);
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cambiarFiltro(String filtro) {
    setState(() {
      _filtroSeleccionado = filtro;
      switch (filtro) {
        case '1':
          _fechaInicio = DateTime.now().subtract(const Duration(days: 1));
          _fechaFin = DateTime.now();
          break;
        case '7':
          _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
          _fechaFin = DateTime.now();
          break;
        case '30':
          _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
          _fechaFin = DateTime.now();
          break;
      }
    });
    if (filtro != 'custom') {
      _cargarDatos();
    }
  }

  Future<void> _seleccionarRangoFechas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
        _filtroSeleccionado = 'custom';
      });
      _cargarDatos();
    }
  }

  Future<void> _exportarExcel() async {
    try {
      final datos = await _estadisticasService.obtenerDatosParaExportar(
        _fechaInicio,
        _fechaFin,
      );

      if (datos.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay datos para exportar en este rango'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final nombreArchivo = ExcelExporter.generarNombreArchivo(
        'Reporte_Prestamos',
        _filtroSeleccionado == 'custom'
            ? '${DateFormat('ddMMyy').format(_fechaInicio)}_${DateFormat('ddMMyy').format(_fechaFin)}'
            : '${_filtroSeleccionado}dias',
      );

      await ExcelExporter.exportarSolicitudes(datos, nombreArchivo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel descargado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveBreakpoints.isMobile(context);
        final isTablet = ResponsiveBreakpoints.isTablet(context);

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: _cargando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Text(
                        '📊 Dashboard de Préstamos',
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Análisis y estadísticas de equipos',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filtros temporales
                      _buildFiltrosTemporales(isMobile),
                      const SizedBox(height: 24),

                      // Tarjetas de estadísticas (sin "En Uso")
                      _buildTarjetasEstadisticas(isMobile, isTablet),
                      const SizedBox(height: 24),

                      // Gráficos
                      if (isMobile) ...[
                        _buildGraficoLineas(isMobile),
                        const SizedBox(height: 24),
                        _buildGraficoBarras(isMobile),
                        const SizedBox(height: 24),
                        _buildGraficoCircular(isMobile),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildGraficoLineas(isMobile)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGraficoBarras(isMobile)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildGraficoCircular(isMobile),
                      ],

                      const SizedBox(height: 32),

                      // Botón exportar
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _exportarExcel,
                          icon: const Icon(Icons.download),
                          label: const Text('Descargar Reporte Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 24 : 32,
                              vertical: isMobile ? 12 : 16,
                            ),
                            textStyle: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildFiltrosTemporales(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Período:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildBotonesFiltro(),
                  ),
                ],
              )
            : Row(
                children: [
                  Text(
                    'Período:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 8,
                    children: _buildBotonesFiltro(),
                  ),
                  const Spacer(),
                  if (_filtroSeleccionado == 'custom')
                    Text(
                      '${DateFormat('dd/MM/yy').format(_fechaInicio)} - ${DateFormat('dd/MM/yy').format(_fechaFin)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildBotonesFiltro() {
    return [
      _buildBotonFiltro('Hoy', '1'),
      _buildBotonFiltro('Últimos 7 días', '7'),
      _buildBotonFiltro('Últimos 30 días', '30'),
      _buildBotonFiltro('Rango', 'custom'),
    ];
  }

  Widget _buildBotonFiltro(String label, String valor) {
    final seleccionado = _filtroSeleccionado == valor;
    return ElevatedButton(
      onPressed: () {
        if (valor == 'custom') {
          _seleccionarRangoFechas();
        } else {
          _cambiarFiltro(valor);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            seleccionado ? Colors.orange.shade700 : Colors.white,
        foregroundColor:
            seleccionado ? Colors.white : Colors.grey.shade700,
        elevation: seleccionado ? 4 : 1,
        side: BorderSide(
          color: seleccionado
              ? Colors.orange.shade700
              : Colors.grey.shade300,
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildTarjetasEstadisticas(bool isMobile, bool isTablet) {
    final crossAxisCount = isMobile ? 2 : (isTablet ? 2 : 4);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.3 : 1.5,
      children: [
        _buildTarjetaEstadistica(
          'Solicitadas',
          _solicitadas.toString(),
          Icons.mail_outline,
          Colors.blue,
        ),
        _buildTarjetaEstadistica(
          'Aceptadas',
          _aceptadas.toString(),
          Icons.check_circle_outline,
          Colors.green,
        ),
        _buildTarjetaEstadistica(
          'Rechazadas',
          _rechazadas.toString(),
          Icons.cancel_outlined,
          Colors.red,
        ),
        _buildTarjetaEstadistica(
          'Devueltos',
          _devueltos.toString(),
          Icons.assignment_turned_in,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildTarjetaEstadistica(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoLineas(bool isMobile) {
    if (_prestamosPorDia.isEmpty) {
      return _buildGraficoVacio('Préstamos por Período', isMobile);
    }

    final entries = _prestamosPorDia.entries.toList();
    final maxY = entries.isEmpty
        ? 10.0
        : entries
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();

    // Muestra hasta 10 etiquetas en el eje X para no saturar
    final totalEntries = entries.length;
    final labelStep = (totalEntries / 10).ceil().clamp(1, totalEntries);

    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 Préstamos por Período',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: isMobile ? 200 : 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 &&
                              index < entries.length &&
                              index % labelStep == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                entries[index].key,
                                style: TextStyle(
                                  fontSize: isMobile ? 9 : 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (entries.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY + 2,
                  lineBarsData: [
                    LineChartBarData(
                      spots: entries
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                                e.key.toDouble(),
                                e.value.value.toDouble(),
                              ))
                          .toList(),
                      isCurved: true,
                      color: Colors.orange.shade700,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.shade700.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoBarras(bool isMobile) {
    if (_equiposMasSolicitados.isEmpty) {
      return _buildGraficoVacio('Top 5 Equipos Más Solicitados', isMobile);
    }

    final entries = _equiposMasSolicitados.entries.take(5).toList();
    final maxY = entries.isEmpty
        ? 10.0
        : entries
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();

    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📦 Top 5 Equipos Más Solicitados',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: isMobile ? 200 : 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < entries.length) {
                            final nombre = entries[index].key;
                            final nombreCorto = nombre.length > 15
                                ? '${nombre.substring(0, 12)}...'
                                : nombre;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Transform.rotate(
                                angle: -0.5,
                                child: Text(
                                  nombreCorto,
                                  style: TextStyle(
                                    fontSize: isMobile ? 9 : 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY + 2,
                  barGroups: entries
                      .asMap()
                      .entries
                      .map(
                        (e) => BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.value.toDouble(),
                              color: Colors.blue.shade600,
                              width: isMobile ? 20 : 30,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoCircular(bool isMobile) {
    if (_asignaturas.isEmpty) {
      return _buildGraficoVacio('Distribución por Asignatura', isMobile);
    }

    final total = _asignaturas.values.reduce((a, b) => a + b);
    final colores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📚 Distribución por Asignatura',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: isMobile ? 250 : 300,
              child: Row(
                children: [
                  Expanded(
                    flex: isMobile ? 2 : 1,
                    child: PieChart(
                      PieChartData(
                        sections: _asignaturas.entries
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final asignatura = entry.value;
                          final porcentaje =
                              (asignatura.value / total) * 100;
                          return PieChartSectionData(
                            color: colores[index % colores.length],
                            value: asignatura.value.toDouble(),
                            title: '${porcentaje.toStringAsFixed(1)}%',
                            radius: isMobile ? 60 : 80,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _asignaturas.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final asignatura = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colores[index % colores.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${asignatura.key}: ${asignatura.value}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 14,
                                    color: Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoVacio(String titulo, bool isMobile) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.insert_chart_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay datos para mostrar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
