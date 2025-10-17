import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chita_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Agregar y eliminar contacto', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Abrir modal
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Llenar formulario
    await tester.enterText(find.byType(TextField).at(0), 'Ana');
    await tester.enterText(find.byType(TextField).at(1), '987654321');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar contacto agregado
    expect(find.text('Ana'), findsOneWidget);

    // Eliminar contacto
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsNothing);
  });
