import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:chita_app/ui/vista_alerta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VistaAlerta - Cuenta regresiva', () {
    testWidgets('Debe iniciar y finalizar correctamente la cuenta regresiva',
        (WidgetTester tester) async {
      // Renderizamos el widget en un entorno de prueba
      await tester.pumpWidget(
        const MaterialApp(
          home: VistaAlerta(),
        ),
      );

      // Verificamos que inicialmente aparece el texto SOS
      expect(find.text('SOS'), findsOneWidget);

      // Simulamos presionar el botón
      final sosButton = find.text('SOS');
      await tester.startGesture(tester.getCenter(sosButton));
      await tester.pump(); // inicia animación

      // Ahora debe mostrar el número "3"
      expect(find.text('3'), findsOneWidget);

      // Avanzamos el tiempo simulado 3 segundos
      await tester.pump(const Duration(seconds: 3));

      // El contador debe desaparecer y debe mostrarse el diálogo de confirmación
      expect(find.text('¿Enviar alerta de Emergencia?'), findsOneWidget);
    });
  });
}
