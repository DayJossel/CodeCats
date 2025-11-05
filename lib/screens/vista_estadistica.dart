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
  State<VistaEstadistica> createState() => _VistaEstadisticaState();
}

class _VistaEstadisticaState extends State<VistaEstadistica> {
  int year = 0;
  int month = 0;

  int? corredorId;
  String? contrasenia;

  bool _isLoading = false;
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
    year = widget.year;
    month = widget.month;
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id');
    contrasenia = prefs.getString('contrasenia');
    await _fetchStats();
  }

  Map<String, String> _authHeaders() => {
        'X-Corredor-Id': '${corredorId ?? ''}',
        'X-Contrasenia': contrasenia ?? '',
      };

  Future<void> _fetchStats() async {
    if (corredorId == null || contrasenia == null) {
      setState(() {
        _error = 'No hay sesión cargada';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_baseUrl/estadistica/mensual?year=$year&month=$month');
      final resp = await http.get(uri, headers: _authHeaders());
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
      } else if (resp.statusCode == 404) {
        // No hay objetivo; intentar cargar métricas (ya vienen en respuesta 404? no)
        // Para fallback local:
        await _fallbackLocal();
      } else {
        // otro error: fallback local
        await _fallbackLocal();
      }
    } on SocketException catch (_) {
      await _fallbackLocal();
    } on TimeoutException catch (_) {
      await _fallbackLocal();
    } on http.ClientException catch (_) {
      await _fallbackLocal();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fallbackLocal() async {
    // Lee 'races_storage_v1' y calcula métricas del mes (sin objetivo)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('races_storage_v1');
      int _total = 0, _hechas = 0, _pend = 0, _no = 0;
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw) as List;
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final dt = DateTime.parse(m['dateTime'] as String);
          if (dt.year == year && dt.month == month) {
            _total += 1;
            final statusIndex = (m['status'] as int?) ?? 0;
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

  Future<void> _setObjetivo() async {
    final controller = TextEditingController(text: (objetivo ?? '').toString());
    final value = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Objetivo mensual'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad de carreras',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final t = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, t);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null) return;

    try {
      final uri = Uri.parse('$_baseUrl/objetivos/mensual?year=$year&month=$month');
      final resp = await http.post(
        uri,
        headers: {
          ..._authHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'objetivo': value}),
      );
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Objetivo guardado')),
        );
        await _fetchStats();
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

  void _prevMonth() {
    final d = DateTime(year, month, 1);
    final p = DateTime(d.year, d.month - 1, 1);
    setState(() {
      year = p.year;
      month = p.month;
    });
    _fetchStats();
  }

  void _nextMonth() {
    final d = DateTime(year, month, 1);
    final n = DateTime(d.year, d.month + 1, 1);
    setState(() {
      year = n.year;
      month = n.month;
    });
    _fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Estadística $month/$year';
    final ok = !_isLoading && _error == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: backgroundColor,
        actions: [
          IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: _isLoading
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
                  _StatTile(label: 'Objetivo mensual', value: objetivo?.toString() ?? 'No registrado'),
                  const SizedBox(height: 8),
                  _StatTile(label: 'Total programadas', value: '$total'),
                  const SizedBox(height: 8),
                  _StatTile(label: 'Hechas', value: '$hechas'),
                  const SizedBox(height: 8),
                  _StatTile(label: 'No realizadas', value: '$noRealizadas'),
                  const SizedBox(height: 8),
                  _StatTile(label: 'Pendientes', value: '$pendientes'),
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
                      onPressed: (corredorId == null || contrasenia == null) ? null : _setObjetivo,
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

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
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
