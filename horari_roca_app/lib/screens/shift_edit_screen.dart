import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ShiftEditScreen extends ConsumerStatefulWidget {
  final Shift? shift;
  final DateTime? initialDate;
  final VoidCallback? onSaved;

  const ShiftEditScreen({
    super.key,
    this.shift,
    this.initialDate,
    this.onSaved,
  });

  @override
  ConsumerState<ShiftEditScreen> createState() => _ShiftEditScreenState();
}

class _ShiftEditScreenState extends ConsumerState<ShiftEditScreen> {
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String? _selectedWorker;
  final _noteController = TextEditingController();
  int _lane = 1;
  bool _isSaving = false;

  bool get _isEditing => widget.shift != null;

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    if (s != null) {
      _selectedDate = DateTime.tryParse(s.date) ?? DateTime.now();
      final start = _parseTime(s.startTime);
      final end = _parseTime(s.endTime);
      _startTime = start;
      _endTime = end;
      _selectedWorker = s.workerName;
      _noteController.text = s.note ?? '';
      _lane = s.lane;
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
    }
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _durationHours() {
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    final diff = endMins - startMins;
    return diff > 0 ? diff / 60.0 : 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      locale: const Locale('ca'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Ajustar end time si cal
        final startMins = picked.hour * 60 + picked.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        if (endMins <= startMins) {
          final newEnd = startMins + 480; // 8h per defecte
          _endTime = TimeOfDay(hour: (newEnd ~/ 60).clamp(0, 23), minute: newEnd % 60);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _save() async {
    if (_selectedWorker == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un treballador')));
      return;
    }
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    if (endMins <= startMins) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'hora de fi ha de ser posterior a la d\'inici')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newShift = Shift(
        id: widget.shift?.id ?? 0,
        workerName: _selectedWorker!,
        date: _formatDate(_selectedDate),
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        note: _noteController.text.trim(),
        lane: _lane,
      );

      if (_isEditing) {
        await ref.read(shiftsCrudProvider.notifier).updateShift(newShift);
      } else {
        await ref.read(shiftsCrudProvider.notifier).createShift(newShift);
      }

      widget.onSaved?.call();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Torn actualitzat' : 'Torn creat')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(workersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar torn' : 'Nou torn'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: workersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workers) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Durada resum
              _DurationSummaryCard(
                durationHours: _durationHours(),
                workerName: _selectedWorker,
                workers: workers,
              ),
              const SizedBox(height: 20),

              // Selecció treballador
              _SectionLabel('Treballador', Icons.person_outline),
              const SizedBox(height: 8),
              _WorkerSelector(
                workers: workers,
                selected: _selectedWorker,
                onChanged: (w) => setState(() => _selectedWorker = w),
              ),
              const SizedBox(height: 20),

              // Data
              _SectionLabel('Data', Icons.calendar_today_outlined),
              const SizedBox(height: 8),
              _DatePicker(date: _selectedDate, onTap: _pickDate),
              const SizedBox(height: 20),

              // Horari
              _SectionLabel('Horari', Icons.access_time_outlined),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _TimePicker(label: 'Inici', time: _startTime, onTap: _pickStartTime)),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: _TimePicker(label: 'Fi', time: _endTime, onTap: _pickEndTime)),
                ],
              ),
              const SizedBox(height: 20),

              // Carril (local)
              _SectionLabel('Local', Icons.store_outlined),
              const SizedBox(height: 8),
              _LaneSelector(lane: _lane, onChanged: (l) => setState(() => _lane = l)),
              const SizedBox(height: 20),

              // Nota
              _SectionLabel('Nota (opcional)', Icons.notes_outlined),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Afegeix una nota...',
                ),
              ),
              const SizedBox(height: 40),

              // Botó guardar principal
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      : Text(_isEditing ? 'Actualitzar torn' : 'Crear torn'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== WIDGETS AUXILIARS ======================

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryColor)),
      ],
    );
  }
}

class _DurationSummaryCard extends StatelessWidget {
  final double durationHours;
  final String? workerName;
  final List<Worker> workers;
  const _DurationSummaryCard({required this.durationHours, required this.workerName, required this.workers});

  @override
  Widget build(BuildContext context) {
    final worker = workerName != null ? workers.firstWhere((w) => w.name == workerName, orElse: () => workers.isNotEmpty ? workers.first : Worker(name: workerName!, color: AppTheme.primaryColor)) : null;
    final color = worker != null ? AppTheme.workerColors[worker.name.hashCode.abs() % AppTheme.workerColors.length] : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 22,
            child: Text(
              workerName?.isNotEmpty == true ? workerName![0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workerName ?? 'Selecciona treballador', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Durada: ${durationHours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text('${durationHours.toStringAsFixed(1)}h', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _WorkerSelector extends StatelessWidget {
  final List<Worker> workers;
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _WorkerSelector({required this.workers, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: workers.isEmpty
          ? const Center(child: Text('Sense treballadors'))
          : DropdownButtonFormField<String>(
              value: selected,
              hint: const Text('Selecciona treballador'),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline, size: 20)),
              items: workers.map((w) {
                final color = AppTheme.workerColors[w.name.hashCode.abs() % AppTheme.workerColors.length];
                return DropdownMenuItem(
                  value: w.name,
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: color, radius: 10, child: Text(w.name[0], style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Text(w.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DatePicker({required this.date, required this.onTap});

  static const List<String> _days = ['dilluns', 'dimarts', 'dimecres', 'dijous', 'divendres', 'dissabte', 'diumenge'];
  static const List<String> _months = ['gener', 'febrer', 'març', 'abril', 'maig', 'juny', 'juliol', 'agost', 'setembre', 'octubre', 'novembre', 'desembre'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(
              '${_days[date.weekday - 1]}, ${date.day} de ${_months[date.month - 1]} ${date.year}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimePicker({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaneSelector extends StatelessWidget {
  final int lane;
  final ValueChanged<int> onChanged;
  const _LaneSelector({required this.lane, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LaneOption(
            label: 'Roca',
            sublabel: 'Carril 1–3',
            icon: Icons.store,
            lanes: [1, 2, 3],
            selected: lane >= 1 && lane <= 3,
            onTap: () => onChanged(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LaneOption(
            label: 'Rambla',
            sublabel: 'Carril 4–6',
            icon: Icons.storefront,
            lanes: [4, 5, 6],
            selected: lane >= 4 && lane <= 6,
            onTap: () => onChanged(4),
          ),
        ),
      ],
    );
  }
}

class _LaneOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final List<int> lanes;
  final bool selected;
  final VoidCallback onTap;

  const _LaneOption({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.lanes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.primaryColor : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? Colors.white : null)),
                Text(sublabel, style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
