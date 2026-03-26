import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// Provider per a l'estat d'autenticació
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Provider per a l'usuari actual
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// Provider per al rol de l'usuari
final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  
  final response = await Supabase.instance.client
      .from('allowed_users')
      .select()
      .eq('email', user.email ?? '')
      .maybeSingle();
  
  if (response == null) return null;
  return UserRole.fromJson(response);
});

// Provider per a la setmana actual (usando NotifierProvider)
class CurrentWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
  
  void setWeek(DateTime date) {
    state = date;
  }
  
  void nextWeek() {
    state = state.add(const Duration(days: 7));
  }
  
  void previousWeek() {
    state = state.subtract(const Duration(days: 7));
  }
}

final currentWeekProvider = NotifierProvider<CurrentWeekNotifier, DateTime>(
  CurrentWeekNotifier.new,
);

// Notifier per a la gestió de treballadors
class WorkersNotifier extends AsyncNotifier<List<Worker>> {
  @override
  Future<List<Worker>> build() async {
    final response = await Supabase.instance.client
        .from('workers')
        .select()
        .order('name');
    
    return (response as List).map((w) => Worker.fromJson(w)).toList();
  }

  Future<void> addWorker(String name, Color color, String? email) async {
    final worker = Worker(name: name, color: color);
    
    // Inserir a la taula workers
    await Supabase.instance.client.from('workers').insert(worker.toJson());
    
    // Inserir a worker_calendars si hi ha email
    if (email != null && email.isNotEmpty) {
      await Supabase.instance.client.from('worker_calendars').insert({
        'worker_name': name,
        'worker_email': email,
      });
    }
    
    ref.invalidateSelf();
  }

  Future<void> deleteWorker(String name) async {
    // Eliminar de ambdues taules (la FK s'encarregaria si estigués definida, però seguim el model actual)
    await Supabase.instance.client.from('worker_calendars').delete().eq('worker_name', name);
    await Supabase.instance.client.from('workers').delete().eq('name', name);
    
    ref.invalidateSelf();
  }
}

final workersProvider = AsyncNotifierProvider<WorkersNotifier, List<Worker>>(
  WorkersNotifier.new,
);

// Provider per als torns de la setmana
final shiftsProvider = FutureProvider.family<List<Shift>, DateTime>((ref, weekStart) async {
  final weekEnd = weekStart.add(const Duration(days: 6));
  
  final response = await Supabase.instance.client
      .from('shifts')
      .select()
      .gte('date', _formatDate(weekStart))
      .lte('date', _formatDate(weekEnd))
      .order('date')
      .order('start_time');
  
  return (response as List).map((s) => Shift.fromJson(s)).toList();
});

// Provider per als torns d'un treballador específic
final workerShiftsProvider = FutureProvider.family<List<Shift>, String>((ref, workerName) async {
  final now = DateTime.now();
  final twoWeeksLater = now.add(const Duration(days: 14));
  
  final response = await Supabase.instance.client
      .from('shifts')
      .select()
      .eq('worker_name', workerName)
      .gte('date', _formatDate(now))
      .lte('date', _formatDate(twoWeeksLater))
      .order('date')
      .order('start_time');
  
  return (response as List).map((s) => Shift.fromJson(s)).toList();
});

// Provider per al mode fosc
class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

// Provider per a l'estat de guardat
enum SavingState { idle, saving, saved, error }

class SavingStateNotifier extends Notifier<SavingState> {
  @override
  SavingState build() => SavingState.idle;
  
  void set(SavingState value) => state = value;
}

final savingStateProvider = NotifierProvider<SavingStateNotifier, SavingState>(
  SavingStateNotifier.new,
);

// Provider per als festius
final holidaysProvider = FutureProvider<List<String>>((ref) async {
  final response = await Supabase.instance.client
      .from('holidays')
      .select('date');
  
  return (response as List).map((h) => h['date'] as String).toList();
});

// Helper per formatar dates
String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
