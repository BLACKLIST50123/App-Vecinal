import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/datos_iniciales.dart';
import '../inicio/mapa_inicio.dart';
import 'pedidos_emergencia.dart';
import 'pedir_ayuda_rapido.dart';
import '../../models.dart';
import '../../screens/confianza.dart';
import '../../screens/detalles.dart';
import '../../screens/inicio.dart';
import '../../screens/publicar.dart';
import '../../screens/qr_screens.dart';
import '../../services/voz.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';

/// Pestaña Emergencia: una sola columna, sin acciones repetidas y con el rojo
/// solo en lo crítico.
///   1. Aviso de la junta
///   2. ¿Cómo estás?  → Estoy bien / Necesito ayuda
///   3. Llamar ahora (105 · 106 · 116)
///   4. También puedes (avisar de un vecino, compartir, QR sin internet)
///   5. Tu punto de ayuda más cercano y cuántos piden ayuda (→ Mapa de ayuda)
/// Para junta, organizaciones y brigadistas: arriba, cuántos vecinos están a salvo.
class EmergenciaScreen extends StatelessWidget {
  const EmergenciaScreen({super.key, required this.irA});
  final ValueChanged<int> irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final coordina = st.esModerador || st.esOrganizacion || st.esBrigadista;
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        const _AvisoJunta(),
        if (coordina) const _VecinosASalvo(),
        if (st.esBrigadista) const PanelBrigadista(),
        const _ComoEstas(),
        _AyudaCerca(irAlMapa: () => irA(1)),
        const _Bloque(
          titulo: 'Llamar ahora',
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _Numeros(),
          ),
        ),
        _Bloque(
          titulo: 'También puedes',
          child: ListaAjustes(filas: [
            FilaAjuste(
              icono: Icons.elderly_outlined,
              texto: 'Avisar de un vecino que necesita ayuda',
              onTap: () => abrirFormulario(context, TipoForm.reportarVulnerable),
            ),
            FilaAjuste(
              icono: Icons.inventory_2_outlined,
              texto: 'Tengo algo para compartir',
              onTap: () => abrirFormulario(context, TipoForm.ofrezcoRecurso),
            ),
            FilaAjuste(
              icono: Icons.qr_code_scanner,
              texto: 'Sin internet: llevar mensajes por QR',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EscanearQrScreen())),
            ),
            if (coordina)
              FilaAjuste(
                icono: Icons.dashboard_outlined,
                texto: 'Panel de coordinación',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelCoordinacionScreen())),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Tu punto de ayuda más cercano y cuántos vecinos piden ayuda en ESTA
/// emergencia (el detalle de ambos está en el Mapa de ayuda).
class _AyudaCerca extends StatelessWidget {
  const _AyudaCerca({required this.irAlMapa});
  final VoidCallback irAlMapa;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Cargador<List<PuntoMapa>>(
      claves: [st.emergencia.clave],
      cargar: (st) async {
        final r = await Future.wait([
          st.repo.servicios(emergencia: true),
          st.repo.publicaciones(emergencia: true),
          st.repo.alertasSos(),
        ]);
        return armarPuntosEmergencia(
          grupos: r[0] as List<Servicio>,
          pedidos: [...r[2] as List<Publicacion>, ...r[1] as List<Publicacion>],
          desde: st.emergencia.desde,
        );
      },
      builder: (context, puntos) {
        final ref = st.referencia;
        final grupos = puntos.where((p) => p.tipo == TipoPunto.grupo).toList()
          ..sort((a, b) => distanciaKm(ref, a.punto).compareTo(distanciaKm(ref, b.punto)));
        final piden = puntos.where((p) => p.tipo == TipoPunto.emergencia).length;
        final cercano = grupos.isEmpty ? null : grupos.first;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const TituloDiseno('Tu punto de ayuda más cercano'),
          if (cercano == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('La junta aún no ha publicado puntos de ayuda para esta emergencia.',
                  style: TextStyle(color: Paleta.gris)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => abrirPuntoDeAyuda(context, cercano.servicio!),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Paleta.linea)),
                    child: Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: TipoPunto.grupo.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(cercano.icono, color: TipoPunto.grupo.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(cercano.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                          Text(formatoDistancia(distanciaKm(ref, cercano.punto)),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TipoPunto.grupo.color)),
                          const Text('Toca para llamar, ver cómo llegar o pedirles ayuda',
                              style: TextStyle(fontSize: 12, color: Paleta.gris)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Paleta.grisClaro),
                    ]),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Todos los reportes de "Necesito ayuda" y SOS, cada uno con "Ver en el mapa".
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: piden == 0 ? null : Paleta.rojoTexto,
                    side: BorderSide(color: piden == 0 ? Paleta.linea : Paleta.rojo, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: piden == 0
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PedidosEmergenciaScreen())),
                  icon: const Icon(Icons.front_hand_outlined),
                  label: Text(piden == 0 ? 'Nadie pide ayuda aún' : '$piden ${piden == 1 ? 'pedido' : 'pedidos'} de ayuda'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: irAlMapa,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Mapa'),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.child});
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TituloDiseno(titulo),
        child,
      ]);
}

