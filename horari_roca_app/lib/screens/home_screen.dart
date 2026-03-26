import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horari Roca v3'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(shiftsProvider);
              ref.invalidate(holidaysProvider);
              ref.invalidate(workersProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          WeeklyCalendarView(),
          MyShiftsView(),
          SettingsView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_view_week), label: 'Setmana'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Els Meus'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustos'),
        ],
      ),
    );
  }
}

class WeeklyCalendarView extends ConsumerWidget {
  const WeeklyCalendarView({super.key});

  static const double hourHeight = 85.0;
  static const double dayWidth = 160.0;
  static const int startHour = 7;
  static const int endHour = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(currentWeekProvider);
    final shiftsAsync = ref.watch(shiftsProvider(weekStart));
    final holidaysAsync = ref.watch(holidaysProvider);
    final workersAsync = ref.watch(workersProvider);
    
    return Column(
      children: [
        _WeekNavigator(weekStart: weekStart),
        Expanded(
          child: shiftsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (shifts) => holidaysAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Error Festius')),
              data: (holidays) => _WeeklyTimelineGrid(
                shifts: shifts,
                holidays: holidays,
                weekStart: weekStart,
                hourHeight: hourHeight,
                dayWidth: dayWidth,
                startHour: startHour,
                endHour: endHour,
              ),
            ),
          ),
        ),
        // BOTONERA DE TREBALLADORS
        Container(
          height: 85,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: workersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const Text('Error'),
            data: (workers) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: workers.length,
              itemBuilder: (context, i) => _DraggableWorker(worker: workers[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyTimelineGrid extends ConsumerWidget {
  final List<Shift> shifts;
  final List<String> holidays;
  final DateTime weekStart;
  final double hourHeight;
  final double dayWidth;
  final int startHour;
  final int endHour;

  const _WeeklyTimelineGrid({
    required this.shifts,
    required this.holidays,
    required this.weekStart,
    required this.hourHeight,
    required this.dayWidth,
    required this.startHour,
    required this.endHour,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double gridHeight = (endHour - startHour + 1) * hourHeight;
    final double gridWidth = dayWidth * 7;
    const double labelsWidth = 55.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // INDICADORS D'HORES
          Column(
            children: [
              const SizedBox(height: 70), // Mateixa alçada que la capçalera
              ...List.generate(endHour - startHour + 1, (i) => Container(
                height: hourHeight,
                width: labelsWidth,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 4),
                child: Text('${i + startHour}:00', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              )),
            ],
          ),
          // GRAELLA
          Column(
            children: [
              // CAPÇALERA DIES
              Row(
                children: List.generate(7, (i) {
                  final date = weekStart.add(Duration(days: i));
                  final isHoliday = holidays.contains(DateFormat('yyyy-MM-dd').format(date));
                  return _DayHeaderCell(date: date, width: dayWidth, isHoliday: isHoliday);
                }),
              ),
              // ÀREA INTERACTIVA
              Expanded(
                child: SingleChildScrollView(
                  child: DragTarget<Worker>(
                    onAcceptWithDetails: (details) => _createNewShift(details, context, ref),
                    builder: (context, candidateData, rejectedData) => Stack(
                      children: [
                        _GridBackground(
                          width: gridWidth,
                          height: gridHeight,
                          dayWidth: dayWidth,
                          hourHeight: hourHeight,
                          startHour: startHour,
                          endHour: endHour,
                        ),
                        // LÍNIA 15:00
                        Positioned(
                          top: (15 - startHour) * hourHeight,
                          child: Container(width: gridWidth, height: 2, color: Colors.red.withOpacity(0.3)),
                        ),
                        ...shifts.map((s) => _InteractiveShiftBlock(
                          shift: s,
                          weekStart: weekStart,
                          dayWidth: dayWidth,
                          hourHeight: hourHeight,
                          startHour: startHour,
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _createNewShift(DragTargetDetails<Worker> details, BuildContext context, WidgetRef ref) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localOffset = box.globalToLocal(details.offset);
    
    // CORRECCIÓ DE COORDENADES
    const double labelsWidth = 55.0;
    const double headerHeight = 70.0;
    
    final adjustedDx = localOffset.dx - labelsWidth;
    final adjustedDy = localOffset.dy - headerHeight;
    
    if (adjustedDx < 0 || adjustedDy < 0) return;

    final dayIndex = (adjustedDx / dayWidth).floor();
    final hourOffset = (adjustedDy / hourHeight);
    final totalHours = startHour + hourOffset;
    
    final startH = totalHours.floor();
    final startM = ((totalHours - startH) * 60 / 30).round() * 30;
    
    final finalStartH = startM >= 60 ? startH + 1 : startH;
    final finalStartM = startM >= 60 ? 0 : startM;

    final date = weekStart.add(Duration(days: dayIndex));
    final startTime = '${finalStartH.toString().padLeft(2,'0')}:${finalStartM.toString().padLeft(2,'0')}:00';
    final endTime = '${(finalStartH + 2).toString().padLeft(2,'0')}:${finalStartM.toString().padLeft(2,'0')}:00';

    final newShift = Shift(
      workerName: details.data.name,
      date: DateFormat('yyyy-MM-dd').format(date),
      startTime: startTime,
      endTime: endTime,
      lane: (adjustedDx % dayWidth / (dayWidth / 5)).floor(), // Calcular carril segons posició horitzontal interna del dia
    );

    try {
      await Supabase.instance.client.from('shifts').insert(newShift.toJson());
      ref.invalidate(shiftsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Torn creat!'), duration: Duration(seconds: 1)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _InteractiveShiftBlock extends ConsumerWidget {
  final Shift shift;
  final DateTime weekStart;
  final double dayWidth;
  final double hourHeight;
  final int startHour;

  const _InteractiveShiftBlock({
    required this.shift,
    required this.weekStart,
    required this.dayWidth,
    required this.hourHeight,
    required this.startHour,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.tryParse(shift.date) ?? DateTime.now();
    final dayOffset = date.difference(weekStart).inDays;
    if (dayOffset < 0 || dayOffset > 6) return const SizedBox.shrink();

    final startParts = shift.startTime.split(':');
    final endParts = shift.endTime.split(':');
    final startH = int.parse(startParts[0]);
    final startM = int.parse(startParts[1]);
    final endH = int.parse(endParts[0]);
    final endM = int.parse(endParts[1]);

    final double top = ((startH - startHour) * hourHeight) + (startM / 60 * hourHeight);
    final double durationHrs = (endH - startH) + ((endM - startM) / 60);
    final double height = durationHrs * hourHeight;
    final double laneWidth = (dayWidth - 10) / 5;
    final double left = (dayOffset * dayWidth) + (shift.lane % 5 * laneWidth) + 5;

    final color = AppTheme.workerColors[shift.workerName.hashCode % AppTheme.workerColors.length];

    return Positioned(
      top: top,
      left: left,
      width: laneWidth - 2,
      height: height,
      child: GestureDetector(
        onLongPress: () => _confirmDelete(context, ref),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.92),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: const Offset(0, 1))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Text(shift.workerName.substring(0,1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
              
              // NANSA SUPERIOR (MÉS GRAN)
              Positioned(
                top: -10, left: 0, right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) => _handleResize(d, ref, context, isBottom: false),
                  child: Container(
                    height: 30,
                    alignment: Alignment.center,
                    child: Container(width: 20, height: 4, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(2))),
                  ),
                ),
              ),
              
              // NANSA INFERIOR (MÉS GRAN)
              Positioned(
                bottom: -10, left: 0, right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) => _handleResize(d, ref, context, isBottom: true),
                  child: Container(
                    height: 30,
                    alignment: Alignment.center,
                    child: Container(width: 20, height: 4, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(2))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleResize(DragUpdateDetails d, WidgetRef ref, BuildContext context, {required bool isBottom}) async {
    final pixelsPerHalfHour = hourHeight / 2;
    if (d.delta.dy.abs() < 5) return; // Filtre per evitar salts massa petits

    final startParts = shift.startTime.split(':');
    final endParts = shift.endTime.split(':');
    int startH = int.parse(startParts[0]);
    int startM = int.parse(startParts[1]);
    int endH = int.parse(endParts[0]);
    int endM = int.parse(endParts[1]);

    final double deltaMins = (d.delta.dy / hourHeight) * 60;
    
    if (isBottom) {
      endM += deltaMins.round();
      // Snap a 15 minuts per facilitar l'edició
      endM = (endM / 15).round() * 15;
      while (endM >= 60) { endM -= 60; endH += 1; }
      while (endM < 0) { endM += 60; endH -= 1; }
    } else {
      startM += deltaMins.round();
      startM = (startM / 15).round() * 15;
      while (startM >= 60) { startM -= 60; startH += 1; }
      while (startM < 0) { startM += 60; startH -= 1; }
    }

    if (endH < startH || (endH == startH && endM <= startM)) return;
    if (startH < 7 || endH > 23) return;

    final newStart = '${startH.toString().padLeft(2,'0')}:${startM.toString().padLeft(2,'0')}:00';
    final newEnd = '${endH.toString().padLeft(2,'0')}:${endM.toString().padLeft(2,'0')}:00';

    if (newStart == shift.startTime && newEnd == shift.endTime) return;

    try {
      await Supabase.instance.client.from('shifts').update({
        'start_time': newStart,
        'end_time': newEnd,
      }).eq('id', shift.id);
      ref.invalidate(shiftsProvider);
    } catch (e) {
      // Ignorem errors visuals durant el drag
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Esborrar torn?'),
      content: Text('Vols eliminar el torn de ${shift.workerName}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await Supabase.instance.client.from('shifts').delete().eq('id', shift.id);
            ref.invalidate(shiftsProvider);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Torn eliminat')));
            }
          }, 
          child: const Text('Eliminar', style: TextStyle(color: Colors.white))
        ),
      ],
    ));
  }
}

class _DraggableWorker extends StatelessWidget {
  final Worker worker;
  const _DraggableWorker({required this.worker});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.workerColors[worker.name.hashCode % AppTheme.workerColors.length];
    return Draggable<Worker>(
      data: worker,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10)]),
          child: Text(worker.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4)],
        ),
        child: Center(child: Text(worker.name, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
      ),
    );
  }
}

class _GridBackground extends StatelessWidget {
  final double width, height, dayWidth, hourHeight;
  final int startHour, endHour;
  const _GridBackground({required this.width, required this.height, required this.dayWidth, required this.hourHeight, required this.startHour, required this.endHour});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(children: List.generate(endHour - startHour + 1, (i) => Container(
          height: hourHeight, width: width,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.12)))),
        ))),
        Row(children: List.generate(7, (i) => Container(
          width: dayWidth, height: height,
          decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5))),
        ))),
      ],
    );
  }
}

