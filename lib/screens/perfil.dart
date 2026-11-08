import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/foto_perfil.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'aportes.dart';
import 'auth_screen.dart';
import 'confianza.dart';
import 'detalles.dart';
import 'qr_screens.dart';
import 'roles.dart';
import 'tutorial.dart';

/// Pestaña "Perfil": foto y datos, reconocimiento, 4 accesos grandes y
/// "Más opciones". Pensada para que un adulto mayor no se pierda.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  void _ir(BuildContext context, Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  /// Pide confirmación (evita salir por un toque accidental) y avisa si hay
  /// publicaciones guardadas sin enviar. Al cerrar, vuelve a la bienvenida;
  /// el tamaño de letra y la accesibilidad se mantienen.
  Future<void> _confirmarCierre(BuildContext context, AppState st) async {
    final n = st.pendientes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.logout, size: 36),
        title: const Text('¿Cerrar sesión?'),
        content: Text(n > 0
            ? 'Tienes ${n == 1 ? '1 publicación' : '$n publicaciones'} sin enviar. '
                'Si cierras sesión ahora, podrían no enviarse. Mejor espera a tener internet.'
            : 'Volverás a la pantalla de inicio. Podrás entrar de nuevo con tu celular y tu clave.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) await st.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final ayudas = (st.perfil?['ayudas_confirmadas'] as num?)?.toInt() ?? 0;

    // Pantalla simple para adultos mayores: quién soy, mi reconocimiento,
    // 4 accesos grandes y el resto en "Más opciones".
    return ListView(padding: const EdgeInsets.only(bottom: 120), children: [
      if (st.logueado) ...[
        const _CabeceraPerfil(),
        _TarjetaReconocimiento(ayudas: ayudas),
      ] else
        _TarjetaInvitado(onEntrar: () => _ir(context, const AuthScreen())),

      const TituloDiseno('Accesos rápidos'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: st.logueado
                  ? _AccesoGrande(
                      icono: Icons.inventory_2_outlined,
                      texto: 'Mis publicaciones',
                      colores: Paleta.naranja,
                      onTap: () => _ir(
                        context,
                        Scaffold(appBar: AppBar(title: const Text('Mis publicaciones')), body: const MisAportesScreen()),
                      ),
                    )
                  : _AccesoGrande(
                      icono: Icons.school_outlined,
                      texto: 'Cómo usar la app',
                      colores: Paleta.naranja,
                      onTap: () => _ir(context, const TutorialScreen()),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AccesoGrande(
                icono: Icons.text_fields,
                texto: 'Letra y voz',
                colores: Paleta.azul,
                onTap: () => _ir(context, const AccesibilidadScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: st.logueado
                  ? _AccesoGrande(
                      icono: Icons.history,
                      texto: 'Mi historial',
                      colores: Paleta.verdeCat,
                      onTap: () => _ir(context, const HistorialScreen()),
                    )
                  : _AccesoGrande(
                      icono: Icons.rule,
                      texto: 'Normas del barrio',
                      colores: Paleta.verdeCat,
                      onTap: () => mostrarNormas(context),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AccesoGrande(
                icono: Icons.group_add_outlined,
                texto: 'Invitar vecinos',
                colores: Paleta.morado,
                onTap: () => compartirWhatsapp(textoInvitacion),
              ),
            ),
          ]),
        ]),
      ),

      // Solo para la junta vecinal y organizaciones.
      if (st.esOrganizacion || st.esModerador) ...[
        TituloDiseno(st.esModerador ? 'Junta vecinal' : 'Organización'),
        ListaAjustes(filas: [
          FilaAjuste(
            icono: Icons.dashboard_outlined,
            texto: 'Panel de coordinación',
            onTap: () => _ir(context, const PanelCoordinacionScreen()),
          ),
          if (st.esModerador)
            FilaAjuste(
              icono: Icons.campaign_outlined,
              texto: 'Modo emergencia',
              valor: st.modoEmergencia ? 'Activa' : 'Apagada',
              color: st.modoEmergencia ? Paleta.rojo : null,
              onTap: () => _ir(context, const JuntaVecinalScreen()),
            ),
        ]),
      ],

      const SizedBox(height: 12),
      ListaAjustes(filas: [
        FilaAjuste(
          icono: Icons.more_horiz,
          texto: 'Más opciones',
          valor: 'Barrio, normas, conexión',
          onTap: () => _ir(context, const MasOpcionesScreen()),
        ),
      ]),

      if (st.logueado)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _confirmarCierre(context, st),
              style: OutlinedButton.styleFrom(
                foregroundColor: Paleta.rojo,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Paleta.rojo, width: 1.5),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión', style: TextStyle(fontSize: 17)),
            ),
          ),
        ),
      const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Conecta Vecino · Equipo AlphaCoders · Hackathon UTP 2026',
            textAlign: TextAlign.center, style: TextStyle(color: Paleta.gris)),
      ),
    ]);
  }
}

