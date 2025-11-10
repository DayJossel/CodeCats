// lib/screens/vista_espacios.dart
import 'package:flutter/material.dart';
import 'package:chita_app/screens/map_detail.dart';

import '../main.dart';
import '../backend/dominio/espacios.dart';
import '../backend/dominio/modelos/espacio.dart';

// --- mapping nombre -> asset (solo UI)
String _assetParaTituloEspacio(String nombre) {
  switch (nombre.trim()) {
    case 'Parque La Encantada':
      return 'assets/parque_la_encantada.jpg';
    case 'Parque Sierra de Álica':
      return 'assets/parque_sierra_de_alica.jpg';
    case 'La Purísima':
      return 'assets/La_purisima.jpg';
    case 'Parque Ramón López Velarde':
      return 'assets/ramon.jpg';
    case 'Parque Arroyo de la Plata':
      return 'assets/plata.jpg';
    default:
      return 'assets/placeholder.jpg';
  }
}

class VistaEspacios extends StatefulWidget {
  const VistaEspacios({super.key});
  @override
  State<VistaEspacios> createState() => _EstadoVistaEspacios();
}

class _EstadoVistaEspacios extends State<VistaEspacios> {
  final List<Espacio> _espacios = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _listarEspacios();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _listarEspacios() async {
    setState(() => _cargando = true);
    try {
      final list = await EspaciosUC.listarEspacios();
      // Cargar notas de cada espacio (si tiene id)
      final withNotes = <Espacio>[];
      for (final e in list) {
        if (e.espacioId != null) {
          try {
            e.notas = await EspaciosUC.listarNotas(e.espacioId!);
          } catch (_) {/* best-effort */}
        }
        withNotes.add(e);
      }
      setState(() {
        _espacios
          ..clear()
          ..addAll(withNotes);
      });
    } catch (e) {
      _snack('Error al obtener espacios: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _agregarEspacio(String nombre, String? enlace) async {
    try {
      final creado = await EspaciosUC.crearEspacio(
        nombre: nombre,
        enlaceRaw: (enlace ?? '').trim(),
      );
      setState(() {
        _espacios.insert(0, creado);
      });
      _snack('Espacio agregado.');
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _abrirEnMapa(Espacio e) async {
    try {
      if ((e.enlace ?? '').isEmpty) {
        _snack('Este espacio no tiene enlace.', error: true);
        return;
      }
      final coords = await EspaciosUC.resolverCoordenadas(e.enlace!);
      if (coords == null) {
        _snack('No se pudieron resolver coordenadas de este link.', error: true);
        return;
      }
      final routeCoords = 'Coordenadas: ${coords.$1}, ${coords.$2}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapDetailScreen(
            routeTitle: e.nombre,
            routeCoordinates: routeCoords,
            mapImagePath: 'assets/map.png',
          ),
        ),
      );
    } catch (err) {
      _snack('No se pudo abrir el mapa: $err', error: true);
    }
  }

  Future<void> _agregarNota(Espacio e, String contenido) async {
    try {
      if (e.espacioId == null) {
        _snack('Primero guarda este espacio en tu cuenta.', error: true);
        return;
      }
      final creada = await EspaciosUC.crearNota(e.espacioId!, contenido.trim());
      setState(() => e.notas.add(creada));
      _snack('Nota agregada.');
    } catch (err) {
      _snack(err.toString(), error: true);
    }
  }

  Future<void> _editarNota(Espacio e, int idx, String contenido) async {
    try {
      if (e.espacioId == null) return;
      final nota = e.notas[idx];
      final respaldo = nota.contenido;
      setState(() => nota.contenido = contenido.trim());
      await EspaciosUC.actualizarNota(e.espacioId!, nota);
      _snack('Nota actualizada.');
    } catch (err) {
      // revertir (por si quieres usar respaldo)
      final nota = e.notas[idx];
      setState(() => nota.contenido = nota.contenido);
      _snack(err.toString(), error: true);
    }
  }

  Future<void> _eliminarNota(Espacio e, int idx) async {
    try {
      if (e.espacioId == null) return;
      final notaId = e.notas[idx].id;
      await EspaciosUC.eliminarNota(e.espacioId!, notaId);
      setState(() => e.notas.removeAt(idx));
      _snack('Nota eliminada.');
    } catch (err) {
      _snack(err.toString(), error: true);
    }
  }

  Future<void> _actualizarSemaforo(Espacio e, SeguridadEspacio nuevo) async {
    if (e.espacioId == null) {
      _snack('Primero guarda este espacio para poder calificarlo.', error: true);
      return;
    }
    final prev = e.semaforo;
    setState(() => e.semaforo = nuevo); // optimista
    try {
      await EspaciosUC.actualizarSemaforo(e.espacioId!, nuevo);
    } catch (err) {
      setState(() => e.semaforo = prev);
      _snack(err.toString(), error: true);
    }
  }

  void _abrirModalAgregarEspacio() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: _HojaAgregarEspacio(onAddSpace: _agregarEspacio),
        );
      },
    );
  }

  void _abrirModalNotaNueva(Espacio e) {
    if (e.notas.length >= 5) {
      _snack('Máximo 5 notas por espacio.', error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: _HojaNota(
            onSave: (t) => _agregarNota(e, t),
          ),
        );
      },
    );
  }

  void _abrirModalEditarNota(Espacio e, int idx) {
    final nota = e.notas[idx];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: _HojaNota(
            notaInicial: nota.contenido,
            onSave: (t) => _editarNota(e, idx, t),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _espacios;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_cargando) const LinearProgressIndicator(minHeight: 2),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Espacios para correr',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _listarEspacios,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lista.isEmpty ? 'Sin espacios' : '${lista.length} espacio(s)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...lista.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _TarjetaEspacio(
                    espacio: e,
                    onAgregarNota: () => _abrirModalNotaNueva(e),
                    onEliminarNota: (i) => _eliminarNota(e, i),
                    onEditarNota: (i) => _abrirModalEditarNota(e, i),
                    onCambiarSemaforo: (s) => _actualizarSemaforo(e, s),
                    onVerMapa: () => _abrirEnMapa(e),
                  ),
                )),
              ],
            ),
            Positioned(
              bottom: 20, right: 20,
              child: ElevatedButton.icon(
                onPressed: _abrirModalAgregarEspacio,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Agregar espacio'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= Modales (UI) =============
class _HojaAgregarEspacio extends StatefulWidget {
  final Future<void> Function(String nombre, String? enlace) onAddSpace;
  const _HojaAgregarEspacio({required this.onAddSpace});

  @override
  State<_HojaAgregarEspacio> createState() => _EstadoHojaAgregarEspacio();
}

class _EstadoHojaAgregarEspacio extends State<_HojaAgregarEspacio> {
  final _formKey = GlobalKey<FormState>();
  final _ctrlNombre = TextEditingController();
  final _ctrlEnlace = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlEnlace.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onAddSpace(_ctrlNombre.text.trim(), _ctrlEnlace.text.trim());
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Agregar Nuevo Espacio',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ctrlNombre,
                decoration: const InputDecoration(labelText: 'Nombre del espacio *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlEnlace,
                decoration: const InputDecoration(
                  labelText: 'Link del espacio *',
                  hintText: 'https://maps.app.goo.gl/… / https://maps.google.com/… / o lat,lng',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un link.' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Agregar Espacio'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HojaNota extends StatefulWidget {
  final String? notaInicial;
  final Function(String) onSave;
  const _HojaNota({this.notaInicial, required this.onSave});

  @override
  State<_HojaNota> createState() => _EstadoHojaNota();
}

class _EstadoHojaNota extends State<_HojaNota> {
  late final TextEditingController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.notaInicial); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() { widget.onSave(_ctrl.text.trim()); Navigator.of(context).pop(); }

  @override
  Widget build(BuildContext context) {
    final editando = widget.notaInicial != null;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          // este padding extra garantiza que el contenido quede por encima del teclado
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(editando ? '   Editar Nota' : '   Agregar Nota Nueva',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.multiline,
              minLines: 4,
              maxLines: null, // que crezca y permita scroll si es necesario
              decoration: const InputDecoration(
                hintText: 'Escribe tus notas aquí...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(onPressed: _submit, child: const Text('Guardar Nota')),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============= Card + control de semáforo (UI) =============
class _TarjetaEspacio extends StatelessWidget {
  final Espacio espacio;
  final VoidCallback onAgregarNota;
  final Function(int) onEliminarNota;
  final Function(int) onEditarNota;
  final Function(SeguridadEspacio) onCambiarSemaforo;
  final VoidCallback onVerMapa;

  const _TarjetaEspacio({
    required this.espacio,
    required this.onAgregarNota,
    required this.onEliminarNota,
    required this.onEditarNota,
    required this.onCambiarSemaforo,
    required this.onVerMapa,
  });

  @override
  Widget build(BuildContext context) {
    final rutaImagen = _assetParaTituloEspacio(espacio.nombre);
    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Image.asset(
          rutaImagen, height: 150, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150, color: Colors.grey[800],
            child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54, size: 50)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(espacio.nombre,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.note_add_outlined), onPressed: onAgregarNota, tooltip: 'Agregar nota'),
            ]),
            const SizedBox(height: 8),
            _ControlSemaforo(semaforo: espacio.semaforo, onChanged: onCambiarSemaforo),
            if (espacio.notas.isNotEmpty) ...[
              const SizedBox(height: 8), const Divider(color: Colors.white24), const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: espacio.notas.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final nota = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• ', style: TextStyle(color: Colors.grey)),
                      Expanded(child: Text(nota.contenido,
                        style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                      SizedBox(
                        height: 24, width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero, iconSize: 18,
                          icon: const Icon(Icons.edit, color: Colors.white54),
                          onPressed: () => onEditarNota(idx),
                        ),
                      ),
                      SizedBox(
                        height: 24, width: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero, iconSize: 20,
                          icon: const Icon(Icons.delete_outline, color: Colors.white54),
                          onPressed: () => onEliminarNota(idx),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onVerMapa, child: const Text('Ver en Mapa'))),
          ]),
        ),
      ]),
    );
  }
}

