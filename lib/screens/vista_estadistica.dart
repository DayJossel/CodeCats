import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // Importa para usar los colores globales

// Modelos de datos (idealmente en un archivo compartido)
enum RaceStatus { pendiente, hecha, noRealizada }

class Race {
  int id;
  String title;
  DateTime dateTime;
  RaceStatus status;

  Race({
    required this.id,
    required this.title,
    required this.dateTime,
    this.status = RaceStatus.pendiente,
  });
}

class VistaEstadistica extends StatefulWidget {
  const VistaEstadistica({super.key});

  @override
  State<VistaEstadistica> createState() => _VistaEstadisticaState();
}

class _VistaEstadisticaState extends State<VistaEstadistica> {
  late DateTime _focusedMonth;
  bool _isLoading = true;

  // Simulación de datos
  int? _monthlyGoal;
  List<Race> _racesForMonth = [];
  final Map<DateTime, int> _goalsDatabase = {};
  final List<Race> _allRaces = [];

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
    _generateDummyData();
    _fetchDataForMonth();
  }
  
  void _generateDummyData() {
     final now = DateTime.now();
     final lastMonth = DateTime(now.year, now.month - 1, 1);
    _allRaces.addAll([
      Race(id: 1, title: "Carrera Matutina", dateTime: now.subtract(const Duration(days: 2)), status: RaceStatus.hecha),
      Race(id: 2, title: "Entrenamiento Parque", dateTime: now.subtract(const Duration(days: 5)), status: RaceStatus.hecha),
      Race(id: 3, title: "Trote ligero", dateTime: now.subtract(const Duration(days: 1)), status: RaceStatus.noRealizada),
      Race(id: 4, title: "Carrera de 10k", dateTime: now.add(const Duration(days: 3)), status: RaceStatus.pendiente),
      Race(id: 5, title: "Carrera de 5k", dateTime: lastMonth.add(const Duration(days: 10)), status: RaceStatus.hecha),
    ]);
     _goalsDatabase[DateTime(now.year, now.month, 1)] = 5;
     _goalsDatabase[DateTime(lastMonth.year, lastMonth.month, 1)] = 8;
  }

  Future<void> _fetchDataForMonth() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    setState(() {
      _racesForMonth = _allRaces.where((race) {
        return race.dateTime.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
               race.dateTime.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      }).toList();
      _monthlyGoal = _goalsDatabase[firstDayOfMonth];
      _isLoading = false;
    });
  }
  
  void _changeMonth(int increment) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + increment, 1);
    });
    _fetchDataForMonth();
  }

  // --- FUNCIÓN ACTUALIZADA: USA UN SELECTOR ESTILO IOS ---
  void _showSetGoalDialog() {
    int selectedGoal = _monthlyGoal ?? 10; // Valor inicial para el picker
    
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    Text(
                      _monthlyGoal == null ? 'Establecer Objetivo' : 'Modificar Objetivo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () {
                        _saveNewGoal(selectedGoal);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40.0,
                  scrollController: FixedExtentScrollController(initialItem: selectedGoal - 1),
                  onSelectedItemChanged: (index) {
                    selectedGoal = index + 1;
                  },
                  children: List<Widget>.generate(100, (index) {
                    return Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _saveNewGoal(int goal) {
     final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
     setState(() {
       _goalsDatabase[firstDayOfMonth] = goal;
       _monthlyGoal = goal;
     });
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objetivo guardado con éxito.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final carrerasHechas = _racesForMonth.where((r) => r.status == RaceStatus.hecha).length;
    final carrerasPendientes = _racesForMonth.where((r) => r.status == RaceStatus.pendiente).length;
    final carrerasNoRealizadas = _racesForMonth.where((r) => r.status == RaceStatus.noRealizada).length;
    
    final progreso = (_monthlyGoal != null && _monthlyGoal! > 0) ? (carrerasHechas / _monthlyGoal!) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetivo Mensual'),
        elevation: 0,
        backgroundColor: backgroundColor,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonthSelector(
                focusedMonth: _focusedMonth,
                onPreviousMonth: () => _changeMonth(-1),
                onNextMonth: () => _changeMonth(1),
              ),
              const SizedBox(height: 24),
              _GoalCard(
                goal: _monthlyGoal,
                onSetGoal: _showSetGoalDialog,
              ),
              const SizedBox(height: 16),
              if (_monthlyGoal != null)
                _ProgressCard(
                  progress: progreso,
                  racesDone: carrerasHechas,
                  goal: _monthlyGoal!,
                ),
              const SizedBox(height: 24),
              
              // --- LAYOUT DE ESTADÍSTICAS MEJORADO ---
              Row(
                children: [
                  Expanded(child: _StatTile(label: 'Realizadas', value: '$carrerasHechas', icon: Icons.check_circle, color: Colors.greenAccent)),
                  const SizedBox(width: 16),
                  Expanded(child: _StatTile(label: 'Pendientes', value: '$carrerasPendientes', icon: Icons.hourglass_top, color: Colors.orangeAccent)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _StatTile(label: 'No Realizadas', value: '$carrerasNoRealizadas', icon: Icons.cancel, color: Colors.redAccent)),
                  const SizedBox(width: 16),
                  Expanded(child: _StatTile(label: 'Total', value: '${_racesForMonth.length}', icon: Icons.calendar_today, color: Colors.blueAccent)),
                ],
              ),
            ],
          ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _MonthSelector extends StatelessWidget {
  final DateTime focusedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _MonthSelector({required this.focusedMonth, required this.onPreviousMonth, required this.onNextMonth});

  @override
  Widget build(BuildContext context) {
    const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    final monthName = meses[focusedMonth.month - 1];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPreviousMonth),
        Text('$monthName ${focusedMonth.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNextMonth),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final int? goal;
  final VoidCallback onSetGoal;
  
  const _GoalCard({this.goal, required this.onSetGoal});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      child: InkWell(
        onTap: onSetGoal,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'OBJETIVO DEL MES',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (goal != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$goal Carreras',
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.edit, color: Colors.grey[600], size: 18),
                  ],
                )
              else
                const Text('Establecer Objetivo'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final double progress;
  final int racesDone;
  final int goal;

  const _ProgressCard({required this.progress, required this.racesDone, required this.goal});

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isCompleted = clampedProgress >= 1.0;
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PROGRESO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                Text('$racesDone / $goal', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            const SizedBox(height: 12),
            if (isCompleted)
              const Text('¡Felicidades! Objetivo cumplido.', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
            else
               Text('Faltan ${goal - racesDone} para cumplir tu objetivo.', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}