class _DayHeaderCell extends StatelessWidget {
  final DateTime date;
  final double width;
  final bool isHoliday;
  const _DayHeaderCell({required this.date, required this.width, required this.isHoliday});

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Dll', 'Dmt', 'Dmc', 'Djs', 'Dvn', 'Dss', 'Dmg'];
    final isToday = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Container(
      width: width, height: 70,
      decoration: BoxDecoration(
        color: isHoliday ? Colors.red.withOpacity(0.1) : (isToday ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white),
        border: Border(
          bottom: BorderSide(color: isHoliday ? Colors.red : (isToday ? AppTheme.primaryColor : Colors.grey.shade300), width: 3),
          left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(dayNames[date.weekday - 1], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isHoliday ? Colors.red : Colors.grey.shade600)),
          Text('${date.day}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isHoliday ? Colors.red : (isToday ? AppTheme.primaryColor : Colors.black87))),
        ],
      ),
    );
  }
}

class _WeekNavigator extends ConsumerWidget {
  final DateTime weekStart;
  const _WeekNavigator({required this.weekStart});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('d MMM', 'ca');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(currentWeekProvider.notifier).previousWeek()),
          Text('${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => ref.read(currentWeekProvider.notifier).nextWeek()),
        ],
      ),
    );
  }
}

