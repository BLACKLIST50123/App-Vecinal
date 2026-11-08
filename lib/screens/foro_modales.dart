import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';

/// Modal para publicar una nueva consulta o tema en el foro vecinal.
class ModalNuevoTema extends StatefulWidget {
  const ModalNuevoTema({super.key});

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
          const SnackBar(
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
      decoration: const BoxDecoration(
        color: Colors.white,
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
                    label: const Text('Comunidad / Diálogo'),
                    selected: _tipo == TipoPublicacionForo.dialogo,
                    selectedColor: const Color(0xFFD1FAE5),
                    labelStyle: TextStyle(
                      color: _tipo == TipoPublicacionForo.dialogo
                          ? const Color(0xFF065F46)
                          : Paleta.tinta,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) =>
                        setState(() => _tipo = TipoPublicacionForo.dialogo),
                  ),
                  ChoiceChip(
                    label: const Text('Recomendación'),
                    selected: _tipo == TipoPublicacionForo.recomendacion,
                    selectedColor: const Color(0xFFFEF3C7),
                    labelStyle: TextStyle(
                      color: _tipo == TipoPublicacionForo.recomendacion
                          ? const Color(0xFF92400E)
                          : Paleta.tinta,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) => setState(
                      () => _tipo = TipoPublicacionForo.recomendacion,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Aviso vecinal'),
                    selected: _tipo == TipoPublicacionForo.aviso,
                    selectedColor: const Color(0xFFF3E8FF),
                    labelStyle: TextStyle(
                      color: _tipo == TipoPublicacionForo.aviso
                          ? const Color(0xFF6B21A8)
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
                DropdownButtonFormField<String>(
                  initialValue: _categoriaServicio,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: categoriasServicio.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(c.icono, size: 18, color: Paleta.acento),
                          const SizedBox(width: 8),
                          Text(c.nombre),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _categoriaServicio = v),
                ),
              ],

              const SizedBox(height: 14),
              const Text(
                'Sector o barrio:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _sector,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: Zona.sectores.keys.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _sector = v);
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa un título claro'
                    : null,
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Describe tu consulta'
                    : null,
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
          const SnackBar(
            content: Text('¡Recomendación compartida con éxito!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF16A34A),
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
      decoration: const BoxDecoration(
        color: Colors.white,
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
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.recommend_rounded,
                      color: Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa el nombre'
                    : null,
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
                validator: (v) => (v == null || v.trim().length < 6)
                    ? 'Ingresa un número válido'
                    : null,
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe tu recomendación'
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
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
