import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/sugerencias.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';
import '../util.dart';

/// Modal para publicar una nueva consulta o tema en el foro vecinal.
class ModalNuevoTema extends StatefulWidget {
  const ModalNuevoTema({super.key, this.textoInicial});

  /// Pregunta ya escrita desde "¿Qué necesitas hoy?" del Inicio.
  final String? textoInicial;

  @override
  State<ModalNuevoTema> createState() => _ModalNuevoTemaState();
}

class _ModalNuevoTemaState extends State<ModalNuevoTema> {
  final _formKey = GlobalKey<FormState>();
  TipoPublicacionForo _tipo = TipoPublicacionForo.servicio;
  String? _categoriaServicio = 'gasfiteria';
  late String _sector;
  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _contenidoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _sector = st.sector ?? 'Bellamar';
    final t = widget.textoInicial?.trim();
    if (t != null && t.isNotEmpty) {
      _tituloCtrl.text = t.length > 80 ? t.substring(0, 80) : t;
      _categoriaServicio = sugerirCategoria(t, [for (final c in categoriasServicio) c.id]) ?? _categoriaServicio;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _guardando) return;

    final st = context.read<AppState>();
    setState(() => _guardando = true);

    try {
      await st.repo.crearTemaForo({
        'autor_id': st.uid,
        'tipo': _tipo.name,
        'categoria_servicio': _tipo == TipoPublicacionForo.servicio
            ? _categoriaServicio
            : null,
        'sector': _sector,
        'titulo': _tituloCtrl.text.trim(),
        'contenido': _contenidoCtrl.text.trim(),
        'lat': st.ubicacion?.lat,
        'lng': st.ubicacion?.lng,
      });

      st.refrescar();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tu consulta se ha publicado en el foro.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Paleta.primario,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al publicar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Paleta.linea,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nueva consulta vecinal',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),

              // Selector de tipo de publicación
              const Text(
                '¿De qué trata tu publicación?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Buscar servicio u oficio'),
                    selected: _tipo == TipoPublicacionForo.servicio,
                    selectedColor: Paleta.acentoSuave,
                    labelStyle: TextStyle(
                      color: _tipo == TipoPublicacionForo.servicio
                          ? Paleta.acentoOscuro
                          : Paleta.tinta,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) => setState(() {
                      _tipo = TipoPublicacionForo.servicio;
                      _categoriaServicio ??= 'gasfiteria';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Comunidad'),
                    selected: _tipo == TipoPublicacionForo.dialogo,
                    selectedColor: Paleta.verdeSuave,
                    labelStyle: TextStyle(
                      color: _tipo == TipoPublicacionForo.dialogo
                          ? Paleta.verde
                          : Paleta.tinta,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) =>
                        setState(() => _tipo = TipoPublicacionForo.dialogo),
                  ),
                  ChoiceChip(
                    label: const Text('Aviso vecinal'),
                    selected: _tipo == TipoPublicacionForo.aviso,
                    selectedColor: Paleta.violetaSuave,
                    labelStyle: TextStyle(
                      color: _tipo == TipoPublicacionForo.aviso
                          ? Paleta.violeta
                          : Paleta.tinta,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) =>
                        setState(() => _tipo = TipoPublicacionForo.aviso),
                  ),
                ],
              ),

