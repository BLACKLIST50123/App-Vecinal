import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models.dart';
import '../../screens/detalles.dart';
import '../../ui/tema.dart';

/// "¿Te atendió bien?": cuando un vecino llama o escribe a un servicio, se
/// recuerda en el celular. Al volver a la app se le pregunta si lo
/// recomienda. Así crecen las recomendaciones reales (de quien sí contactó)
/// sin que nadie tenga que acordarse de hacerlo.
class ContactosPendientes {
  static const _clave = 'contactos_pendientes';

  /// Tiempo mínimo después del contacto antes de preguntar.
  static const espera = Duration(seconds: 30);

  /// Si responde "Todavía no", se vuelve a preguntar después de esto.
  static const reintento = Duration(days: 1);

  static bool _preguntando = false;

  static List<Map<String, dynamic>> leer(SharedPreferences p) {
    try {
      final raw = p.getString(_clave);
      if (raw == null) return [];
      return [for (final e in jsonDecode(raw) as List) Map<String, dynamic>.from(e as Map)];
    } catch (_) {
      return [];
    }
  }

  static void _guardar(SharedPreferences p, List<Map<String, dynamic>> l) => p.setString(_clave, jsonEncode(l));

  static void registrar(SharedPreferences p, Servicio s) {
    final l = leer(p)..removeWhere((e) => e['id'] == s.id);
    l.add({
      'id': s.id,
      'titulo': s.titulo,
      'autor': s.autorNombre ?? 'el vecino',
      'desde': DateTime.now().add(espera).toIso8601String(),
    });
    // Solo los últimos 5: no se acumulan preguntas.
    _guardar(p, l.length > 5 ? l.sublist(l.length - 5) : l);
  }

  static void quitar(SharedPreferences p, String id) => _guardar(p, leer(p)..removeWhere((e) => e['id'] == id));

  static void _posponer(SharedPreferences p, String id) {
    final l = leer(p);
    for (final e in l) {
      if (e['id'] == id) e['desde'] = DateTime.now().add(reintento).toIso8601String();
    }
    _guardar(p, l);
  }

  /// Si hay un contacto pendiente y ya pasó el tiempo, pregunta (una sola
  /// pregunta a la vez).
  static Future<void> revisar(BuildContext context, SharedPreferences p, {required bool logueado}) async {
    if (_preguntando || !logueado) return;
    final ahora = DateTime.now();
    final listo = leer(p).where((e) => (DateTime.tryParse('${e['desde']}') ?? ahora).isBefore(ahora)).firstOrNull;
    if (listo == null) return;
    _preguntando = true;
    try {
      final id = listo['id'] as String;
      final titulo = '${listo['titulo']}';
      final respuesta = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.handshake_outlined, size: 44, color: Paleta.acentoOscuro),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text('¿Te atendió bien ${listo['autor']}?',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Text('Contactaste a "$titulo". Tu respuesta ayuda a tus vecinos a elegir bien.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Paleta.gris, fontSize: 15)),
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(c, 'si'),
                  icon: const Icon(Icons.thumb_up),
                  label: const Text('Sí, lo recomiendo', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(c, 'luego'),
                  child: const Text('Todavía no me atiende'),
                ),
              ),
              TextButton(onPressed: () => Navigator.pop(c, 'no'), child: const Text('No me fue bien')),
            ]),
          ),
        ),
      );
      if (!context.mounted) return;
      switch (respuesta) {
        case 'si':
          final ok = await dialogoVistoBueno(context, servicioId: id, titulo: titulo);
          ok ? quitar(p, id) : _posponer(p, id);
        case 'no':
          // No se recomienda. (Si fue grave, puede usar "Reportar" en el servicio.)
          quitar(p, id);
        default:
          _posponer(p, id);
      }
    } finally {
      _preguntando = false;
    }
  }
}
