import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'shift_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userRole = ref.watch(userRoleProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horari Roca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(shiftsProvider);
              ref.invalidate(workersProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
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
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week),
            label: 'Setmana',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Els Meus',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustos',
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tancar sessió'),
        content: const Text('Segur que vols sortir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel·lar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sortir'),
          ),
        ],
      ),
    );
  }
}

// Vista del calendari setmanal
class WeeklyCalendarView extends ConsumerWidget {
  const WeeklyCalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(currentWeekProvider);
    final shiftsAsync = ref.watch(shiftsProvider(weekStart));
    
    return Column(
      children: [
        // Navegació setmana
        _WeekNavigator(weekStart: weekStart),
        
        // Capçalera dies
        _DaysHeader(weekStart: weekStart),
        
        // Llista de torns
        Expanded(
          child: shiftsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (shifts) => _ShiftsList(shifts: shifts, weekStart: weekStart),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(currentWeekProvider.notifier).previousWeek();
            },
          ),
          GestureDetector(
            onTap: () => _pickWeek(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(currentWeekProvider.notifier).nextWeek();
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _pickWeek(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: weekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      // Obtenir dilluns de la setmana seleccionada
      final monday = picked.subtract(Duration(days: picked.weekday - 1));
      ref.read(currentWeekProvider.notifier).setWeek(
          DateTime(monday.year, monday.month, monday.day));
    }
  }
}

class _DaysHeader extends StatelessWidget {
  final DateTime weekStart;
  
  const _DaysHeader({required this.weekStart});
  
  @override
  Widget build(BuildContext context) {
    final days = ['Dl', 'Dt', 'Dc', 'Dj', 'Dv', 'Ds', 'Dg'];
    final today = DateTime.now();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
          
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: isToday ? BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ) : null,
              child: Column(
                children: [
                  Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppTheme.primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: isToday ? const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ) : null,
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.white : null,
                      ),
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

class _ShiftsList extends StatelessWidget {
  final List<Shift> shifts;
  final DateTime weekStart;
  
  const _ShiftsList({required this.shifts, required this.weekStart});
  
  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hi ha torns aquesta setmana',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    // Agrupar torns per dia
    final Map<String, List<Shift>> shiftsByDay = {};
    for (var shift in shifts) {
      shiftsByDay.putIfAbsent(shift.date, () => []).add(shift);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 7,
      itemBuilder: (context, dayIndex) {
        final date = weekStart.add(Duration(days: dayIndex));
        final dateStr = _formatDate(date);
        final dayShifts = shiftsByDay[dateStr] ?? [];
        
        if (dayShifts.isEmpty) return const SizedBox.shrink();
        
        return _DayCard(
          date: date,
          shifts: dayShifts,
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final List<Shift> shifts;
  
  const _DayCard({required this.date, required this.shifts});
  
  @override
  Widget build(BuildContext context) {
    final dayNames = ['Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte', 'Diumenge'];
    final dayName = dayNames[date.weekday - 1];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del dia
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  dayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('d/M').format(date),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Llista de torns
          ...shifts.map((shift) => _ShiftTile(shift: shift)),
        ],
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  
  const _ShiftTile({required this.shift});
  
  @override
  Widget build(BuildContext context) {
    final color = AppTheme.workerColors[
        shift.workerName.hashCode % AppTheme.workerColors.length];
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShiftDetailScreen(shift: shift),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: 4),
          ),
        ),
        child: Row(
          children: [
            // Indicador de color
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                shift.workerName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Informació
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.workerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: shift.location == 'Roca' 
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          shift.location,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: shift.location == 'Roca' 
                                ? Colors.blue.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Duració
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(shift.durationMinutes / 60).toStringAsFixed(1)}h',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (shift.note != null && shift.note!.isNotEmpty)
                  const Icon(Icons.note, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Vista dels meus torns
class MyShiftsView extends ConsumerWidget {
  const MyShiftsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    // Obtenir el nom del treballador a partir de l'email o user metadata
    final workerName = user?.userMetadata?['name'] ?? 
                       user?.email?.split('@').first ?? 'Usuari';
    
    final shiftsAsync = ref.watch(workerShiftsProvider(workerName));
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      workerName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workerName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Pròxims 14 dies',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Llista de torns
          Expanded(
            child: shiftsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (shifts) {
                if (shifts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.beach_access, 
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('No tens torns programats!'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: shifts.length,
                  itemBuilder: (context, index) {
                    final shift = shifts[index];
                    return _MyShiftCard(shift: shift);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MyShiftCard extends StatelessWidget {
  final Shift shift;
  
  const _MyShiftCard({required this.shift});
  
  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(shift.date);
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isToday ? AppTheme.primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isToday ? AppTheme.primaryColor : 
                   isPast ? Colors.grey.shade300 : AppTheme.accentColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: isToday || !isPast ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                DateFormat('MMM').format(date).toUpperCase(),
                style: TextStyle(
                  color: isToday || !isPast ? Colors.white70 : Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isPast ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(shift.location),
        trailing: Text(
          '${(shift.durationMinutes / 60).toStringAsFixed(1)}h',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// Vista d'ajustos
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDarkMode = ref.watch(darkModeProvider);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Informació usuari
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'Usuari',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Opcions
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Mode fosc'),
                value: isDarkMode,
                onChanged: (value) {
                  ref.read(darkModeProvider.notifier).set(value);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sincronitzar ara'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.invalidate(shiftsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronitzant...')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Versió'),
                trailing: const Text('1.0.0'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Peu
        Center(
          child: Text(
            'Horari Roca © ${DateTime.now().year}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
