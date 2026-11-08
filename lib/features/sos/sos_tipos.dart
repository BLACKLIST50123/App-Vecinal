import 'package:flutter/material.dart';
import '../../ui/tema.dart';

/// Colores del modo SOS.
class ColoresSos {
  static Color get rojo => Paleta.rojo; // Rojo Alerta Crítica
  static Color get rojoOscuro => Paleta.rojoTexto;
  static Color get rojoSuave => Paleta.rojoSuave;
  static Color get ambar => Paleta.ambar; // advertencia (desastres naturales)
  static Color get ambarSuave => Paleta.ambarSuave;
}

/// Reportes de un toque ("One-Tap Reporting"). Elegidos según las
/// emergencias más frecuentes en barrios del Perú (INEI, INDECI, Bomberos,
/// PNP): válidos para cualquier ciudad, no solo la zona de la demo.
/// Ver docs/SOS.md.
enum TipoSos {
  medico(
    titulo: 'Emergencia Médica',
    subtitulo: 'Necesito atención',
    icono: Icons.medical_services_outlined,
    categoria: 'salud',
    reporte: 'SOS: necesito atención médica',
    prioridad: 'critica',
  ),
  inseguridad(
    titulo: 'Inseguridad',
    subtitulo: 'Robo, secuestro, extorsión',
    icono: Icons.shield_outlined,
    categoria: 'inseguridad',
    reporte: 'SOS: riesgo o amenaza',
    prioridad: 'critica',
  ),
  inundacion(
    titulo: 'Lluvia o Inundación',
    subtitulo: 'Agua en casa o huaico',
    icono: Icons.flood_outlined,
    categoria: 'inundacion',
    reporte: 'SOS: lluvia intensa, inundación o huaico',
    prioridad: 'critica',
    advertencia: true,
  ),
  incendio(
    titulo: 'Incendio o Gas',
    subtitulo: 'Fuego, humo o fuga de gas',
    icono: Icons.local_fire_department_outlined,
    categoria: 'incendio',
    reporte: 'SOS: incendio o fuga de gas',
    prioridad: 'critica',
  ),
  accidente(
    titulo: 'Accidente',
    subtitulo: 'Choque o atropello',
    icono: Icons.car_crash_outlined,
    categoria: 'accidente',
    reporte: 'SOS: accidente de tránsito',
    prioridad: 'critica',
  ),
  sismo(
    titulo: 'Sismo',
    subtitulo: 'Reportar daños',
    icono: Icons.house_outlined,
    categoria: 'sismo',
    reporte: 'SOS: daños por sismo',
    prioridad: 'critica',
    advertencia: true,
  ),

  // ---- Subtipos de Inseguridad (segundo toque) ----
  robo(
    titulo: 'Robo',
    subtitulo: 'Me están robando o acaban de hacerlo',
    icono: Icons.directions_run,
    categoria: 'inseguridad',
    reporte: 'SOS: robo en curso',
    prioridad: 'critica',
  ),
  secuestro(
    titulo: 'Secuestro',
    subtitulo: 'Se llevaron a alguien o lo retienen',
    icono: Icons.person_off_outlined,
    categoria: 'inseguridad',
    reporte: 'SOS reservado: posible secuestro',
    prioridad: 'critica',
    reservado: true,
  ),
  extorsion(
    titulo: 'Extorsión',
    subtitulo: 'Me amenazan para pedir dinero',
    icono: Icons.money_off_csred_outlined,
    categoria: 'inseguridad',
    reporte: 'SOS reservado: extorsión',
    prioridad: 'alta',
    reservado: true,
  ),
  violencia(
    titulo: 'Violencia',
    subtitulo: 'Agresión o violencia en casa',
    icono: Icons.front_hand_outlined,
    categoria: 'inseguridad',
    reporte: 'SOS reservado: violencia o agresión',
    prioridad: 'critica',
    reservado: true,
  );

  const TipoSos({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.categoria,
    required this.reporte,
    required this.prioridad,
    this.advertencia = false,
    this.reservado = false,
  });

  final String titulo, subtitulo, categoria, reporte, prioridad;
  final IconData icono;

  /// Resaltado en ámbar (desastre natural) en lugar de rojo.
  final bool advertencia;

  /// Aviso reservado: solo lo ven la junta y las organizaciones de apoyo.
  /// Publicarlo para todos podría alertar al agresor.
  final bool reservado;

  /// Tarjetas de la primera pantalla.
  static const principales = [medico, inseguridad, inundacion, incendio, accidente, sismo];

  /// Opciones al tocar "Inseguridad".
  static const deInseguridad = [robo, secuestro, extorsion, violencia];

  bool get abreSubmenu => this == inseguridad;

  Color get color => advertencia ? ColoresSos.ambar : ColoresSos.rojo;
  Color get colorSuave => advertencia ? ColoresSos.ambarSuave : ColoresSos.rojoSuave;

  /// Consejo inmediato y seguro según el tipo.
  String? get consejo => switch (this) {
        extorsion => 'No pagues ni negocies. Guarda los mensajes y números, y denuncia al 105.',
        secuestro => 'No intentes intervenir solo. Anota placas, ropa y dirección, y llama al 105.',
        violencia => 'Si puedes, ve a un lugar seguro y con gente. Llama al 105.',
        robo => 'No te enfrentes. Tu vida vale más. Busca un lugar seguro.',
        inundacion => 'Sube a un lugar alto, aléjate de ríos y quebradas, y corta la luz si es seguro.',
        incendio => 'Sal de inmediato. Si huele a gas, no prendas luces ni fósforos y abre puertas. Bomberos: 116.',
        accidente => 'No muevas a los heridos. Señaliza la zona y llama al 106 (SAMU) o al 116.',
        sismo => 'Aléjate de paredes dañadas. Si estás en la costa, ve a una zona alta por riesgo de tsunami.',
        _ => null,
      };
}
