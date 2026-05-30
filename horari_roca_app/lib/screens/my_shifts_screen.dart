import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MyShiftsScreen extends ConsumerWidget {
  const MyShiftsScreen({super.key});

  static const List<String> _dayNames = [
    'Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte', 'Diumenge'
  ];
  static const List<String> _monthNames = [
    'gen', 'feb', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'oct', 'nov', 'des'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myShiftsAsync = ref.watch(myShiftsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Els meus torns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(myShiftsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header d'usuari
          if (user != null) _UserHeader(user: user),

          // Llista de torns
          Expanded(
            child: myShiftsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text('No s\'han pogut carregar els torns', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Comprova que el teu correu\nestà vinculat a un treballador',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(myShiftsProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reintentar'),
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
                        Icon(Icons.event_available_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('Sense torns propers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('No tens torns als propers 21 dies',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                // Resum d'hores setmanals
                final totalHours = shifts.fold<double>(0.0, (sum, s) => sum + s.durationMinutes / 60.0);

                return Column(
                  children: [
                    _SummaryBar(totalHours: totalHours, shiftCount: shifts.length),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: shifts.length,
                        itemBuilder: (context, i) {
                          final shift = shifts[i];
                          final date = DateTime.tryParse(shift.date) ?? DateTime.now();
                          final isToday = DateFormat('yyyy-MM-dd').format(date) ==
                              DateFormat('yyyy-MM-dd').format(DateTime.now());
                          final isTomorrow = DateFormat('yyyy-MM-dd').format(date) ==
                              DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));

                          return _MyShiftCard(
                            shift: shift,
                            date: date,
                            isToday: isToday,
                            isTomorrow: isTomorrow,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final dynamic user;
  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final email = user.email ?? '';
    final name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? email.split('@').first;
    final avatarUrl = user.userMetadata?['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Text('Connectat', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final double totalHours;
  final int shiftCount;
  const _SummaryBar({required this.totalHours, required this.shiftCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Torns propers', value: '$shiftCount', icon: Icons.calendar_today),
          Container(width: 1, height: 32, color: Colors.white38),
          _StatItem(label: 'Hores totals', value: '${totalHours.toStringAsFixed(1)}h', icon: Icons.access_time),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

class _MyShiftCard extends StatelessWidget {
  final Shift shift;
  final DateTime date;
  final bool isToday;
  final bool isTomorrow;

  const _MyShiftCard({
    required this.shift,
    required this.date,
    required this.isToday,
    required this.isTomorrow,
  });

  static const List<String> _days = ['Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte', 'Diumenge'];
  static const List<String> _months = ['gen', 'feb', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'oct', 'nov', 'des'];

  @override
  Widget build(BuildContext context) {
    final start = shift.startTime.length >= 5 ? shift.startTime.substring(0, 5) : shift.startTime;
    final end = shift.endTime.length >= 5 ? shift.endTime.substring(0, 5) : shift.endTime;
    final location = shift.lane >= 4 ? 'Rambla' : 'Roca';
    final color = isToday ? AppTheme.primaryColor : (isTomorrow ? AppTheme.accentColor : Colors.blueGrey.shade400);
    final durationHours = shift.durationMinutes / 60.0;

    String dateLabel;
    if (isToday) dateLabel = 'Avui';
    else if (isTomorrow) dateLabel = 'Demà';
    else dateLabel = '${_days[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(isToday ? 0.4 : 0.15), width: isToday ? 2 : 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Data lateral
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${date.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  Text(_months[date.month - 1].toUpperCase(), style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(dateLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                          child: const Text('AVUI', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('$start – $end', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                      Icon(Icons.store_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(location, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                  if (shift.note != null && shift.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(shift.note!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),

            // Hores
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${durationHours.toStringAsFixed(1)}h',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
