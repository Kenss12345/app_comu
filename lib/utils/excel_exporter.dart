import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;

class ExcelExporter {
  /// Exporta solicitudes a un archivo Excel
  static Future<void> exportarSolicitudes(
    List<Map<String, dynamic>> datos,
    String nombreArchivo,
  ) async {
    try {
      // Crear archivo Excel
      var excel = Excel.createExcel();
      
      // Eliminar hoja por defecto
      excel.delete('Sheet1');
      
      // Crear hoja de datos
      Sheet sheetData = excel['Reporte_Solicitudes'];
      
      // Establecer estilos para encabezados
      CellStyle headerStyle = CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: ExcelColor.fromHexString('#FF6B35'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // Definir encabezados
      final headers = [
        'Fecha Solicitud',
        'Nombre',
        'DNI',
        'Email',
        'Celular',
        'Equipos',
        'Cant. Equipos',
        'Estado',
        'Asignatura',
        'Trabajo',
        'Docente',
        'Lugar de Uso',
        'Fecha Préstamo',
        'Fecha Devolución',
        'Días Préstamo',
      ];

      // Escribir encabezados
      for (int i = 0; i < headers.length; i++) {
        var cell = sheetData.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Escribir datos
      for (int rowIndex = 0; rowIndex < datos.length; rowIndex++) {
        final solicitud = datos[rowIndex];
        final excelRow = rowIndex + 1;

        final rowData = [
          solicitud['fecha_envio'] ?? 'N/A',
          solicitud['nombre'] ?? 'Sin nombre',
          solicitud['dni'] ?? 'N/A',
          solicitud['email'] ?? 'N/A',
          solicitud['celular'] ?? 'N/A',
          solicitud['equipos'] ?? 'Sin equipos',
          solicitud['cantidad_equipos']?.toString() ?? '0',
          solicitud['estado'] ?? 'Pendiente',
          solicitud['asignatura'] ?? 'N/A',
          solicitud['trabajo'] ?? 'N/A',
          solicitud['docente'] ?? 'N/A',
          solicitud['lugar'] ?? 'N/A',
          solicitud['fecha_prestamo'] ?? 'N/A',
          solicitud['fecha_devolucion'] ?? 'N/A',
          solicitud['dias_prestamo'] ?? 'N/A',
        ];

        for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
          var cell = sheetData.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: excelRow,
            ),
          );
          cell.value = TextCellValue(rowData[colIndex].toString());
        }
      }

      // Ajustar ancho de columnas automáticamente
      for (int i = 0; i < headers.length; i++) {
        sheetData.setColumnWidth(i, 20);
      }

      // Crear hoja de resumen
      Sheet sheetResumen = excel['Resumen'];
      
      // Calcular estadísticas
      int total = datos.length;
      int aceptadas = datos.where((d) => d['estado'] == 'Aceptada').length;
      int rechazadas = datos.where((d) => d['estado'] == 'Rechazada').length;
      int pendientes = datos.where((d) => d['estado'] == 'Pendiente' || d['estado'] == null).length;
      int totalEquipos = datos.fold(0, (sum, d) => sum + (d['cantidad_equipos'] as int? ?? 0));

      // Escribir resumen
      final resumenData = [
        ['REPORTE DE PRÉSTAMOS DE EQUIPOS'],
        ['Fecha de Generación:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())],
        [''],
        ['ESTADÍSTICAS GENERALES'],
        ['Total de Solicitudes:', total.toString()],
        ['Solicitudes Aceptadas:', aceptadas.toString()],
        ['Solicitudes Rechazadas:', rechazadas.toString()],
        ['Solicitudes Pendientes:', pendientes.toString()],
        ['Total de Equipos Solicitados:', totalEquipos.toString()],
        [''],
        ['DISTRIBUCIÓN POR ESTADO'],
        ['Aceptadas: ${((aceptadas / (total > 0 ? total : 1)) * 100).toStringAsFixed(1)}%'],
        ['Rechazadas: ${((rechazadas / (total > 0 ? total : 1)) * 100).toStringAsFixed(1)}%'],
        ['Pendientes: ${((pendientes / (total > 0 ? total : 1)) * 100).toStringAsFixed(1)}%'],
      ];

      for (int i = 0; i < resumenData.length; i++) {
        for (int j = 0; j < resumenData[i].length; j++) {
          var cell = sheetResumen.cell(
            CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          );
          cell.value = TextCellValue(resumenData[i][j]);
          
          if (i == 0) {
            cell.cellStyle = CellStyle(
              bold: true,
              fontSize: 16,
              fontColorHex: ExcelColor.fromHexString('#FF6B35'),
            );
          } else if (resumenData[i][0].contains(':')) {
            if (j == 0) {
              cell.cellStyle = CellStyle(bold: true);
            }
          }
        }
      }

      sheetResumen.setColumnWidth(0, 30);
      sheetResumen.setColumnWidth(1, 20);

      // Codificar archivo
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Error al generar el archivo Excel');
      }

      // Descargar archivo (Web)
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', nombreArchivo)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      throw Exception('Error al exportar Excel: $e');
    }
  }

  /// Genera nombre de archivo con fecha actual
  static String generarNombreArchivo(String prefijo, String filtro) {
    final fecha = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${prefijo}_${filtro}_$fecha.xlsx';
  }
}
