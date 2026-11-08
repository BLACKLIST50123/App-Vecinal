import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../screens/detalles.dart';
import '../state/app_state.dart';
import '../util.dart';
import 'tema.dart';

/// Piezas visuales del diseño de Figma, adaptadas a Flutter y a
/// accesibilidad (texto mínimo 13 px, áreas táctiles de 48 px o más).

String iniciales(String? nombre) {
  final partes = (nombre ?? 'V').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return 'V';
  if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
  return (partes[0].substring(0, 1) + partes[1].substring(0, 1)).toUpperCase();
}

/// Encabezado de cada pantalla: subtítulo pequeño, título grande y acciones.
class EncabezadoPantalla extends StatelessWidget {
  const EncabezadoPantalla({super.key, required this.titulo, this.subtitulo, this.acciones = const []});
  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (subtitulo != null)
                Text(subtitulo!, style: const TextStyle(color: Paleta.gris, fontSize: 13, fontWeight: FontWeight.w500)),
              Semantics(
                header: true,
                child: Text(titulo,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26, height: 1.15)),
              ),
            ]),
          ),
          for (final a in acciones) Padding(padding: const EdgeInsets.only(left: 8), child: a),
        ]),
      );
}

/// Botón cuadrado blanco con borde (como la campana del diseño).
class BotonCuadrado extends StatelessWidget {
  const BotonCuadrado({super.key, required this.icono, required this.tooltip, required this.onTap, this.contador = 0, this.color, this.texto});
  final IconData icono;

  /// Si se indica, se muestra este texto (ej. "Aa") en lugar del ícono.
  final String? texto;
  final String tooltip;
  final VoidCallback onTap;
  final int contador;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: contador > 0 ? '$tooltip, $contador pendientes' : tooltip,
          excludeSemantics: true,
          child: Material(
            color: color ?? Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Paleta.linea)),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(alignment: Alignment.center, children: [
                  if (texto != null)
                    Text(texto!, textScaler: TextScaler.noScaling, style: const TextStyle(color: Paleta.gris, fontSize: 19, fontWeight: FontWeight.w800, height: 1))
                  else
                    Icon(icono, color: Paleta.gris),
                  if (contador > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: Paleta.acento, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Caja de búsqueda blanca con sombra suave.
class CajaBusqueda extends StatelessWidget {
  const CajaBusqueda({super.key, required this.pista, this.onChanged, this.onSubmitted, this.controller, this.etiqueta});
  final String pista;
  final String? etiqueta;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 18, offset: Offset(0, 5))],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: pista,
            labelText: etiqueta,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            prefixIcon: const Icon(Icons.search, color: Paleta.grisClaro),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
}

/// Píldora verde con el sector del vecino.
class PildoraUbicacion extends StatelessWidget {
  const PildoraUbicacion({super.key, required this.texto, this.onTap});
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.primaryContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_outlined, size: 18, color: c.primary),
            const SizedBox(width: 6),
            Text(texto, style: TextStyle(color: c.primary, fontWeight: FontWeight.w600, fontSize: 14)),
            if (onTap != null) Icon(Icons.chevron_right, size: 18, color: c.primary),
          ]),
        ),
      ),
    );
  }
}

/// Título de sección con "ceja" opcional y acción a la derecha.
class TituloDiseno extends StatelessWidget {
  const TituloDiseno(this.titulo, {super.key, this.ceja, this.accion, this.detalle});
  final String titulo;
  final String? ceja;
  final String? detalle;
  final (String, VoidCallback)? accion;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (ceja != null)
                Text(ceja!.toUpperCase(),
                    style: const TextStyle(color: Paleta.grisClaro, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              Semantics(
                header: true,
                child: Text(titulo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
              ),
            ]),
          ),
          if (detalle != null) Text(detalle!, style: const TextStyle(color: Paleta.gris, fontSize: 13)),
          if (accion != null) TextButton(onPressed: accion!.$2, child: Text(accion!.$1)),
        ]),
      );
}

/// Ícono de categoría (cuadro de color con esquinas redondeadas).
class IconoCategoria extends StatelessWidget {
  const IconoCategoria({super.key, required this.icono, required this.colores, this.tamano = 60});
  final IconData icono;
  final (Color, Color) colores;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(color: colores.$2, borderRadius: BorderRadius.circular(tamano * 0.32)),
        child: Icon(icono, color: colores.$1, size: tamano * 0.45),
      );
}

