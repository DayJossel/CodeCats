import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chita_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VistaAlerta - Integración', () {
    testWidgets('Debe enviar alerta al confirmar desde el botón SOS', (tester) async {
      // Iniciamos la app completa
      app.main();
      await tester.pumpAndSettle();

      // Verificamos que aparece el botón SOS
      expect(find.text('SOS'), findsOneWidget);

      // Simulamos mantener presionado el botón 3 segundos
      final sosButton = find.text('SOS');
      final gesture = await tester.startGesture(tester.getCenter(sosButton));
      await tester.pump(const Duration(seconds: 3));
      await gesture.up();
      await tester.pumpAndSettle();

      // Debe aparecer el AlertDialog
      expect(find.text('¿Enviar alerta de Emergencia?'), findsOneWidget);

      // Simulamos presionar el botón "Enviar Alerta"
      final enviarBtn = find.text('Enviar Alerta');
      await tester.tap(enviarBtn);
      await tester.pumpAndSettle();

      // Debe aparecer un SnackBar de éxito o fallo
      expect(
        find.byType(SnackBar),
        findsOneWidget,
      );
    });
  });
}