              if (_tipo == TipoPublicacionForo.servicio) ...[
                const SizedBox(height: 14),
                const Text(
                  'Oficio que necesitas:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final catActual = buscarCategoria(_categoriaServicio ?? 'gasfiteria');
                    final ancho = MediaQuery.of(context).size.width - 40;
                    return Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: PopupMenuButton<String>(
                        tooltip: 'Seleccionar oficio',
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Paleta.linea),
                        ),
                        elevation: 8,
                        color: Paleta.superficie,
                        constraints: BoxConstraints(
                          maxHeight: 270,
                          minWidth: ancho,
                          maxWidth: ancho,
                        ),
                        onSelected: (val) {
                          setState(() => _categoriaServicio = val);
                        },
                        itemBuilder: (context) {
                          return categoriasServicio.map((c) {
                            final seleccionado = c.id == _categoriaServicio;
                            return PopupMenuItem<String>(
                              value: c.id,
                              height: 44,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: seleccionado
                                            ? Paleta.acentoSuave
                                            : Paleta.grisFondo,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        c.icono,
                                        size: 15,
                                        color: seleccionado
                                            ? Paleta.acentoOscuro
                                            : Paleta.gris,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        c.nombre,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: seleccionado
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: seleccionado
                                              ? Paleta.acentoOscuro
                                              : Paleta.tinta,
                                        ),
                                      ),
                                    ),
                                    if (seleccionado)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Paleta.acentoOscuro,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Paleta.grisFondo,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Paleta.linea),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Paleta.acentoSuave,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  catActual.icono,
                                  size: 16,
                                  color: Paleta.acentoOscuro,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  catActual.nombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Paleta.tinta,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Paleta.gris,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 14),
              const Text(
                'Sector o barrio:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final ancho = MediaQuery.of(context).size.width - 40;
                  return Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: PopupMenuButton<String>(
                      tooltip: 'Seleccionar sector',
                      position: PopupMenuPosition.under,
                      offset: const Offset(0, 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Paleta.linea),
                      ),
                      elevation: 8,
                      color: Paleta.superficie,
                      constraints: BoxConstraints(
                        maxHeight: 280,
                        minWidth: ancho,
                        maxWidth: ancho,
                      ),
                      onSelected: (val) {
                        setState(() => _sector = val);
                      },
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[];
                        for (final entry in Zona.sectoresPorCiudad.entries) {
                          items.add(
                            PopupMenuItem<String>(
                              enabled: false,
                              height: 32,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Paleta.grisFondo,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Paleta.linea,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_city_rounded,
                                      size: 13,
                                      color: Paleta.primario,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      entry.key.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Paleta.primario,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          for (final s in entry.value) {
                            final seleccionado = s == _sector;
                            items.add(
                              PopupMenuItem<String>(
                                value: s,
                                height: 40,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: seleccionado
                                          ? Paleta.verde
                                          : Paleta.grisClaro,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        s,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: seleccionado
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: seleccionado
                                              ? Paleta.verde
                                              : Paleta.tinta,
                                        ),
                                      ),
                                    ),
                                    if (seleccionado)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Paleta.verde,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                        return items;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Paleta.grisFondo,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Paleta.linea),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: Paleta.primario,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _sector,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Paleta.tinta,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Paleta.gris,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Título de tu consulta:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _tituloCtrl,
                maxLength: Limites.titulo,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ej: ¿Alguien conoce un buen gasfitero para tubería rota?',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => validarTitulo(v ?? '', min: 8, vacio: 'Ingresa un título claro'),
              ),

              const SizedBox(height: 14),
              const Text(
                'Detalle de lo que requieres:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contenidoCtrl,
                maxLines: 3,
                maxLength: Limites.texto,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe el problema, urgencia o lo que buscas consultar con los vecinos...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => validarTexto(v ?? '', obligatorio: true),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Paleta.primario,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Publicar en el foro',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal especializado para recomendar un especialista o prestador con teléfono directo.
class ModalRecomendarPrestador extends StatefulWidget {
  const ModalRecomendarPrestador({
    super.key,
    required this.tema,
    required this.onRecomendado,
  });

  final TemaForo tema;
  final VoidCallback onRecomendado;

  @override
  State<ModalRecomendarPrestador> createState() =>
      _ModalRecomendarPrestadorState();
}

class _ModalRecomendarPrestadorState extends State<ModalRecomendarPrestador> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarRecomendacion() async {
    if (!_formKey.currentState!.validate() || _enviando) return;

    final st = context.read<AppState>();
    setState(() => _enviando = true);

    try {
      await st.repo.crearRespuestaForo({
        'tema_id': widget.tema.id,
        'autor_id': st.uid,
        'contenido': _comentarioCtrl.text.trim(),
        'nombre_comercial': _nombreCtrl.text.trim(),
        'contacto_telefono': _telefonoCtrl.text.trim(),
        'sector': st.sector,
      });

      widget.onRecomendado();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Recomendación compartida con éxito!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Paleta.verde,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir recomendación: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Paleta.linea,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Paleta.ambarSuave,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.recommend_rounded,
                      color: Paleta.ambar,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recomendar a un especialista',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Comparte los datos de contacto con el vecino',
                          style: TextStyle(fontSize: 12, color: Paleta.gris),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Nombre del especialista o negocio:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreCtrl,
                maxLength: Limites.nombre,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej: Maestro Carlos Gasfitería',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => validarTitulo(v ?? '', min: 3, max: Limites.nombre, vacio: 'Ingresa el nombre'),
              ),
              const SizedBox(height: 14),
              const Text(
                'Teléfono / Celular de contacto:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: formatoTelefono,
                decoration: InputDecoration(
                  hintText: 'Ej: 943123456',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => validarTelefono(v ?? '', obligatorio: true),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tu opinión o experiencia con este servicio:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _comentarioCtrl,
                maxLines: 2,
                maxLength: Limites.comentario,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ej: Muy puntual, me reparó una fuga en 30 minutos y cobra justo.',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => validarTexto(v ?? '', min: 10, max: Limites.comentario, obligatorio: true),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Paleta.verde,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _enviando ? null : _guardarRecomendacion,
                  icon: _enviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Compartir recomendación',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
