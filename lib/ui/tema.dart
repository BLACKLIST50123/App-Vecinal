import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta del proyecto: azul marino #1E293B, crema #FAF8F5, blanco,
/// naranja #E8956B y rojo alerta crítica #E53935.
///
/// Cada color tiene versión clara y oscura; [oscuro] elige cuál. Son getters
/// (no const) para que toda la app cambie de tema sin tocar cada pantalla.
class Paleta {
  static bool oscuro = false;
  static Color _c(int claro, int noche) => Color(oscuro ? noche : claro);

  // Principal (azul marino) y sus variantes. En oscuro, un azul que se lee
  // sobre fondo oscuro y sigue llevando texto blanco encima.
  static Color get primario => _c(0xFF1E293B, 0xFF3B82F6);
  static Color get primarioOscuro => _c(0xFF0F172A, 0xFFF1F5F9);
  static Color get primarioClaro => _c(0xFF334155, 0xFFCBD5E1);
  static Color get primarioSuave => _c(0xFFE8ECF2, 0xFF273449);
  // Fondo de pantalla y de tarjetas.
  static Color get crema => _c(0xFFFAF8F5, 0xFF0F172A);
  static Color get superficie => _c(0xFFFFFFFF, 0xFF1E293B);
  // Banda oscura con texto blanco (avisos destacados): marino en ambos temas.
  static Color get banda => _c(0xFF1E293B, 0xFF334155);
  // Acento naranja.
  static Color get acento => _c(0xFFE8956B, 0xFFE8956B);
  static Color get acentoOscuro => _c(0xFFA9532B, 0xFFE8956B); // 5:1 sobre crema (AA)
  static Color get acentoSuave => _c(0xFFFCEEE6, 0xFF3A261C);
  // Fondo de secciones grandes (durazno en claro; pizarra en oscuro, no marrón).
  static Color get seccion => _c(0xFFFCEEE6, 0xFF162032);
  // Texto y líneas.
  static Color get tinta => _c(0xFF1E293B, 0xFFE2E8F0);
  static Color get gris => _c(0xFF5B6577, 0xFF94A3B8); // 5.5:1 sobre crema (AA para texto pequeño)
  static Color get grisClaro => _c(0xFF94A3B8, 0xFF64748B);
  static Color get linea => _c(0xFFE5E7EB, 0xFF334155);
  // Rojo alerta crítica.
  static Color get rojo => _c(0xFFE53935, 0xFFE53935);
  static Color get rojoOscuro => _c(0xFFE53935, 0xFFEF5350);
  static Color get rojoSuave => _c(0xFFFDECEA, 0xFF3B1F22);

  // Superficies y bordes neutros.
  static Color get grisFondo => _c(0xFFF1F5F9, 0xFF273449);
  static Color get lineaFuerte => _c(0xFFCBD5E1, 0xFF475569);

  // Colores de estado (los mismos en toda la app). Los de texto cumplen
  // contraste AA sobre blanco o sobre su fondo suave.
  static Color get verde => _c(0xFF2E7D32, 0xFF43A047); // atendido, verificado, éxito
  static Color get verdeSuave => _c(0xFFE8F5E9, 0xFF16301F);
  static Color get verdeClaro => _c(0xFF86EFAC, 0xFF86EFAC);
  static Color get azulInfo => _c(0xFF1565C0, 0xFF42A5F5); // en atención, información, "estás aquí"
  static Color get azulSuave => _c(0xFFE3F2FD, 0xFF172B45);
  static Color get violeta => _c(0xFF6A1B9A, 0xFFBA68C8); // junta vecinal, colectas
  static Color get violetaSuave => _c(0xFFF3E5F5, 0xFF2D1F3A);
  static Color get rosa => _c(0xFFC2185B, 0xFFEC407A); // agradecimientos
  static Color get rosaSuave => _c(0xFFFCE4EC, 0xFF3A1A28);
  static Color get ambar => _c(0xFFB45309, 0xFFF59E0B); // advertencia, pendiente
  static Color get ambarSuave => _c(0xFFFEF3C7, 0xFF3A2A12);
  static Color get oro => _c(0xFFFFB300, 0xFFFFB300); // reconocimiento
  static Color get oroClaro => _c(0xFFFFE082, 0xFF8A6D1F);
  static Color get oroFondo => _c(0xFFFFF8E1, 0xFF3A3214);
  static Color get rojoTexto => _c(0xFFC62828, 0xFFEF9A9A); // texto rojo sobre fondo claro
  static Color get whatsapp => _c(0xFF25D366, 0xFF25D366); // color de marca de WhatsApp

  // Pares (texto, fondo) de las categorías.
  static (Color, Color) get naranja => (_c(0xFFA9532B, 0xFFF0A882), _c(0xFFFCEEE6, 0xFF3A261C));
  static (Color, Color) get azul => (_c(0xFF334155, 0xFFCBD5E1), _c(0xFFE8ECF2, 0xFF273449));
  static (Color, Color) get verdeCat => (_c(0xFF397158, 0xFF7FC8A0), _c(0xFFE2F0E8, 0xFF16301F));
  static (Color, Color) get morado => (_c(0xFF725984, 0xFFC9A8DE), _c(0xFFEEE8F2, 0xFF2D1F3A));
}

/// Grupo de un servicio para colores y filtros: servicios, productos o clases.
String grupoServicio(String categoria) => switch (categoria) {
      'bodega' || 'panaderia' || 'comida' || 'artesania' || 'segunda_mano' => 'productos',
      'clases' => 'clases',
      _ => 'servicios',
    };

