import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'shift_edit_screen.dart';

class ShiftsWeekScreen extends ConsumerWidget {
  const ShiftsWeekScreen({super.key});

  static const List<String> _dayNames = [
    'Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte', 'Diumenge'
  ];
  static const List<String> _dayShort = ['Dll', 'Dmt', 'Dmc', 'Djs', 'Dvn', 'Dss', 'Dmg'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(currentWeekProvider);
    final shiftsAsync = ref.watch(shiftsProvider(weekStart));
    final userRoleAsync = ref.watch(userRoleProvider);
    final holidaysAsync = ref.watch(holidaysProvider);
    final isAdmin = userRoleAsync.value?.role == 'admin';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Horari Roca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Anar a avui',
            onPressed: () => ref.read(currentWeekProvider.notifier).goToday(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Actualitzar',
            onPressed: () => ref.invalidate(shiftsProvider),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _createShift(context, ref, weekStart),
              icon: const Icon(Icons.add),
              label: const Text('Nou torn'),
            )
          : null,
      body: Column(
        children: [
          // Navegació setmanal
          _WeekNavigator(weekStart: weekStart),

          // Graella de dies (capçalera horitzontal)
          _DaysHeader(weekStart: weekStart, holidaysAsync: holidaysAsync),

          // Llista de torns
          Expanded(
            child: shiftsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Error: $e', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(shiftsProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (shifts) {
                if (shifts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('Sense torns aquesta setmana',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                        if (isAdmin) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _createShift(context, ref, weekStart),
                            icon: const Icon(Icons.add),
                            label: const Text('Crear primer torn'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Agrupem per dia
                final shiftsByDay = <int, List<Shift>>{};
                for (final s in shifts) {
                  final date = DateTime.tryParse(s.date);
                  if (date == null) continue;
                  final dayOffset = date.difference(weekStart).inDays;
                  if (dayOffset >= 0 && dayOffset <= 6) {
                    shiftsByDay.putIfAbsent(dayOffset, () => []).add(s);
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: 7,
                  itemBuilder: (context, dayIndex) {
                    final dayShifts = shiftsByDay[dayIndex] ?? [];
                    final date = weekStart.add(Duration(days: dayIndex));
                    final isToday = DateFormat('yyyy-MM-dd').format(date) ==
                        DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final holidays = holidaysAsync.value ?? [];
                    final isHoliday = holidays.contains(DateFormat('yyyy-MM-dd').format(date));

                    return _DaySection(
                      dayName: _dayNames[dayIndex],
                      date: date,
                      shifts: dayShifts,
                      isToday: isToday,
                      isHoliday: isHoliday,
                      isAdmin: isAdmin,
                      weekStart: weekStart,
                      onRefresh: () => ref.invalidate(shiftsProvider),
                      onAdd: isAdmin ? () => _createShiftForDay(context, ref, date) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createShift(BuildContext context, WidgetRef ref, DateTime weekStart) async {
    final today = DateTime.now();
    final defaultDate = today.isAfter(weekStart) && today.isBefore(weekStart.add(const Duration(days: 7)))
        ? today
        : weekStart;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftEditScreen(
          initialDate: defaultDate,
          onSaved: () => ref.invalidate(shiftsProvider),
        ),
      ),
    );
  }

  Future<void> _createShiftForDay(BuildContext context, WidgetRef ref, DateTime date) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftEditScreen(
          initialDate: date,
          onSaved: () => ref.invalidate(shiftsProvider),
        ),
      ),
    );
  }
}

// ====================== NAVEGACIÓ SETMANAL ======================

class _WeekNavigator extends ConsumerWidget {
  final DateTime weekStart;
  const _WeekNavigator({required this.weekStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM', 'ca');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(currentWeekProvider.notifier).previousWeek(),
          ),
          Text(
            '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}'.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(currentWeekProvider.notifier).nextWeek(),
          ),
        ],
      ),
    );
  }
}

// ====================== CAPÇALERA DIES ======================

class _DaysHeader extends StatelessWidget {
  final DateTime weekStart;
  final AsyncValue<List<String>> holidaysAsync;

  const _DaysHeader({required this.weekStart, required this.holidaysAsync});

  static const List<String> _dayShort = ['Dll', 'Dmt', 'Dmc', 'Djs', 'Dvn', 'Dss', 'Dmg'];

  @override
  Widget build(BuildContext context) {
    final holidays = holidaysAsync.value ?? [];
    return Container(
      height: 58,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: List.generate(7, (i) {
          final date = weekStart.add(Duration(days: i));
          final isToday = DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          final isHoliday = holidays.contains(DateFormat('yyyy-MM-dd').format(date));

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              decoration: BoxDecoration(
                color: isHoliday
                    ? Colors.red.withOpacity(0.15)
                    : isToday
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayShort[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white : (isHoliday ? Colors.red : Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : (isHoliday ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ====================== SECCIÓ DIA ======================

class _DaySection extends ConsumerWidget {
  final String dayName;
  final DateTime date;
  final List<Shift> shifts;
  final bool isToday;
  final bool isHoliday;
  final bool isAdmin;
  final DateTime weekStart;
  final VoidCallback onRefresh;
  final VoidCallback? onAdd;

  const _DaySection({
    required this.dayName,
    required this.date,
    required this.shifts,
    required this.isToday,
    required this.isHoliday,
    required this.isAdmin,
    required this.weekStart,
    required this.onRefresh,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shifts.isEmpty && !isToday) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capçalera del dia
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHoliday
                        ? Colors.red.withOpacity(0.1)
                        : isToday
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHoliday
                          ? Colors.red.shade200
                          : isToday
                              ? AppTheme.primaryColor.withOpacity(0.4)
                              : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$dayName ${date.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isHoliday ? Colors.red : (isToday ? AppTheme.primaryColor : null),
                        ),
                      ),
                      if (isHoliday) ...[
                        const SizedBox(width: 4),
                        const Text('🎉', style: TextStyle(fontSize: 12)),
                      ],
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Avui', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                if (onAdd != null)
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                    ),
                  ),
              ],
            ),
          ),

          // Torns del dia
          if (shifts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Sense torns', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            )
          else
            ...shifts.map((shift) => _ShiftCard(
              shift: shift,
              isAdmin: isAdmin,
              onRefresh: onRefresh,
            )),

          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

// ====================== TARGETA TORN ======================

class _ShiftCard extends ConsumerWidget {
  final Shift shift;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _ShiftCard({required this.shift, required this.isAdmin, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.workerColors[shift.workerName.hashCode.abs() % AppTheme.workerColors.length];
    final start = shift.startTime.length >= 5 ? shift.startTime.substring(0, 5) : shift.startTime;
    final end = shift.endTime.length >= 5 ? shift.endTime.substring(0, 5) : shift.endTime;
    final location = shift.lane >= 4 ? 'Rambla' : 'Roca';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAdmin ? () => _editShift(context, ref) : null,
          onLongPress: isAdmin ? () => _confirmDelete(context, ref) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 12),

                // Info treballador
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.workerName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_outlined, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('$start – $end',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(width: 10),
                          Icon(Icons.store_outlined, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      if (shift.note != null && shift.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(shift.note!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),

                // Durada
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(shift.durationMinutes / 60).toStringAsFixed(1)}h',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 4),
                      Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade400),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editShift(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftEditScreen(
          shift: shift,
          onSaved: onRefresh,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar torn?'),
        content: Text('Vols eliminar el torn de ${shift.workerName}?\n${shift.startTime.substring(0, 5)} – ${shift.endTime.substring(0, 5)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(shiftsCrudProvider.notifier).deleteShift(shift.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Torn eliminat')));
              }
              onRefresh();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
