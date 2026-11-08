import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/datos_iniciales.dart';
import 'data/repo.dart';
import 'features/sos/sos_atajo.dart';
import 'features/sos/sos_boton.dart';
import 'features/sos/sos_navegacion.dart';
import 'screens/bienvenida.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'ui/tema.dart';

// Las credenciales se inyectan al compilar desde supabase.json
// (flutter run --dart-define-from-file=supabase.json). No las escribas aquí.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(const SinCredenciales());
    return;
  }
  // Datos incluidos en la app (números de emergencia, grupos de apoyo) para
  // que funcione desde el primer uso, aunque nunca haya tenido internet.
  await DatosIniciales.cargar(Zona.nombre);
  final prefs = await SharedPreferences.getInstance();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  final estado = AppState(prefs, Repo(prefs, Supabase.instance.client));
  AtajoVolumenSos.instalar();
  runApp(ChangeNotifierProvider.value(value: estado, child: const AppVecinal()));
}

class AppVecinal extends StatelessWidget {
  const AppVecinal({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return MaterialApp(
      title: 'Conecta Vecino',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: mensajero,
      navigatorKey: navegador,
      navigatorObservers: [observadorSos],
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: construirTema(emergencia: st.modoEmergencia, altoContraste: st.altoContraste),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final sistema = mq.textScaler.scale(1);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(sistema > st.escala ? sistema : st.escala)),
          // Aviso de SOS cercano sobre todas las pantallas.
          child: CapaSos(child: child!),
        );
      },
      // Bienvenida (iniciar sesión / crear cuenta / invitado) → tutorial solo
      // la primera vez → la app. El rol de brigadista lo da la junta vecinal.
      // La guía "Esto puedes hacer" vive dentro del Inicio (ya no hay
      // diapositivas al entrar); el tutorial sigue en Perfil > Cómo usar la app.
      home: !st.entro ? const BienvenidaScreen() : const HomeShell(),
    );
  }
}

class SinCredenciales extends StatelessWidget {
  const SinCredenciales({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Faltan SUPABASE_URL / SUPABASE_ANON_KEY.\n'
                'Ejecuta: flutter run --dart-define-from-file=supabase.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