class _ControlSemaforo extends StatelessWidget {
  final SeguridadEspacio semaforo;
  final Function(SeguridadEspacio) onChanged;
  const _ControlSemaforo({required this.semaforo, required this.onChanged});

  double _valorSlider(SeguridadEspacio s) => switch (s) {
        SeguridadEspacio.inseguro => 0.0,
        SeguridadEspacio.parcialmenteSeguro => 1.0,
        SeguridadEspacio.seguro => 2.0,
        SeguridadEspacio.ninguno => 1.0,
      };

  String _etiqueta(SeguridadEspacio s) => switch (s) {
        SeguridadEspacio.inseguro => 'Inseguro',
        SeguridadEspacio.parcialmenteSeguro => 'Parcialmente Seguro',
        SeguridadEspacio.seguro => 'Seguro',
        SeguridadEspacio.ninguno => 'Sin calificar',
      };

  Color _color(SeguridadEspacio s) => switch (s) {
        SeguridadEspacio.inseguro => Colors.redAccent,
        SeguridadEspacio.parcialmenteSeguro => Colors.orangeAccent,
        SeguridadEspacio.seguro => Colors.greenAccent,
        SeguridadEspacio.ninguno => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(semaforo);
    return Row(children: [
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: _valorSlider(semaforo), min: 0, max: 2, divisions: 2,
            activeColor: color, inactiveColor: Colors.grey[700],
            onChanged: (v) {
              final nuevo = v == 0.0
                  ? SeguridadEspacio.inseguro
                  : v == 1.0
                      ? SeguridadEspacio.parcialmenteSeguro
                      : SeguridadEspacio.seguro;
              onChanged(nuevo);
            },
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(_etiqueta(semaforo), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }
}