/// Foto grande (tocar para cambiarla), nombre, barrio y distintivos.
class _CabeceraPerfil extends StatelessWidget {
  const _CabeceraPerfil();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final primario = Theme.of(context).colorScheme.primary;
    final rolTexto = switch (st.rol) {
      'moderador' => 'Junta vecinal · ${st.sector ?? Zona.nombre}',
      'organizacion' => 'Organización de apoyo',
      _ => 'Vecino de ${st.sector ?? Zona.nombre}',
    };
    final sinFoto = st.fotoUrl == null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Paleta.linea)),
      child: Column(children: [
        Semantics(
          button: true,
          label: sinFoto ? 'Poner mi foto de perfil' : 'Cambiar mi foto de perfil',
          child: GestureDetector(
            onTap: () => cambiarFotoPerfil(context),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Paleta.primarioSuave, width: 3)),
                child: AvatarVecino(nombre: st.nombre, fotoUrl: st.fotoUrl, tamano: 104),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Paleta.acentoOscuro,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.photo_camera, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text(st.nombre,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(rolTexto, textAlign: TextAlign.center, style: const TextStyle(color: Paleta.gris, fontSize: 16)),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          _Distintivo(
            icono: st.verificado ? Icons.verified_user : Icons.gpp_maybe_outlined,
            texto: st.verificado ? 'Vecino verificado' : 'Sin verificar',
            color: st.verificado ? primario : const Color(0xFFB45309),
          ),
          if (st.esPrestador) const _Distintivo(icono: Icons.handyman, texto: 'Ofrece servicios', color: Paleta.acentoOscuro),
        ]),
        if (sinFoto) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.tonalIcon(
              onPressed: () => cambiarFotoPerfil(context),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Poner mi foto', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Distintivo extends StatelessWidget {
  const _Distintivo({required this.icono, required this.texto, required this.color});
  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 17, color: color),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Acceso grande con ícono y texto (fácil de tocar y de leer).
class _AccesoGrande extends StatelessWidget {
  const _AccesoGrande({required this.icono, required this.texto, required this.colores, required this.onTap});
  final IconData icono;
  final String texto;
  final (Color, Color) colores;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: texto,
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Paleta.linea)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: colores.$2, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icono, color: colores.$1, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2)),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _TarjetaInvitado extends StatelessWidget {
  const _TarjetaInvitado({required this.onEntrar});
  final VoidCallback onEntrar;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Paleta.linea)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: Icon(Icons.account_circle, size: 84, color: Paleta.primarioSuave)),
          const SizedBox(height: 8),
          const Text('Estás como invitado',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Crea tu cuenta gratis para publicar, ayudar, poner tu foto y ganar reconocimiento.',
              textAlign: TextAlign.center, style: TextStyle(color: Paleta.gris, fontSize: 16, height: 1.35)),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onEntrar,
              icon: const Icon(Icons.login),
              label: const Text('Ingresar o crear cuenta', style: TextStyle(fontSize: 17)),
            ),
          ),
        ]),
      );
}

/// Opciones que se usan poco: aquí no estorban en la pantalla principal.
class MasOpcionesScreen extends StatelessWidget {
  const MasOpcionesScreen({super.key});

  void _ir(BuildContext context, Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Más opciones')),
      body: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
        const TituloDiseno('Mi barrio'),
        ListaAjustes(filas: [
          FilaAjuste(icono: Icons.location_on_outlined, texto: 'Mi barrio', valor: st.sector ?? Zona.nombre),
          FilaAjuste(
            icono: infoRol(st.rolSimulado).icono,
            texto: '¿Quién soy hoy?',
            valor: infoRol(st.rolSimulado).titulo.split(' /').first,
            color: infoRol(st.rolSimulado).color,
            onTap: () => _ir(context, const SelectorRolScreen(inicial: false)),
          ),
          FilaAjuste(
            icono: Icons.emoji_events_outlined,
            texto: 'Vecinos que más ayudan',
            onTap: () => _ir(context, const VecinosDestacadosScreen()),
          ),
        ]),
        const TituloDiseno('Seguridad'),
        ListaAjustes(filas: [
          FilaAjuste(icono: Icons.rule, texto: 'Normas del barrio', onTap: () => mostrarNormas(context)),
          FilaAjuste(icono: Icons.shield_outlined, texto: 'Ayudar con seguridad', onTap: () => mostrarConsejos(context)),
        ]),
        const TituloDiseno('Ayuda'),
        ListaAjustes(filas: [
          FilaAjuste(
            icono: st.online ? Icons.cloud_done_outlined : Icons.cloud_off,
            texto: 'Conexión y mensajes QR',
            valor: st.pendientes > 0 ? '${st.pendientes} por enviar' : (st.online ? 'Con internet' : 'Sin internet'),
            onTap: () => _ir(context, const ConexionScreen()),
          ),
          FilaAjuste(icono: Icons.help_outline, texto: 'Cómo usar la app', onTap: () => _ir(context, const TutorialScreen())),
        ]),
      ]),
    );
  }
}

