import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notificaciones.dart';
import '../services/vigia.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';

/// Ajustes de notificaciones: activar los avisos y elegir cuáles recibir.
/// Las emergencias van primero y se recomiendan siempre encendidas.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> with WidgetsBindingObserver {
  bool _activando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AppState>().revisarPermisoAvisos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver de los Ajustes del celular, se revisa si ya dio el permiso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) context.read<AppState>().revisarPermisoAvisos();
  }

  Future<void> _activar() async {
    setState(() => _activando = true);
    final ok = await context.read<AppState>().activarAvisos();
    if (!mounted) return;
    setState(() => _activando = false);
    avisar(ok
        ? '¡Listo! Te avisaremos de emergencias y alertas SOS cerca de ti.'
        : 'El celular bloqueó los avisos. Actívalos en Ajustes > Apps > Conecta Vecino > Notificaciones.');
  }

  Future<void> _cambiar(AppState st, TipoAviso t, bool v) async {
    if (!v && t.critico) {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: Paleta.rojo, size: 40),
          title: const Text('¿Apagar este aviso?'),
          content: Text('"${t.titulo}" te avisa cuando tú o un vecino están en peligro. '
              'Te recomendamos dejarlo encendido.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Dejar encendido')),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              style: TextButton.styleFrom(foregroundColor: Paleta.rojo),
              child: const Text('Apagar'),
            ),
          ],
        ),
      );
      if (seguro != true) return;
    }
    st.setAviso(t, v);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final bloqueadas = st.permisoAvisos == false && st.avisosActivados;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        _estado(st, bloqueadas),
        const TituloDiseno('Emergencias', ceja: 'Muy importantes'),
        _lista(st, TipoAviso.values.where((t) => t.critico)),
        const TituloDiseno('Mi barrio', ceja: 'Elige lo que te interesa'),
        _lista(st, TipoAviso.values.where((t) => !t.critico)),
        if (Vigia.soportado && st.avisosActivados) ...[
          const TituloDiseno('Con la app cerrada', ceja: 'Para no perderte nada'),
          ListaAjustes(filas: [
            SwitchListTile(
              value: st.modoAlerta,
              onChanged: st.setModoAlerta,
              secondary: Icon(Icons.shield_moon_outlined, color: Paleta.rojo),
              title: const Text('Modo alerta permanente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: Text(
                st.modoAlertaActivo
                    ? 'Encendido: revisa cada 30 s. Verás un aviso fijo de Conecta Vecino en la barra.'
                    : 'Avisos al instante aunque cierres la app. Usa un poco más de batería.',
                style: TextStyle(fontSize: 13, color: Paleta.gris),
              ),
              activeThumbColor: Paleta.rojo,
            ),
          ]),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            Vigia.soportado
                ? 'Con la app cerrada, Conecta Vecino revisa tu barrio cada 15 minutos. '
                    'Durante una emergencia se enciende solo el modo alerta para avisarte al instante.'
                : 'Con la app abierta verás los avisos como un mensaje en pantalla.',
            style: TextStyle(color: Paleta.gris, fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }

  Widget _estado(AppState st, bool bloqueadas) {
    final falta = st.faltaActivarAvisos;
    final color = falta ? Paleta.rojo : Paleta.verde;
    final fondo = falta ? Paleta.rojoSuave : Paleta.verdeSuave;
    final (titulo, texto) = bloqueadas
        ? ('El celular bloquea los avisos', 'Actívalos en Ajustes > Apps > Conecta Vecino > Notificaciones para no perderte una emergencia.')
        : !st.avisosActivados
            ? ('Activa los avisos de emergencia', 'Así sabrás al instante si hay un sismo, una inundación o un vecino cerca pide ayuda.')
            : falta
                ? ('Tienes avisos de emergencia apagados', 'Te recomendamos encenderlos: son los que pueden salvar una vida.')
                : ('Tus avisos están activos', 'Te avisaremos de emergencias y de lo que elegiste abajo.');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(falta ? Icons.notifications_active_outlined : Icons.notifications_on, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(texto, style: TextStyle(fontSize: 14, color: Paleta.tinta, height: 1.35)),
            ]),
          ),
        ]),
        if (!st.avisosActivados || bloqueadas) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
            onPressed: _activando ? null : _activar,
            icon: _activando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.notifications_active),
            label: Text(bloqueadas ? 'Volver a intentar' : 'Activar notificaciones'),
          ),
        ],
      ]),
    );
  }

  Widget _lista(AppState st, Iterable<TipoAviso> tipos) => ListaAjustes(filas: [
        for (final t in tipos)
          SwitchListTile(
            value: st.avisos[t] == true,
            onChanged: (v) => _cambiar(st, t, v),
            secondary: Icon(t.icono, color: t.critico ? Paleta.rojo : Paleta.primario),
            title: Text(t.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            subtitle: Text(t.descripcion, style: TextStyle(fontSize: 13, color: Paleta.gris)),
            activeThumbColor: t.critico ? Paleta.rojo : null,
          ),
      ]);
}
