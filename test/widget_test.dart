import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_alphacoders/main.dart';

void main() {
  testWidgets('Muestra aviso si faltan credenciales', (tester) async {
    await tester.pumpWidget(const PruebaApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Faltan SUPABASE_URL'), findsOneWidget);
  });
}