/// Reconocimiento público: los vecinos con más ayudas confirmadas.
class VecinosDestacadosScreen extends StatelessWidget {
  const VecinosDestacadosScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vecinos que más ayudan')),
        body: Cargador<List<Map<String, dynamic>>>(
          cargar: (st) => st.repo.vecinosDestacados(),
          builder: (c, destacados) => ListView(padding: const EdgeInsets.only(top: 8, bottom: 120), children: [
            if (destacados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay ayudas confirmadas en el barrio.',
                    textAlign: TextAlign.center, style: TextStyle(color: Paleta.gris, fontSize: 16)),
              )
            else
              ListaAjustes(filas: [
                for (final d in destacados)
                  FilaAjuste(
                    icono: Icons.emoji_events_outlined,
                    texto: (d['nombre'] ?? 'Vecino') as String,
                    valor: () {
                      final n = (d['ayudas_confirmadas'] as num?)?.toInt() ?? 0;
                      return '${Nivel.de(n).corto} · $n ${n == 1 ? 'ayuda' : 'ayudas'}';
                    }(),
                  ),
              ]),
          ]),
        ),
      );
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            MedallaNivel(n, tamano: 56),
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
          const SizedBox(height: 14),
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
                : 'Te ${faltan == 1 ? 'falta 1 ayuda confirmada' : 'faltan $faltan ayudas confirmadas'} para ser ${sig.nombre}',
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

/// Historial: una frase de resumen, 3 cifras, distintivos y lo hecho por mes.
class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  static (IconData, Color) _icono(String tipo) => switch (tipo) {
        'agradecimiento' => (Icons.favorite, const Color(0xFFC2185B)),
        'visto_bueno' => (Icons.thumb_up, const Color(0xFF2E7D32)),
        _ => (Icons.volunteer_activism, const Color(0xFF1565C0)),
      };

  static const _meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

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
            final vbs = lista.where((e) => e.tipo == 'visto_bueno').length;
            final colectas = respondi.where((e) => e.publicacion?.esColecta == true).length;
            final emergencias = respondi.where((e) => e.publicacion?.esEmergencia == true).length;
            final cuidado = respondi.where((e) => e.publicacion?.categoria == 'cuidado').length;
            final vecinos = respondi.map((e) => e.publicacion?.autorVisible).whereType<String>().toSet().length;

            // Agrupa por mes, manteniendo el orden (más reciente primero).
            final porMes = <String, List<EntradaHistorial>>{};
            for (final e in lista) {
              porMes.putIfAbsent('${_meses[e.fecha.month - 1]} ${e.fecha.year}', () => []).add(e);
            }

            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  respondi.isEmpty
                      ? 'Aún no respondes a un pedido, ¡pero ya sumas en el barrio!'
                      : 'Ayudaste a $vecinos ${vecinos == 1 ? 'vecino' : 'vecinos'} y recibiste $gracias ${gracias == 1 ? 'agradecimiento' : 'agradecimientos'}.',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  _Dato(Icons.volunteer_activism, 'Ayudas', respondi.length),
                  const SizedBox(width: 8),
                  _Dato(Icons.favorite, 'Gracias', gracias),
                  const SizedBox(width: 8),
                  _Dato(Icons.thumb_up, 'Vistos Buenos', vbs),
                ]),
              ),
              if (emergencias > 0 || cuidado > 0 || colectas > 0) ...[
                const TituloSeccion('Tus distintivos'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    if (emergencias > 0)
                      const Chip(avatar: Icon(Icons.health_and_safety_rounded, size: 18), label: Text('Ayudó en una emergencia')),
                    if (cuidado > 0) const Chip(avatar: Icon(Icons.elderly_rounded, size: 18), label: Text('Acompaña a los mayores')),
                    if (colectas > 0)
                      const Chip(avatar: Icon(Icons.redeem_rounded, size: 18), label: Text('Apoya eventos solidarios')),
                  ]),
                ),
              ],
              for (final MapEntry(key: mes, value: entradas) in porMes.entries) ...[
                TituloSeccion(mes),
                for (final e in entradas)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _icono(e.tipo).$2.withValues(alpha: 0.15),
                      child: Icon(_icono(e.tipo).$1, color: _icono(e.tipo).$2),
                    ),
                    title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([?e.detalle, haceCuanto(e.fecha)].where((s) => s.isNotEmpty).join('\n')),
                    trailing: e.publicacion == null
                        ? null
                        : e.publicacion!.estado == 'resuelta'
                            ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
                            : const Icon(Icons.chevron_right),
                    onTap: e.publicacion == null
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: e.publicacion!))),
                  ),
              ],
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
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icono),
            Text('$valor', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            Text(texto, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
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
