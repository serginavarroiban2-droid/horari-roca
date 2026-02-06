import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ShiftDetailScreen extends StatelessWidget {
  final Shift shift;
  
  const ShiftDetailScreen({super.key, required this.shift});
  
  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(shift.date);
    final dayNames = ['Dilluns', 'Dimarts', 'Dimecres', 'Dijous', 'Divendres', 'Dissabte', 'Diumenge'];
    final dayName = dayNames[date.weekday - 1];
    final color = AppTheme.workerColors[
        shift.workerName.hashCode % AppTheme.workerColors.length];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detall del Torn'),
        backgroundColor: color,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header amb info principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      shift.workerName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    shift.workerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      shift.location,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Info detallada
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _DetailCard(
                    icon: Icons.calendar_today,
                    title: 'Data',
                    value: '$dayName, ${DateFormat('d MMMM yyyy', 'ca').format(date)}',
                  ),
                  _DetailCard(
                    icon: Icons.access_time,
                    title: 'Horari',
                    value: '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}',
                  ),
                  _DetailCard(
                    icon: Icons.hourglass_bottom,
                    title: 'Durada',
                    value: '${(shift.durationMinutes / 60).toStringAsFixed(1)} hores',
                  ),
                  _DetailCard(
                    icon: Icons.store,
                    title: 'Ubicació',
                    value: shift.location == 'Roca' ? 'Botiga Roca' : 'Botiga Rambla',
                  ),
                  if (shift.note != null && shift.note!.isNotEmpty)
                    _DetailCard(
                      icon: Icons.note,
                      title: 'Nota',
                      value: shift.note!,
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Resum visual
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Resum',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            icon: Icons.wb_sunny,
                            label: 'Inici',
                            value: shift.startTime.substring(0, 5),
                            color: Colors.orange,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          _StatItem(
                            icon: Icons.nightlight_round,
                            label: 'Fi',
                            value: shift.endTime.substring(0, 5),
                            color: Colors.indigo,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          _StatItem(
                            icon: Icons.timer,
                            label: 'Total',
                            value: '${(shift.durationMinutes / 60).toStringAsFixed(1)}h',
                            color: AppTheme.accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
