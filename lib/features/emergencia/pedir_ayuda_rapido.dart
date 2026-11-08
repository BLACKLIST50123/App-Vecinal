import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../screens/detalles.dart';
import '../../services/ubicacion.dart';
import '../../state/app_state.dart';
import '../../ui/tema.dart';
import '../../util.dart';

/// Situaciones de un toque: (categoría, texto, ícono, grave por sí sola).
const situacionesAyuda = <(String, String, IconData, bool)>[
  ('rescate', 'Estoy atrapado o en peligro', Icons.emergency_rounded, true),
  ('salud', 'Hay un herido o enfermo', Icons.medical_services_rounded, true),
  ('vulnerable', 'Adulto mayor, niño o persona con discapacidad en riesgo', Icons.elderly_rounded, true),
  ('albergue', 'Necesito dónde quedarme', Icons.night_shelter_rounded, false),
  ('agua_alimento', 'Necesito agua o comida', Icons.water_drop_rounded, false),
];

/// Palabras que vuelven grave un pedido aunque la situación no lo sea.
const _palabrasGraves = [
  'atrapad', 'herid', 'sangr', 'inconscien', 'no respira', 'desmay', 'fuego', 'incendi', 'humo',
  'ahog', 'derrumb', 'quemad', 'fractur', 'parto', 'embaraz', 'convulsi', 'infarto', 'electrocut',
  'corriente', 'arrastr', 'bebe', 'bebé', 'muerto', 'grave',
];

/// Gravedad automática: 'critica' (muy urgente) o 'alta' (urgente).
/// Función pura para poder probarla.
String gravedadPedido({required bool situacionGrave, String texto = ''}) {
  if (situacionGrave) return 'critica';
  final t = texto.toLowerCase();
  return _palabrasGraves.any(t.contains) ? 'critica' : 'alta';
}

/// "Necesito ayuda" en 1 toque: eliges tu situación y se envía con tu
/// ubicación aproximada. La gravedad la decide el sistema. Escribir es opcional.
class PedirAyudaRapidoScreen extends StatefulWidget {
  const PedirAyudaRapidoScreen({super.key});

  @override
  State<PedirAyudaRapidoScreen> createState() => _PedirAyudaRapidoScreenState();
}

class _PedirAyudaRapidoScreenState extends State<PedirAyudaRapidoScreen> {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  bool _enviando = false;
  Map<String, dynamic>? _enviado; // datos del pedido ya enviado
  bool _enLinea = true;

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _enviar(String categoria, String titulo, bool grave) async {
    if (_enviando) return;
    final st = context.read<AppState>();
    final extra = _texto.text.trim();
    if (categoria == 'otros' && extra.length < 3) {
      _foco.requestFocus();
      avisar('Escribe en pocas palabras qué pasa.');
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() => _enviando = true);
    final punto = st.ubicacion ?? await Ubicacion.gps().timeout(const Duration(seconds: 6), onTimeout: () => null) ?? st.referencia;
    final aprox = aproximar(punto);
    final prioridad = gravedadPedido(situacionGrave: grave, texto: '$titulo $extra');
    final datos = <String, dynamic>{
      'id': nuevoId(),
      'tipo': 'pido',
      'categoria': categoria,
      'titulo': categoria == 'otros' ? (extra.length > 120 ? '${extra.substring(0, 117)}...' : extra) : titulo,
      'descripcion': categoria == 'otros' || extra.isEmpty ? null : extra,
      'contacto_nombre': st.logueado ? st.nombre : null,
      'contacto_telefono': st.perfil?['telefono'],
      'prioridad': prioridad,
      'es_emergencia': true,
      'lat': aprox.lat,
      'lng': aprox.lng,
      'sector': st.sector,
      'autor_nombre': st.logueado ? st.nombre : 'Vecino',
      'creado_offline_en': DateTime.now().toUtc().toIso8601String(),
      if (!st.logueado) ...{'autor_id': null, 'origen': 'sin_cuenta'},
    };
    try {
      final enLinea = await st.publicar('publicaciones', datos);
      if (st.logueado) st.marcarEstado('ayuda').catchError((_) {});
      if (!mounted) return;
      setState(() {
        _enviado = datos;
        _enLinea = enLinea;
      });
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelar() async {
    final st = context.read<AppState>();
    final id = _enviado?['id'] as String?;
    if (id == null) return;
    try {
      await st.repo.eliminar('publicaciones', id);
      st.refrescar();
      if (mounted) Navigator.pop(context);
      avisar('Cancelaste tu pedido de ayuda.');
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Necesito ayuda')),
        body: SafeArea(child: _enviado == null ? _elegir() : _listo()),
      );

  Widget _elegir() => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Text('Toca lo que te pasa. Se envía al instante con tu ubicación aproximada.',
            style: TextStyle(fontSize: 15, color: Paleta.gris)),
        const SizedBox(height: 12),
        for (final s in situacionesAyuda)
          _Situacion(
            icono: s.$3,
            texto: s.$2,
            grave: s.$4,
            ocupado: _enviando,
            onTap: () => _enviar(s.$1, s.$2, s.$4),
          ),
        const SizedBox(height: 8),
        Text('¿Es otra cosa? Escríbelo (también se suma a lo que elijas arriba):',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Paleta.tinta)),
        const SizedBox(height: 6),
        TextField(
          controller: _texto,
          focusNode: _foco,
          minLines: 2,
          maxLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej: Se cayó el techo, somos 3 en casa'),
        ),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
            onPressed: _enviando ? null : () => _enviar('otros', 'Necesito ayuda', false),
            icon: _enviando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Enviar lo que escribí', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        Text('Si hay riesgo de vida, llama también al 105, 106 o 116.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Paleta.gris)),
      ]);

  Widget _listo() {
    final st = context.watch<AppState>();
    final critica = _enviado!['prioridad'] == 'critica';
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [
      Icon(_enLinea ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
          size: 72, color: _enLinea ? Paleta.verde : Paleta.gris),
      const SizedBox(height: 12),
      Text(
        _enLinea ? 'Tu pedido de ayuda fue enviado' : 'Guardado sin señal',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Paleta.tinta),
      ),
      const SizedBox(height: 6),
      Text(
        _enLinea
            ? 'Tus vecinos, la junta y los brigadistas ya lo ven en el mapa.'
            : 'Se enviará apenas vuelva la señal. También puedes pasarlo por QR.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: Paleta.gris),
      ),
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: (critica ? Paleta.rojo : Paleta.ambar).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            critica ? 'Prioridad: MUY URGENTE' : 'Prioridad: URGENTE',
            style: TextStyle(fontWeight: FontWeight.w900, color: critica ? Paleta.rojo : Paleta.ambar),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text('La prioridad la calculó la app según lo que elegiste.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Paleta.gris)),
      const SizedBox(height: 24),
      SizedBox(
        height: 54,
        child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
      ),
      if (st.logueado && _enLinea) ...[
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Paleta.rojo),
          onPressed: _cancelar,
          child: const Text('Fue un error, cancelar pedido'),
        ),
      ],
    ]);
  }
}

class _Situacion extends StatelessWidget {
  const _Situacion({required this.icono, required this.texto, required this.grave, required this.ocupado, required this.onTap});
  final IconData icono;
  final String texto;
  final bool grave, ocupado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = grave ? Paleta.rojo : Paleta.ambar;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: ocupado ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5)),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(texto, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.tinta)),
              ),
              Icon(Icons.send_rounded, color: color),
            ]),
          ),
        ),
      ),
    );
  }
}
