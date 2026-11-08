import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta del proyecto: azul marino #1E293B, crema #FAF8F5, blanco,
/// naranja #E8956B y rojo alerta crítica #E53935.
class Paleta {
  // Principal (azul marino) y sus variantes.
  static const primario = Color(0xFF1E293B);
  static const primarioOscuro = Color(0xFF0F172A);
  static const primarioClaro = Color(0xFF334155);
  static const primarioSuave = Color(0xFFE8ECF2);
  // Fondo.
  static const crema = Color(0xFFFAF8F5);
  // Acento naranja.
  static const acento = Color(0xFFE8956B);
  static const acentoOscuro = Color(0xFFA9532B); // 5:1 sobre crema (AA)
  static const acentoSuave = Color(0xFFFCEEE6);
  // Texto y líneas.
  static const tinta = Color(0xFF1E293B);
  static const gris = Color(0xFF5B6577); // 5.5:1 sobre crema (AA para texto pequeño)
  static const grisClaro = Color(0xFF94A3B8);
  static const linea = Color(0xFFE5E7EB);
  // Rojo alerta crítica.
  static const rojo = Color(0xFFE53935);
  static const rojoOscuro = Color(0xFFE53935);
  static const rojoSuave = Color(0xFFFDECEA);

  // Superficies y bordes neutros.
  static const grisFondo = Color(0xFFF1F5F9);
  static const lineaFuerte = Color(0xFFCBD5E1);

  // Colores de estado (los mismos en toda la app). Los de texto cumplen
  // contraste AA sobre blanco o sobre su fondo suave.
  static const verde = Color(0xFF2E7D32); // atendido, verificado, éxito
  static const verdeSuave = Color(0xFFE8F5E9);
  static const verdeClaro = Color(0xFF86EFAC);
  static const azulInfo = Color(0xFF1565C0); // en atención, información, "estás aquí"
  static const azulSuave = Color(0xFFE3F2FD);
  static const violeta = Color(0xFF6A1B9A); // junta vecinal, colectas
  static const violetaSuave = Color(0xFFF3E5F5);
  static const rosa = Color(0xFFC2185B); // agradecimientos
  static const rosaSuave = Color(0xFFFCE4EC);
  static const ambar = Color(0xFFB45309); // advertencia, pendiente
  static const ambarSuave = Color(0xFFFEF3C7);
  static const oro = Color(0xFFFFB300); // reconocimiento
  static const oroClaro = Color(0xFFFFE082);
  static const oroFondo = Color(0xFFFFF8E1);
  static const rojoTexto = Color(0xFFC62828); // texto rojo sobre fondo claro
  static const whatsapp = Color(0xFF25D366); // color de marca de WhatsApp

  // Pares (texto, fondo) de las categorías.
  static const naranja = (Color(0xFFA9532B), Color(0xFFFCEEE6));
  static const azul = (Color(0xFF334155), Color(0xFFE8ECF2));
  static const verdeCat = (Color(0xFF397158), Color(0xFFE2F0E8));
  static const morado = (Color(0xFF725984), Color(0xFFEEE8F2));
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
/// emergencia. En alto contraste se refuerzan bordes y colores.
ThemeData construirTema({required bool emergencia, required bool altoContraste}) {
  // En emergencia se mantiene el azul marino: el rojo queda solo para lo
  // crítico (aviso de la junta, SOS, "Necesito ayuda", muy urgente). Si todo
  // fuera rojo, el rojo dejaría de alertar.
  const primario = Paleta.primario;
  const suave = Paleta.primarioSuave;
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
      color: Colors.white,
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
        backgroundColor: Colors.white,
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borde)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primario, width: 2)),
      hintStyle: const TextStyle(color: Paleta.gris),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
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
        backgroundColor: Colors.white,
        selectedBackgroundColor: primario,
        selectedForegroundColor: Colors.white,
        foregroundColor: Paleta.gris,
        side: BorderSide(color: borde),
        textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
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
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Paleta.tinta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
