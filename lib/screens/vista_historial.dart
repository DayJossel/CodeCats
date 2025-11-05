import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../core/app_events.dart';

class VistaHistorial extends StatefulWidget {
  const VistaHistorial({super.key});

  @override
  State<VistaHistorial> createState() => _EstadoVistaHistorial();
}

class _EstadoVistaHistorial extends State<VistaHistorial> {
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  late final VoidCallback _escuchadorEventos;

  @override
  void initState() {
    super.initState();
    // Cuando se cree una nueva alerta (CU-1), refresca
    _escuchadorEventos = () => _recargar();
    EventosApp.alertHistoryVersion.addListener(_escuchadorEventos);

    // Carga inicial
    _recargar();
  }

  @override
  void dispose() {
    EventosApp.alertHistoryVersion.removeListener(_escuchadorEventos);
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final list = await ServicioApi.listarHistorial();
      // Ordena por fecha descendente
      list.sort((a, b) {
        final fa = DateTime.tryParse(a['fecha']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final fb = DateTime.tryParse(b['fecha']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return fb.compareTo(fa);
      });
      setState(() {
        _items = list;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar el historial. $e';
        _cargando = false;
      });
    }
  }

  String _formatearFecha(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return 'fecha desconocida';
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final mes = (l.month >= 1 && l.month <= 12) ? meses[l.month - 1] : '--';
    return '${two(l.day)} $mes ${l.year} • ${two(l.hour)}:${two(l.minute)}';
    }

  @override
  Widget build(BuildContext context) {
    final body = _cargando
        ? const Center(child: CircularProgressIndicator())
        : (_items.isEmpty
            ? _EstadoVacio(onReload: _recargar)
            : RefreshIndicator(
                onRefresh: _recargar,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
                  itemBuilder: (context, i) {
                    final h = _items[i];
                    final id = (h['historial_id'] as num).toInt();
                    final fecha = _formatearFecha(h['fecha']?.toString());

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFD54F), // amarillo suave
                        child: Icon(Icons.warning_amber_rounded, color: Colors.black),
                      ),
                      title: const Text(
                        'Alerta',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('ID #$id • $fecha',
                          style: const TextStyle(color: Colors.grey)),
                      // onTap: () => _openDetalle(id), // opcional
                    );
                  },
                ),
              ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Alertas'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _error != null ? _EstadoError(message: _error!, onRetry: _recargar) : body,
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final Future<void> Function() onReload;
  const _EstadoVacio({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 50),
            const SizedBox(height: 24),
            const Text(
              'Aún no hay alertas',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus alertas de emergencia aparecerán aquí',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onReload,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _EstadoError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 50),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
