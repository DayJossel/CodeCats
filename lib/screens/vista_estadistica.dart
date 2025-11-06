// lib/screens/vista_estadistica.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart'; // colores

const String _baseUrl = 'http://157.137.187.110:8000';

class VistaEstadistica extends StatefulWidget {
  final int year;
  final int month;
  const VistaEstadistica({super.key, required this.year, required this.month});

  @override
  State<VistaEstadistica> createState() => EstadoVistaEstadistica();
}

class EstadoVistaEstadistica extends State<VistaEstadistica> {
  int anio = 0;
  int mes = 0;

  int? corredorId;
  String? contrasenia;

  bool _cargando = false;
  String? _error;

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
    _inicializar();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id');
    contrasenia = prefs.getString('contrasenia');
    await _cargarEstadisticas();
  }

  Map<String, String> _encabezadosAuth() => {
        'X-Corredor-Id': '${corredorId ?? ''}',
        'X-Contrasenia': contrasenia ?? '',
      };

  Future<void> _cargarEstadisticas() async {
    if (corredorId == null || contrasenia == null) {
      setState(() {
        _error = 'No hay sesión cargada';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_baseUrl/estadistica/mensual?year=$anio&month=$mes');
      final resp = await http.get(uri, headers: _encabezadosAuth());
      if (resp.statusCode == 200) {
        final m = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          objetivo = m['objetivo'] as int?;
          total = m['total'] as int;
          hechas = m['hechas'] as int;
          pendientes = m['pendientes'] as int;
          noRealizadas = m['no_realizadas'] as int;
          cumple = m['cumple_objetivo'] as bool?;
        });
      } else {
        await _respaldoLocal();
      }
    } on SocketException catch (_) {
      await _respaldoLocal();
    } on TimeoutException catch (_) {
      await _respaldoLocal();
    } on http.ClientException catch (_) {
      await _respaldoLocal();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _respaldoLocal() async {
    // Lee 'races_storage_v1' y calcula métricas del mes (sin objetivo)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('races_storage_v1');
      int _total = 0, _hechas = 0, _pend = 0, _no = 0;
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw) as List;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          // Vista Calendario guarda: 'fechaHora' (ISO) y 'estado' (índice)
          final dt = DateTime.parse(m['fechaHora'] as String);
          if (dt.year == anio && dt.month == mes) {
            _total += 1;
            final statusIndex = (m['estado'] as int?) ?? 0;
            if (statusIndex == 1) {
              _hechas += 1;
            } else if (statusIndex == 2) {
              _no += 1;
            } else {
              _pend += 1;
            }
          }
        }
      }
      setState(() {
        objetivo = null;
        total = _total;
        hechas = _hechas;
        pendientes = _pend;
        noRealizadas = _no;
        cumple = null;
        _error = 'Mostrando datos locales (sin objetivo)';
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo recuperar estadísticas. $e';
      });
    }
  }

  Future<void> _definirObjetivo() async {
    final controlador = TextEditingController(text: (objetivo ?? '').toString());
    final valor = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      final uri = Uri.parse('$_baseUrl/objetivos/mensual?year=$anio&month=$mes');
      final resp = await http.post(
        uri,
        headers: {
          ..._encabezadosAuth(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'objetivo': valor}),
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Objetivo guardado')),
        );
        await _cargarEstadisticas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar objetivo (${resp.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sin conexión. No se pudo guardar. $e')),
      );
    }
  }

  void _mesAnterior() {
    final d = DateTime(anio, mes, 1);
    final p = DateTime(d.year, d.month - 1, 1);
    setState(() {
      anio = p.year;
      mes = p.month;
    });
    _cargarEstadisticas();
  }

  void _mesSiguiente() {
    final d = DateTime(anio, mes, 1);
    final n = DateTime(d.year, d.month + 1, 1);
    setState(() {
      anio = n.year;
      mes = n.month;
    });
    _cargarEstadisticas();
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
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.orange)),
                    ),
                  const SizedBox(height: 12),
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
                      onPressed: (corredorId == null || contrasenia == null) ? null : _definirObjetivo,
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
