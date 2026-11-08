import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';
import 'auth_screen.dart';

/// Pantalla de entrada: logo animado, iniciar sesión, crear cuenta o entrar
/// como invitado (explicando qué se puede hacer sin cuenta).
class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> with TickerProviderStateMixin {
  /// Entrada: logo, nombre, lema y botones aparecen en cascada.
  late final AnimationController _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  /// Después: el logo "respira" suavemente.
  late final AnimationController _respiro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    _entrada.forward().whenComplete(() {
      if (mounted) _respiro.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Accesibilidad: si el celular pide "reducir animaciones", todo aparece quieto.
    if (MediaQuery.of(context).disableAnimations) {
      _entrada.value = 1;
      _respiro.stop();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _respiro.dispose();
    super.dispose();
  }

  Animation<double> _tramo(double desde, double hasta, [Curve curva = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _entrada,
    curve: Interval(desde, hasta, curve: curva),
  );

  void _abrirCuenta(int tab) => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthScreen(tabInicial: tab)));

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Paleta.crema,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              // Alto mínimo = pantalla: el logo arriba y los botones abajo,
              // al alcance del pulgar. Ancho máximo 440 en tablet o web.
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(math.max(24, (c.maxWidth - 440) / 2), 28, math.max(24, (c.maxWidth - 440) / 2), 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        SizedBox(height: c.maxHeight > 700 ? 28 : 8),
                        _LogoAnimado(entrada: _entrada, respiro: _respiro),
                        const SizedBox(height: 22),
                        _Aparece(
                          animacion: _tramo(0.40, 0.75),
                          child: Semantics(
                            header: true,
                            label: 'Conecta Vecino',
                            excludeSemantics: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Conecta ',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(
                                    text: 'Vecino',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                              style: const TextStyle(fontSize: 34, color: Paleta.tinta, letterSpacing: -0.5, height: 1.1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Aparece(
                          animacion: _tramo(0.55, 0.85),
                          child: Text(
                            'Tu barrio te respalda, con o sin internet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, color: Paleta.gris, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _Aparece(
                      animacion: _tramo(0.65, 1.0),
                      desplazamiento: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (st.modoEmergencia) ...[_AvisoEmergencia(onPedirAyuda: st.entrarEnEmergencia), const SizedBox(height: 16)],
                          SizedBox(
                            height: 58,
                            child: FilledButton.icon(
                              onPressed: () => _abrirCuenta(0),
                              icon: const Icon(Icons.login),
                              label: const Text('Iniciar sesión', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 58,
                            child: OutlinedButton.icon(
                              onPressed: () => _abrirCuenta(1),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Paleta.primario, width: 1.5),
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Crear cuenta gratis', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Row(
                            children: [
                              Expanded(child: Divider(color: Paleta.linea)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('o', style: TextStyle(color: Paleta.gris)),
                              ),
                              Expanded(child: Divider(color: Paleta.linea)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 52,
                            child: TextButton.icon(
                              onPressed: () => mostrarModoInvitado(context),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Entrar como invitado', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Equipo AlphaCoders · ${Zona.nombre}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Paleta.gris, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================ logo animado

/// Halo que se expande, logo que entra con un rebote suave y luego flota.
class _LogoAnimado extends StatelessWidget {
  const _LogoAnimado({required this.entrada, required this.respiro});
  final AnimationController entrada;
  final AnimationController respiro;

  @override
  Widget build(BuildContext context) {
    final halo = CurvedAnimation(
      parent: entrada,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    final escala = CurvedAnimation(
      parent: entrada,
      curve: const Interval(0.05, 0.60, curve: Curves.elasticOut),
    );
    final opacidad = CurvedAnimation(parent: entrada, curve: const Interval(0.05, 0.30));
    final onda = CurvedAnimation(
      parent: entrada,
      curve: const Interval(0.35, 0.95, curve: Curves.easeOut),
    );
    return Semantics(
      image: true,
      label: 'Logo de Conecta Vecino: dos vecinos dándose la mano dentro de una casa',
      child: SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: Listenable.merge([entrada, respiro]),
          builder: (context, _) {
            final t = respiro.value * 2 * math.pi;
            final flota = math.sin(t) * 4; // ±4 px
            final latido = 1 + math.sin(t) * 0.025;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Onda que sale una vez al aparecer (como un "saludo").
                if (onda.value > 0 && onda.value < 1)
                  Opacity(
                    opacity: (1 - onda.value) * 0.5,
                    child: Container(
                      width: 150 + 70 * onda.value,
                      height: 150 + 70 * onda.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Paleta.acento, width: 2),
                      ),
                    ),
                  ),
                // Halo de fondo.
                Transform.scale(
                  scale: (0.6 + 0.4 * halo.value) * latido,
                  child: Opacity(
                    opacity: halo.value,
                    child: Container(
                      width: 184,
                      height: 184,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Colors.white, Paleta.primarioSuave]),
                        boxShadow: [BoxShadow(color: Paleta.primario.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 12))],
                      ),
                    ),
                  ),
                ),
                // Logo.
                Transform.translate(
                  offset: Offset(0, flota),
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * escala.value,
                    child: Opacity(
                      opacity: opacidad.value,
                      child: Image.asset('assets/images/logo_icono.png', width: 118, filterQuality: FilterQuality.medium),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Aparece subiendo y con desvanecido, según [animacion].
class _Aparece extends StatelessWidget {
  const _Aparece({required this.animacion, required this.child, this.desplazamiento = 12});
  final Animation<double> animacion;
  final Widget child;
  final double desplazamiento;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animacion,
    builder: (_, child) => Opacity(
      opacity: animacion.value,
      child: Transform.translate(offset: Offset(0, desplazamiento * (1 - animacion.value)), child: child),
    ),
    child: child,
  );
}

class _AvisoEmergencia extends StatelessWidget {
  const _AvisoEmergencia({required this.onPedirAyuda});
  final VoidCallback onPedirAyuda;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Paleta.rojoSuave, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Paleta.rojo),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hay una emergencia activa en tu barrio',
                style: TextStyle(color: Paleta.rojo, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Puedes pedir ayuda ahora mismo, sin cuenta.', style: TextStyle(fontSize: 15)),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo, foregroundColor: Colors.white),
            onPressed: onPedirAyuda,
            icon: const Icon(Icons.sos),
            label: const Text('NECESITO AYUDA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    ),
  );
}

// ============================================================ modo invitado

/// Explica qué se puede y qué no se puede hacer sin cuenta (según las
/// reglas de la app y de la base de datos) antes de entrar como invitado.
Future<void> mostrarModoInvitado(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (c) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text('Entrar como invitado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ),
          const SizedBox(height: 4),
          const Text('Puedes mirar todo el barrio sin registrarte.', style: TextStyle(color: Paleta.gris, fontSize: 15)),
          const SizedBox(height: 16),
          const _ListaPermisos(
            titulo: 'Sin cuenta puedes',
            color: Paleta.verde,
            icono: Icons.check_circle,
            items: [
              'Ver servicios y productos con su Visto Bueno',
              'Llamar o escribir por WhatsApp a quien ofrece',
              'Ver favores, colectas y el mapa del barrio',
              'En una emergencia: pedir ayuda y avisar de un vecino vulnerable',
            ],
          ),
          const SizedBox(height: 12),
          const _ListaPermisos(
            titulo: 'Necesitas cuenta para',
            color: Paleta.acentoOscuro,
            icono: Icons.lock_outline,
            items: [
              'Publicar favores, servicios o colectas',
              'Dar tu Visto Bueno a un servicio',
              'Responder "Yo ayudo" a un vecino',
              'Reportar contenido falso o una estafa',
              'Tener tu historial y reconocimiento en el barrio',
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(c);
                context.read<AppState>().entrarComoInvitado();
              },
              child: const Text('Entrar como invitado', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen(tabInicial: 1)));
            },
            child: const Text('Mejor creo mi cuenta (1 minuto)'),
          ),
        ],
      ),
    ),
  ),
);

class _ListaPermisos extends StatelessWidget {
  const _ListaPermisos({required this.titulo, required this.color, required this.icono, required this.items});
  final String titulo;
  final Color color;
  final IconData icono;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
        const SizedBox(height: 10),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(i, style: const TextStyle(fontSize: 15, height: 1.3))),
              ],
            ),
          ),
      ],
    ),
  );
}
