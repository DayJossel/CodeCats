// lib/screens/vista_estadistica.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../main.dart'; // Colores
import '../backend/dominio/estadistica.dart';
import '../backend/dominio/modelos/estadistica.dart'; // (ok si no se usa directamente)

class VistaEstadistica extends StatefulWidget {
  final int year;
  final int month;
  const VistaEstadistica({super.key, required this.year, required this.month});

  @override
  State<VistaEstadistica> createState() => _EstadoVistaEstadistica();
}

class _EstadoVistaEstadistica extends State<VistaEstadistica> {
  late int anio;
  late int mes;

  bool _cargando = false;
  String? _error;
  String? _notaFuente; // “Mostrando datos locales (sin objetivo)”
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
    setState(() {
      _cargando = true;
      _error = null;
      _notaFuente = null;
    });
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
      setState(() {
        _error = 'No se pudo cargar estadísticas. $e';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _definirObjetivoCupertinoPicker() async {
    if (!_tieneSesion) return;
    final items = List<int>.generate(60, (i) => i + 1);
    int selected = (objetivo != null && objetivo! >= 1 && objetivo! <= 60) ? objetivo! : 10;
    int index = items.indexOf(selected);

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      builder: (ctx) {
        int localSelected = selected;
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
                      const Text('Establecer Objetivo', style: TextStyle(fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, localSelected),
                        child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: index),
                    itemExtent: 42,
                    onSelectedItemChanged: (i) => localSelected = items[i],
                    children: items.map((v) => Center(child: Text('$v'))).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;

    try {
      await EstadisticaUC.definirObjetivo(year: anio, month: mes, objetivo: result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Objetivo guardado')));
      await _cargarEstadisticas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _mesAnterior() async {
    final d = DateTime(anio, mes, 1);
    final p = DateTime(d.year, d.month - 1, 1);
    setState(() {
      anio = p.year; mes = p.month;
    });
    await _cargarEstadisticas();
  }

  void _mesSiguiente() async {
    final d = DateTime(anio, mes, 1);
    final n = DateTime(d.year, d.month + 1, 1);
    setState(() {
      anio = n.year; mes = n.month;
    });
    await _cargarEstadisticas();
  }

  String _mesLargo(int m) {
    const meses = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];
    return (m >= 1 && m <= 12) ? meses[m - 1] : '$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetivo Mensual'),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Selector de mes
                    Row(
                      children: [
                        IconButton(onPressed: _mesAnterior, icon: const Icon(Icons.chevron_left)),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_mesLargo(mes)} $anio',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        IconButton(onPressed: _mesSiguiente, icon: const Icon(Icons.chevron_right)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_error != null)
                      _BannerInfo(
                        color: Colors.red.withOpacity(0.12),
                        textColor: Colors.redAccent,
                        text: _error!,
                      ),

                    if (_notaFuente != null) ...[
                      const SizedBox(height: 8),
                      _BannerInfo(
                        color: Colors.orange.withOpacity(0.15),
                        textColor: Colors.orange,
                        text: _notaFuente!,
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Tarjeta: Objetivo del mes
                    _CardObjetivo(
                      objetivo: objetivo,
                      hechas: hechas,
                      enabled: _tieneSesion,
                      onTapEditar: _definirObjetivoCupertinoPicker,
                    ),

                    const SizedBox(height: 16),

                    // Grid 2x2 de métricas
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.check_circle,
                            iconColor: Colors.greenAccent,
                            value: '$hechas',
                            label: 'Realizadas',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.hourglass_bottom,
                            iconColor: primaryColor,
                            value: '$pendientes',
                            label: 'Pendientes',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            icon: Icons.cancel,
                            iconColor: Colors.redAccent,
                            value: '$noRealizadas',
                            label: 'No Realizadas',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.event_note,
                            iconColor: Colors.blueAccent,
                            value: '$total',
                            label: 'Total',
                          ),
                        ),
                      ],
                    ),

                    // espacio extra por si el teclado o la barra gestual ocupan lugar
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ),
    );
  }
}

/* =========================
 *  Widgets privados (UI)
 * ========================= */

class _BannerInfo extends StatelessWidget {
  final Color color;
  final Color textColor;
  final String text;
  const _BannerInfo({required this.color, required this.textColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: textColor)),
    );
  }
}

class _CardObjetivo extends StatelessWidget {
  final int? objetivo;
  final int hechas;
  final bool enabled;
  final VoidCallback onTapEditar;

  const _CardObjetivo({
    required this.objetivo,
    required this.hechas,
    required this.enabled,
    required this.onTapEditar,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = (objetivo != null && objetivo! > 0);
    final target = objetivo ?? 0;
    final done = hechas.clamp(0, target);
    final restante = hasGoal ? (target - hechas).clamp(0, target) : null;
    final ratio = hasGoal && target > 0 ? (done / target) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'OBJETIVO DEL MES',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          if (!hasGoal)
            GestureDetector(
              onTap: enabled ? onTapEditar : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Text('Establecer Objetivo',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$target ',
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Carreras',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                if (enabled)
                  InkWell(
                    onTap: onTapEditar,
                    child: const Icon(Icons.edit, size: 18, color: Colors.white70),
                  ),
              ],
            ),

          if (hasGoal) ...[
            const SizedBox(height: 14),
            Row(
              children: const [
                Text('PROGRESO', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              restante == 0 ? '¡Objetivo cumplido!' : 'Faltan $restante para cumplir tu objetivo.',
              style: TextStyle(color: restante == 0 ? Colors.greenAccent : Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Evita el overflow en pantallas pequeñas / escalas de fuente altas
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconColor.withOpacity(0.25),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
