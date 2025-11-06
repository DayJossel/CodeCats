// lib/screens/vista_estadistica.dart
import 'package:flutter/material.dart';

import '../main.dart'; // colores
import '../backend/dominio/estadistica.dart';
import '../backend/dominio/modelos/estadistica.dart';

class VistaEstadistica extends StatefulWidget {
  final int year;
  final int month;
  const VistaEstadistica({super.key, required this.year, required this.month});

  @override
  State<VistaEstadistica> createState() => EstadoVistaEstadistica();
}

class EstadoVistaEstadistica extends State<VistaEstadistica> {
  late int anio;
  late int mes;

  bool _cargando = false;
  String? _error;
  String? _notaFuente; // “Mostrando datos locales…”
  bool _tieneSesion = false;

  // Datos
  int? objetivo;
  int total = 0;
  int hechas = 0;
  int pendientes = 0;
  int noRealizadas = 0;
  bool? cumple;

  @override
  void initState() {
    super.initState();
    anio = widget.year;
    mes = widget.month;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _tieneSesion = await EstadisticaUC.tieneSesion();
    await _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() { _cargando = true; _error = null; _notaFuente = null; });
    try {
      final est = await EstadisticaUC.cargar(year: anio, month: mes);
      setState(() {
        objetivo = est.objetivo;
        total = est.total;
        hechas = est.hechas;
        pendientes = est.pendientes;
        noRealizadas = est.noRealizadas;
        cumple = est.cumpleObjetivo;
        _notaFuente = est.fromLocal ? 'Mostrando datos locales (sin objetivo)' : null;
      });
    } catch (e) {
      setState(() { _error = 'No se pudo cargar estadísticas. $e'; });
    } finally {
      if (mounted) setState(() { _cargando = false; });
    }
  }

  Future<void> _definirObjetivo() async {
    final controlador = TextEditingController(text: (objetivo ?? '').toString());
    final valor = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Objetivo mensual'),
        content: TextField(
          controller: controlador,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad de carreras'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final t = int.tryParse(controlador.text.trim());
              Navigator.pop(ctx, t);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (valor == null) return;

    try {
      await EstadisticaUC.definirObjetivo(year: anio, month: mes, objetivo: valor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Objetivo guardado')));
      await _cargarEstadisticas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _mesAnterior() async {
    final d = DateTime(anio, mes, 1);
    final p = DateTime(d.year, d.month - 1, 1);
    setState(() { anio = p.year; mes = p.month; });
    await _cargarEstadisticas();
  }

  void _mesSiguiente() async {
    final d = DateTime(anio, mes, 1);
    final n = DateTime(d.year, d.month + 1, 1);
    setState(() { anio = n.year; mes = n.month; });
    await _cargarEstadisticas();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = 'Estadística $mes/$anio';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: backgroundColor,
        actions: [
          IconButton(onPressed: _mesAnterior, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: _mesSiguiente, icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  if (_notaFuente != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_notaFuente!, style: const TextStyle(color: Colors.orange)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FichaEstadistica(etiqueta: 'Objetivo mensual', valor: objetivo?.toString() ?? 'No registrado'),
                  const SizedBox(height: 8),
                  FichaEstadistica(etiqueta: 'Total programadas', valor: '$total'),
                  const SizedBox(height: 8),
                  FichaEstadistica(etiqueta: 'Hechas', valor: '$hechas'),
                  const SizedBox(height: 8),
                  FichaEstadistica(etiqueta: 'No realizadas', valor: '$noRealizadas'),
                  const SizedBox(height: 8),
                  FichaEstadistica(etiqueta: 'Pendientes', valor: '$pendientes'),
                  const SizedBox(height: 16),
                  if (cumple != null)
                    Row(
                      children: [
                        Icon(
                          cumple! ? Icons.check_circle : Icons.cancel,
                          color: cumple! ? Colors.greenAccent : Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cumple! ? 'Objetivo CUMPLIDO' : 'Objetivo NO cumplido',
                          style: TextStyle(
                            color: cumple! ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.flag),
                      label: Text(objetivo == null ? 'Registrar objetivo' : 'Editar objetivo'),
                      onPressed: _tieneSesion ? _definirObjetivo : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class FichaEstadistica extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const FichaEstadistica({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: const TextStyle(color: Colors.white70))),
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
