import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'aportes.dart';
import 'auth_screen.dart';
import 'confianza.dart';
import 'detalles.dart';
import 'publicar.dart';
import 'qr_screens.dart';
import 'roles.dart';
import 'tutorial.dart';

/// Pestaña "Perfil" (diseño Figma): tarjeta de perfil, impacto en el barrio
/// y lista de opciones.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  void _ir(BuildContext context, Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final ayudas = (st.perfil?['ayudas_confirmadas'] as num?)?.toInt() ?? 0;
    final nivel = Nivel.de(ayudas);
    final esPrestador = st.perfil?['es_prestador'] == true;
    final rolTexto = switch (st.rol) {
      'moderador' => 'Junta vecinal',
      'organizacion' => 'Organización de apoyo',
      _ => 'Vecino de ${st.sector ?? Zona.nombre}',
    };

    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      if (st.logueado) ...[
        // ------------------------------------------- tarjeta de perfil
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Paleta.linea)),
          child: Row(children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(19)),
              child: Text(iniciales(st.nombre), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(rolTexto, style: const TextStyle(color: Paleta.gris, fontSize: 14)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(st.verificado ? Icons.verified_user : Icons.gpp_maybe_outlined,
                      size: 16, color: st.verificado ? Theme.of(context).colorScheme.primary : const Color(0xFFEF6C00)),
                  const SizedBox(width: 4),
                  Text(st.verificado ? 'Vecino verificado' : 'Sin verificación GPS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: st.verificado ? Theme.of(context).colorScheme.primary : const Color(0xFFEF6C00),
                      )),
                ]),
                if (esPrestador) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Paleta.acentoSuave,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Paleta.acentoOscuro.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.handyman, size: 12, color: Paleta.acentoOscuro),
                        SizedBox(width: 4),
                        Text(
                          'Prestador de servicios local',
                          style: TextStyle(color: Paleta.acentoOscuro, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
            InsigniaNivel(ayudas, mostrarSiCero: true),
          ]),
        ),

        // ------------------------------------------- tarjeta de impacto
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Paleta.linea)),
          child: Cargador<(List<Publicacion>, List<Servicio>)>(
            cargar: (st) => st.repo.misPublicaciones(),
            builder: (c, datos) => IntrinsicHeight(
              child: Row(children: [
                ImpactoNumero('$ayudas', 'Ayudas confirmadas'),
                const VerticalDivider(width: 1),
                ImpactoNumero('${datos.$1.length + datos.$2.length}', 'Publicaciones'),
                const VerticalDivider(width: 1),
                ImpactoNumero(nivel.emoji, nivel.nombre),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _TarjetaReconocimiento(ayudas: ayudas),
        const TituloDiseno('Mi actividad'),
        ListaAjustes(filas: [
          FilaAjuste(
            icono: Icons.inventory_2_outlined,
            texto: 'Mis aportes (servicios y pedidos)',
            onTap: () => _ir(
              context,
              Scaffold(
                appBar: AppBar(title: const Text('Mis aportes')),
                body: const MisAportesScreen(),
              ),
            ),
          ),
          FilaAjuste(icono: Icons.history, texto: 'Mi historial de ayudas', onTap: () => _ir(context, const HistorialScreen())),
          FilaAjuste(icono: Icons.list_alt, texto: 'Mis publicaciones', onTap: () => _ir(context, const MisPublicacionesScreen())),
          FilaAjuste(
            icono: Icons.storefront_outlined,
            texto: 'Ofrezco un servicio o producto',
            final_: Switch(
              value: esPrestador,
              onChanged: st.online
                  ? (v) async {
                      try {
                        await st.repo.actualizarPerfil({'es_prestador': v});
                        await st.cargarPerfil();
                        if (v && context.mounted) abrirFormulario(context, TipoForm.servicio);
                      } catch (e) {
                        avisar(traducirError(e));
                      }
                    }
                  : null,
            ),
          ),
          if (st.esOrganizacion || st.esModerador)
            FilaAjuste(icono: Icons.dashboard_outlined, texto: 'Panel de coordinación', onTap: () => _ir(context, const PanelCoordinacionScreen())),
          if (st.esModerador)
            FilaAjuste(
              icono: Icons.campaign_outlined,
              texto: 'Junta vecinal: emergencia',
              valor: st.modoEmergencia ? 'Activa' : 'Apagada',
              color: st.modoEmergencia ? Paleta.rojo : null,
              onTap: () => _ir(context, const JuntaVecinalScreen()),
            ),
        ]),
      ] else ...[
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Paleta.linea)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Únete a tu barrio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Puedes ver todo sin cuenta. Para publicar, ayudar y ganar reconocimiento, crea tu cuenta gratis con tu celular.',
                style: TextStyle(color: Paleta.gris, fontSize: 15)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _ir(context, const AuthScreen()),
              icon: const Icon(Icons.login),
              label: const Text('Ingresar o crear cuenta'),
            ),
          ]),
        ),
      ],

      const TituloDiseno('Comunidad'),
      ListaAjustes(filas: [
        FilaAjuste(
          icono: infoRol(st.rolSimulado).icono,
          texto: '¿Quién soy hoy?',
          valor: infoRol(st.rolSimulado).titulo.split(' /').first,
          color: infoRol(st.rolSimulado).color,
          onTap: () => _ir(context, const SelectorRolScreen(inicial: false)),
        ),
        FilaAjuste(icono: Icons.location_on_outlined, texto: 'Mi barrio', valor: st.sector ?? Zona.nombre),
        FilaAjuste(icono: Icons.group_add_outlined, texto: 'Invitar vecinos por WhatsApp', onTap: () => compartirWhatsapp(textoInvitacion)),
        FilaAjuste(icono: Icons.rule, texto: 'Normas del barrio', onTap: () => mostrarNormas(context)),
        FilaAjuste(icono: Icons.shield_outlined, texto: 'Ayudar con seguridad', onTap: () => mostrarConsejos(context)),
      ]),

      const TituloDiseno('Ajustes'),
      ListaAjustes(filas: [
        FilaAjuste(
          icono: Icons.accessibility_new,
          texto: 'Accesibilidad',
          valor: [if (st.escala > 1) 'Letra ${st.escala >= 1.6 ? 'A++' : 'A+'}', if (st.altoContraste) 'Contraste'].join(' · '),
          onTap: () => _ir(context, const AccesibilidadScreen()),
        ),
        FilaAjuste(
          icono: st.online ? Icons.cloud_done_outlined : Icons.cloud_off,
          texto: 'Conexión y mensajes QR',
          valor: st.pendientes > 0 ? '${st.pendientes} por enviar' : (st.online ? 'Con internet' : 'Sin internet'),
          onTap: () => _ir(context, const ConexionScreen()),
        ),
        FilaAjuste(icono: Icons.help_outline, texto: 'Cómo usar la app', onTap: () => _ir(context, const TutorialScreen())),
        if (st.logueado)
          FilaAjuste(
            icono: Icons.logout,
            texto: 'Cerrar sesión',
            color: Paleta.rojo,
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              await st.cargarPerfil();
            },
          ),
      ]),
      const Padding(
        padding: EdgeInsets.all(20),
        child: Text('App Vecinal · Equipo AlphaCoders · Hackathon UTP 2026',
            textAlign: TextAlign.center, style: TextStyle(color: Paleta.grisClaro)),
      ),
    ]);
  }
}


