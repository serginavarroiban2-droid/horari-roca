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

// Provider per als treballadors
final workersProvider = FutureProvider<List<Worker>>((ref) async {
  final response = await Supabase.instance.client
      .from('workers')
      .select()
      .order('name');
  
  return (response as List).map((w) => Worker.fromJson(w)).toList();
});

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

// Helper per formatar dates
String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
