import 'package:flutter/material.dart';

/// Colores del modo SOS.
class ColoresSos {
  static const rojo = Color(0xFFE53935); // Rojo Alerta Crítica
  static const rojoOscuro = Color(0xFFB71C1C);
  static const rojoSuave = Color(0xFFFFEBEE);
  static const ambar = Color(0xFFEF6C00); // advertencia (sismo)
  static const ambarSuave = Color(0xFFFFF3E0);
}

/// Reportes de un toque ("One-Tap Reporting").
enum TipoSos {
  medico(
    titulo: 'Auxilio Médico',
    subtitulo: 'Necesito atención',
    icono: Icons.medical_services_outlined,
    categoria: 'salud',
    reporte: 'SOS: necesito atención médica',
    prioridad: 'critica',
  ),
  inseguridad(
    titulo: 'Inseguridad',
    subtitulo: 'Riesgo o amenaza',
    icono: Icons.shield_outlined,
    categoria: 'inseguridad',
    reporte: 'SOS: estoy en riesgo o bajo amenaza',
    prioridad: 'critica',
  ),
  agua(
    titulo: 'Falta de Agua',
    subtitulo: 'Corte no informado',
    icono: Icons.water_drop_outlined,
    categoria: 'agua_alimento',
    reporte: 'SOS: corte de agua no informado',
    prioridad: 'alta',
  ),
  sismo(
    titulo: 'Sismo',
    subtitulo: 'Reportar daños',
    icono: Icons.house_outlined,
    categoria: 'sismo',
    reporte: 'SOS: daños por sismo',
    prioridad: 'critica',
    advertencia: true,
  );

  const TipoSos({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.categoria,
    required this.reporte,
    required this.prioridad,
    this.advertencia = false,
  });

  final String titulo, subtitulo, categoria, reporte, prioridad;
  final IconData icono;

  /// Resaltado en ámbar (advertencia) en lugar de rojo.
  final bool advertencia;

  Color get color => advertencia ? ColoresSos.ambar : ColoresSos.rojo;
  Color get colorSuave => advertencia ? ColoresSos.ambarSuave : ColoresSos.rojoSuave;
}
