import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:chita_app/screens/vista_espacios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Agrega un nuevo espacio desde el modal', (WidgetTester tester) async {
    // 1. Renderiza la app
    await tester.pumpWidget(const MaterialApp(home: VistaEspacios()));

    // 2. Abre el modal
    await tester.tap(find.text('Agregar espacio'));
    await tester.pumpAndSettle();

    // 3. Ingresa texto
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.decoration?.labelText == 'Nombre del espacio *',
      ),
      'Parque de Pruebas',
    );

    // 4. Envía el formulario
    await tester.tap(find.text('Agregar Espacio'));
    await tester.pumpAndSettle();

    // 5. Verifica que el nuevo espacio aparezca
    expect(find.text('Parque de Pruebas'), findsOneWidget);
  });
}
