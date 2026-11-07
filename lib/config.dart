import 'package:flutter/material.dart';

/// Coordenada simple (latitud, longitud).
class Punto {
  const Punto(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Zona de la app. Debe coincidir con `en_zona()` en supabase/schema.sql.
class Zona {
  static const nombre = 'Chimbote';
  static const centro = Punto(-9.0950, -78.5600);
  static const radioKm = 15.0;

  static const sectores = <String, Punto>{
    'Casco Urbano': Punto(-9.0747, -78.5935),
    'Miraflores Alto': Punto(-9.0655, -78.5795),
    'El Progreso': Punto(-9.0560, -78.5710),
    'San Pedro': Punto(-9.0480, -78.5860),
    'La Florida': Punto(-9.0815, -78.5760),
    '21 de Abril': Punto(-9.0870, -78.5830),
    'Villa María': Punto(-9.0990, -78.5690),
    'Bellamar': Punto(-9.1180, -78.5420),
    'Buenos Aires': Punto(-9.1265, -78.5255),
    'Nicolás Garatea': Punto(-9.1340, -78.5150),
  };
}

class Categoria {
  const Categoria(this.id, this.nombre, this.icono);
  final String id;
  final String nombre;
  final IconData icono;
}

/// Módulo 1 · día a día: productos, oficios y profesiones del barrio.
const categoriasServicio = <Categoria>[
  Categoria('bodega', 'Bodega y abarrotes', Icons.storefront),
  Categoria('panaderia', 'Pan y postres', Icons.bakery_dining),
  Categoria('comida', 'Comida casera', Icons.restaurant),
  Categoria('artesania', 'Artesanía', Icons.palette),
  Categoria('segunda_mano', 'Segunda mano', Icons.recycling),
  Categoria('gasfiteria', 'Gasfitería', Icons.plumbing),
  Categoria('electricidad', 'Electricidad', Icons.electrical_services),
  Categoria('carpinteria', 'Carpintería', Icons.carpenter),
  Categoria('cerrajeria', 'Cerrajería', Icons.key),
  Categoria('albanileria', 'Albañilería', Icons.construction),
  Categoria('mascotas', 'Mascotas', Icons.pets),
  Categoria('clases', 'Clases', Icons.school),
  Categoria('costura', 'Costura', Icons.content_cut),
  Categoria('tecnologia', 'Tecnología', Icons.computer),
  Categoria('salud', 'Salud', Icons.medical_services),
  Categoria('otros', 'Otros', Icons.handyman),
];

/// Módulo 1 · emergencia: grupos y servicios de apoyo.
const categoriasApoyo = <Categoria>[
  Categoria('rescate', 'Rescate', Icons.emergency),
  Categoria('salud', 'Salud', Icons.local_hospital),
  Categoria('albergue', 'Albergue', Icons.night_shelter),
  Categoria('alimentos', 'Alimentos', Icons.soup_kitchen),
  Categoria('psicologico', 'Apoyo emocional', Icons.psychology),
  Categoria('otros', 'Otros', Icons.volunteer_activism),
];

/// Módulo 2 · día a día: cadena de favores (sin dinero).
const categoriasFavor = <Categoria>[
  Categoria('ayuda', 'Una mano', Icons.front_hand),
  Categoria('herramientas', 'Herramientas y cosas', Icons.build),
  Categoria('donacion', 'Regalos y donaciones', Icons.card_giftcard),
  Categoria('cuidado', 'Compañía y cuidado', Icons.elderly),
  Categoria('habilidad', 'Enseño o aprendo', Icons.school),
  Categoria('movilidad', 'Te llevo', Icons.directions_car),
  Categoria('colecta', 'Colectas del barrio', Icons.diversity_1),
  Categoria('otros', 'Otros', Icons.more_horiz),
];

/// Módulo 2 · emergencia: tablero humanitario y recursos críticos.
const categoriasEmergencia = <Categoria>[
  Categoria('vulnerable', 'Persona que necesita cuidado', Icons.elderly),
  Categoria('rescate', 'Salir de un lugar peligroso', Icons.emergency),
  Categoria('salud', 'Salud y medicinas', Icons.medication),
  Categoria('agua_alimento', 'Agua y comida', Icons.water_drop),
  Categoria('albergue', 'Un lugar para dormir', Icons.night_shelter),
  Categoria('recurso', 'Cosas para compartir', Icons.inventory_2),
  Categoria('inseguridad', 'Inseguridad', Icons.shield_outlined),
  Categoria('sismo', 'Daños por sismo', Icons.house_outlined),
  Categoria('otros', 'Otros', Icons.more_horiz),
];

/// Reportes rápidos del botón SOS (Modo Emergencia).
const categoriasSOS = <Categoria>[
  Categoria('sos_medico', 'Auxilio médico', Icons.medical_services),
  Categoria('sos_inseguridad', 'Inseguridad', Icons.local_police),
  Categoria('sos_agua', 'Falta de agua', Icons.water_drop),
  Categoria('sos_sismo', 'Sismo', Icons.house_siding),
];

Categoria buscarCategoria(String id, {bool emergencia = false}) {
  final listas = emergencia
      ? [categoriasSOS, categoriasEmergencia, categoriasApoyo, categoriasFavor, categoriasServicio]
      : [categoriasServicio, categoriasFavor, categoriasApoyo, categoriasEmergencia, categoriasSOS];
  for (final l in listas) {
    for (final c in l) {
      if (c.id == id) return c;
    }
  }
  return categoriasFavor.last;
}

/// Números de emergencia del Perú (llamada gratuita).
const numerosEmergencia = <(String, String, IconData)>[
  ('Bomberos', '116', Icons.fire_truck),
  ('Policía', '105', Icons.local_police),
  ('Ambulancia SAMU', '106', Icons.emergency),
];
