import 'package:flutter/material.dart';

/// Tema accesible: botones grandes (mín. 52 px de alto), bordes visibles
/// en alto contraste y un color distinto cuando hay emergencia.
ThemeData construirTema({required bool emergencia, required bool altoContraste}) {
  final ColorScheme esquema;
  if (altoContraste) {
    esquema = ColorScheme.highContrastLight(
      primary: emergencia ? const Color(0xFF8B0000) : const Color(0xFF003D36),
      secondary: const Color(0xFF000000),
      error: const Color(0xFF8B0000),
    );
  } else {
    esquema = ColorScheme.fromSeed(
      seedColor: emergencia ? const Color(0xFFC62828) : const Color(0xFF00796B),
    );
  }
  final base = ThemeData(colorScheme: esquema, useMaterial3: true);
  final borde = altoContraste ? const BorderSide(color: Colors.black, width: 2) : BorderSide.none;

  return base.copyWith(
    materialTapTargetSize: MaterialTapTargetSize.padded,
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: altoContraste ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: borde),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        side: altoContraste ? const BorderSide(width: 2) : null,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      extendedTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}
