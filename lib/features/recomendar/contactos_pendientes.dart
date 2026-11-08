import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models.dart';
import '../../screens/detalles.dart';
import '../../ui/tema.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../sos/sos_navegacion.dart';

/// "¿Te atendió bien?": cuando un vecino llama o escribe a un servicio, se
/// recuerda en el celular. Al volver a la app se le pregunta si lo
/// recomienda. Así crecen las recomendaciones reales (de quien sí contactó)
/// sin que nadie tenga que acordarse de hacerlo.
class ContactosPendientes {
  static const _clave = 'contactos_pendientes';

  /// Tiempo después de tocar Llamar o WhatsApp antes de preguntar.
  static const espera = Duration(seconds: 3);

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

  /// "¿Qué pasó?" con un toque. "" = prefiere no decir; null = canceló.
  static Future<String?> _preguntarMotivo(BuildContext context) => showModalBottomSheet<String>(
        context: context,
        // Obligatorio elegir una opción: no se cierra tocando afuera, arrastrando ni con "atrás".
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true, // toma la altura que necesita (no se corta)
        backgroundColor: Paleta.superficie,
        builder: (c) => PopScope(canPop: false, child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('¿Qué pasó?', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Es privado: no se publica ni se muestra tu nombre.',
                  textAlign: TextAlign.center, style: TextStyle(color: Paleta.gris, fontSize: 15)),
              const SizedBox(height: 14),
              for (final (id, texto, icono) in const [
                ('no_vino', 'No vino o no respondió', Icons.event_busy),
                ('cobro_de_mas', 'Cobró de más', Icons.money_off),
                ('mal_trabajo', 'El trabajo quedó mal', Icons.build_outlined),
                ('mal_trato', 'Me trató mal', Icons.sentiment_dissatisfied),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), alignment: Alignment.centerLeft),
                    onPressed: () => Navigator.pop(c, id),
                    icon: Icon(icono),
                    label: Text(texto, style: const TextStyle(fontSize: 16)),
                  ),
                ),
              TextButton(onPressed: () => Navigator.pop(c, ''), child: const Text('Prefiero no decir')),
            ]),
          ),
        )),
      );

  /// Pregunta [espera] después de tocar Llamar o WhatsApp, sobre la pantalla
  /// que esté abierta (en el celular aparece al volver de la llamada).
  static void programar(SharedPreferences p) => Future.delayed(espera + const Duration(milliseconds: 300), () {
        final c = navegador.currentContext;
        if (c == null || !c.mounted) return;
        final st = c.read<AppState>();
        if (st.modoEmergencia) return; // en emergencia no se interrumpe
        revisar(c, p, logueado: st.logueado);
      });

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
        // Obligatorio elegir una opción: no se cierra tocando afuera, arrastrando ni con "atrás".
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true, // con letra grande tampoco se corta
        backgroundColor: Paleta.superficie,
        builder: (c) => PopScope(canPop: false, child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.handshake_outlined, size: 44, color: Paleta.acentoOscuro),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text('¿Te atendió bien ${listo['autor']}?',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Text('Contactaste a "$titulo". Tu respuesta ayuda a tus vecinos a elegir bien.',
                  textAlign: TextAlign.center, style: TextStyle(color: Paleta.gris, fontSize: 15)),
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
        )),
      );
      if (!context.mounted) return;
      switch (respuesta) {
        case 'si':
          final ok = await dialogoVistoBueno(context, servicioId: id, titulo: titulo);
          ok ? quitar(p, id) : _posponer(p, id);
        case 'no':
          // Se guarda en PRIVADO: nadie lo ve en público, solo baja un poco
          // el orden y avisa a la junta si se repite.
          quitar(p, id);
          final motivo = await _preguntarMotivo(context);
          if (motivo == null || !context.mounted) return;
          try {
            await context.read<AppState>().repo.registrarExperiencia(id, motivo.isEmpty ? null : motivo);
            avisar('Gracias. Tu respuesta es privada y ayuda a cuidar a tus vecinos.');
          } catch (_) {
            avisar('No se pudo guardar tu respuesta. Inténtalo más tarde.');
          }
        default:
          _posponer(p, id);
      }
    } finally {
      _preguntando = false;
    }
  }
}