/// Acceso de la cuadrícula "Explora tu barrio".
class AccesoCategoria extends StatelessWidget {
  const AccesoCategoria({super.key, required this.texto, required this.icono, required this.colores, required this.onTap});
  final String texto;
  final IconData icono;
  final (Color, Color) colores;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconoCategoria(icono: icono, colores: colores),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Paleta.gris, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

/// Banner con degradado (marino "Entre vecinos..." o naranja "Solidaridad").
class BannerDegradado extends StatelessWidget {
  const BannerDegradado({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    required this.colores,
    this.onTap,
    this.colorIcono = Paleta.ambarSuave,
  });
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final List<Color> colores;
  final VoidCallback? onTap;
  final Color colorIcono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          borderRadius: BorderRadius.circular(21),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: const [BoxShadow(color: Color(0x2E1E293B), blurRadius: 28, offset: Offset(0, 11))],
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(17)),
                    child: Icon(icono, color: colorIcono, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.25)),
                      if (subtitulo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(subtitulo!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.4)),
                        ),
                    ]),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Pie de tarjeta: Visto Bueno a la izquierda, precio a la derecha.
class _PieServicio extends StatelessWidget {
  const _PieServicio(this.s);
  final Servicio s;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (s.pendiente)
          const Text('Por enviar', style: TextStyle(fontWeight: FontWeight.w700, color: Paleta.gris, fontSize: 13))
        else
          Semantics(
            label: '${s.vistosBuenos} Vistos Buenos',
            excludeSemantics: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.thumb_up_alt_rounded, size: 16, color: Paleta.verde),
              const SizedBox(width: 4),
              Text('${s.vistosBuenos}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Paleta.verde)),
            ]),
          ),
        const SizedBox(width: 8),
        if (s.precioRef != null)
          Expanded(
            child: Text(s.precioRef!,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
      ]);
}

/// "Cerca de ti": tarjeta horizontal. Orden de lectura: qué → quién y dónde
/// → confianza y precio. Nada a la derecha que corte el título.
class TarjetaCerca extends StatelessWidget {
  const TarjetaCerca(this.s, {super.key});
  final Servicio s;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final cat = buscarCategoria(s.categoria, emergencia: s.esEmergencia);
    final grupo = s.esEmergencia ? 'apoyo' : grupoServicio(s.categoria);
    final dist = s.punto == null ? null : distanciaKm(st.referencia, s.punto!);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServicioDetalle(servicio: s))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            IconoCategoria(icono: cat.icono, colores: colorGrupo(grupo), tamano: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.nombre.toUpperCase(),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                Text(s.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 2),
                Text([s.autorNombre ?? 'Vecino', if (dist != null) formatoDistancia(dist)].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                const SizedBox(height: 6),
                _PieServicio(s),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tarjeta horizontal de "Servicios y productos": ícono, datos, precio y flecha.
class TarjetaMercado extends StatelessWidget {
  const TarjetaMercado(this.s, {super.key});
  final Servicio s;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final cat = buscarCategoria(s.categoria, emergencia: s.esEmergencia);
    final grupo = s.esEmergencia ? 'apoyo' : grupoServicio(s.categoria);
    final colores = colorGrupo(grupo);
    final dist = s.punto == null ? null : distanciaKm(st.referencia, s.punto!);
    final apoyo = grupo == 'apoyo';
    const naranja = Paleta.acentoOscuro;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServicioDetalle(servicio: s))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Ícono de categoría (relleno naranja para ayuda voluntaria).
            Semantics(
              label: cat.nombre,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: apoyo ? Paleta.acento : colores.$2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(cat.icono, color: apoyo ? Colors.white : colores.$1, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(s.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2)),
                  ),
                  if (s.autorRol == 'organizacion')
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.verified, color: Paleta.azulInfo, size: 16),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(s.autorNombre ?? 'Vecino',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Paleta.gris, fontSize: 14)),
                const SizedBox(height: 6),
                // Lo que más importa al elegir: qué tan cerca y quién lo recomienda.
                if (dist != null)
                  _Dato(
                    icono: Icons.place_outlined,
                    texto: dist < 0.1 ? 'Muy cerca de ti' : '${_primeraMayuscula(formatoDistancia(dist))} de ti',
                    color: Paleta.tinta,
                  ),
                if (s.pendiente)
                  const _Dato(icono: Icons.schedule, texto: 'Por enviar', color: Paleta.gris)
                else if (apoyo)
                  const _Dato(icono: Icons.favorite_border, texto: 'Ayuda voluntaria', color: naranja)
                else if (s.tieneSello(st.sector))
                  // Sello: 3+ vecinos VERIFICADOS de la misma zona lo recomiendan.
                  SelloBarrio(propio: st.sector != null, total: s.vistosBuenos)
                else
                  _Dato(
                    icono: s.vistosBuenos > 0 ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                    texto: switch (s.vistosBuenos) {
                      0 => 'Aún sin recomendaciones',
                      1 => '1 vecino lo recomienda',
                      final n => '$n vecinos lo recomiendan',
                    },
                    color: s.vistosBuenos > 0 ? Paleta.verde : Paleta.gris,
                  ),
                // Por qué lo recomiendan (los 2 motivos más elegidos).
                if (!apoyo && s.motivosPrincipales().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(s.motivosPrincipales().map(textoMotivo).join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Paleta.gris, fontWeight: FontWeight.w600)),
                  ),
                if (s.precioRef != null) ...[
                  const SizedBox(height: 3),
                  Text(s.precioRef!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            // Botón cuadrado con flecha (como el diseño).
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Paleta.linea),
              ),
              child: const Icon(Icons.chevron_right, color: Paleta.tinta),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Sello dorado "Recomendado en tu barrio": lo dan 3 o más vecinos
