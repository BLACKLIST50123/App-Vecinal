import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/datos_iniciales.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import 'auth_screen.dart';
import 'detalles.dart';
import '../ui/tema.dart';

// El panel de coordinación vive en features/emergencia (se reexporta aquí).
export '../features/emergencia/panel_coordinacion.dart' show PanelCoordinacionScreen;

// ================================================================ compartir

/// Comparte por WhatsApp (el canal que los vecinos ya usan).
Future<void> compartirWhatsapp(String texto) async {
  try {
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}'), mode: LaunchMode.externalApplication);
  } catch (_) {
    avisar('No se pudo abrir WhatsApp');
  }
}

String textoCompartir(Publicacion p) =>
    '${p.esEmergencia ? 'EMERGENCIA. ' : ''}Vecino${p.sector != null ? ' de ${p.sector}' : ''} '
    '${p.esPedido ? 'necesita' : 'ofrece'}: "${p.titulo}". '
    '${p.esPedido ? '¿Puedes ayudar? ' : ''}Míralo en Conecta Vecino ${Zona.nombre}.';

const textoInvitacion = 'Únete a Conecta Vecino ${Zona.nombre}: encuentra servicios y productos recomendados por tus vecinos, '
    'pide o presta cosas sin dinero y coordina ayuda en emergencias, incluso sin internet. Pídeme el instalador.';

// ================================================================== normas

const normasBarrio = <(IconData, String, String)>[
  (Icons.handshake, 'Respeto', 'Trata a todos por igual. No se permiten mensajes por apariencia, origen, edad o condición económica.'),
  (Icons.gavel, 'Nada de acusaciones', 'No acuses a nadie de un delito. Si ves algo grave, llama a la Policía (105).'),
  (Icons.fact_check, 'Información verdadera', 'Publica solo lo que sabes que es cierto. Las alarmas falsas quitan ayuda a quien la necesita.'),
  (Icons.privacy_tip, 'Cuida los datos', 'No publiques direcciones exactas, ni quién vive solo, ni fotos de otras personas sin permiso.'),
  (Icons.local_police, 'La app no reemplaza a las autoridades', 'En riesgo de vida llama primero a Bomberos 116, Policía 105 o SAMU 106.'),
  (Icons.flag, 'Reporta lo que esté mal', 'Si algo es falso, una estafa u ofensivo, usa "Reportar". Con 3 reportes se oculta.'),
];

Future<void> mostrarNormas(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (c, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Semantics(
              header: true,
              child: Text('Normas del barrio', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            BotonEscuchar(normasBarrio.map((n) => '${n.$2}. ${n.$3}').join(' ')),
            for (final (icono, titulo, texto) in normasBarrio)
              ListTile(
                leading: Icon(icono, size: 32),
                title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(texto, style: const TextStyle(fontSize: 16)),
              ),
          ]),
        ),
      ),
    );

// ================================================= consejos para ayudar seguro

const consejosSeguridad = <(IconData, String, String)>[
  (Icons.door_front_door, 'Encuéntrense en un lugar conocido', 'En la puerta de la casa, la bodega o el local comunal. Mejor de día.'),
  (Icons.location_off, 'Tu dirección, solo por teléfono', 'No la escribas en la publicación. Dísela solo a quien te va a ayudar.'),
  (Icons.money_off, 'Aquí no se cobra', 'La Red de Solidaridad es sin dinero. Si alguien te pide pago o un adelanto, repórtalo.'),
  (Icons.groups, 'Si es un adulto mayor, que esté acompañado', 'Que un familiar o vecino de confianza sepa quién va a ir.'),
  (Icons.flag, 'Si algo te parece raro, repórtalo', 'Toca la banderita de la publicación. Entre todos cuidamos el barrio.'),
];

Future<void> mostrarConsejos(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Semantics(
            header: true,
            child: Text('Ayudar con seguridad', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          BotonEscuchar(consejosSeguridad.map((x) => '${x.$2}. ${x.$3}').join(' ')),
          for (final (icono, titulo, texto) in consejosSeguridad)
            ListTile(
              leading: Icon(icono, size: 32),
              title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(texto, style: const TextStyle(fontSize: 16)),
            ),
        ]),
      ),
    );

// ================================================================ reportar

const motivosReporte = <(String, String, IconData)>[
  ('falso', 'Es falso o una emergencia que no existe', Icons.report),
  ('estafa', 'Parece una estafa', Icons.money_off),
  ('discriminacion', 'Discrimina u ofende', Icons.do_not_disturb_on),
  ('acusacion', 'Acusa a alguien sin pruebas', Icons.gavel),
  ('datos_personales', 'Expone datos o la dirección de alguien', Icons.privacy_tip),
  ('otro', 'Otro motivo', Icons.more_horiz),
];

Future<void> reportarContenido(BuildContext context, {required String tabla, required String id, required String titulo}) async {
  final st = context.read<AppState>();
  if (!st.logueado) {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const AuthScreen(mensaje: 'Para reportar necesitas una cuenta de vecino (así evitamos reportes falsos).'),
    ));
    return;
  }
  final motivo = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('¿Qué problema tiene?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        for (final (id, texto, icono) in motivosReporte)
          ListTile(leading: Icon(icono), title: Text(texto), onTap: () => Navigator.pop(c, id)),
      ]),
    ),
  );
  if (motivo == null) return;
  try {
    await st.repo.reportar(tabla: tabla, id: id, titulo: titulo, motivo: motivo);
    avisar('Gracias. La junta vecinal lo revisará. Con 3 reportes se oculta automáticamente.');
    st.refrescar();
  } catch (e) {
    avisar(traducirError(e).contains('ya estaba') ? 'Ya habías reportado esta publicación.' : traducirError(e));
  }
}

// ============================================== aviso: no reemplaza autoridades

class AvisoAutoridades extends StatelessWidget {
  const AvisoAutoridades({super.key});

  @override
  Widget build(BuildContext context) => Card(
        color: Paleta.ambarSuave,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info, color: Paleta.ambar),
              SizedBox(width: 8),
              Expanded(
                child: Text('Esta app coordina ayuda entre vecinos. No reemplaza a las autoridades.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Si hay riesgo de vida, llama primero:', style: TextStyle(color: Colors.black87)),
            const SizedBox(height: 8),
            BotonesNumeros(numeros: DatosIniciales.actual.numeros),
          ]),
        ),
      );
}

/// Botones para llamar: nacionales (105, 106, 116) y, si la zona los tiene
/// confirmados, los locales (Serenazgo, comisaría...).
class BotonesNumeros extends StatelessWidget {
  const BotonesNumeros({super.key, required this.numeros, this.claro = false});
  final List<NumeroEmergencia> numeros;

  /// Estilo para fondo rojo (pantalla SOS): botones blancos con borde.
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final locales = numeros.where((n) => n.local).toList();
    final nacionales = numeros.where((n) => !n.local).toList();
    Widget boton(NumeroEmergencia n) => claro
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
            ),
            onPressed: () => llamar(n.numero),
            icon: Icon(n.icono),
            label: Text('${n.numero} · ${n.nombre}'),
          )
        : FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo, foregroundColor: Colors.white),
            onPressed: () => llamar(n.numero),
            icon: Icon(n.icono),
            label: Text('${n.nombre} ${n.numero}'),
          );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [for (final n in nacionales) boton(n)]),
      if (locales.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Números de tu zona',
            style: TextStyle(fontWeight: FontWeight.w700, color: claro ? Colors.white : Colors.black87)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final n in locales) boton(n)]),
      ],
    ]);
  }
}

