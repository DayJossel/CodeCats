import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chita_app/main.dart' as app;
// -----------------------------
// Mock para http.Client
// -----------------------------
class MockClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockClient client;

  setUp(() {
    client = MockClient();

    // Mock de SharedPreferences
    SharedPreferences.setMockInitialValues({
      'corredor_id': 1,
      'contrasenia': '1234',
    });
  });

  group('Pruebas unitarias _AddContactSheet', () {
    testWidgets('Valida campos obligatorios', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: _AddContactSheet(
          corredorId: 1,
          contrasenia: '1234',
          onSave: () {},
          totalContactos: 0,
        ),
      ));

      // Toca el botón "Guardar" sin llenar campos
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      // Verifica Snackbar de validación
      expect(find.text('Por favor llena los campos obligatorios'), findsOneWidget);
    });

    testWidgets('Límite de 5 contactos', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: _AddContactSheet(
          corredorId: 1,
          contrasenia: '1234',
          onSave: () {},
          totalContactos: 5, // límite alcanzado
        ),
      ));

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      // Verifica mensaje de límite
      expect(find.text('Solo puedes tener hasta 5 contactos.'), findsOneWidget);
    });

    testWidgets('Campos opcionales pueden estar vacíos', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: _AddContactSheet(
          corredorId: 1,
          contrasenia: '1234',
          onSave: () {},
          totalContactos: 0,
        ),
      ));

      // Llenar solo campos obligatorios
      await tester.enterText(find.byType(TextField).at(0), 'Ana');
      await tester.enterText(find.byType(TextField).at(1), '987654321');

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      // Debe intentar guardar sin error (no se llena relación)
      expect(find.text('Por favor llena los campos obligatorios'), findsNothing);
    });
  });
}
