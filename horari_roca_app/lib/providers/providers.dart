import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// ===================== AUTH =====================

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// ===================== ROL =====================

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

// ===================== SETMANA =====================

class CurrentWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  void nextWeek() => state = state.add(const Duration(days: 7));
  void previousWeek() => state = state.subtract(const Duration(days: 7));
  void goToday() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    state = DateTime(monday.year, monday.month, monday.day);
  }
}

final currentWeekProvider = NotifierProvider<CurrentWeekNotifier, DateTime>(
  CurrentWeekNotifier.new,
);

// ===================== TREBALLADORS =====================

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
    await Supabase.instance.client.from('workers').insert(worker.toJson());
    if (email != null && email.isNotEmpty) {
      await Supabase.instance.client.from('worker_calendars').insert({
        'worker_name': name,
        'worker_email': email,
      });
    }
    ref.invalidateSelf();
  }

  Future<void> deleteWorker(String name) async {
    await Supabase.instance.client.from('worker_calendars').delete().eq('worker_name', name);
    await Supabase.instance.client.from('workers').delete().eq('name', name);
    ref.invalidateSelf();
  }
}

final workersProvider = AsyncNotifierProvider<WorkersNotifier, List<Worker>>(
  WorkersNotifier.new,
);

// ===================== TORNS =====================

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

// Torns del treballador lligat al compte Google actual
final myShiftsProvider = FutureProvider<List<Shift>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final email = user.email ?? '';
  final now = DateTime.now();
  final twoWeeksLater = now.add(const Duration(days: 21));

  // Buscar el treballador vinculat a aquest correu
  final calConfig = await Supabase.instance.client
      .from('worker_calendars')
      .select('worker_name')
      .eq('worker_email', email)
      .maybeSingle();

  if (calConfig == null) {
    // Intentem fer-ho per email directe a allowed_users
    return [];
  }

  final workerName = calConfig['worker_name'] as String;

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

// ===================== CRUD TORNS =====================

class ShiftsCrudNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> createShift(Shift shift) async {
    await Supabase.instance.client.from('shifts').insert(shift.toJson());
  }

  Future<void> updateShift(Shift shift) async {
    await Supabase.instance.client.from('shifts').update({
      'worker_name': shift.workerName,
      'date': shift.date,
      'start_time': shift.startTime,
      'end_time': shift.endTime,
      'note': shift.note ?? '',
      'lane': shift.lane,
    }).eq('id', shift.id);
  }

  Future<void> deleteShift(dynamic shiftId) async {
    await Supabase.instance.client.from('shifts').delete().eq('id', shiftId);
  }
}

final shiftsCrudProvider = NotifierProvider<ShiftsCrudNotifier, void>(
  ShiftsCrudNotifier.new,
);

// ===================== GOOGLE SIGN IN =====================

class GoogleSignInNotifier extends AsyncNotifier<void> {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  @override
  Future<void> build() async {}

  Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) return false;

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await Supabase.instance.client.auth.signOut();
  }
}

final googleSignInProvider = AsyncNotifierProvider<GoogleSignInNotifier, void>(
  GoogleSignInNotifier.new,
);

// ===================== ALTRES PROVIDERS =====================

class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

final holidaysProvider = FutureProvider<List<String>>((ref) async {
  final response = await Supabase.instance.client
      .from('holidays')
      .select('date');
  return (response as List).map((h) => h['date'] as String).toList();
});

// ===================== HELPERS =====================

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
