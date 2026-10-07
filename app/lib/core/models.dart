// Modelos de las respuestas de la API (api/src/adherence/adherence.module.ts).

class PlanExercise {
  final int exerciseId;
  final String name;
  final String instructions;
  final String? videoUrl;
  final int sets;
  final int reps;
  final int restSec;

  const PlanExercise({
    required this.exerciseId,
    required this.name,
    required this.instructions,
    this.videoUrl,
    required this.sets,
    required this.reps,
    required this.restSec,
  });

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
        exerciseId: j['exerciseId'] as int,
        name: j['name'] as String,
        instructions: j['instructions'] as String,
        videoUrl: j['videoUrl'] as String?,
        sets: j['sets'] as int,
        reps: j['reps'] as int,
        restSec: j['restSec'] as int,
      );
}

class Prescription {
  final String id;
  final int frequencyPerWeek;
  final String? notes;
  final List<PlanExercise> exercises;

  const Prescription({required this.id, required this.frequencyPerWeek, this.notes, required this.exercises});

  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
        id: j['id'] as String,
        frequencyPerWeek: j['frequencyPerWeek'] as int,
        notes: j['notes'] as String?,
        exercises: (j['exercises'] as List).map((e) => PlanExercise.fromJson(e as Map<String, dynamic>)).toList(),
      );

  int get totalReps => exercises.fold(0, (a, e) => a + e.sets * e.reps);
}

class MeData {
  final String patientName;
  final bool rightArm;
  final String clinicName;
  final String physioName;
  final String? deviceName; // null = sin reloj: apego reportado
  final Prescription? prescription;

  const MeData({
    required this.patientName,
    required this.rightArm,
    required this.clinicName,
    required this.physioName,
    this.deviceName,
    this.prescription,
  });

  factory MeData.fromJson(Map<String, dynamic> j) => MeData(
        patientName: j['patient']['displayName'] as String,
        rightArm: j['patient']['affectedArm'] == 'RIGHT',
        clinicName: j['clinic']['name'] as String,
        physioName: j['physio'] as String,
        deviceName: (j['device'] as Map<String, dynamic>?)?['bleName'] as String?,
        prescription: j['prescription'] == null ? null : Prescription.fromJson(j['prescription'] as Map<String, dynamic>),
      );

  String get firstName => patientName.split(' ').first;
}

enum DayStatus { complete, incomplete, aborted, none }

DayStatus parseDayStatus(String s) => switch (s) {
      'COMPLETE' => DayStatus.complete,
      'INCOMPLETE' => DayStatus.incomplete,
      'ABORTED' => DayStatus.aborted,
      _ => DayStatus.none,
    };

class HistoryDay {
  final DateTime day;
  final DayStatus status;
  const HistoryDay(this.day, this.status);
}

class HistorySession {
  final DateTime startedAt;
  final DayStatus status;
  final bool verified;
  final int repsDone;
  final int repsPrescribed;
  const HistorySession(this.startedAt, this.status, this.verified, this.repsDone, this.repsPrescribed);
}

class HistoryData {
  final List<HistoryDay> calendar;
  final int streak;
  final List<HistorySession> sessions;
  const HistoryData(this.calendar, this.streak, this.sessions);

  factory HistoryData.fromJson(Map<String, dynamic> j) => HistoryData(
        (j['calendar'] as List).map((d) => HistoryDay(DateTime.parse(d['day'] as String), parseDayStatus(d['status'] as String))).toList(),
        j['streak'] as int,
        (j['sessions'] as List).map((s) {
          final results = s['results'] as List;
          return HistorySession(
            DateTime.parse(s['startedAt'] as String).toLocal(),
            parseDayStatus(s['status'] as String),
            s['source'] == 'VERIFIED',
            results.fold(0, (a, r) => a + (r['repsDone'] as int)),
            results.fold(0, (a, r) => a + (r['repsPrescribed'] as int)),
          );
        }).toList(),
      );

  /// ¿Hoy ya hay una sesión completa?
  bool get doneToday {
    final now = DateTime.now();
    return calendar.any((d) => d.day.year == now.year && d.day.month == now.month && d.day.day == now.day && d.status == DayStatus.complete);
  }
}