/// verificados de la misma zona. Fácil de reconocer de un vistazo.
class SelloBarrio extends StatelessWidget {
  const SelloBarrio({super.key, required this.propio, required this.total, this.grande = false});

  /// true: zona de quien mira ("tu barrio"); false: zona del servicio.
  final bool propio;
  final int total;
  final bool grande;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${propio ? 'Recomendado en tu barrio' : 'Recomendado en su barrio'}. $total vecinos lo recomiendan.',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: EdgeInsets.symmetric(horizontal: grande ? 12 : 8, vertical: grande ? 8 : 4),
          decoration: BoxDecoration(
            color: Paleta.oroFondo,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Paleta.oroClaro),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium, size: grande ? 22 : 17, color: Paleta.ambar),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${propio ? 'Recomendado en tu barrio' : 'Recomendado en su barrio'} · $total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: grande ? 16 : 13, fontWeight: FontWeight.w800, color: Paleta.ambar),
              ),
            ),
          ]),
        ),
      );
}

String _primeraMayuscula(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

/// Un dato de la tarjeta: ícono + texto corto en una línea.
class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, required this.color});
  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Icon(icono, size: 17, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ),
        ]),
      );
}

/// Cuadrícula de 2 columnas con filas de IGUAL altura (se ve ordenada) y
/// que respeta el tamaño de letra elegido.
class Cuadricula2 extends StatelessWidget {
  const Cuadricula2({super.key, required this.hijos});
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final columnas = c.maxWidth > 700 ? 3 : 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            for (var i = 0; i < hijos.length; i += columnas)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var j = 0; j < columnas; j++) ...[
                      if (j > 0) const SizedBox(width: 11),
                      Expanded(child: i + j < hijos.length ? hijos[i + j] : const SizedBox.shrink()),
                    ],
                  ]),
                ),
              ),
          ]),
        );
      });
}

/// Fila de píldoras de filtro (como el diseño).
class FilaPildoras extends StatelessWidget {
  const FilaPildoras({super.key, required this.opciones, required this.seleccion, required this.onCambio});
  final List<(String, String)> opciones; // (valor, texto)
  final String seleccion;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: [
            for (final (valor, texto) in opciones)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(texto,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: seleccion == valor ? Colors.white : Paleta.gris,
                      )),
                  selected: seleccion == valor,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  showCheckmark: false,
                  onSelected: (_) => onCambio(valor),
                ),
              ),
          ],
        ),
      );
}

/// Contenedor blanco tipo "lista de ajustes" del diseño.
class ListaAjustes extends StatelessWidget {
  const ListaAjustes({super.key, required this.filas});
  final List<Widget> filas;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Paleta.linea),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < filas.length; i++) ...[
            filas[i],
            if (i < filas.length - 1) const Divider(height: 1),
          ],
        ]),
      );
}

class FilaAjuste extends StatelessWidget {
  const FilaAjuste({super.key, required this.icono, required this.texto, this.valor, this.onTap, this.final_, this.color});
  final IconData icono;
  final String texto;
  final String? valor;
  final VoidCallback? onTap;
  final Widget? final_;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: (color ?? c.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
              child: Icon(icono, size: 21, color: color ?? c.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color ?? Paleta.tinta))),
            if (valor != null) Text(valor!, style: const TextStyle(color: Paleta.gris, fontSize: 13)),
            final_ ?? (onTap != null ? const Icon(Icons.chevron_right, color: Paleta.grisClaro) : const SizedBox.shrink()),
          ]),
        ),
      ),
    );
  }
}

/// Número de la tarjeta de impacto del perfil.
class ImpactoNumero extends StatelessWidget {
  const ImpactoNumero(this.valor, this.texto, {super.key});
  final String valor, texto;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          label: '$texto: $valor',
          excludeSemantics: true,
          child: Column(children: [
            Text(valor, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Paleta.gris, fontSize: 13)),
          ]),
        ),
      );
}

String fechaLarga(DateTime d) {
  const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  return '${dias[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]}';
}