(Color, Color) colorGrupo(String grupo) => switch (grupo) {
      'productos' => Paleta.azul,
      'clases' => Paleta.verdeCat,
      'apoyo' => Paleta.morado,
      _ => Paleta.naranja,
    };

/// DM Sans en cada estilo de texto (carga la variante de peso correcta).
TextTheme _dmSans(TextTheme t) => TextTheme(
      displayLarge: GoogleFonts.dmSans(textStyle: t.displayLarge),
      displayMedium: GoogleFonts.dmSans(textStyle: t.displayMedium),
      displaySmall: GoogleFonts.dmSans(textStyle: t.displaySmall),
      headlineLarge: GoogleFonts.dmSans(textStyle: t.headlineLarge),
      headlineMedium: GoogleFonts.dmSans(textStyle: t.headlineMedium),
      headlineSmall: GoogleFonts.dmSans(textStyle: t.headlineSmall),
      titleLarge: GoogleFonts.dmSans(textStyle: t.titleLarge),
      titleMedium: GoogleFonts.dmSans(textStyle: t.titleMedium),
      titleSmall: GoogleFonts.dmSans(textStyle: t.titleSmall),
      bodyLarge: GoogleFonts.dmSans(textStyle: t.bodyLarge),
      bodyMedium: GoogleFonts.dmSans(textStyle: t.bodyMedium),
      bodySmall: GoogleFonts.dmSans(textStyle: t.bodySmall),
      labelLarge: GoogleFonts.dmSans(textStyle: t.labelLarge),
      labelMedium: GoogleFonts.dmSans(textStyle: t.labelMedium),
      labelSmall: GoogleFonts.dmSans(textStyle: t.labelSmall),
    );

/// Tema accesible basado en el diseño: DM Sans, fondo crema, tarjetas
/// blancas con borde fino, botones de al menos 52 px y color distinto en
/// emergencia. En alto contraste se refuerzan bordes y colores. Claro u
/// oscuro según [Paleta.oscuro] (el alto contraste siempre es claro).
ThemeData construirTema({required bool emergencia, required bool altoContraste}) {
  // En emergencia se mantiene el azul marino: el rojo queda solo para lo
  // crítico (aviso de la junta, SOS, "Necesito ayuda", muy urgente). Si todo
  // fuera rojo, el rojo dejaría de alertar.
  final primario = Paleta.primario;
  final suave = Paleta.primarioSuave;
  final fondo = altoContraste ? Colors.white : Paleta.crema;
  final borde = altoContraste ? Colors.black : Paleta.linea;

  final esquema = altoContraste
      ? ColorScheme.highContrastLight(
          primary: const Color(0xFF0F172A),
          primaryContainer: suave,
          onPrimaryContainer: Colors.black,
          secondary: Colors.black,
          error: const Color(0xFF8B0000),
        )
      : ColorScheme.fromSeed(
          brightness: Paleta.oscuro ? Brightness.dark : Brightness.light,
          seedColor: primario,
          primary: primario,
          onPrimary: Colors.white,
          primaryContainer: suave,
          onPrimaryContainer: Paleta.primarioOscuro,
          surface: fondo,
          onSurface: Paleta.tinta,
          onSurfaceVariant: Paleta.gris,
          outline: Paleta.grisClaro,
          outlineVariant: Paleta.linea,
          surfaceContainerHighest: Paleta.grisFondo,
        );

  final base = ThemeData(colorScheme: esquema, useMaterial3: true, scaffoldBackgroundColor: fondo);
  final texto = _dmSans(base.textTheme).apply(
    bodyColor: altoContraste ? Colors.black : Paleta.tinta,
    displayColor: altoContraste ? Colors.black : Paleta.tinta,
  );
  final redondeo15 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15));

  return base.copyWith(
    textTheme: texto.copyWith(
      headlineSmall: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
      titleLarge: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: fondo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Paleta.tinta,
      titleTextStyle: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Paleta.tinta),
    ),
    cardTheme: CardThemeData(
      color: Paleta.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borde, width: altoContraste ? 2 : 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondeo15,
        textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondeo15,
        backgroundColor: Paleta.superficie,
        side: BorderSide(color: borde, width: altoContraste ? 2 : 1),
        textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primario,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: redondeo15,
      extendedTextStyle: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Paleta.superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borde)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primario, width: 2)),
      hintStyle: TextStyle(color: Paleta.gris),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Paleta.superficie,
      selectedColor: suave,
      checkmarkColor: primario,
      side: BorderSide(color: borde),
      shape: const StadiumBorder(),
      labelStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Paleta.tinta),
      secondaryLabelStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: Paleta.tinta),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Paleta.superficie,
        selectedBackgroundColor: primario,
        selectedForegroundColor: Colors.white,
        foregroundColor: Paleta.gris,
        side: BorderSide(color: borde),
        textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Paleta.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: suave,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      height: 74,
      labelTextStyle: WidgetStateTextStyle.resolveWith((s) => GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? primario : Paleta.grisClaro,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? primario : Paleta.grisClaro, size: 24)),
    ),
    listTileTheme: ListTileThemeData(iconColor: primario, titleTextStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: Paleta.tinta)),
    dividerTheme: DividerThemeData(color: borde, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: fondo, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: Paleta.superficie, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    // Fondo marino siempre: el texto va blanco para leerse en claro y oscuro.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Paleta.banda,
      contentTextStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
      actionTextColor: const Color(0xFF93C5FD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    // Bolita blanca al estar encendido, sobre la pista del color principal.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
    ),
  );
}
