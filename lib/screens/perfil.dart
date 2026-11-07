import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import 'auth_screen.dart';
import 'confianza.dart';
import 'detalles.dart';
import 'publicar.dart';
import 'qr_screens.dart';
import 'tutorial.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final rolTexto = switch (st.rol) {
      'moderador' => 'Moderador (junta vecinal)',
      'organizacion' => 'Organización de apoyo',
      'vecino' => 'Vecino',
      _ => 'Visitante',
    };
    final esPrestador = st.perfil?['es_prestador'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil y ajustes')),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        if (st.logueado)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                ListTile(
                  leading: CircleAvatar(radius: 28, child: Text(st.nombre.characters.first.toUpperCase(), style: const TextStyle(fontSize: 24))),
                  title: Text(st.nombre, style: Theme.of(context).textTheme.titleLarge),
                  subtitle: Text([rolTexto, ?st.sector].join(' · ')),
                ),
                ListTile(
                  leading: Icon(st.verificado ? Icons.verified : Icons.gpp_maybe,
                      color: st.verificado ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00)),
                  title: Text(st.verificado ? 'Vecino verificado por GPS' : 'Sin verificación GPS'),
                ),
              ]),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Estás como visitante. Puedes ver todo; para publicar, crea tu cuenta gratis.',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
                  icon: const Icon(Icons.login),
                  label: const Text('Ingresar o crear cuenta'),
                ),
              ]),
            ),
          ),

        if (st.logueado) ...[
          ListTile(
            leading: const Icon(Icons.list_alt, size: 32),
            title: const Text('Mis publicaciones', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Ver, marcar como resueltas o eliminar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisPublicacionesScreen())),
          ),
          const TituloSeccion('Perfil prestador'),
          SwitchListTile(
            secondary: const Icon(Icons.handyman),
            title: const Text('Ofrezco un oficio, servicio o producto'),
            subtitle: const Text('Aparecerás en el directorio de tu barrio'),
            value: esPrestador,
            onChanged: st.online
                ? (v) async {
                    try {
                      await st.repo.actualizarPerfil({'es_prestador': v});
                      await st.cargarPerfil();
                    } catch (e) {
                      avisar(traducirError(e));
                    }
                  }
                : null,
          ),
          if (esPrestador)
            ListTile(
              leading: const Icon(Icons.add_business),
              title: const Text('Publicar mi servicio'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => abrirFormulario(context, TipoForm.servicio),
            ),
        ],

        if (st.esOrganizacion || st.esModerador)
          ListTile(
            leading: const Icon(Icons.dashboard, size: 32),
            title: const Text('Panel de coordinación', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(st.esModerador ? 'Indicadores, pedidos por estado y reportes' : 'Indicadores y pedidos por estado'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelCoordinacionScreen())),
          ),

        const TituloSeccion('Comunidad'),
        ListTile(
          leading: const Icon(Icons.group_add, size: 32),
          title: const Text('Invitar vecinos por WhatsApp'),
          subtitle: const Text('Mientras más vecinos, más rápido llega la ayuda'),
          onTap: () => compartirWhatsapp(textoInvitacion),
        ),
        ListTile(
          leading: const Icon(Icons.rule, size: 32),
          title: const Text('Normas del barrio'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => mostrarNormas(context),
        ),

        const TituloSeccion('Accesibilidad'),
        ListTile(
          leading: const Icon(Icons.format_size),
          title: const Text('Tamaño de letra'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 1.0, label: Text('A', style: TextStyle(fontSize: 16)), tooltip: 'Letra normal'),
                ButtonSegment(value: 1.3, label: Text('A+', style: TextStyle(fontSize: 20)), tooltip: 'Letra grande'),
                ButtonSegment(value: 1.6, label: Text('A++', style: TextStyle(fontSize: 24)), tooltip: 'Letra muy grande'),
              ],
              selected: {st.escala},
              onSelectionChanged: (s) => st.setEscala(s.first),
            ),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.contrast),
          title: const Text('Alto contraste'),
          subtitle: const Text('Colores más fuertes y bordes marcados'),
          value: st.altoContraste,
          onChanged: st.setAltoContraste,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.record_voice_over),
          title: const Text('Botón "Escuchar"'),
          subtitle: const Text('Lee en voz alta cada publicación'),
          value: st.voz,
          onChanged: st.setVoz,
        ),
        ListTile(
          leading: const Icon(Icons.school),
          title: const Text('Ver el tutorial otra vez'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
        ),

        const TituloSeccion('Conexión'),
        ListTile(
          leading: Icon(st.online ? Icons.cloud_done : Icons.cloud_off),
          title: Text(st.online ? 'Con internet' : 'Sin internet'),
          subtitle: Text('${st.pendientes} publicación(es) por enviar'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendientesScreen())),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi_off),
          title: const Text('Simular sin internet'),
          subtitle: const Text('Para probar el modo offline en una demostración'),
          value: st.simulandoOffline,
          onChanged: st.setSimularOffline,
        ),

        if (st.esModerador) ...[
          const TituloSeccion('Junta vecinal (moderador)'),
          const _PanelModerador(),
        ],

        if (st.logueado)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                await st.cargarPerfil();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('App Vecinal · Equipo AlphaCoders · Hackathon UTP 2026',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      ]),
    );
  }
}