class MyShiftsView extends ConsumerWidget {
  const MyShiftsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) { return const Center(child: Text('Els meus torns')); }
}

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRoleAsync = ref.watch(userRoleProvider);
    final workersAsync = ref.watch(workersProvider);
    final isDark = ref.watch(darkModeProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Preferències', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Mode Fosc'),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              value: isDark,
              onChanged: (val) => ref.read(darkModeProvider.notifier).set(val),
            ),
          ),
          const SizedBox(height: 24),
          
          // GESTIÓ DE TREBALLADORS (NOMÉS ADMINS)
          userRoleAsync.when(
            data: (role) {
              if (role?.isAdmin != true) return const SizedBox.shrink();
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gestió de Treballadors', style: Theme.of(context).textTheme.titleLarge),
                      IconButton.filled(
                        onPressed: () => _showAddWorkerDialog(context, ref),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  workersAsync.when(
                    data: (workers) => ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workers.length,
                      itemBuilder: (context, i) {
                        final w = workers[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: w.color),
                            title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDeleteWorker(context, ref, w.name),
                            ),
                          ),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error carregant treballadors: $e'),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showAddWorkerDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddWorkerDialog(),
    );
  }

  void _confirmDeleteWorker(BuildContext context, WidgetRef ref, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar treballador?'),
        content: Text('Vols eliminar a $name? Això també eliminarà la seva configuració de calendari.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(workersProvider.notifier).deleteWorker(name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AddWorkerDialog extends ConsumerStatefulWidget {
  const _AddWorkerDialog();

  @override
  ConsumerState<_AddWorkerDialog> createState() => _AddWorkerDialogState();
}

class _AddWorkerDialogState extends ConsumerState<_AddWorkerDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  Color _selectedColor = AppTheme.workerColors[0];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nou Treballador'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom', hintText: 'Ex: Sergi'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email de Google (opcional)',
                hintText: 'Per sincronitzar calendari',
                helperText: 'El treballador rebrà una invitació al calendari.',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            const Text('Color identificatiu:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppTheme.workerColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                      boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel·lar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Guardar'),
        ),
      ],
    );
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(workersProvider.notifier).addWorker(
        name, 
        _selectedColor, 
        _emailController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
