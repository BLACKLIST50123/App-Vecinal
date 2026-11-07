import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Las credenciales se inyectan al compilar desde supabase.json
// (flutter run --dart-define-from-file=supabase.json). No las escribas aquí.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  }
  runApp(const PruebaApp());
}

class PruebaApp extends StatelessWidget {
  const PruebaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba AlphaCoders',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const MensajePage(),
    );
  }
}

class MensajePage extends StatefulWidget {
  const MensajePage({super.key});

  @override
  State<MensajePage> createState() => _MensajePageState();
}

class _MensajePageState extends State<MensajePage> {
  late Future<String> _mensaje;

  @override
  void initState() {
    super.initState();
    _mensaje = _cargarMensaje();
  }

  Future<String> _cargarMensaje() async {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw 'Faltan SUPABASE_URL / SUPABASE_ANON_KEY.\n'
          'Ejecuta: flutter run --dart-define-from-file=supabase.json';
    }
    final fila = await Supabase.instance.client
        .from('prueba')
        .select('id, mensaje')
        .order('id')
        .limit(1)
        .maybeSingle();
    if (fila == null) {
      throw 'La tabla "prueba" está vacía o RLS no permite leerla.';
    }
    return fila['mensaje'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba Supabase')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Breakpoints: celular < 600, tablet < 1024, escritorio >= 1024.
            final ancho = constraints.maxWidth;
            final esCelular = ancho < 600;
            final esTablet = ancho >= 600 && ancho < 1024;
            final padding = esCelular ? 16.0 : (esTablet ? 32.0 : 48.0);
            final tamanoTexto = esCelular ? 28.0 : (esTablet ? 40.0 : 52.0);

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: ConstrainedBox(
                  // En pantallas grandes la tarjeta no se estira de más.
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(padding * 1.5),
                      child: FutureBuilder<String>(
                        future: _mensaje,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.hasError) {
                            return Text(
                              'Error: ${snap.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            );
                          }
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_done_outlined,
                                size: tamanoTexto * 1.6,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                snap.data!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: tamanoTexto,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Leído desde la tabla "prueba" de Supabase',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