class MisPublicacionesScreen extends StatelessWidget {
  const MisPublicacionesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis publicaciones')),
        body: Cargador<(List<Publicacion>, List<Servicio>)>(
          cargar: (st) => st.repo.misPublicaciones(),
          builder: (context, datos) {
            final (pubs, servs) = datos;
            final abiertas = pubs.where((p) => p.estado != 'resuelta').toList();
            final resueltas = pubs.where((p) => p.estado == 'resuelta').toList();
            if (pubs.isEmpty && servs.isEmpty) {
              return EstadoVacio(
                icono: Icons.post_add,
                texto: 'Todavía no publicaste nada.\nToca Publicar para pedir u ofrecer algo a tus vecinos.',
                accion: ('Publicar ahora', () {
                  Navigator.pop(context);
                  abrirMenuPublicar(context);
                }),
              );
            }
            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              if (abiertas.isNotEmpty) ...[
                TituloSeccion('Activas (${abiertas.length})'),
                for (final p in abiertas) TarjetaPublicacion(p),
              ],
              if (servs.isNotEmpty) ...[
                TituloSeccion('Mis servicios y productos (${servs.length})'),
                for (final s in servs) TarjetaServicio(s),
              ],
              if (resueltas.isNotEmpty) ...[
                TituloSeccion('Resueltas (${resueltas.length})'),
                for (final p in resueltas) Opacity(opacity: 0.6, child: TarjetaPublicacion(p)),
              ],
            ]);
          },
        ),
      );
}

class _PanelModerador extends StatefulWidget {
  const _PanelModerador();

  @override
  State<_PanelModerador> createState() => _PanelModeradorState();
}

class _PanelModeradorState extends State<_PanelModerador> {
  late final TextEditingController _titulo;
  late final TextEditingController _mensaje;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    final e = context.read<AppState>().emergencia;
    _titulo = TextEditingController(text: e.titulo ?? 'Lluvias intensas e inundaciones');
    _mensaje = TextEditingController(
      text: e.mensaje ?? 'Si necesitas ayuda, toca NECESITO AYUDA. Si no tienes internet, comparte tu pedido por QR.',
    );
  }

  Future<void> _cambiar(bool activar) async {
    final st = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(activar ? '¿Activar el modo emergencia?' : '¿Terminar el modo emergencia?'),
        content: Text(activar
            ? 'Todos los vecinos verán la app en modo emergencia y podrán pedir ayuda sin cuenta.'
            : 'La app volverá al modo del día a día para todos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(activar ? 'Activar' : 'Terminar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cargando = true);
    try {
      await st.repo.cambiarEmergencia(activa: activar, titulo: _titulo.text.trim(), mensaje: _mensaje.text.trim());
      await st.actualizarEmergencia();
      avisar(activar ? 'Modo emergencia ACTIVADO para todo el barrio' : 'Modo emergencia terminado');
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activa = context.watch<AppState>().modoEmergencia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(activa ? 'La emergencia está ACTIVA' : 'Sin emergencia activa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: activa ? const Color(0xFFB71C1C) : null)),
          const SizedBox(height: 12),
          TextField(controller: _titulo, decoration: const InputDecoration(labelText: 'Tipo de emergencia')),
          const SizedBox(height: 12),
          TextField(controller: _mensaje, maxLines: 3, decoration: const InputDecoration(labelText: 'Mensaje para los vecinos')),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: activa ? null : FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
            onPressed: _cargando ? null : () => _cambiar(!activa),
            icon: Icon(activa ? Icons.check_circle : Icons.warning),
            label: Text(activa ? 'Terminar emergencia' : 'Activar modo emergencia'),
          ),
          if (activa)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(onPressed: _cargando ? null : () => _cambiar(true), child: const Text('Actualizar mensaje')),
            ),
        ]),
      ),
    );
  }
}
