import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Número de emergencia (nacional o local de la zona).
class NumeroEmergencia {
  const NumeroEmergencia({required this.nombre, required this.numero, required this.tipo, this.local = false});
  final String nombre, numero, tipo;
  final bool local;

  IconData get icono => switch (tipo) {
        'policia' => Icons.local_police_outlined,
        'ambulancia' => Icons.emergency_outlined,
        'bomberos' => Icons.fire_truck_outlined,
        'serenazgo' => Icons.security_outlined,
        'hospital' => Icons.local_hospital_outlined,
        'defensa_civil' => Icons.health_and_safety_outlined,
        _ => Icons.call_outlined,
      };

  factory NumeroEmergencia.fromMap(Map<String, dynamic> m, {bool local = false}) => NumeroEmergencia(
        nombre: (m['nombre'] ?? '') as String,
        numero: (m['numero'] ?? '') as String,
        tipo: (m['tipo'] ?? 'otro') as String,
        local: local,
      );
}

/// Datos incluidos en la app (assets/datos_iniciales.json) para el PRIMER
/// uso sin internet: números de emergencia y grupos de apoyo. Las normas y
/// consejos ya están dentro del código, así que también funcionan offline.
class DatosIniciales {
  DatosIniciales({required this.numerosNacionales, required this.numerosLocales, required this.gruposApoyo});

  /// Valores mínimos si el archivo no se pudiera leer (nunca dejar sin números).
  DatosIniciales.minimos()
      : numerosNacionales = const [
          NumeroEmergencia(nombre: 'Policía', numero: '105', tipo: 'policia'),
          NumeroEmergencia(nombre: 'SAMU (ambulancia)', numero: '106', tipo: 'ambulancia'),
          NumeroEmergencia(nombre: 'Bomberos', numero: '116', tipo: 'bomberos'),
        ],
        numerosLocales = const [],
        gruposApoyo = const [];

  static DatosIniciales actual = DatosIniciales.minimos();

  final List<NumeroEmergencia> numerosNacionales;
  final List<NumeroEmergencia> numerosLocales; // de la zona configurada
  final List<Map<String, dynamic>> gruposApoyo;

  /// Primero los nacionales (verificados) y luego los locales de la zona.
  List<NumeroEmergencia> get numeros => [...numerosNacionales, ...numerosLocales];

  static Future<void> cargar(String zona) async {
    try {
      final texto = await rootBundle.loadString('assets/datos_iniciales.json');
      actual = desdeJson(texto, zona);
    } catch (_) {
      actual = DatosIniciales.minimos();
    }
  }

  static DatosIniciales desdeJson(String texto, String zona) {
    final j = jsonDecode(texto) as Map<String, dynamic>;
    final nacionales = [
      for (final n in (j['numeros_nacionales'] as List? ?? const [])) NumeroEmergencia.fromMap(Map<String, dynamic>.from(n as Map)),
    ];
    final datosZona = (j['zonas'] as Map?)?[zona] as Map?;
    final locales = [
      for (final n in (datosZona?['numeros_locales'] as List? ?? const []))
        NumeroEmergencia.fromMap(Map<String, dynamic>.from(n as Map), local: true),
    ].where((n) => n.numero.trim().isNotEmpty).toList();
    final grupos = [
      for (final g in (j['grupos_apoyo_demo'] as List? ?? const [])) Map<String, dynamic>.from(g as Map),
    ];
    return DatosIniciales(
      numerosNacionales: nacionales.isEmpty ? DatosIniciales.minimos().numerosNacionales : nacionales,
      numerosLocales: locales,
      gruposApoyo: grupos,
    );
  }

  /// Respaldo para una consulta que nunca se pudo hacer con internet.
  List<Map<String, dynamic>>? respaldo(String clave) => switch (clave) {
        'servicios_true' => gruposApoyo,
        _ => null,
      };
}
