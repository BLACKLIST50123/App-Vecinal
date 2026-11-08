import 'package:app_vecinal/ui/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => Paleta.oscuro = false);

  test('modo oscuro: texto claro sobre superficies oscuras', () {
    Paleta.oscuro = true;
    expect(Paleta.tinta.computeLuminance(), greaterThan(0.6));
    expect(Paleta.superficie.computeLuminance(), lessThan(0.1));
    expect(Paleta.crema.computeLuminance(), lessThan(0.1));
  });

  test('modo claro: queda como antes', () {
    expect(Paleta.tinta, const Color(0xFF1E293B));
    expect(Paleta.superficie, Colors.white);
    expect(Paleta.crema, const Color(0xFFFAF8F5));
  });
}