/// Tarjeta roja con el aviso de la junta: el único bloque rojo grande.
class _AvisoJunta extends StatelessWidget {
  const _AvisoJunta();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final e = st.emergencia;
    final titulo = e.titulo ?? 'Emergencia en tu barrio';
    final texto = 'Emergencia. $titulo. ${e.mensaje ?? ''}';
    return Semantics(
      liveRegion: true,
      label: texto,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(color: Paleta.rojo, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  e.desde == null ? 'AVISO DE LA JUNTA VECINAL' : 'AVISO DE LA JUNTA · ${haceCuanto(e.desde!.toLocal()).toUpperCase()}',
                  style: const TextStyle(color: Color(0xFFFFE4E4), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
                if (e.mensaje != null && e.mensaje!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.mensaje!, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35)),
                ],
              ]),
            ),
          ),
          IconButton(
            tooltip: 'Escuchar aviso',
            onPressed: () => Voz.hablar(texto),
            icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
          ),
        ]),
      ),
    );
  }
}

/// ¿Cómo estás? Estoy bien / Necesito ayuda.
class _ComoEstas extends StatelessWidget {
  const _ComoEstas();

  static const _verde = Color(0xFF15803D);

  Future<void> _bien(BuildContext context) async {
    final st = context.read<AppState>();
    try {
      await st.marcarEstado('bien');
      avisar(st.online ? 'Gracias. Tu junta sabe que estás bien.' : 'Guardado. Se avisará cuando vuelva la señal.');
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  void _ayuda(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PedirAyudaRapidoScreen()));

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final estado = st.miEstado;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Paleta.linea)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          header: true,
          child: Text(
            estado == null ? '¿Cómo estás?' : 'Tu estado',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Paleta.tinta),
          ),
        ),
        if (estado != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(estado == 'bien' ? Icons.check_circle_rounded : Icons.front_hand_rounded,
                color: estado == 'bien' ? _verde : Paleta.rojo, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                estado == 'bien' ? 'Avisaste que estás bien.' : 'Avisaste que necesitas ayuda.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: estado == 'bien' ? _verde : Paleta.rojoTexto),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Puedes cambiarlo si tu situación cambia.', style: TextStyle(fontSize: 13, color: Paleta.gris)),
        ] else ...[
          const SizedBox(height: 2),
          Text(
            st.logueado ? 'Avisa con un toque. Tu junta sabrá quién está a salvo.' : 'Si necesitas ayuda, pídela aquí. Funciona sin cuenta y sin internet.',
            style: const TextStyle(fontSize: 14, color: Paleta.gris),
          ),
        ],
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (st.logueado) ...[
              Expanded(
                child: _BotonEstado(
                  icono: Icons.check_rounded,
                  titulo: 'Estoy bien',
                  detalle: 'Avisa a tu junta',
                  color: _verde,
                  relleno: estado == 'bien',
                  onTap: () => _bien(context),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _BotonEstado(
                icono: Icons.front_hand_rounded,
                titulo: 'Necesito ayuda',
                detalle: 'Se envía en 1 toque',
                color: Paleta.rojo,
                relleno: true,
                onTap: () => _ayuda(context),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Botón grande de estado: círculo con ícono, título y una línea de ayuda.
class _BotonEstado extends StatelessWidget {
  const _BotonEstado({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.relleno,
    required this.onTap,
  });
  final IconData icono;
  final String titulo, detalle;
  final Color color;
  final bool relleno;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = relleno ? Colors.white : color;
    return Semantics(
      button: true,
      label: '$titulo. $detalle',
      excludeSemantics: true,
      child: Material(
        color: relleno ? color : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        elevation: relleno ? 3 : 0,
        shadowColor: color.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: relleno ? null : Border.all(color: color, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: relleno ? Colors.white.withValues(alpha: 0.22) : color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 30, color: texto),
              ),
              const SizedBox(height: 10),
              Text(titulo, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: texto)),
              const SizedBox(height: 2),
              Text(detalle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: relleno ? Colors.white70 : Paleta.gris)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Numeros extends StatelessWidget {
  const _Numeros();

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BotonesNumeros(numeros: DatosIniciales.actual.numeros),
        const SizedBox(height: 6),
        const Text(
          'Esta app coordina ayuda entre vecinos. Si hay riesgo de vida, llama primero.',
          style: TextStyle(fontSize: 12, color: Paleta.gris),
        ),
      ]);
}

/// Junta el conteo sin repetir a nadie: "necesitan ayuda" suma a quien tocó
/// "Necesito ayuda", a quien mandó un SOS o un pedido de esta emergencia (con
/// o sin cuenta). Quien tiene un pedido abierto no cuenta como "a salvo".
/// Función pura para poder probarla.
({int bien, int ayuda}) contarVecinos({
  required Set<String> bien,
  required Set<String> ayuda,
  required List<Publicacion> pedidos,
}) {
  final conPedido = {for (final p in pedidos) if (p.autorId != null) p.autorId!};
  final sinCuenta = pedidos.where((p) => p.autorId == null).length;
  final necesitan = {...ayuda, ...conPedido};
  return (bien: bien.difference(necesitan).length, ayuda: necesitan.length + sinCuenta);
}

/// Para quienes coordinan: cuántos vecinos avisaron que están bien y cuántos
/// necesitan ayuda en esta emergencia (se actualiza en tiempo real).
class _VecinosASalvo extends StatelessWidget {
  const _VecinosASalvo();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final clave = st.emergencia.clave;
    if (clave == null) return const SizedBox.shrink();
    return Cargador<({int bien, int ayuda})>(
      claves: [clave],
      cargar: (st) async {
        var estados = (bien: <String>{}, ayuda: <String>{});
        try {
          estados = await st.repo.resumenEstados(clave);
        } catch (_) {} // sin la migración 0012: se cuentan solo los pedidos
        final pedidos = await cargarPedidosEmergencia(st);
        return contarVecinos(bien: estados.bien, ayuda: estados.ayuda, pedidos: pedidos);
      },
      builder: (context, r) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Paleta.linea)),
        child: Column(children: [
          const Text('Vecinos en esta emergencia',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Paleta.gris, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(children: [
              Expanded(child: _Cifra(valor: r.bien, texto: 'a salvo', color: _ComoEstas._verde, icono: Icons.check_circle_rounded)),
              const VerticalDivider(width: 1),
              Expanded(child: _Cifra(valor: r.ayuda, texto: 'necesitan ayuda', color: Paleta.rojo, icono: Icons.front_hand_rounded)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.texto, required this.color, required this.icono});
  final int valor;
  final String texto;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$valor $texto',
        excludeSemantics: true,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 6),
            Text('$valor', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
          ]),
          Text(texto, style: const TextStyle(fontSize: 13, color: Paleta.tinta)),
        ]),
      );
}
