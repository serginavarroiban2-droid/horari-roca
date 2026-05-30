import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'shifts_week_screen.dart';
import 'my_shifts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userRoleAsync = ref.watch(userRoleProvider);

    return userRoleAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Error carregant rol'))),
      data: (role) {
        // Treballador sols veu "Els meus" i "Ajustos"
        final isWorker = role?.role == 'treballador';

        final pages = isWorker
            ? <Widget>[const MyShiftsScreen(), const SettingsScreen()]
            : <Widget>[const ShiftsWeekScreen(), const MyShiftsScreen(), const SettingsScreen()];

        final destinations = isWorker
            ? const <NavigationDestination>[
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Els meus'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustos'),
              ]
            : const <NavigationDestination>[
                NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week), label: 'Setmana'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Els meus'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustos'),
              ];

        // Assegurem-nos que l'índex estigui dins del rang de destinacions
        final safeIndex = _selectedIndex.clamp(0, pages.length - 1);

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: destinations,
            height: 65,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black12,
            elevation: 4,
          ),
        );
      },
    );
  }
}
