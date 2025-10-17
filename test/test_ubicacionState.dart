import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../lib/views/vista_ubicacion.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  group('VistaUbicacion', () {
    late MockApiService apiService;

    setUp(() {
      apiService = MockApiService();
    });

    testWidgets('Carga contactos correctamente', (tester) async {
      // Simular respuesta de API
      when(apiService.getContactos()).thenAnswer((_) async => [
            {'contacto_id': 1, 'nombre': 'Juan', 'telefono': '123456789'}
          ]);

      await tester.pumpWidget(
        MaterialApp(
          home: VistaUbicacion(),
        ),
      );

      // Esperar a que se cargue
      await tester.pumpAndSettle();

      expect(find.text('Juan'), findsOneWidget);
      expect(find.byType(_ContactTile), findsOneWidget);
    });

    testWidgets('Seleccionar y deseleccionar contacto', (tester) async {
      await tester.pumpWidget(MaterialApp(home: VistaUbicacion()));

      // Inicialmente lista vacía
      expect(find.byType(_ContactTile), findsNothing);

      // Podemos forzar el setState para agregar un contacto manualmente
      final state =
          tester.state<_VistaUbicacionState>(find.byType(VistaUbicacion));
      state.setState(() {
        state._contacts.add(ContactVm(
            contactoId: 1, nombre: 'Ana', telefono: '111222333', initials: 'A'));
      });
      await tester.pump();

      // Tap para seleccionar
      await tester.tap(find.byType(_ContactTile));
      await tester.pump();

      expect(state._selectedIds.contains(1), isTrue);

      // Tap para deseleccionar
      await tester.tap(find.byType(_ContactTile));
      await tester.pump();

      expect(state._selectedIds.contains(1), isFalse);
    });
  });
}