class AccesibilidadScreen extends StatelessWidget {
  const AccesibilidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Accesibilidad')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text('Ajusta la app para leerla y usarla con comodidad.', style: TextStyle(color: Paleta.gris, fontSize: 15)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: Paleta.linea)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Tamaño de letra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 1.0, label: Text('A', style: TextStyle(fontSize: 16)), tooltip: 'Letra normal'),
                ButtonSegment(value: 1.3, label: Text('A+', style: TextStyle(fontSize: 20)), tooltip: 'Letra grande'),
                ButtonSegment(value: 1.6, label: Text('A++', style: TextStyle(fontSize: 24)), tooltip: 'Letra muy grande'),
              ],
              selected: {st.escala},
              showSelectedIcon: false,
              onSelectionChanged: (s) => st.setEscala(s.first),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        ListaAjustes(filas: [
          FilaAjuste(
            icono: Icons.contrast,
            texto: 'Alto contraste',
            final_: Switch(value: st.altoContraste, onChanged: st.setAltoContraste),
          ),
          FilaAjuste(
            icono: Icons.record_voice_over_outlined,
            texto: 'Botón "Escuchar"',
            final_: Switch(value: st.voz, onChanged: st.setVoz),
          ),
          FilaAjuste(
            icono: Icons.school_outlined,
            texto: 'Ver el tutorial otra vez',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
          ),
        ]),
      ]),
    );
  }
}

class ConexionScreen extends StatelessWidget {
  const ConexionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Conexión y mensajes QR')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text('Sin internet, lo que publiques se guarda y puedes compartirlo por QR para que otro vecino lo envíe.',
              style: TextStyle(color: Paleta.gris, fontSize: 15)),
        ),
        ListaAjustes(filas: [
          FilaAjuste(
            icono: st.online ? Icons.cloud_done_outlined : Icons.cloud_off,
            texto: st.online ? 'Con internet' : 'Sin internet',
            valor: '${st.pendientes} por enviar',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendientesScreen())),
          ),
          FilaAjuste(
            icono: Icons.qr_code_scanner,
            texto: 'Escanear QR de un vecino',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EscanearQrScreen())),
          ),
          FilaAjuste(
            icono: Icons.wifi_off,
            texto: 'Simular sin internet (para demostración)',
            final_: Switch(value: st.simulandoOffline, onChanged: st.setSimularOffline),
          ),
        ]),
      ]),
    );
  }
}

class JuntaVecinalScreen extends StatelessWidget {
  const JuntaVecinalScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Junta vecinal')),
        body: ListView(padding: const EdgeInsets.only(bottom: 32), children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Activa el modo emergencia cuando el barrio lo necesite. Todos los vecinos lo verán al instante.',
                style: TextStyle(color: Paleta.gris, fontSize: 15)),
          ),
          _PanelModerador(),
        ]),
      );
}

