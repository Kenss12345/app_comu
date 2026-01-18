import 'package:flutter/material.dart';

/// Sistema centralizado de breakpoints para diseño responsive
class ResponsiveBreakpoints {
  // Breakpoints estándar
  static const double mobile = 768;
  static const double tablet = 1200;
  static const double desktop = 1920;
  
  /// Verifica si el dispositivo es móvil
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }
  
  /// Verifica si el dispositivo es tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < tablet;
  }
  
  /// Verifica si el dispositivo es desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tablet;
  }
  
  /// Obtiene el padding horizontal según el tamaño de pantalla
  static double getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 40;
  }
  
  /// Obtiene el padding vertical según el tamaño de pantalla
  static double getVerticalPadding(BuildContext context) {
    if (isMobile(context)) return 12;
    if (isTablet(context)) return 20;
    return 32;
  }
  
  /// Obtiene el ancho máximo del contenido
  static double getMaxContentWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 900;
    return 1200;
  }
  
  /// Obtiene el número de columnas para grids
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }
  
  /// Obtiene el tamaño de fuente según el contexto
  static double getFontSize(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }
}

