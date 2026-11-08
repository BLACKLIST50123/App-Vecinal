import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../data/datos_iniciales.dart';
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
/// Los puntos de ayuda y los pedidos están en la pestaña Mapa de ayuda.
/// Para junta, organizaciones y brigadistas: arriba, cuántos vecinos están a salvo.
class EmergenciaScreen extends StatelessWidget {
  const EmergenciaScreen({super.key, required this.irA});
  final ValueChanged<int> irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        const _AvisoJunta(),
        // Solo la junta (moderador): cuántos están a salvo. La gestión está en la pestaña Pedidos y SOS.
        if (st.esModerador) const _VecinosASalvo(),
        if (st.esBrigadista) const PanelBrigadista(),
        const _ComoEstas(),
        const _MiPedido(),
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
          ]),
        ),
      ]),
    );
  }
}

/// "Tu pedido de ayuda": lo que enviaste y cómo va (sin atender, en
/// atención, atendido, cuántos vecinos van a ayudar).
class _MiPedido extends StatelessWidget {
  const _MiPedido();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final guardado = st.miPedidoEmergencia;
    if (guardado == null && !st.logueado) return const SizedBox.shrink();
    return Cargador<Publicacion?>(
      claves: [st.emergencia.clave, guardado?['id']],
      cargar: (st) async {
        final pedidos = await cargarPedidosEmergencia(st);
        final id = guardado?['id'];
        for (final p in pedidos) {
          if (p.id == id) return p;
        }
        // Con cuenta: también lo enviado desde otro celular.
        final mios = pedidos.where((p) => p.autorId != null && p.autorId == st.uid).toList()
          ..sort((a, b) => b.creado.compareTo(a.creado));
        return mios.isEmpty ? null : mios.first;
      },
      builder: (context, p) {
        if (p == null && guardado == null) return const SizedBox.shrink();
        final titulo = p?.titulo ?? (guardado!['titulo'] ?? 'Necesito ayuda') as String;
        final critica = (p?.prioridad ?? guardado?['prioridad']) == 'critica';
        final creado = p?.creado ?? DateTime.tryParse('${guardado?['creado_offline_en']}')?.toLocal();
        final (estado, color) = p == null
            ? ('Por enviar · sin señal', Paleta.gris)
            : switch (p.estado) {
                'resuelta' => ('Atendido', Paleta.verde),
                'en_curso' => ('En atención', Paleta.azulInfo),
                _ => ('Esperando ayuda', Paleta.ambar),
              };
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Paleta.superficie,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Paleta.rojo.withValues(alpha: 0.35)),
          ),
          child: InkWell(
            onTap: p == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TU PEDIDO DE AYUDA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Paleta.rojoTexto)),
              const SizedBox(height: 4),
              Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.tinta)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _Pastilla(critica ? 'Muy urgente' : 'Urgente', critica ? Paleta.rojo : Paleta.ambar),
                _Pastilla(estado, color),
                if (creado != null) Text('Enviado ${fechaHora(creado)}', style: TextStyle(fontSize: 13, color: Paleta.gris)),
              ]),
              if (p != null && p.ayudantes > 0) ...[
                const SizedBox(height: 6),
                Text('${p.ayudantes} ${p.ayudantes == 1 ? 'vecino va' : 'vecinos van'} a ayudarte',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Paleta.verde)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla(this.texto, this.color);
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      );
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
    final esSismo = e.origen == 'sismo';
    final titulo = e.titulo ?? (esSismo ? 'Alerta Sísmica' : 'Emergencia en tu barrio');
    final texto = 'Emergencia. $titulo. ${e.mensaje ?? ''}';

    String? infoDistancia;
    if (e.lat != null && e.lng != null) {
      final d = distanciaKm(st.referencia, Punto(e.lat!, e.lng!));
      infoDistancia = 'Epicentro a ${d.toStringAsFixed(0)} km de ti';
      if (e.radioKm != null) {
        infoDistancia += ' · Radio de alerta: ${e.radioKm!.toStringAsFixed(0)} km';
      }
    }

    return Semantics(
      liveRegion: true,
      label: texto,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(color: Paleta.rojo, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(esSismo ? Icons.vibration : Icons.warning_amber_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  esSismo
                      ? 'ALERTA SÍSMICA OFICIAL'
                      : (e.desde == null ? 'AVISO DE LA JUNTA VECINAL' : 'AVISO DE LA JUNTA · ${haceCuanto(e.desde!.toLocal()).toUpperCase()}'),
                  style: const TextStyle(color: Color(0xFFFFE4E4), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
                if (infoDistancia != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      infoDistancia,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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

  static Color get _verde => Paleta.verde;

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
      decoration: BoxDecoration(color: Paleta.superficie, borderRadius: BorderRadius.circular(20), border: Border.all(color: Paleta.linea)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          header: true,
          child: Text(
            estado == null ? '¿Cómo estás?' : 'Tu estado',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Paleta.tinta),
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
          Text('Puedes cambiarlo si tu situación cambia.', style: TextStyle(fontSize: 13, color: Paleta.gris)),
        ] else ...[
          const SizedBox(height: 2),
          Text(
            st.logueado ? 'Avisa con un toque. Tu junta sabrá quién está a salvo.' : 'Si necesitas ayuda, pídela aquí. Funciona sin cuenta y sin internet.',
            style: TextStyle(fontSize: 14, color: Paleta.gris),
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
        Text(
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
        decoration: BoxDecoration(color: Paleta.superficie, borderRadius: BorderRadius.circular(18), border: Border.all(color: Paleta.linea)),
        child: Column(children: [
          Text('Vecinos en esta emergencia',
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
          Text(texto, style: TextStyle(fontSize: 13, color: Paleta.tinta)),
        ]),
      );
}