/// Nivel de reconocimiento y cuánto falta para el siguiente.
class _TarjetaReconocimiento extends StatelessWidget {
  const _TarjetaReconocimiento({required this.ayudas});
  final int ayudas;

  @override
  Widget build(BuildContext context) {
    final n = Nivel.de(ayudas);
    final sig = Nivel.siguiente(ayudas);
    final progreso = sig == null ? 1.0 : ((ayudas - n.minimo) / (sig.minimo - n.minimo)).clamp(0.0, 1.0);
    final faltan = sig == null ? 0 : sig.minimo - ayudas;
    final texto = 'Tu reconocimiento: ${n.nombre}. ${n.descripcion} '
        '${sig == null ? '¡Llegaste al nivel más alto!' : 'Te faltan $faltan ayudas confirmadas para ser ${sig.nombre}.'}';
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(n.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                Text('$ayudas ${ayudas == 1 ? 'ayuda confirmada' : 'ayudas confirmadas'}',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              ]),
            ),
            BotonEscuchar(texto, compacto: true),
          ]),
          const SizedBox(height: 8),
          Text(n.descripcion, style: const TextStyle(color: Colors.black87, fontSize: 15)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 12,
              color: const Color(0xFFFFB300),
              backgroundColor: const Color(0xFFFFE082),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sig == null
                ? '¡Llegaste al nivel más alto! Gracias por cuidar tu barrio.'
                : 'Te ${faltan == 1 ? 'falta 1 ayuda confirmada' : 'faltan $faltan ayudas confirmadas'} para ser ${sig.emoji} ${sig.nombre}',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Una ayuda se confirma cuando la persona a la que ayudaste te agradece en la app.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  static (IconData, Color) _icono(String tipo) => switch (tipo) {
        'agradecimiento' => (Icons.favorite, const Color(0xFFC2185B)),
        'visto_bueno' => (Icons.thumb_up, const Color(0xFF2E7D32)),
        _ => (Icons.volunteer_activism, const Color(0xFF1565C0)),
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mi historial de ayudas')),
        body: Cargador<List<EntradaHistorial>>(
          cargar: (st) => st.repo.historial(),
          builder: (context, lista) {
            if (lista.isEmpty) {
              return EstadoVacio(
                icono: Icons.volunteer_activism,
                texto: 'Aquí verás cada vez que ayudes a un vecino.\n¡Tu primera ayuda está a un toque!',
                accion: ('Ver quién necesita una mano', () => Navigator.pop(context)),
              );
            }
            final respondi = lista.where((e) => e.tipo == 'respondi').toList();
            final gracias = lista.where((e) => e.tipo == 'agradecimiento').length;
            final colectas = respondi.where((e) => e.publicacion?.esColecta == true).length;
            final emergencias = respondi.where((e) => e.publicacion?.esEmergencia == true).length;
            final cuidado = respondi.where((e) => e.publicacion?.categoria == 'cuidado').length;
            final vbs = lista.where((e) => e.tipo == 'visto_bueno').length;
            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  _Dato(Icons.volunteer_activism, 'Veces que respondiste', respondi.length),
                  _Dato(Icons.favorite, 'Agradecimientos', gracias),
                  _Dato(Icons.diversity_1, 'Colectas apoyadas', colectas),
                  _Dato(Icons.thumb_up, 'Vistos Buenos dados', vbs),
                ]),
              ),
              if (emergencias > 0 || cuidado > 0 || colectas > 0) ...[
                const TituloSeccion('Tus distintivos'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    if (emergencias > 0) const Chip(avatar: Text('🚨'), label: Text('Ayudó en una emergencia')),
                    if (cuidado > 0) const Chip(avatar: Text('👵'), label: Text('Acompaña a los mayores')),
                    if (colectas > 0) const Chip(avatar: Text('🎁'), label: Text('Aporta a las colectas')),
                  ]),
                ),
              ],
              const TituloSeccion('Lo que has hecho'),
              for (final e in lista)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _icono(e.tipo).$2.withValues(alpha: 0.15),
                    child: Icon(_icono(e.tipo).$1, color: _icono(e.tipo).$2),
                  ),
                  title: Text(e.tipo == 'respondi' ? e.titulo : e.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([?e.detalle, haceCuanto(e.fecha)].join('\n')),
                  trailing: e.publicacion?.estado == 'resuelta' ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : null,
                ),
            ]);
          },
        ),
      );
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto, this.valor);
  final IconData icono;
  final String texto;
  final int valor;

  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono),
          Text('$valor', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: activa ? const Color(0xFFE53935) : null)),
          const SizedBox(height: 12),
          TextField(controller: _titulo, decoration: const InputDecoration(labelText: 'Tipo de emergencia')),
          const SizedBox(height: 12),
          TextField(controller: _mensaje, maxLines: 3, decoration: const InputDecoration(labelText: 'Mensaje para los vecinos')),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: activa ? null : FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
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
