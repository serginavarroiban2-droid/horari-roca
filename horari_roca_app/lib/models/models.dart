import 'package:flutter/material.dart';

// Model per a un Treballador
class Worker {
  final String name;
  final Color color;
  final bool selected;

  Worker({
    required this.name,
    required this.color,
    this.selected = true,
  });

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      name: json['name'] ?? '',
      color: _parseColor(json['color']),
      selected: json['selected'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    String hex = color.value.toRadixString(16).padLeft(8, '0');
    return {
      'name': name,
      'color': '#${hex.substring(2)}',
    };
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

// Model per a un Torn
class Shift {
  final dynamic id;
  final String workerName;
  final String date;
  final String startTime;
  final String endTime;
  final String? note;
  final int lane;
  final Color? workerColor;

  Shift({
    this.id,
    required this.workerName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.note,
    this.lane = 0,
    this.workerColor,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      workerName: json['worker_name'] ?? '',
      date: json['date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      note: json['note'],
      lane: json['lane'] is int ? json['lane'] : int.tryParse(json['lane']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'worker_name': workerName,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'note': note ?? '',
      'lane': lane,
    };
  }

  // Obtenir la duració en minuts
  int get durationMinutes {
    try {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      int endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      
      // Si el torn creua mitjanit
      if (endMins <= startMins) endMins += 24 * 60;
      
      return endMins - startMins;
    } catch (e) {
      return 0;
    }
  }

  // Obtenir minuts des de l'inici del dia
  static int timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  // Comprovar si dos torns se superposen
  static bool checkOverlap(Shift s1, Shift s2) {
    if (s1.id == s2.id) return false;
    if (s1.date != s2.date) return false;
    if (s1.lane != s2.lane) return false;

    final start1 = timeToMinutes(s1.startTime);
    final end1 = timeToMinutes(s1.endTime);
    final start2 = timeToMinutes(s2.startTime);
    final end2 = timeToMinutes(s2.endTime);

    // Condició de superposició: (StartA < EndB) && (EndA > StartB)
    return start1 < end2 && end1 > start2;
  }

  // Ubicació basada en lane
  String get location => lane >= 4 ? 'Rambla' : 'Roca';

  // Copiar amb modificacions
  Shift copyWith({
    dynamic id,
    String? workerName,
    String? date,
    String? startTime,
    String? endTime,
    String? note,
    int? lane,
    Color? workerColor,
  }) {
    return Shift(
      id: id ?? this.id,
      workerName: workerName ?? this.workerName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      note: note ?? this.note,
      lane: lane ?? this.lane,
      workerColor: workerColor ?? this.workerColor,
    );
  }
}

// Model per a la configuració d'usuari
class UserRole {
  final String email;
  final String role; // 'admin' o 'viewer'

  UserRole({required this.email, required this.role});

  bool get isAdmin => role == 'admin';

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      email: json['email'] ?? '',
      role: json['role'] ?? 'viewer',
    );
  }
}
